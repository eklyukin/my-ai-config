#!/bin/bash
# ============================================================================
# Neo4j Skill - HTTP API Implementation
# ============================================================================
# Description: Neo4j graph database operations via HTTP Query API
# Version: 3.0.0 (curl-based, no Python dependencies)
#
# Key Changes from v2.0:
#   - Uses Neo4j HTTP Query API (no neo4j Python driver required)
#   - Dual-mode JSON handling (jq preferred, Python fallback)
#   - All operations implemented in bash
#   - Maintains full feature parity with v2.0
#
# Usage:
#   neo4j read --query="MATCH (n) RETURN n LIMIT 5"
#   neo4j schema --sample-size=100
#   neo4j template entity_pool --label=Customer --limit=50
#   neo4j templates --list
#   neo4j discover
# ============================================================================

set -eo pipefail

# ============================================================================
# CONFIGURATION LOADING
# ============================================================================

# Skill directory detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="${SKILL_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# GCP Secret Manager configuration
# Note: GCP_PROJECT_ID should be set via environment variable or config file
# Example: export GCP_PROJECT_ID="your-gcp-project-id"
GCP_PROJECT_ID="${GCP_PROJECT_ID:-}"
GCP_SERVICE_ACCOUNT="${GCP_SERVICE_ACCOUNT:-}"
GCP_SERVICE_ACCOUNT_PREFIX="${GCP_SERVICE_ACCOUNT_PREFIX:-xenia-npc}"
GCP_SECRET_BASE_PREFIX="${GCP_SECRET_BASE_PREFIX:-xenia-npc}"
GCP_SECRET_PREFIX="${GCP_SECRET_PREFIX:-neo4j}"
GCP_SECRET_SUFFIX="${GCP_SECRET_SUFFIX:-prod}"
USE_GCP_SECRETS="${USE_GCP_SECRETS:-auto}"

# Config file paths
CONFIG_FILE="${HOME}/.claude/skills/neo4j/config/neo4j.conf"
CONFIG_TEMPLATE="${SKILL_DIR}/config/neo4j.conf.template"

# Operation settings
DEFAULT_TIMEOUT="${DEFAULT_TIMEOUT:-10}"
DEBUG="${DEBUG:-false}"
LOG_FILE="${LOG_FILE:-./neo4j-operation.log}"

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

log_info() {
    echo "[INFO] $*" >&2
    if [[ "$DEBUG" == "true" ]]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*" >> "$LOG_FILE"
    fi
}

log_success() {
    echo "[SUCCESS] $*" >&2
    if [[ "$DEBUG" == "true" ]]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $*" >> "$LOG_FILE"
    fi
}

log_error() {
    echo "[ERROR] $*" >&2
    if [[ "$DEBUG" == "true" ]]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*" >> "$LOG_FILE"
    fi
}

log_warn() {
    echo "[WARN] $*" >&2
    if [[ "$DEBUG" == "true" ]]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [WARN] $*" >> "$LOG_FILE"
    fi
}

log_debug() {
    if [[ "$DEBUG" == "true" ]]; then
        echo "[DEBUG] $*" >&2
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [DEBUG] $*" >> "$LOG_FILE"
    fi
}

# ============================================================================
# SOURCE LIBRARY MODULES
# ============================================================================

# Source all library modules
source "$SCRIPT_DIR/lib/json_utils.sh"
source "$SCRIPT_DIR/lib/http_client.sh"
source "$SCRIPT_DIR/lib/gcp_secrets.sh"
source "$SCRIPT_DIR/lib/credentials.sh"
source "$SCRIPT_DIR/lib/template_engine.sh"

# ============================================================================
# DEPENDENCY CHECKS
# ============================================================================

