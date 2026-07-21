#!/bin/bash
# ============================================================================
# Neo4j Skill - Bash Wrapper
# ============================================================================
# Description: Wrapper script for Neo4j graph database operations
# Version: 2.0.0
#
# Reason: Provides consistent CLI interface for Neo4j skill operations.
#         Handles config loading, validation, and routes to Python script.
#         Template system enables user-defined reusable queries.
#
# Usage:
#   neo4j read --query="MATCH (n) RETURN n LIMIT 5"
#   neo4j schema --sample-size=100
#   neo4j template entity_pool --label=Customer --limit=50
#   neo4j templates --list
#   neo4j discover
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURATION LOADING
# ============================================================================

# Skill directory detection
# Reason: Supports both direct execution and claude skill invocation
SKILL_DIR="${SKILL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# GCP Secret Manager configuration
# Reason: Enables automatic credential fetching from GCP Secret Manager
GCP_PROJECT_ID="${GCP_PROJECT_ID:-ai-experiments-469513}"
GCP_SERVICE_ACCOUNT="${GCP_SERVICE_ACCOUNT:-}"  # Auto-detect if empty
USE_GCP_SECRETS="${USE_GCP_SECRETS:-auto}"      # auto|true|false
GCLOUD_CLI_SKILL_DIR="${GCLOUD_CLI_SKILL_DIR:-}"  # Path to gcloud-cli skill

# Config file paths
# Reason: User config > Template defaults (allows customization)
CONFIG_FILE="${HOME}/.claude/skills/neo4j/config/neo4j.conf"
CONFIG_TEMPLATE="${SKILL_DIR}/config/neo4j.conf.template"

# Function: Load configuration from file
load_config() {
    # Save environment variables BEFORE sourcing config
    # Reason: Env vars should have highest precedence, but sourcing config
    #         can overwrite them. We preserve them here to restore later.
    local env_uri="${NEO4J_URI:-}"
    local env_url="${NEO4J_URL:-}"
    local env_username="${NEO4J_USERNAME:-}"
    local env_password="${NEO4J_PASSWORD:-}"
    local env_database="${NEO4J_DATABASE:-}"
    local env_sample_size="${NEO4J_SCHEMA_SAMPLE_SIZE:-}"

    # Check if config file exists
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    elif [[ -f "$CONFIG_TEMPLATE" ]]; then
        # Use template if no user config
        # shellcheck source=/dev/null
        source "$CONFIG_TEMPLATE"
    fi

    # Apply precedence: Env vars > Config file > Defaults
    # Reason: Environment variables should always win over config files
    NEO4J_URI="${env_uri:-${env_url:-${NEO4J_URI:-${NEO4J_URL:-}}}}"
    NEO4J_USERNAME="${env_username:-${NEO4J_USERNAME:-}}"
    NEO4J_PASSWORD="${env_password:-${NEO4J_PASSWORD:-}}"
    NEO4J_DATABASE="${env_database:-${NEO4J_DATABASE:-neo4j}}"
    NEO4J_SCHEMA_SAMPLE_SIZE="${env_sample_size:-${NEO4J_SCHEMA_SAMPLE_SIZE:-100}}"

    # Operation settings
    DEFAULT_TIMEOUT="${DEFAULT_TIMEOUT:-10}"
    MAX_RETRIES="${MAX_RETRIES:-5}"
    DEBUG="${DEBUG:-false}"
    LOG_FILE="${LOG_FILE:-./neo4j-operation.log}"

    # Fetch secrets from GCP if enabled
    # Reason: Auto-fetch credentials from GCP Secret Manager when env vars not set
    fetch_secrets_from_gcp || true  # Don't fail if GCP unavailable
}

