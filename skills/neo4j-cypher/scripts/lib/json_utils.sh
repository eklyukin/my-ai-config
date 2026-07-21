#!/bin/bash
# JSON Utilities with jq and Python fallback
# Provides JSON parsing and building functionality with automatic fallback

set -eo pipefail

# Check if jq is available
HAS_JQ=false
if command -v jq &>/dev/null; then
    HAS_JQ=true
    if declare -f log_debug >/dev/null 2>&1; then
        log_debug "JSON processor: jq (native)"
    fi
else
    if declare -f log_debug >/dev/null 2>&1; then
        log_debug "JSON processor: Python fallback (jq not installed)"
    fi
fi

# Function: Build Neo4j query request JSON
# Args: $1=cypher_query, $2=params_json (optional, default: {})
# Returns: JSON request body
build_json_request() {
    local cypher="$1"
    local params="$2"

    # Use empty JSON object if no params provided
    if [[ -z "$params" ]]; then
        params='{}'
    fi

    # Ensure params is valid JSON (not quoted string)
    if [[ "$params" == '"{}"' ]] || [[ "$params" == "'{}'" ]]; then
        params='{}'
    fi

    # Debug: show what we're working with
    if declare -f log_debug >/dev/null 2>&1; then
        log_debug "build_json_request params value: [$params]"
        log_debug "build_json_request params length: ${#params}"
    fi

    if [[ "$HAS_JQ" == "true" ]]; then
        # jq path (fast)
        jq -n \
            --arg stmt "$cypher" \
            --argjson params "$params" \
            '{statement: $stmt, parameters: $params}'
    else
        # Python fallback - use stdin to prevent command injection
        printf '%s\n%s' "$cypher" "$params" | python3 -c "
import json
import sys

# Read from stdin (safe from command injection)
cypher = sys.stdin.readline().rstrip('\n')
params_str = sys.stdin.readline().rstrip('\n')

try:
    params = json.loads(params_str) if params_str else {}
except json.JSONDecodeError:
    params = {}

request = {
    'statement': cypher,
    'parameters': params
}

print(json.dumps(request))
" 2>/dev/null || {
            log_error "Failed to build JSON request (jq and Python unavailable)"
            return 1
        }
    fi
}

# Function: Extract field from JSON
# Args: $1=json_string, $2=json_path (jq syntax)
# Returns: Field value
# Examples:
#   json_get '{"foo": "bar"}' '.foo' → "bar"
#   json_get '{"data": [1,2,3]}' '.data[0]' → 1
json_get() {
    local json_input="${1:-}"
    local json_path="${2:-}"

    # Support both patterns:
    # 1. json_get "$json" "$path" - explicit arguments
    # 2. echo "$json" | json_get "$path" - piped input
    if [[ -z "$json_path" ]] && [[ -n "$json_input" ]]; then
        # Piped pattern: $1 is the path, read JSON from stdin
        json_path="$json_input"
        json_input=$(cat)
    fi

    if [[ -z "$json_input" ]] || [[ -z "$json_path" ]]; then
        if declare -f log_error >/dev/null 2>&1; then
            log_error "json_get: json_input and json_path required"
            log_error "  Received: json_input='${json_input:0:50}' json_path='${json_path}'"
        fi
        return 1
    fi

    if [[ "$HAS_JQ" == "true" ]]; then
        # jq path
        echo "$json_input" | jq -r "$json_path" 2>/dev/null
    else
        # Python fallback - use stdin to prevent command injection
        printf '%s\n%s' "$json_input" "$json_path" | python3 -c "
import json
import sys

try:
    # Read from stdin (safe from command injection)
    json_input = sys.stdin.readline().rstrip('\n')
    json_path = sys.stdin.readline().rstrip('\n')

    data = json.loads(json_input)

    # Parse jq-style path (simplified)
    path = json_path.strip('.')

    # Handle array access: .data[0] → data, 0
    if '[' in path:
        base_path, index = path.split('[')
        index = int(index.rstrip(']'))
        result = data
        if base_path:
            for key in base_path.split('.'):
                result = result[key]
        result = result[index]
    # Handle object access: .foo.bar
    else:
        result = data
        for key in path.split('.'):
            if key:
                result = result[key]

    if isinstance(result, (dict, list)):
        print(json.dumps(result))
    else:
        print(result)
except Exception as e:
    sys.stderr.write(f'json_get error: {e}\n')
    sys.exit(1)
" 2>/dev/null
    fi
}