check_dependencies() {
    local errors=0

    # Check curl (required)
    if ! command -v curl &> /dev/null; then
        log_error "curl not found (required for HTTP API)"
        log_error "Install: brew install curl (should be pre-installed on macOS)"
        errors=$((errors + 1))
    fi

    # Check Python 3 (required for YAML parsing)
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 not found (required for YAML template parsing)"
        log_error "Install: brew install python3"
        errors=$((errors + 1))
    else
        # Check PyYAML
        if ! python3 -c "import yaml" 2>/dev/null; then
            log_warn "PyYAML not installed (required for template features)"
            log_warn "Install: pip3 install pyyaml"
            log_warn "Templates will be disabled without PyYAML"
        fi
    fi

    # Check jq (recommended but optional)
    if ! command -v jq &> /dev/null; then
        log_warn "jq not found (recommended for faster JSON processing)"
        log_warn "Install: brew install jq"
        log_warn "Falling back to Python for JSON operations"
    else
        log_debug "JSON processor: jq"
    fi

    return $errors
}

# ============================================================================
# OPERATION IMPLEMENTATIONS
# ============================================================================

# Operation: read (Execute raw Cypher query)
operation_read() {
    local query="$1"
    local params="$2"
    local timeout="${3:-$DEFAULT_TIMEOUT}"

    # Use empty params if not provided
    if [[ -z "$params" ]]; then
        params=""
    fi

    log_info "Executing Cypher query..."
    log_debug "Query: ${query:0:100}..."
    log_debug "Params: $params"

    # Execute with retry
    local response
    if ! response=$(execute_with_retry neo4j_http_query "$query" "$params" "$timeout"); then
        build_error_response "Query execution failed" "read"
        return 1
    fi

    # Parse and format response
    parse_neo4j_response "$response" "read"
}

# Operation: schema (Inspect database schema)
operation_schema() {
    local sample_size="${1:-100}"
    local timeout="${2:-30}"

    log_info "Fetching database schema..."

    # Use simple schema query (avoiding APOC parameter complexity for now)
    # Query node labels, relationship types, and sample properties
    local query="CALL db.labels() YIELD label
WITH collect(label) AS node_labels
CALL db.relationshipTypes() YIELD relationshipType
WITH node_labels, collect(relationshipType) AS rel_types
RETURN {
    node_labels: node_labels,
    relationship_types: rel_types
} AS schema"

    local response
    if ! response=$(execute_with_retry neo4j_http_query "$query" "" "$timeout"); then
        build_error_response "Schema query failed" "schema"
        return 1
    fi

    # Parse and add metadata
    local result
    result=$(parse_neo4j_response "$response" "schema")

    if [[ "$HAS_JQ" == "true" ]]; then
        echo "$result" | jq --arg note "Simplified schema (db.labels + db.relationshipTypes)" \
            '. + {note: $note}'
    else
        echo "$result"
    fi
}

# Operation: template (Execute YAML template)
operation_template() {
    local template_name="$1"
    local user_params_json="$2"
    local timeout="${3:-$DEFAULT_TIMEOUT}"

    # Use empty params if not provided
    if [[ -z "$user_params_json" ]]; then
        user_params_json=""
    fi

    log_info "Executing template: $template_name..."

    # Find template file
    local template_file
    if ! template_file=$(find_template_file "$template_name" 2>&1); then
        log_debug "Template not found: $template_name"
        build_notfound_response "$template_name" "template"
        return 0  # Not an error, just not found
    fi

    log_debug "Template file: $template_file"

    # Parse YAML to JSON
    local template_json
    if ! template_json=$(parse_yaml_template "$template_file" 2>&1); then
        log_error "YAML parsing failed: $template_json"
        build_error_response "Failed to parse template YAML" "template"
        return 1
    fi

    log_debug "Template parsed successfully"

    # Validate parameters
    local validated_params
    if ! validated_params=$(apply_param_defaults "$template_json" "$user_params_json" 2>&1); then
        log_error "Param validation failed: $validated_params"
        build_error_response "Parameter validation failed" "template"
        return 1
    fi

    log_debug "Validated params: $validated_params"

    # Render query
    local render_output
    if ! render_output=$(render_query "$template_json" "$validated_params" 2>&1); then
        log_error "Query rendering failed: $render_output"
        build_error_response "Query rendering failed" "template"
        return 1
    fi

    log_debug "Query rendered successfully"

    # Extract rendered query (before delimiter, exclude delimiter line)
    local rendered_query=$(echo "$render_output" | sed -n '1,/^---PARAMS---$/p' | sed '$d')
    # Extract params (after delimiter)
    local cypher_params=$(echo "$render_output" | sed -n '/^---PARAMS---$/,$p' | tail -n +2)

    log_debug "Rendered query: $rendered_query"
    log_debug "Cypher params: $cypher_params"

    # Execute query
    local response
    if ! response=$(execute_with_retry neo4j_http_query "$rendered_query" "$cypher_params" "$timeout" 2>&1); then
        log_error "Query execution failed"
        build_error_response "Template query execution failed" "template"
        return 1
    fi

    log_debug "Query executed successfully"

    # Add template metadata to result
    local result
    result=$(parse_neo4j_response "$response" "template")

    # Add template metadata
    result=$(json_add_field "$result" "template_name" "\"$template_name\"")
    result=$(json_add_field "$result" "parameters_applied" "$validated_params")

    echo "$result"
}