# Function: Fetch Neo4j credentials from GCP Secret Manager
# Reason: Securely fetch credentials from cloud instead of hardcoding
fetch_secrets_from_gcp() {
    # Determine if we should use GCP secrets
    local use_gcp="false"
    if [[ "$USE_GCP_SECRETS" == "true" ]]; then
        use_gcp="true"
    elif [[ "$USE_GCP_SECRETS" == "auto" ]]; then
        # Auto mode: Use GCP if no env vars set
        if [[ -z "${NEO4J_URI:-}" || -z "${NEO4J_PASSWORD:-}" ]]; then
            use_gcp="true"
        fi
    fi

    if [[ "$use_gcp" != "true" ]]; then
        log_debug "GCP secrets disabled (USE_GCP_SECRETS=$USE_GCP_SECRETS)"
        return 0
    fi

    # Locate gcloud-cli skill
    local gcloud_script=""
    if [[ -n "$GCLOUD_CLI_SKILL_DIR" && -f "$GCLOUD_CLI_SKILL_DIR/scripts/fetch_neo4j_credentials.sh" ]]; then
        gcloud_script="$GCLOUD_CLI_SKILL_DIR/scripts/fetch_neo4j_credentials.sh"
    elif [[ -f "$HOME/.claude/skills/gcloud-cli/scripts/fetch_neo4j_credentials.sh" ]]; then
        gcloud_script="$HOME/.claude/skills/gcloud-cli/scripts/fetch_neo4j_credentials.sh"
    elif [[ -f "$(dirname "$SKILL_DIR")/google/gcloud-cli/scripts/fetch_neo4j_credentials.sh" ]]; then
        gcloud_script="$(dirname "$SKILL_DIR")/google/gcloud-cli/scripts/fetch_neo4j_credentials.sh"
    fi

    if [[ -z "$gcloud_script" ]]; then
        log_error "GCP secrets enabled but gcloud-cli skill not found"
        log_error "Install: ln -s <repo>/google/gcloud-cli ~/.claude/skills/gcloud-cli"
        log_error "Or disable GCP: export USE_GCP_SECRETS=false"
        return 1
    fi

    # Source and call the credential fetcher
    # shellcheck source=/dev/null
    source "$gcloud_script"

    # Auto-detect service account if not provided
    local sa="${GCP_SERVICE_ACCOUNT}"
    if [[ -z "$sa" ]]; then
        # Sanitize username: extract before @ (if email), then replace dots with hyphens
        # Example: user@xsolla.com → user → username
        local username
        username=$(whoami | cut -d'@' -f1 | tr '.' '-')
        sa="xenia-npc-${username}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
    fi

    log_info "Fetching Neo4j credentials from GCP Secret Manager..."
    fetch_neo4j_credentials "$GCP_PROJECT_ID" "$sa"

    if [[ -n "${NEO4J_URI:-}" ]]; then
        log_debug "Loaded NEO4J_URI from GCP"
    fi
    if [[ -n "${NEO4J_USERNAME:-}" ]]; then
        log_debug "Loaded NEO4J_USERNAME from GCP"
    fi
    if [[ -n "${NEO4J_PASSWORD:-}" ]]; then
        log_debug "Loaded NEO4J_PASSWORD from GCP (${#NEO4J_PASSWORD} chars)"
    fi
}

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
# PYTHON DEPENDENCY CHECK
# ============================================================================

# Function: Print Python installation instructions
print_python_install_instructions() {
    cat >&2 <<'EOF'

Python 3.8+ is required for the Neo4j skill.

INSTALLATION INSTRUCTIONS:
--------------------------

macOS (using Homebrew):
    brew install python3
    pip3 install neo4j pyyaml

macOS (using official installer):
    Download from https://www.python.org/downloads/macos/
    pip3 install neo4j pyyaml

Ubuntu/Debian:
    sudo apt update
    sudo apt install python3 python3-pip
    pip3 install neo4j pyyaml

Windows (WSL):
    sudo apt update
    sudo apt install python3 python3-pip
    pip3 install neo4j pyyaml

After installation, verify with:
    python3 --version
    python3 -c "import neo4j; print('neo4j package OK')"

EOF
}

