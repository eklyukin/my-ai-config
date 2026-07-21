#!/bin/bash
# Neo4j HTTP API Client
# Provides core HTTP functionality for querying Neo4j via HTTP Query API

set -eo pipefail

# Function: Convert Neo4j bolt:// URI to HTTP endpoint
# Args: $1=uri (bolt://host:port or bolt+s://host:port)
# Returns: HTTP endpoint URL
# Examples:
#   bolt://localhost:7687 → http://localhost:7474
#   bolt+s://neo4j.cloud:7687 → https://neo4j.cloud:7473
convert_bolt_to_http() {
    local uri="$1"

    if [[ -z "$uri" ]]; then
        log_error "convert_bolt_to_http: URI required"
        return 1
    fi

    # Parse URI components
    local protocol
    local host_port

    # Match secure protocols (bolt+s, neo4j+s)
    if [[ "$uri" =~ ^(bolt|neo4j)\+s://(.+)$ ]]; then
        protocol="https"
        host_port="${BASH_REMATCH[2]}"
    # Match insecure protocols (bolt, neo4j)
    elif [[ "$uri" =~ ^(bolt|neo4j)://(.+)$ ]]; then
        protocol="http"
        host_port="${BASH_REMATCH[2]}"
    else
        log_error "Invalid Neo4j URI format: $uri"
        log_error "Expected: bolt://host:port or bolt+s://host:port"
        return 1
    fi

    # Validate hostname (extract hostname without port for validation)
    local hostname="${host_port%%:*}"
    if [[ -z "$hostname" ]]; then
        log_error "Empty hostname in URI: $uri"
        return 1
    fi
    # Validate hostname format: alphanumeric, dots, hyphens only
    if [[ ! "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
        log_error "Invalid hostname format: $hostname"
        log_error "Hostname must contain only alphanumeric characters, dots, and hyphens"
        return 1
    fi

    # Replace bolt port (7687) with HTTP port, or add default if no port specified
    if [[ "$protocol" == "https" ]]; then
        # If URI has :7687, replace it
        if [[ "$host_port" =~ :7687$ ]]; then
            host_port="${host_port/:7687/:7473}"
        elif [[ ! "$host_port" =~ :[0-9]+$ ]]; then
            # No port specified - check if it's Neo4j Aura (uses default HTTPS port 443)
            if [[ "$host_port" =~ \.databases\.neo4j\.io$ ]]; then
                # Neo4j Aura - use default HTTPS port (no explicit port needed)
                : # host_port stays as-is
            else
                # Self-hosted - add explicit HTTPS port
                host_port="${host_port}:7473"
            fi
        fi
    else
        # If URI has :7687, replace it
        if [[ "$host_port" =~ :7687$ ]]; then
            host_port="${host_port/:7687/:7474}"
        elif [[ ! "$host_port" =~ :[0-9]+$ ]]; then
            # No port specified, add default HTTP port for self-hosted
            host_port="${host_port}:7474"
        fi
    fi

    echo "${protocol}://${host_port}"
}

# Function: Generate HTTP Basic Auth header
# Args: $1=username, $2=password
# Returns: Authorization header string
# Example: "Authorization: Basic bmVvNGo6cGFzc3dvcmQ="
generate_auth_header() {
    local username="$1"
    local password="$2"

    if [[ -z "$username" ]] || [[ -z "$password" ]]; then
        log_error "generate_auth_header: username and password required"
        return 1
    fi

    # Encode username:password in base64
    local credentials="${username}:${password}"
    local encoded

    # Handle macOS vs Linux base64 differences
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS base64
        encoded=$(echo -n "$credentials" | base64)
    else
        # Linux base64 (prevent line wrapping)
        encoded=$(echo -n "$credentials" | base64 -w 0)
    fi

    echo "Authorization: Basic $encoded"
}

# Function: Execute Neo4j HTTP query
# Args: $1=cypher_query, $2=params_json (optional, default: {}), $3=timeout (optional, default: 10)
# Returns: JSON response from Neo4j
# Exit codes: 0 (success), 1 (transient error), 2 (permanent error)
neo4j_http_query() {
    local cypher="$1"
    local params_json="$2"
    local timeout="${3:-10}"

    log_debug "neo4j_http_query called with:"
    log_debug "  cypher: $cypher"
    log_debug "  params: $params_json"
    log_debug "  timeout: $timeout"

    # Use empty JSON object if no params provided
    if [[ -z "$params_json" ]]; then
        params_json='{}'
        log_debug "  params defaulted to: {}"
    fi
    local database="${NEO4J_DATABASE:-neo4j}"

    # Validate required environment variables
    if [[ -z "$NEO4J_URI" ]]; then
        log_error "NEO4J_URI not set"
        return 2
    fi
    log_debug "  NEO4J_URI: $NEO4J_URI"

    if [[ -z "$NEO4J_USERNAME" ]] || [[ -z "$NEO4J_PASSWORD" ]]; then
        log_error "NEO4J_USERNAME and NEO4J_PASSWORD required"
        return 2
    fi
    log_debug "  Credentials: OK"

    # Convert bolt:// URI to HTTP endpoint
    local http_endpoint
    if ! http_endpoint=$(convert_bolt_to_http "$NEO4J_URI" 2>&1); then
        log_error "URI conversion failed: $http_endpoint"
        return 2
    fi
    log_debug "  HTTP endpoint: $http_endpoint"

    # Generate Basic Auth header
    local auth_header
    if ! auth_header=$(generate_auth_header "$NEO4J_USERNAME" "$NEO4J_PASSWORD" 2>&1); then
        log_error "Auth header generation failed: $auth_header"
        return 2
    fi
    log_debug "  Auth header: ${auth_header:0:50}..."

    # Build JSON request body
    local request_body
    if ! request_body=$(build_json_request "$cypher" "$params_json" 2>&1); then
        log_error "Failed to build JSON request: $request_body"
        return 2
    fi
    log_debug "  Request body: ${request_body:0:100}..."

    log_debug "HTTP POST ${http_endpoint}/db/${database}/query/v2"

    # Execute curl request
    local response
    local http_code

    response=$(curl -s -w "\n%{http_code}" \
        --max-time "$timeout" \
        -X POST \
        -H "$auth_header" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "$request_body" \
        "${http_endpoint}/db/${database}/query/v2" 2>&1)

    # Extract HTTP status code (last line)
    http_code=$(echo "$response" | tail -n1)
    response=$(echo "$response" | sed '$d')

    log_debug "HTTP Response Code: $http_code"
    log_debug "HTTP Response Body: ${response:0:500}..."

    # Handle HTTP status codes
    case "$http_code" in
        200|202)
            # Success (200 = OK, 202 = Accepted for Aura)
            log_debug "HTTP $http_code: Query successful"
            echo "$response"
            return 0
            ;;
        401|403)
            # Authentication/authorization failure (permanent error)
            log_error "HTTP $http_code: Authentication failed"
            local error_msg=$(echo "$response" | json_get ".errors[0].message" 2>/dev/null || echo "Authentication required")
            log_error "$error_msg"
            return 2
            ;;
        400)
            # Bad request - query syntax error (permanent error)
            log_error "HTTP 400: Bad request"
            local error_msg=$(echo "$response" | json_get ".errors[0].message" 2>/dev/null || echo "Invalid query")
            log_error "$error_msg"
            return 2
            ;;
        404)
            # Endpoint not found (permanent error)
            log_error "HTTP 404: Endpoint not found"
            log_error "Neo4j HTTP API may not be enabled or Neo4j version < 5.19"
            return 2
            ;;
        408|429|500|502|503|504)
            # Transient errors (retry-able)
            log_warn "HTTP $http_code: Transient error (will retry)"
            local error_msg=$(echo "$response" | json_get ".errors[0].message" 2>/dev/null || echo "Server error")
            log_debug "$error_msg"
            return 1
            ;;
        *)
            # Unknown error
            log_error "HTTP $http_code: Unexpected response"
            log_debug "Response: ${response:0:200}..."
            return 2
            ;;
    esac
}