# Operation: templates (List/Show/Validate templates)
operation_templates() {
    local action="$1"
    local template_name="${2:-}"

    case "$action" in
        list)
            log_info "Listing available templates..."

            local templates_json
            templates_json=$(list_all_templates)

            local count
            if [[ "$HAS_JQ" == "true" ]]; then
                count=$(echo "$templates_json" | jq 'length')
            else
                count=$(echo "$templates_json" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
            fi

            if [[ "$HAS_JQ" == "true" ]]; then
                jq -n \
                    --arg status "success" \
                    --arg operation "templates" \
                    --arg action "list" \
                    --argjson count "$count" \
                    --argjson templates "$templates_json" \
                    --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")" \
                    '{
                        status: $status,
                        operation: $operation,
                        action: $action,
                        template_count: $count,
                        templates: $templates,
                        timestamp: $timestamp
                    }'
            else
                python3 -c "
import json
output = {
    'status': 'success',
    'operation': 'templates',
    'action': 'list',
    'template_count': $count,
    'templates': json.loads('''$templates_json'''),
    'timestamp': '$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'
}
print(json.dumps(output, indent=2))
"
            fi
            ;;

        show)
            if [[ -z "$template_name" ]]; then
                build_error_response "Template name required for --show" "templates"
                return 1
            fi

            log_info "Showing template: $template_name..."

            local template_file
            if ! template_file=$(find_template_file "$template_name"); then
                build_notfound_response "$template_name" "templates"
                return 0
            fi

            local template_json
            if ! template_json=$(parse_yaml_template "$template_file"); then
                build_error_response "Failed to parse template" "templates"
                return 1
            fi

            if [[ "$HAS_JQ" == "true" ]]; then
                echo "$template_json" | jq \
                    --arg status "success" \
                    --arg operation "templates" \
                    --arg action "show" \
                    --arg source "$template_file" \
                    --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")" \
                    '. + {
                        status: $status,
                        operation: $operation,
                        action: $action,
                        source: $source,
                        timestamp: $timestamp
                    }'
            else
                python3 -c "
import json
template = json.loads('''$template_json''')
template.update({
    'status': 'success',
    'operation': 'templates',
    'action': 'show',
    'source': '$template_file',
    'timestamp': '$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'
})
print(json.dumps(template, indent=2))
"
            fi
            ;;

        *)
            build_error_response "Unknown templates action: $action" "templates"
            return 1
            ;;
    esac
}