# Function: Check and report Python dependencies
check_python_dependencies() {
    local errors=0
    local warnings=0

    # Check Python 3.8+
    # Reason: neo4j Python driver requires Python 3.7+, we target 3.8+
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 not found in PATH"
        print_python_install_instructions
        return 1
    fi

    # Verify Python version
    local python_version
    python_version=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || echo "0.0")
    local major minor
    major=$(echo "$python_version" | cut -d. -f1)
    minor=$(echo "$python_version" | cut -d. -f2)

    if [[ "$major" -lt 3 ]] || { [[ "$major" -eq 3 ]] && [[ "$minor" -lt 8 ]]; }; then
        log_error "Python version $python_version is too old. Requires Python 3.8+"
        print_python_install_instructions
        return 1
    fi
    log_debug "Python version: $python_version"

    # Check neo4j package (required)
    # Reason: Required for Neo4j driver operations
    if ! python3 -c "import neo4j" 2>/dev/null; then
        log_error "neo4j package not installed"
        log_error "Install with: pip3 install neo4j"
        errors=$((errors + 1))
    else
        log_debug "neo4j package: installed"
    fi

    # Check pyyaml package (optional, required for templates)
    # Reason: Template features require YAML parsing
    if ! python3 -c "import yaml" 2>/dev/null; then
        log_warn "PyYAML package not installed (required for template features)"
        log_warn "Install with: pip3 install pyyaml"
        warnings=$((warnings + 1))
        # Don't increment errors - PyYAML is optional for basic operations
    else
        log_debug "pyyaml package: installed"
    fi

    if [[ $errors -gt 0 ]]; then
        log_error "Missing required Python packages ($errors errors)"
        return 1
    fi

    if [[ $warnings -gt 0 ]]; then
        log_warn "Some optional packages missing. Template features may be limited."
    fi

    return 0
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

