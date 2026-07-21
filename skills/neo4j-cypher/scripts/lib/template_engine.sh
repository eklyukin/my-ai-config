#!/bin/bash
# Neo4j Template Engine
# Handles YAML template discovery, parsing, validation, and query rendering

set -eo pipefail

# Get SKILL_DIR (assume script is in $SKILL_DIR/scripts/lib/)
TEMPLATE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_SKILL_DIR="$(cd "$TEMPLATE_SCRIPT_DIR/../.." && pwd)"

# Function: Get template search paths in precedence order
# Returns: List of directories to search (newline-separated)
# Precedence: Project (.claude/) > Skill (skill dir) > User (~/.claude/)
get_template_search_paths() {
    local paths=()

    # 1. Project-level templates (highest precedence)
    if [[ -d ".claude/neo4j-templates" ]]; then
        paths+=(".claude/neo4j-templates")
    fi

    # 2. Skill-bundled templates
    if [[ -d "$TEMPLATE_SKILL_DIR/templates" ]]; then
        paths+=("$TEMPLATE_SKILL_DIR/templates")
    fi

    # 3. User-level templates (lowest precedence)
    if [[ -d "$HOME/.claude/neo4j-templates" ]]; then
        paths+=("$HOME/.claude/neo4j-templates")
    fi

    printf '%s\n' "${paths[@]}"
}

# Function: Find template file by name
# Args: $1=template_name
# Returns: Absolute path to template file
# Exit: 0 (found), 1 (not found)
find_template_file() {
    local template_name="$1"

    if [[ -z "$template_name" ]]; then
        if declare -f log_error >/dev/null 2>&1; then
            log_error "find_template_file: template_name required"
        fi
        return 1
    fi

    # Debug search paths
    if declare -f log_debug >/dev/null 2>&1; then
        log_debug "Searching for template: $template_name"
        log_debug "TEMPLATE_SKILL_DIR: $TEMPLATE_SKILL_DIR"
    fi

    # Search paths in precedence order
    while IFS= read -r search_path; do
        if declare -f log_debug >/dev/null 2>&1; then
            log_debug "  Checking: $search_path"
        fi

        local template_file="$search_path/${template_name}.yaml"

        if [[ -f "$template_file" ]]; then
            if declare -f log_debug >/dev/null 2>&1; then
                log_debug "  Found: $template_file"
            fi
            echo "$template_file"
            return 0
        fi
    done < <(get_template_search_paths)

    if declare -f log_debug >/dev/null 2>&1; then
        log_debug "Template not found: $template_name"
    fi
    return 1
}

# Function: Parse YAML template to JSON
# Args: $1=template_file_path
# Returns: Template as JSON
parse_yaml_template() {
    local template_file="$1"

    if [[ ! -f "$template_file" ]]; then
        log_error "Template file not found: $template_file"
        return 1
    fi

    # Use Python YAML parser
    if ! python3 "$TEMPLATE_SCRIPT_DIR/yaml_parser.py" < "$template_file" 2>/dev/null; then
        log_error "Failed to parse YAML template: $template_file"
        log_error "Check YAML syntax or install PyYAML: pip3 install pyyaml"
        return 1
    fi
}

# Function: Sanitize identifier for Cypher labels/properties
# Args: $1=identifier_value
# Returns: Sanitized identifier (only alphanumeric + underscore)
# Exit: 0 (valid), 1 (invalid)
sanitize_identifier() {
    local input="$1"

    # Only allow: letters, numbers, underscore
    # Not starting with number
    if [[ "$input" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo "$input"
        return 0
    else
        log_error "Invalid identifier: '$input'"
        log_error "Must match: ^[a-zA-Z_][a-zA-Z0-9_]*$"
        return 1
    fi
}

# Function: Validate parameter type
# Args: $1=param_name, $2=param_value, $3=param_type
# Returns: Validated value (may be coerced)
# Exit: 0 (valid), 1 (invalid)
validate_param_type() {
    local param_name="$1"
    local param_value="$2"
    local param_type="${3:-string}"

    case "$param_type" in
        string)
            # Always valid (any input coerces to string)
            echo "$param_value"
            return 0
            ;;
        integer)
            # Validate numeric
            if [[ "$param_value" =~ ^-?[0-9]+$ ]]; then
                echo "$param_value"
                return 0
            else
                log_error "Parameter '$param_name' must be integer, got: $param_value"
                return 1
            fi
            ;;
        boolean)
            # Coerce to true/false
            case "${param_value,,}" in
                true|1|yes) echo "true"; return 0 ;;
                false|0|no) echo "false"; return 0 ;;
                *) log_error "Parameter '$param_name' must be boolean"; return 1 ;;
            esac
            ;;
        array)
            # Validate JSON array
            if echo "$param_value" | json_get "." &>/dev/null && \
               [[ "$(echo "$param_value" | json_get "type")" == "array" ]]; then
                echo "$param_value"
                return 0
            else
                log_error "Parameter '$param_name' must be JSON array"
                return 1
            fi
            ;;
        object)
            # Validate JSON object
            if echo "$param_value" | json_get "." &>/dev/null && \
               [[ "$(echo "$param_value" | json_get "type")" == "object" ]]; then
                echo "$param_value"
                return 0
            else
                log_error "Parameter '$param_name' must be JSON object"
                return 1
            fi
            ;;
        *)
            # Unknown type - treat as string
            echo "$param_value"
            return 0
            ;;
    esac
}