# Operation: discover (Analyze schema and suggest templates)
operation_discover() {
    local suggest_templates="${1:-true}"
    local timeout="${2:-30}"

    log_info "Discovering schema patterns..."

    # Query for node labels and counts
    local query="MATCH (n) RETURN DISTINCT labels(n) AS labels, count(*) AS count ORDER BY count DESC LIMIT 20"

    local response
    if ! response=$(execute_with_retry neo4j_http_query "$query" "" "$timeout"); then
        build_error_response "Discovery query failed" "discover"
        return 1
    fi

    # Extract data
    local data=$(echo "$response" | json_get ".data")

    # Generate template suggestions
    local suggestions="[]"

    if [[ "$suggest_templates" == "true" ]]; then
        # Parse each record and build suggestions
        local records
        if [[ "$HAS_JQ" == "true" ]]; then
            records=$(echo "$data" | jq -c '.[]')
        else
            records=$(echo "$data" | python3 -c "import json,sys; [print(json.dumps(r)) for r in json.load(sys.stdin)]")
        fi

        while IFS= read -r record; do
            [[ -z "$record" ]] && continue

            local labels=$(echo "$record" | json_get ".labels")
            local count=$(echo "$record" | json_get ".count")

            # Get first label
            local label
            if [[ "$HAS_JQ" == "true" ]]; then
                label=$(echo "$labels" | jq -r '.[0]')
            else
                label=$(echo "$labels" | python3 -c "import json,sys; print(json.load(sys.stdin)[0])")
            fi

            [[ -z "$label" ]] && continue

            # Build suggested template YAML
            local template_yaml="name: ${label,,}_query
description: Query $label nodes
version: \"1.0\"

parameters:
  limit:
    type: integer
    required: false
    default: 100
    description: Maximum number of results

query: |
  MATCH (n:$label)
  RETURN n
  LIMIT \$limit"

            # Add to suggestions array
            if [[ "$HAS_JQ" == "true" ]]; then
                suggestions=$(echo "$suggestions" | jq \
                    --arg type "node_query" \
                    --arg label "$label" \
                    --arg count "$count" \
                    --arg yaml "$template_yaml" \
                    '. + [{
                        type: $type,
                        label: $label,
                        node_count: ($count | tonumber),
                        suggested_template: $yaml
                    }]')
            else
                suggestions=$(python3 -c "
import json
arr = json.loads('''$suggestions''')
arr.append({
    'type': 'node_query',
    'label': '$label',
    'node_count': int('$count'),
    'suggested_template': '''$template_yaml'''
})
print(json.dumps(arr))
")
            fi
        done <<< "$records"
    fi

    # Build final output
    if [[ "$HAS_JQ" == "true" ]]; then
        jq -n \
            --arg status "success" \
            --arg operation "discover" \
            --argjson suggestions "$suggestions" \
            --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")" \
            '{
                status: $status,
                operation: $operation,
                suggestion_count: ($suggestions | length),
                suggestions: $suggestions,
                timestamp: $timestamp
            }'
    else
        python3 -c "
import json
output = {
    'status': 'success',
    'operation': 'discover',
    'suggestion_count': len(json.loads('''$suggestions''')),
    'suggestions': json.loads('''$suggestions'''),
    'timestamp': '$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'
}
print(json.dumps(output, indent=2))
"
    fi
}

# ============================================================================
# USAGE
# ============================================================================