# Function: Execute operation with exponential backoff retry
# Args: $1=function_name, $@=function_args
# Returns: Function output with retry metadata
# Implements: 5 retries, delays: 2s, 4s, 8s, 16s, 32s
execute_with_retry() {
    local operation_func="$1"
    shift
    local operation_args=("$@")

    log_debug "execute_with_retry: func=$operation_func"
    log_debug "execute_with_retry: args=(${operation_args[*]})"

    local max_retries=5
    local attempt=0
    local attempts_json="[]"

    while [[ $attempt -le $max_retries ]]; do
        local attempt_num=$((attempt + 1))

        # Get timestamp in milliseconds (cross-platform)
        local start_ms
        if [[ "$(uname)" == "Darwin" ]]; then
            # macOS: date doesn't support %N, use seconds only
            start_ms=$(($(date +%s) * 1000))
        else
            # Linux: use nanoseconds
            start_ms=$(date +%s%3N)
        fi

        log_debug "Attempt $attempt_num/$((max_retries + 1))..."

        # Execute operation
        local result
        local exit_code=0
        result=$("$operation_func" "${operation_args[@]}" 2>&1) || exit_code=$?

        local end_ms
        if [[ "$(uname)" == "Darwin" ]]; then
            end_ms=$(($(date +%s) * 1000))
        else
            end_ms=$(date +%s%3N)
        fi

        local duration_ms=$((end_ms - start_ms))

        if [[ $exit_code -eq 0 ]]; then
            # Success - add retry metadata
            attempts_json=$(echo "$attempts_json" | json_append_object \
                "attempt" "$attempt_num" \
                "success" "true" \
                "duration_ms" "$duration_ms")

            # Add retry metadata to result
            local retry_meta="{\"total_attempts\": $attempt_num, \"success\": true, \"attempts\": $attempts_json}"
            local final_result
            final_result=$(json_add_field "$result" "retry_metadata" "$retry_meta")

            echo "$final_result"
            return 0

        elif [[ $exit_code -eq 2 ]]; then
            # Permanent error - fail immediately
            attempts_json=$(echo "$attempts_json" | json_append_object \
                "attempt" "$attempt_num" \
                "success" "false" \
                "error_type" "permanent" \
                "duration_ms" "$duration_ms")

            log_error "Permanent error - no retry"
            return 1

        else
            # Transient error - retry if attempts remain
            attempts_json=$(echo "$attempts_json" | json_append_object \
                "attempt" "$attempt_num" \
                "success" "false" \
                "error_type" "transient" \
                "duration_ms" "$duration_ms")

            if [[ $attempt -lt $max_retries ]]; then
                # Calculate exponential backoff delay
                local delay=$((2 ** attempt))
                [[ $delay -gt 32 ]] && delay=32

                log_warn "Attempt $attempt_num failed, retrying in ${delay}s..."
                sleep "$delay"
            else
                log_error "All $((max_retries + 1)) attempts failed"
            fi
        fi

        attempt=$((attempt + 1))
    done

    # All retries exhausted
    log_error "Operation failed after $((max_retries + 1)) attempts"
    return 1
}

# Export functions for use by other modules
export -f convert_bolt_to_http
export -f generate_auth_header
export -f neo4j_http_query
export -f execute_with_retry