# Function: Apply parameter defaults and validate
# Args: $1=template_json, $2=user_params_json
# Returns: Validated params JSON
apply_param_defaults() {
    local template_json="$1"
    local user_params_json="$2"

    # Use empty JSON object if no params provided
    if [[ -z "$user_params_json" ]]; then
        user_params_json='{}'
    fi

    local validated_params='{}'

    # Get parameter specs from template
    local param_specs
    param_specs=$(echo "$template_json" | json_get ".parameters" 2>/dev/null)

    if [[ -z "$param_specs" ]] || [[ "$param_specs" == "null" ]]; then
        # No parameters defined
        echo "{}"
        return 0
    fi

    # Iterate over parameter names
    local param_names
    if [[ "$HAS_JQ" == "true" ]]; then
        param_names=$(echo "$param_specs" | jq -r 'keys[]')
    else
        param_names=$(echo "$param_specs" | python3 -c "import json,sys; print('\n'.join(json.load(sys.stdin).keys()))")
    fi

    while IFS= read -r param_name; do
        # Get parameter spec
        local param_spec
        param_spec=$(echo "$param_specs" | json_get ".${param_name}")

        # Extract spec fields
        local is_required=$(echo "$param_spec" | json_get ".required" 2>/dev/null)
        [[ "$is_required" == "null" ]] && is_required="false"

        local param_type=$(echo "$param_spec" | json_get ".type" 2>/dev/null)
        [[ "$param_type" == "null" ]] && param_type="string"

        local default_value=$(echo "$param_spec" | json_get ".default" 2>/dev/null)

        # Check if user provided value
        local user_value=$(echo "$user_params_json" | json_get ".${param_name}" 2>/dev/null)

        if [[ -n "$user_value" ]] && [[ "$user_value" != "null" ]]; then
            # Validate user-provided value
            local validated_value
            if ! validated_value=$(validate_param_type "$param_name" "$user_value" "$param_type"); then
                return 1
            fi

            # Add to validated params
            if [[ "$HAS_JQ" == "true" ]]; then
                validated_params=$(echo "$validated_params" | jq \
                    --arg key "$param_name" \
                    --arg val "$validated_value" \
                    '.[$key] = $val')
            else
                validated_params=$(python3 -c "
import json
data = json.loads('''$validated_params''')
data['$param_name'] = '$validated_value'
print(json.dumps(data))
")
            fi

        elif [[ "$default_value" != "null" ]]; then
            # Use default value
            if [[ "$HAS_JQ" == "true" ]]; then
                validated_params=$(echo "$validated_params" | jq \
                    --arg key "$param_name" \
                    --argjson val "$default_value" \
                    '.[$key] = $val')
            else
                validated_params=$(python3 -c "
import json
data = json.loads('''$validated_params''')
data['$param_name'] = json.loads('''$default_value''')
print(json.dumps(data))
")
            fi

        elif [[ "$is_required" == "true" ]]; then
            # Required but missing
            log_error "Missing required parameter: $param_name"
            return 1
        fi
    done <<< "$param_names"

    echo "$validated_params"
}

# Function: Render query with two substitution styles
# Args: $1=template_json, $2=validated_params_json
# Returns: Two-line output: rendered_query \n cypher_params_json
render_query() {
    local template_json="$1"
    local params_json="$2"

    # Extract query from template
    local query
    query=$(echo "$template_json" | json_get ".query")

    # Phase 1: Substitute ${param} style (string interpolation)
    # Extract all ${param} placeholders
    local dollar_brace_params
    dollar_brace_params=$(echo "$query" | grep -oE '\$\{[a-zA-Z_][a-zA-Z0-9_]*\}' | sed 's/[${}]//g' | sort -u)

    while IFS= read -r param; do
        [[ -z "$param" ]] && continue

        # Get value from params_json
        local param_value
        param_value=$(echo "$params_json" | json_get ".${param}" 2>/dev/null)

        if [[ -n "$param_value" ]] && [[ "$param_value" != "null" ]]; then
            # Sanitize for Cypher identifier usage
            local safe_value
            if ! safe_value=$(sanitize_identifier "$param_value"); then
                log_error "Cannot use parameter '${param}' as Cypher identifier"
                return 1
            fi

            # Replace ${param} with sanitized value
            query="${query//\$\{${param}\}/${safe_value}}"
        fi
    done <<< "$dollar_brace_params"

    # Phase 2: Extract $param style (Cypher parameters)
    # These remain as $param in query, but we build params object
    local dollar_params
    dollar_params=$(echo "$query" | grep -oE '\$[a-zA-Z_][a-zA-Z0-9_]*' | sed 's/\$//' | sort -u)

    local cypher_params="{}"

    while IFS= read -r param; do
        [[ -z "$param" ]] && continue

        # Get value from params_json
        local param_value
        param_value=$(echo "$params_json" | json_get ".${param}" 2>/dev/null)

        if [[ -n "$param_value" ]] && [[ "$param_value" != "null" ]]; then
            # Add to cypher params object
            if [[ "$HAS_JQ" == "true" ]]; then
                cypher_params=$(echo "$cypher_params" | jq \
                    --arg key "$param" \
                    --argjson val "\"$param_value\"" \
                    '.[$key] = $val')
            else
                cypher_params=$(python3 -c "
import json
data = json.loads('''$cypher_params''')
data['$param'] = '''$param_value'''
print(json.dumps(data))
")
            fi
        fi
    done <<< "$dollar_params"

    # Output both (separated by delimiter)
    echo "$query"
    echo "---PARAMS---"
    echo "$cypher_params"
}

# Function: List all available templates
# Returns: JSON array of template metadata
list_all_templates() {
    local templates_json="[]"
    local seen_names=()

    # Iterate search paths (precedence order)
    while IFS= read -r search_path; do
        # Find all YAML files (exclude _examples)
        find "$search_path" -maxdepth 1 -name "*.yaml" -type f 2>/dev/null | while read -r template_file; do
            # Skip _examples directory
            if [[ "$(dirname "$template_file")" =~ _examples ]]; then
                continue
            fi

            # Parse template
            local template_json
            template_json=$(parse_yaml_template "$template_file" 2>/dev/null) || continue

            local name=$(echo "$template_json" | json_get ".name" 2>/dev/null)
            local description=$(echo "$template_json" | json_get ".description" 2>/dev/null)
            local version=$(echo "$template_json" | json_get ".version" 2>/dev/null)

            [[ -z "$name" ]] && continue

            # Skip if already seen (precedence)
            if [[ " ${seen_names[@]} " =~ " ${name} " ]]; then
                continue
            fi
            seen_names+=("$name")

            # Add to templates array
            if [[ "$HAS_JQ" == "true" ]]; then
                templates_json=$(echo "$templates_json" | jq \
                    --arg name "$name" \
                    --arg desc "$description" \
                    --arg ver "$version" \
                    --arg src "$template_file" \
                    '. + [{name: $name, description: $desc, version: $ver, source: $src}]')
            else
                templates_json=$(python3 -c "
import json
arr = json.loads('''$templates_json''')
arr.append({
    'name': '$name',
    'description': '$description',
    'version': '$version',
    'source': '$template_file'
})
print(json.dumps(arr))
")
            fi
        done
    done < <(get_template_search_paths)

    echo "$templates_json"
}

# Export functions
export -f get_template_search_paths
export -f find_template_file
export -f parse_yaml_template
export -f sanitize_identifier
export -f validate_param_type
export -f apply_param_defaults
export -f render_query
export -f list_all_templates