# Function: Add field to JSON object
# Args: $1=json_string, $2=field_name, $3=field_value_json
# Returns: Updated JSON
json_add_field() {
    local json_input="$1"
    local field_name="$2"
    local field_value="$3"

    if [[ "$HAS_JQ" == "true" ]]; then
        # jq path
        echo "$json_input" | jq \
            --arg key "$field_name" \
            --argjson val "$field_value" \
            '. + {($key): $val}'
    else
        # Python fallback - use stdin to prevent command injection
        printf '%s\n%s\n%s' "$json_input" "$field_name" "$field_value" | python3 -c "
import json
import sys

# Read from stdin (safe from command injection)
json_input = sys.stdin.readline().rstrip('\n')
field_name = sys.stdin.readline().rstrip('\n')
field_value = sys.stdin.readline().rstrip('\n')

data = json.loads(json_input)
value = json.loads(field_value)

data[field_name] = value
print(json.dumps(data))
"
    fi
}

# Function: Append object to JSON array
# Args: Reads JSON array from stdin, $@=key/value pairs
# Returns: Updated array
# Example: echo '[]' | json_append_object 'foo' 'bar' 'num' '42'
json_append_object() {
    # Read JSON array from stdin
    local json_array=$(cat)

    # Debug: show all arguments
    if declare -f log_debug >/dev/null 2>&1; then
        log_debug "json_append_object called with $# args: $*"
        log_debug "json_append_object input array: ${json_array:0:100}"
    fi

    # Build object from key/value pairs
    local obj="{"
    local first=true
    while [[ $# -gt 1 ]]; do
        local key="$1"
        local value="$2"

        if declare -f log_debug >/dev/null 2>&1; then
            log_debug "  Pair: key='$key' value='$value'"
        fi

        shift 2

        if [[ "$first" != "true" ]]; then
            obj+=","
        fi
        first=false

        # Quote value if it's a string
        if [[ "$value" =~ ^[0-9]+$ ]] || [[ "$value" == "true" ]] || [[ "$value" == "false" ]]; then
            obj+="\"$key\":$value"
        else
            obj+="\"$key\":\"$value\""
        fi
    done
    obj+="}"

    if declare -f log_debug >/dev/null 2>&1; then
        log_debug "json_append_object built object: $obj"
    fi

    if [[ "$HAS_JQ" == "true" ]]; then
        # jq path
        echo "$json_array" | jq --argjson obj "$obj" '. + [$obj]'
    else
        # Python fallback - use stdin to prevent command injection
        printf '%s\n%s' "$json_array" "$obj" | python3 -c "
import json
import sys

# Read from stdin (safe from command injection)
json_array = sys.stdin.readline().rstrip('\n')
obj_str = sys.stdin.readline().rstrip('\n')

array = json.loads(json_array)
obj = json.loads(obj_str)

array.append(obj)
print(json.dumps(array))
"
    fi
}

# Function: Convert Neo4j tabular format to array of objects
# Args: $1=fields_array, $2=values_array
# Returns: Array of record objects
convert_tabular_to_objects() {
    local fields="$1"
    local values="$2"

    if [[ "$HAS_JQ" == "true" ]]; then
        jq -n \
            --argjson fields "$fields" \
            --argjson values "$values" \
            '
            $values | map(
                . as $row |
                $fields | to_entries | map({
                    key: .value,
                    value: $row[.key]
                }) | from_entries
            )
            '
    else
        # Python fallback - use stdin to prevent command injection
        printf '%s\n%s' "$fields" "$values" | python3 -c "
import json
import sys

# Read from stdin (safe from command injection)
fields_str = sys.stdin.readline().rstrip('\n')
values_str = sys.stdin.readline().rstrip('\n')

fields = json.loads(fields_str)
values = json.loads(values_str)

records = []
for row in values:
    record = {}
    for i, field in enumerate(fields):
        record[field] = row[i]
    records.append(record)

print(json.dumps(records))
"
    fi
}

# Function: Parse Neo4j HTTP response
# Args: $1=http_response_json, $2=operation_name
# Returns: Skill-format JSON output
parse_neo4j_response() {
    local http_response="$1"
    local operation="${2:-query}"

    # Neo4j HTTP API returns data in tabular format: {fields: [...], values: [[...]]}
    local fields
    local values

    fields=$(echo "$http_response" | json_get ".data.fields")
    values=$(echo "$http_response" | json_get ".data.values")

    # Convert to array of objects
    local records
    records=$(convert_tabular_to_objects "$fields" "$values")

    # Count records
    local record_count
    if [[ "$HAS_JQ" == "true" ]]; then
        record_count=$(echo "$records" | jq 'length')
    else
        record_count=$(echo "$records" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
    fi

    # Build skill output format
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

    if [[ "$HAS_JQ" == "true" ]]; then
        jq -n \
            --arg status "success" \
            --arg operation "$operation" \
            --argjson record_count "$record_count" \
            --argjson records "$records" \
            --arg timestamp "$timestamp" \
            '{
                status: $status,
                operation: $operation,
                record_count: $record_count,
                records: $records,
                timestamp: $timestamp
            }'
    else
        python3 -c "
import json

output = {
    'status': 'success',
    'operation': '$operation',
    'record_count': $record_count,
    'records': json.loads('''$records'''),
    'timestamp': '$timestamp'
}

print(json.dumps(output, indent=2))
"
    fi
}

# Function: Build error response JSON
# Args: $1=error_message, $2=operation_name
# Returns: Error JSON
build_error_response() {
    local error_msg="$1"
    local operation="${2:-unknown}"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

    if [[ "$HAS_JQ" == "true" ]]; then
        jq -n \
            --arg status "error" \
            --arg operation "$operation" \
            --arg error "$error_msg" \
            --arg timestamp "$timestamp" \
            '{
                status: $status,
                operation: $operation,
                error: $error,
                timestamp: $timestamp
            }'
    else
        # Python fallback - use stdin to prevent command injection
        printf '%s\n%s\n%s' "$operation" "$error_msg" "$timestamp" | python3 -c "
import json
import sys

# Read from stdin (safe from command injection)
operation = sys.stdin.readline().rstrip('\n')
error_msg = sys.stdin.readline().rstrip('\n')
timestamp = sys.stdin.readline().rstrip('\n')

output = {
    'status': 'error',
    'operation': operation,
    'error': error_msg,
    'timestamp': timestamp
}

print(json.dumps(output, indent=2))
"
    fi
}

# Function: Build not_found response JSON
# Args: $1=item_name, $2=operation_name
# Returns: Not found JSON
build_notfound_response() {
    local item_name="$1"
    local operation="${2:-unknown}"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

    if [[ "$HAS_JQ" == "true" ]]; then
        jq -n \
            --arg status "not_found" \
            --arg operation "$operation" \
            --arg item "$item_name" \
            --arg error "Not found: $item_name" \
            --arg timestamp "$timestamp" \
            '{
                status: $status,
                operation: $operation,
                item: $item,
                error: $error,
                timestamp: $timestamp
            }'
    else
        # Python fallback - use stdin to prevent command injection
        printf '%s\n%s\n%s' "$operation" "$item_name" "$timestamp" | python3 -c "
import json
import sys

# Read from stdin (safe from command injection)
operation = sys.stdin.readline().rstrip('\n')
item_name = sys.stdin.readline().rstrip('\n')
timestamp = sys.stdin.readline().rstrip('\n')

output = {
    'status': 'not_found',
    'operation': operation,
    'item': item_name,
    'error': f'Not found: {item_name}',
    'timestamp': timestamp
}

print(json.dumps(output, indent=2))
"
    fi
}

# Export functions
export -f build_json_request
export -f json_get
export -f json_add_field
export -f json_append_object
export -f parse_neo4j_response
export -f build_error_response
export -f build_notfound_response