usage() {
    cat <<EOF
Neo4j Skill - Graph Database Operations (HTTP API)

USAGE:
    neo4j <operation> [options]

OPERATIONS:
    read        Execute raw Cypher query
    schema      Inspect database schema
    template    Execute YAML template
    templates   Manage templates (list/show)
    discover    Discover schema patterns

READ OPTIONS:
    --query=<cypher>        Cypher query to execute (required)
    --params=<json>         Query parameters as JSON (default: {})
    --timeout=<seconds>     Query timeout (default: 10)

SCHEMA OPTIONS:
    --sample-size=<n>       Sample size for schema inspection (default: 100)

TEMPLATE OPTIONS:
    --name=<template>       Template name (required)
    --<param>=<value>       Template parameters
    --params=<json>         All parameters as JSON

TEMPLATES OPTIONS:
    --list                  List available templates
    --show=<template>       Show template details

DISCOVER OPTIONS:
    --suggest-templates     Generate template suggestions (default: true)

EXAMPLES:
    # Raw Cypher query
    neo4j read --query="MATCH (n:Person) RETURN n LIMIT 5"

    # Parameterized query
    neo4j read --query="MATCH (n:Person {name: \$name}) RETURN n" --params='{"name": "Alice"}'

    # Schema inspection
    neo4j schema --sample-size=100

    # Execute template
    neo4j template --name=entity_pool --label=Customer --limit=50

    # List templates
    neo4j templates --list

    # Discover schema patterns
    neo4j discover

CONFIGURATION:
    Config file: $CONFIG_FILE

    Environment variables (highest precedence):
        NEO4J_URI           Neo4j connection URI (bolt://host:port)
        NEO4J_USERNAME      Database username
        NEO4J_PASSWORD      Database password
        NEO4J_DATABASE      Database name (default: neo4j)
        USE_GCP_SECRETS     auto|true|false (default: auto)
        DEBUG               true|false (default: false)

EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    # Parse operation
    local operation="${1:-}"
    shift || true

    if [[ -z "$operation" ]] || [[ "$operation" == "--help" ]] || [[ "$operation" == "-h" ]]; then
        usage
        exit 0
    fi

    # Check dependencies
    if ! check_dependencies; then
        log_error "Dependency check failed"
        exit 1
    fi

    # Load credentials
    load_neo4j_credentials

    # Validate credentials
    if ! validate_credentials; then
        exit 1
    fi

    # Parse operation-specific arguments
    local query=""
    local params=""
    local timeout="$DEFAULT_TIMEOUT"
    local sample_size="100"
    local template_name=""
    local template_params=""
    local templates_action=""
    local show_template=""
    local suggest_templates="true"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --query=*)
                query="${1#*=}"
                ;;
            --query)
                shift
                query="$1"
                ;;
            --params=*)
                params="${1#*=}"
                ;;
            --params)
                shift
                params="$1"
                ;;
            --timeout=*)
                timeout="${1#*=}"
                ;;
            --timeout)
                shift
                timeout="$1"
                ;;
            --sample-size=*)
                sample_size="${1#*=}"
                ;;
            --sample-size)
                shift
                sample_size="$1"
                ;;
            --name=*)
                template_name="${1#*=}"
                ;;
            --name)
                shift
                template_name="$1"
                ;;
            --list)
                templates_action="list"
                ;;
            --show=*)
                templates_action="show"
                show_template="${1#*=}"
                ;;
            --show)
                shift
                templates_action="show"
                show_template="$1"
                ;;
            --suggest-templates=*)
                suggest_templates="${1#*=}"
                ;;
            --suggest-templates)
                shift
                suggest_templates="$1"
                ;;
            --*=*)
                # Template parameter with = format
                local key="${1#--}"
                key="${key%%=*}"
                local value="${1#*=}"

                if [[ "$HAS_JQ" == "true" ]]; then
                    template_params=$(echo "$template_params" | jq \
                        --arg k "$key" \
                        --arg v "$value" \
                        '.[$k] = $v')
                else
                    template_params=$(python3 -c "
import json
data = json.loads('''$template_params''')
data['$key'] = '$value'
print(json.dumps(data))
")
                fi
                ;;
            -*)
                log_error "Unknown option: $1"
                log_error ""
                log_error "If you're trying to pass a query, use: --query=\"YOUR QUERY HERE\""
                log_error "Make sure to properly quote complex queries with spaces or special characters."
                usage
                exit 1
                ;;
            *)
                log_error "Unexpected argument: $1"
                log_error ""
                log_error "All options must start with -- (e.g., --query=\"...\")"
                log_error "If this is part of a query, make sure it's properly quoted:"
                log_error "  Correct:   --query=\"MATCH (n) RETURN n\""
                log_error "  Incorrect: --query=MATCH (n) RETURN n"
                usage
                exit 1
                ;;
        esac
        shift
    done

    # Execute operation
    case "$operation" in
        read)
            if [[ -z "$query" ]]; then
                log_error "Missing required option: --query"
                usage
                exit 1
            fi
            operation_read "$query" "$params" "$timeout"
            ;;

        schema)
            operation_schema "$sample_size" "$timeout"
            ;;

        template)
            if [[ -z "$template_name" ]]; then
                log_error "Missing required option: --name"
                usage
                exit 1
            fi
            # Merge --params with individual params
            if [[ -n "$params" ]]; then
                template_params="$params"
            fi
            operation_template "$template_name" "$template_params" "$timeout"
            ;;

        templates)
            if [[ -z "$templates_action" ]]; then
                log_error "Missing templates action: --list or --show=<name>"
                usage
                exit 1
            fi
            operation_templates "$templates_action" "$show_template"
            ;;

        discover)
            operation_discover "$suggest_templates" "$timeout"
            ;;

        *)
            log_error "Unknown operation: $operation"
            log_error "Valid operations: read, schema, template, templates, discover"
            usage
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