validate_prerequisites() {
    local errors=0

    # Check Python dependencies
    if ! check_python_dependencies; then
        return 1
    fi

    # Check Neo4j connection parameters
    # Reason: All operations require these to connect
    if [[ -z "$NEO4J_URI" ]]; then
        log_error "NEO4J_URI not set (also checked NEO4J_URL)"
        log_error "Option 1: Set environment variable:"
        log_error "    export NEO4J_URI='bolt://localhost:7687'"
        log_error "Option 2: Configure in: $CONFIG_FILE"
        if [[ "$USE_GCP_SECRETS" != "false" ]]; then
            log_error "Option 3: Stored in GCP secret: xenia-npc-neo4j-database-prod"
            log_error "    Check access: gcloud secrets versions access latest \\"
            log_error "        --secret=xenia-npc-neo4j-database-prod \\"
            log_error "        --project=$GCP_PROJECT_ID"
        fi
        errors=$((errors + 1))
    else
        log_debug "NEO4J_URI: $NEO4J_URI"
    fi

    if [[ -z "$NEO4J_USERNAME" ]]; then
        log_error "NEO4J_USERNAME not set"
        log_error "Option 1: Set environment variable:"
        log_error "    export NEO4J_USERNAME='neo4j'"
        log_error "Option 2: Configure in: $CONFIG_FILE"
        if [[ "$USE_GCP_SECRETS" != "false" ]]; then
            local username
            username=$(whoami | cut -d'@' -f1 | tr '.' '-')
            log_error "Option 3: Stored in GCP secret: xenia-npc-user-${username}-neo4j-username-prod"
            log_error "    Check access: gcloud secrets versions access latest \\"
            log_error "        --secret=xenia-npc-user-${username}-neo4j-username-prod \\"
            log_error "        --project=$GCP_PROJECT_ID"
        fi
        errors=$((errors + 1))
    else
        log_debug "NEO4J_USERNAME: $NEO4J_USERNAME"
    fi

    if [[ -z "$NEO4J_PASSWORD" ]]; then
        log_error "NEO4J_PASSWORD not set"
        log_error "Option 1: Set environment variable:"
        log_error "    export NEO4J_PASSWORD='your_password'"
        log_error "Option 2: Configure in: $CONFIG_FILE"
        if [[ "$USE_GCP_SECRETS" != "false" ]]; then
            local username
            username=$(whoami | cut -d'@' -f1 | tr '.' '-')
            log_error "Option 3: Stored in GCP secret: xenia-npc-user-${username}-neo4j-password-prod"
            log_error "    Check access: gcloud secrets versions access latest \\"
            log_error "        --secret=xenia-npc-user-${username}-neo4j-password-prod \\"
            log_error "        --project=$GCP_PROJECT_ID"
        fi
        errors=$((errors + 1))
    else
        log_debug "NEO4J_PASSWORD: set (${#NEO4J_PASSWORD} chars)"
    fi

    if [[ $errors -gt 0 ]]; then
        log_error "Prerequisites check failed ($errors errors)"
        return 1
    fi

    log_debug "Prerequisites check: passed"
    return 0
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

usage() {
    cat <<EOF
Neo4j Skill - Query Neo4j graph databases with raw Cypher or YAML templates

USAGE:
    $(basename "$0") OPERATION [OPTIONS]

OPERATIONS:
    read        Execute raw Cypher query (read-only)
    schema      Get database schema via APOC inspection
    template    Execute a YAML-defined query template
    templates   List, show, or validate templates
    discover    Analyze schema and suggest template patterns

READ OPTIONS:
    --query=CYPHER      Cypher query string (required)
    --params=JSON       Query parameters as JSON object
    --timeout=SECONDS   Query timeout (default: $DEFAULT_TIMEOUT)

SCHEMA OPTIONS:
    --sample-size=N     Number of nodes to sample (default: $NEO4J_SCHEMA_SAMPLE_SIZE)

TEMPLATE OPTIONS:
    <name>              Template name (required)
    --<param>=VALUE     Template-specific parameters
    --timeout=SECONDS   Query timeout (default: $DEFAULT_TIMEOUT)

TEMPLATES OPTIONS:
    --list              List available templates (default)
    --show=NAME         Show template definition
    --validate=NAME     Validate template syntax

DISCOVER OPTIONS:
    --suggest-templates Generate template suggestions from schema

EXAMPLES:
    # Raw Cypher query
    $(basename "$0") read --query="MATCH (n:Person) RETURN n.name LIMIT 5"

    # Query with parameters
    $(basename "$0") read --query="MATCH (n:Person {email: \\\$email}) RETURN n" \\
        --params='{"email": "john@example.com"}'

    # Get database schema
    $(basename "$0") schema --sample-size=100

    # List available templates
    $(basename "$0") templates --list

    # Execute a template
    $(basename "$0") template nodes_by_label --label=Person --limit=50

    # Execute template with exclusion filter
    $(basename "$0") template entity_pool --label=Customer --status_value=Active

    # Discover templates from schema
    $(basename "$0") discover

ENVIRONMENT:
    NEO4J_URI / NEO4J_URL     Neo4j connection URI (required)
    NEO4J_USERNAME            Database username (required)
    NEO4J_PASSWORD            Database password (required)
    NEO4J_DATABASE            Database name (default: neo4j)
    NEO4J_SCHEMA_SAMPLE_SIZE  Schema sample size (default: 100)
    DEBUG                     Enable debug logging (true|false)

DEPENDENCIES:
    Python 3.8+               Required
    neo4j (pip package)       Required for database operations
    pyyaml (pip package)      Required for template features

CONFIG:
    $CONFIG_FILE

For more information, see: $SKILL_DIR/reference.md
EOF
}

# ============================================================================
# MAIN OPERATIONS
# ============================================================================

main() {
    # Load configuration
    load_config

    # Parse operation
    local operation="${1:-}"
    shift || true

    if [[ -z "$operation" ]]; then
        usage
        exit 1
    fi

    # Handle help/version before prerequisite check
    if [[ "$operation" == "--help" || "$operation" == "-h" ]]; then
        usage
        exit 0
    fi

    if [[ "$operation" == "--version" || "$operation" == "-v" ]]; then
        echo "Neo4j Skill v2.0.0"
        exit 0
    fi

    # Parse arguments for operation
    local query=""
    local params=""
    local timeout="$DEFAULT_TIMEOUT"
    local sample_size="$NEO4J_SCHEMA_SAMPLE_SIZE"
    local template_name=""
    local template_action="list"  # Default action for templates command
    local show_template=""
    local validate_template=""
    local suggest_templates="false"

    # Collect all remaining args for template parameters
    local template_params=()

    # For template command, first positional arg after 'template' is the name
    if [[ "$operation" == "template" ]]; then
        if [[ $# -gt 0 && ! "$1" =~ ^-- ]]; then
            template_name="$1"
            shift
        fi
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --query=*)
                query="${1#*=}"
                ;;
            --params=*)
                params="${1#*=}"
                ;;
            --timeout=*)
                timeout="${1#*=}"
                ;;
            --sample-size=*)
                sample_size="${1#*=}"
                ;;
            --list)
                template_action="list"
                ;;
            --show=*)
                template_action="show"
                show_template="${1#*=}"
                ;;
            --validate=*)
                template_action="validate"
                validate_template="${1#*=}"
                ;;
            --suggest-templates)
                suggest_templates="true"
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            --*)
                # Collect template parameters (any --key=value)
                template_params+=("$1")
                ;;
            *)
                log_error "Unknown argument: $1"
                usage
                exit 1
                ;;
        esac
        shift
    done

    # Validate prerequisites
    # Reason: Catch missing dependencies early before running Python
    if ! validate_prerequisites; then
        exit 1
    fi

    # Execute operation
    log_info "Operation: $operation"

    # Build Python command with arguments
    local python_args=()

    case "$operation" in
        read)
            # Validate required arguments
            if [[ -z "$query" ]]; then
                log_error "Missing required argument: --query"
                exit 1
            fi

            python_args=("read" "--query=$query")
            if [[ -n "$params" ]]; then
                python_args+=("--params=$params")
            fi
            python_args+=("--timeout=$timeout")

            log_info "Executing Cypher query..."
            ;;

        schema)
            python_args=("schema")
            if [[ -n "$sample_size" ]]; then
                python_args+=("--sample-size=$sample_size")
            fi

            log_info "Fetching database schema (sample size: $sample_size)..."
            ;;

        template)
            # Validate required arguments
            if [[ -z "$template_name" ]]; then
                log_error "Missing template name"
                log_error "Usage: $(basename "$0") template <name> [--param=value ...]"
                exit 1
            fi

            python_args=("template" "$template_name")
            python_args+=("--timeout=$timeout")

            # Pass through all template parameters
            # Reason: Use ${arr[@]+"${arr[@]}"} pattern to safely handle empty arrays with set -u
            if [[ ${#template_params[@]} -gt 0 ]]; then
                for param in "${template_params[@]}"; do
                    python_args+=("$param")
                done
            fi

            log_info "Executing template: $template_name..."
            ;;

        templates)
            python_args=("templates")

            case "$template_action" in
                list)
                    python_args+=("--list")
                    log_info "Listing available templates..."
                    ;;
                show)
                    python_args+=("--show=$show_template")
                    log_info "Showing template: $show_template..."
                    ;;
                validate)
                    python_args+=("--validate=$validate_template")
                    log_info "Validating template: $validate_template..."
                    ;;
            esac
            ;;

        discover)
            python_args=("discover")
            if [[ "$suggest_templates" == "true" ]]; then
                python_args+=("--suggest-templates")
            fi

            log_info "Discovering schema patterns..."
            ;;

        *)
            log_error "Unknown operation: $operation"
            log_error "Valid operations: read, schema, template, templates, discover"
            usage
            exit 1
            ;;
    esac

    # Execute Python script
    # Reason: Python handles actual Neo4j driver operations, bash handles CLI
    log_debug "Running: python3 $SKILL_DIR/scripts/neo4j_operations.py ${python_args[*]}"

    if python3 "$SKILL_DIR/scripts/neo4j_operations.py" "${python_args[@]}"; then
        log_success "Operation completed successfully"
    else
        log_error "Operation failed"
        exit 1
    fi
}

# Execute main function
main "$@"
