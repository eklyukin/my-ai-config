#!/bin/bash
# Credentials Management
# Implements credential precedence: ENV > GCP > Config

set -eo pipefail

# Function: Load credentials with precedence: ENV > GCP > Config
# Sets: NEO4J_URI, NEO4J_USERNAME, NEO4J_PASSWORD
# Returns: 0 on success, 1 on failure
load_neo4j_credentials() {
    log_debug "Loading Neo4j credentials..."

    # Step 1: Save environment variables (highest precedence)
    local env_uri="${NEO4J_URI:-}"
    local env_user="${NEO4J_USERNAME:-}"
    local env_pass="${NEO4J_PASSWORD:-}"

    # Save GCP configuration (prevent config file from overriding)
    local env_gcp_project="${GCP_PROJECT_ID:-}"
    local env_gcp_sa="${GCP_SERVICE_ACCOUNT:-}"
    local env_gcp_sa_prefix="${GCP_SERVICE_ACCOUNT_PREFIX:-}"
    local env_gcp_secret_base_prefix="${GCP_SECRET_BASE_PREFIX:-}"
    local env_gcp_secret_prefix="${GCP_SECRET_PREFIX:-}"
    local env_gcp_secret_suffix="${GCP_SECRET_SUFFIX:-}"
    local env_use_gcp="${USE_GCP_SECRETS:-}"

    log_debug "ENV vars: URI=${env_uri:+set} USER=${env_user:+set} PASS=${env_pass:+set}"

    # Step 2: Load config file (lowest precedence)
    if [[ -f "$CONFIG_FILE" ]]; then
        log_debug "Loading config from: $CONFIG_FILE"
        source "$CONFIG_FILE" 2>/dev/null || {
            log_warn "Failed to source config file: $CONFIG_FILE"
        }
    elif [[ -f "$CONFIG_TEMPLATE" ]]; then
        log_debug "Loading config template: $CONFIG_TEMPLATE"
        source "$CONFIG_TEMPLATE" 2>/dev/null || {
            log_warn "Failed to source config template"
        }
    fi

    # Step 2.5: Restore GCP environment variables (ENV takes precedence over config)
    [[ -n "$env_gcp_project" ]] && GCP_PROJECT_ID="$env_gcp_project"
    [[ -n "$env_use_gcp" ]] && USE_GCP_SECRETS="$env_use_gcp"
    [[ -n "$env_gcp_sa" ]] && GCP_SERVICE_ACCOUNT="$env_gcp_sa"
    [[ -n "$env_gcp_sa_prefix" ]] && GCP_SERVICE_ACCOUNT_PREFIX="$env_gcp_sa_prefix"
    [[ -n "$env_gcp_secret_base_prefix" ]] && GCP_SECRET_BASE_PREFIX="$env_gcp_secret_base_prefix"
    [[ -n "$env_gcp_secret_prefix" ]] && GCP_SECRET_PREFIX="$env_gcp_secret_prefix"
    [[ -n "$env_gcp_secret_suffix" ]] && GCP_SECRET_SUFFIX="$env_gcp_secret_suffix"

    log_debug "GCP config: PROJECT=${GCP_PROJECT_ID:+set} USE=${USE_GCP_SECRETS:-auto}"

    # Step 3: Fetch from GCP if enabled and needed
    local use_gcp="false"

    if [[ "${USE_GCP_SECRETS:-auto}" == "true" ]]; then
        # Always fetch from GCP (override config, but env vars still win)
        use_gcp="true"
        log_debug "GCP fetch mode: force (USE_GCP_SECRETS=true)"
    elif [[ "${USE_GCP_SECRETS:-auto}" == "auto" ]]; then
        # Fetch from GCP only if env vars are missing
        if [[ -z "$env_uri" ]] || [[ -z "$env_user" ]] || [[ -z "$env_pass" ]]; then
            use_gcp="true"
            log_debug "GCP fetch mode: auto (some ENV vars missing)"
        else
            log_debug "GCP fetch mode: skipped (all ENV vars set)"
        fi
    else
        log_debug "GCP fetch mode: disabled (USE_GCP_SECRETS=${USE_GCP_SECRETS:-auto})"
    fi

    if [[ "$use_gcp" == "true" ]]; then
        log_debug "Attempting to fetch credentials from GCP..."
        # Don't fail script on GCP errors - just log and continue
        fetch_neo4j_credentials_from_gcp || {
            log_warn "GCP credential fetch failed, will use ENV/config"
        }
    fi

    # Step 4: Apply final precedence (ENV wins over everything)
    NEO4J_URI="${env_uri:-${NEO4J_URI:-}}"
    NEO4J_USERNAME="${env_user:-${NEO4J_USERNAME:-}}"
    NEO4J_PASSWORD="${env_pass:-${NEO4J_PASSWORD:-}}"

    # Also support NEO4J_URL as alias for NEO4J_URI
    NEO4J_URI="${NEO4J_URI:-${NEO4J_URL:-}}"

    # Export for downstream scripts
    export NEO4J_URI NEO4J_USERNAME NEO4J_PASSWORD

    log_debug "Final credentials: URI=${NEO4J_URI:+set} USER=${NEO4J_USERNAME:+set} PASS=${NEO4J_PASSWORD:+set}"

    return 0
}

# Function: Validate credentials are complete
# Returns: 0 if valid, 1 if incomplete
validate_credentials() {
    local errors=0

    if [[ -z "$NEO4J_URI" ]]; then
        log_error "NEO4J_URI not set"
        log_error ""
        log_error "Set via one of:"
        log_error "  1. Environment: export NEO4J_URI='bolt://host:7687'"
        log_error "  2. Config file: $CONFIG_FILE"
        if [[ "${USE_GCP_SECRETS:-auto}" != "false" ]]; then
            log_error "  3. GCP Secret: xenia-npc-neo4j-database-prod"
        fi
        errors=$((errors + 1))
    fi

    if [[ -z "$NEO4J_USERNAME" ]]; then
        log_error "NEO4J_USERNAME not set"
        log_error ""
        log_error "Set via one of:"
        log_error "  1. Environment: export NEO4J_USERNAME='neo4j'"
        log_error "  2. Config file: $CONFIG_FILE"
        if [[ "${USE_GCP_SECRETS:-auto}" != "false" ]]; then
            log_error "  3. GCP Secret: xenia-npc-user-<username>-neo4j-username-prod"
        fi
        errors=$((errors + 1))
    fi

    if [[ -z "$NEO4J_PASSWORD" ]]; then
        log_error "NEO4J_PASSWORD not set"
        log_error ""
        log_error "Set via one of:"
        log_error "  1. Environment: export NEO4J_PASSWORD='password'"
        log_error "  2. Config file: $CONFIG_FILE"
        if [[ "${USE_GCP_SECRETS:-auto}" != "false" ]]; then
            log_error "  3. GCP Secret: xenia-npc-user-<username>-neo4j-password-prod"
        fi
        errors=$((errors + 1))
    fi

    if [[ $errors -gt 0 ]]; then
        log_error ""
        log_error "Missing $errors required credential(s)"
        return 1
    fi

    log_debug "Credentials validation: passed"
    return 0
}

# Export functions
export -f load_neo4j_credentials
export -f validate_credentials
