#!/usr/bin/env python3
"""
Neo4j Operations - Universal Python Driver for Claude Code Skill

A project-agnostic Neo4j skill with:
- Raw Cypher execution with retry logic and connection pooling
- Schema inspection via APOC
- YAML-based template system for custom query patterns

Version: 2.0.0
Created: 2025-12-04
Updated: 2025-12-25

Operations:
    read      - Execute raw Cypher query (read-only)
    schema    - Get database schema via APOC
    template  - Execute a YAML-defined query template
    templates - List/validate available templates
    discover  - Suggest templates based on schema

Environment Variables:
    NEO4J_URI / NEO4J_URL     - Neo4j connection URI (required)
    NEO4J_USERNAME            - Database username (required)
    NEO4J_PASSWORD            - Database password (required)
    NEO4J_DATABASE            - Database name (default: neo4j)
    NEO4J_SCHEMA_SAMPLE_SIZE  - Schema inspection sample size (default: 100)
"""

import os
import sys
import json
import argparse
import time
import re
from datetime import datetime
from pathlib import Path
from string import Template
from typing import Dict, List, Any, Optional, Tuple

# Reason: Try importing neo4j driver, provide clear error if not installed
try:
    from neo4j import GraphDatabase
    from neo4j.exceptions import (
        ServiceUnavailable,
        SessionExpired,
        TransientError,
        AuthError,
        ClientError,
        Neo4jError
    )
except ImportError:
    print(json.dumps({
        "status": "error",
        "error": "neo4j package not installed",
        "solution": "Run: pip install neo4j"
    }), file=sys.stderr)
    sys.exit(1)

# Reason: Try importing PyYAML for template support
try:
    import yaml
except ImportError:
    yaml = None  # Template features will be disabled


# ============================================================================
# CONFIGURATION DEFAULTS
# ============================================================================

DEFAULT_TIMEOUT_SECONDS = 10
MAX_RETRIES = 5
RETRY_BASE_DELAY = 2  # seconds
RETRY_MAX_DELAY = 32  # seconds
SCHEMA_SAMPLE_SIZE = 100


# ============================================================================
# ERROR CLASSIFICATION
# ============================================================================

# Reason: Transient errors should trigger retry with backoff
TRANSIENT_ERRORS = (
    ServiceUnavailable,
    SessionExpired,
    TransientError,
)

# Reason: Permanent errors should fail immediately (no point retrying)
PERMANENT_ERRORS = (
    AuthError,
)


# ============================================================================
# NEO4J CLIENT CLASS
# ============================================================================

class Neo4jClient:
    """
    Neo4j client with connection pooling and retry logic.

    Implements automatic retry for transient errors with exponential backoff.
    Retry policy: 5 retries, 2s base delay, 32s max delay.

    Reason: Synchronous driver is simpler for skill subprocess pattern.
    Skills are short-lived processes - async provides no benefit here.
    """

    _driver = None  # Class-level driver for connection pooling within process

    def __init__(self):
        """Initialize client, reuse existing driver if available."""
        # Reason: Support both NEO4J_URI and NEO4J_URL for compatibility
        self.uri = os.getenv('NEO4J_URI') or os.getenv('NEO4J_URL')
        self.username = os.getenv('NEO4J_USERNAME')
        self.password = os.getenv('NEO4J_PASSWORD')
        self.database = os.getenv('NEO4J_DATABASE', 'neo4j')
        self.schema_sample_size = int(os.getenv('NEO4J_SCHEMA_SAMPLE_SIZE', SCHEMA_SAMPLE_SIZE))

        self._validate_config()
        self._get_or_create_driver()

    def _validate_config(self):
        """Validate required environment variables."""
        missing = []
        if not self.uri:
            missing.append('NEO4J_URI or NEO4J_URL')
        if not self.username:
            missing.append('NEO4J_USERNAME')
        if not self.password:
            missing.append('NEO4J_PASSWORD')

        if missing:
            raise ValueError(
                f"Missing required environment variables: {', '.join(missing)}. "
                "Set via environment or config/neo4j.conf"
            )

    def _get_or_create_driver(self):
        """Get existing driver or create new one (connection pooling)."""
        # Reason: Reuse driver within process for connection efficiency
        if Neo4jClient._driver is None:
            # ═══════════════════════════════════════════════════════════════════
            # SUPPRESS DRIVER NOTIFICATIONS
            # Issue: "Received notification from DBMS server" messages go to stdout
            # Fix: Configure driver to suppress GQL notifications
            # ═══════════════════════════════════════════════════════════════════

            # Create driver with notification filtering
            driver_config = {
                "auth": (self.username, self.password),
                "max_connection_pool_size": 5,
                "connection_timeout": 30,
            }

            # Reason: Try to disable notifications (neo4j 5.x feature)
            try:
                from neo4j import NotificationDisabledClassification
                driver_config["notifications_disabled_classifications"] = [
                    NotificationDisabledClassification.HINT,
                    NotificationDisabledClassification.UNRECOGNIZED,
                    NotificationDisabledClassification.GENERIC,
                    NotificationDisabledClassification.DEPRECATION,
                    NotificationDisabledClassification.PERFORMANCE,
                ]
            except ImportError:
                # Older driver version - notifications can't be disabled at driver level
                pass

            Neo4jClient._driver = GraphDatabase.driver(self.uri, **driver_config)
        return Neo4jClient._driver

    def execute_with_retry(
        self,
        operation_func,
        operation_name: str,
        timeout: int = DEFAULT_TIMEOUT_SECONDS
    ) -> Tuple[Any, Dict]:
        """
        Execute operation with retry logic.

        Implements exponential backoff: 2s, 4s, 8s, 16s, 32s

        Args:
            operation_func: Function(timeout) -> result
            operation_name: Name for logging
            timeout: Query timeout in seconds

        Returns:
            Tuple of (result, metadata with retry info)

        Raises:
            RuntimeError: After all retries exhausted or on permanent error
        """
        last_error = None
        attempts = []

        for attempt in range(MAX_RETRIES + 1):
            attempt_start = time.time()

            try:
                result = operation_func(timeout)
                duration_ms = int((time.time() - attempt_start) * 1000)

                attempts.append({
                    "attempt": attempt + 1,
                    "success": True,
                    "duration_ms": duration_ms
                })

                return result, {
                    "attempts": attempts,
                    "total_attempts": attempt + 1,
                    "success": True
                }

            except TRANSIENT_ERRORS as e:
                duration_ms = int((time.time() - attempt_start) * 1000)
                last_error = e

                attempts.append({
                    "attempt": attempt + 1,
                    "success": False,
                    "error": str(e),
                    "error_type": "transient",
                    "duration_ms": duration_ms
                })

                if attempt < MAX_RETRIES:
                    # Reason: Exponential backoff: 2, 4, 8, 16, 32 seconds
                    delay = min(RETRY_BASE_DELAY * (2 ** attempt), RETRY_MAX_DELAY)
                    time.sleep(delay)

            except PERMANENT_ERRORS as e:
                duration_ms = int((time.time() - attempt_start) * 1000)

                attempts.append({
                    "attempt": attempt + 1,
                    "success": False,
                    "error": str(e),
                    "error_type": "permanent",
                    "duration_ms": duration_ms
                })

                # Reason: Permanent error - fail immediately, no retry
                raise RuntimeError(f"Permanent error (no retry): {e}")

            except (ClientError, Neo4jError) as e:
                # Reason: Query errors (syntax, etc.) - don't retry, report clearly
                duration_ms = int((time.time() - attempt_start) * 1000)

                attempts.append({
                    "attempt": attempt + 1,
                    "success": False,
                    "error": str(e),
                    "error_type": "client_error",
                    "duration_ms": duration_ms
                })

                raise RuntimeError(f"Neo4j error: {e}")

        # All retries exhausted
        raise RuntimeError(
            f"Operation '{operation_name}' failed after {MAX_RETRIES + 1} attempts. "
            f"Last error: {last_error}"
        )

    def close(self):
        """Close driver connection (optional - pooling keeps it alive)."""
        if Neo4jClient._driver:
            Neo4jClient._driver.close()
            Neo4jClient._driver = None


# ============================================================================
# CORE OPERATIONS
# ============================================================================

def execute_read(
    client: Neo4jClient,
    query: str,
    params: Optional[Dict] = None,
    timeout: int = DEFAULT_TIMEOUT_SECONDS
) -> Dict[str, Any]:
    """
    Execute raw Cypher read query.

    Args:
        client: Neo4j client instance
        query: Cypher query string
        params: Query parameters (optional)
        timeout: Query timeout in seconds

    Returns:
        dict: Query results with metadata
    """
    params = params or {}

    def _execute(timeout_seconds):
        driver = client._get_or_create_driver()
        with driver.session(database=client.database) as session:
            result = session.run(query, params, timeout=timeout_seconds)
            # Reason: Consume all records before closing session
            records = [dict(record) for record in result]
            summary = result.consume()
            return {
                "records": records,
                "summary": {
                    "result_available_after": summary.result_available_after,
                    "result_consumed_after": summary.result_consumed_after
                }
            }

    result, metadata = client.execute_with_retry(
        _execute,
        "read_query",
        timeout
    )

    return {
        "status": "success",
        "operation": "read",
        "record_count": len(result["records"]),
        "records": result["records"],
        "query_summary": result["summary"],
        "retry_metadata": metadata,
        "timestamp": datetime.now().isoformat() + 'Z'
    }


def get_schema(
    client: Neo4jClient,
    sample_size: Optional[int] = None
) -> Dict[str, Any]:
    """
    Get database schema using APOC meta.schema.

    Requires APOC plugin installed on Neo4j instance.

    Args:
        client: Neo4j client instance
        sample_size: Number of nodes to sample (default from config)

    Returns:
        dict: Schema information with node labels, properties, relationships
    """
    sample_size = sample_size or client.schema_sample_size

    # Reason: Use APOC meta.schema with sampling for large DBs
    query = "CALL apoc.meta.schema({sample: $sample_size}) YIELD value RETURN value"

    def _execute(timeout_seconds):
        driver = client._get_or_create_driver()
        with driver.session(database=client.database) as session:
            result = session.run(query, {"sample_size": sample_size}, timeout=timeout_seconds)
            record = result.single()
            return record["value"] if record else {}

    try:
        result, metadata = client.execute_with_retry(
            _execute,
            "get_schema",
            30  # Schema can take longer on large DBs
        )
    except RuntimeError as e:
        if "ProcedureNotFound" in str(e):
            return {
                "status": "error",
                "operation": "schema",
                "error": "APOC plugin not installed",
                "solution": "Install and enable APOC plugin on Neo4j instance",
                "timestamp": datetime.now().isoformat() + 'Z'
            }
        raise

    return {
        "status": "success",
        "operation": "schema",
        "sample_size": sample_size,
        "schema": result,
        "retry_metadata": metadata,
        "timestamp": datetime.now().isoformat() + 'Z'
    }


# ============================================================================
# TEMPLATE ENGINE
# ============================================================================

class TemplateEngine:
    """
    Load and execute YAML-defined query templates.

    Templates are discovered from multiple locations in order of precedence:
    1. Project templates: .claude/neo4j-templates/
    2. Skill templates: <skill>/templates/
    3. User templates: ~/.claude/neo4j-templates/

    Reason: Allows project-specific, skill-bundled, and user-level templates
    to coexist with clear override semantics.
    """

    def __init__(self, template_dirs: Optional[List[Path]] = None):
        """
        Initialize template engine with discovery directories.

        Args:
            template_dirs: Custom directories to scan for templates.
                          If None, uses default discovery locations.
        """
        if yaml is None:
            raise RuntimeError(
                "PyYAML not installed. Template features disabled. "
                "Install with: pip install pyyaml"
            )

        self.templates: Dict[str, Dict] = {}
        self.template_sources: Dict[str, Path] = {}

        if template_dirs is None:
            template_dirs = self._get_default_dirs()

        self._discover_templates(template_dirs)

    def _get_default_dirs(self) -> List[Path]:
        """
        Get default template discovery directories.

        Returns directories in precedence order (first wins).
        """
        dirs = []

        # 1. Project-level templates (highest precedence)
        project_dir = Path.cwd() / '.claude' / 'neo4j-templates'
        if project_dir.exists():
            dirs.append(project_dir)

        # 2. Skill-bundled templates
        # Reason: Relative to this script's location
        script_dir = Path(__file__).parent.parent / 'templates'
        if script_dir.exists():
            dirs.append(script_dir)

        # 3. User-level templates (lowest precedence)
        user_dir = Path.home() / '.claude' / 'neo4j-templates'
        if user_dir.exists():
            dirs.append(user_dir)

        return dirs

    def _discover_templates(self, dirs: List[Path]) -> None:
        """
        Scan directories for YAML template files.

        Args:
            dirs: List of directories to scan (in precedence order)
        """
        for template_dir in dirs:
            if not template_dir.exists():
                continue

            # Reason: Skip _examples directory (for reference only)
            for yaml_file in template_dir.glob("*.yaml"):
                if yaml_file.parent.name == '_examples':
                    continue

                try:
                    template = self._load_template(yaml_file)
                    name = template.get("name", yaml_file.stem)

                    # Reason: First occurrence wins (precedence order)
                    if name not in self.templates:
                        self.templates[name] = template
                        self.template_sources[name] = yaml_file

                except Exception as e:
                    # Reason: Log error but continue loading other templates
                    print(f"Warning: Failed to load template {yaml_file}: {e}",
                          file=sys.stderr)

    def _load_template(self, yaml_file: Path) -> Dict:
        """
        Load and validate a single template file.

        Args:
            yaml_file: Path to YAML template

        Returns:
            Parsed template dictionary

        Raises:
            ValueError: If template is invalid
        """
        with open(yaml_file, 'r') as f:
            template = yaml.safe_load(f)

        # Validate required fields
        if not template:
            raise ValueError("Empty template file")

        if 'query' not in template:
            raise ValueError("Template missing required 'query' field")

        # Set defaults
        template.setdefault('name', yaml_file.stem)
        template.setdefault('description', '')
        template.setdefault('version', '1.0')
        template.setdefault('parameters', {})

        return template

    def list_templates(self) -> List[Dict[str, str]]:
        """
        List all available templates.

        Returns:
            List of template info dicts with name, description, source
        """
        result = []
        for name, template in self.templates.items():
            result.append({
                "name": name,
                "description": template.get("description", ""),
                "version": template.get("version", "1.0"),
                "source": str(self.template_sources.get(name, "unknown"))
            })
        return sorted(result, key=lambda x: x["name"])

    def get_template(self, name: str) -> Optional[Dict]:
        """
        Get a template by name.

        Args:
            name: Template name

        Returns:
            Template dict or None if not found
        """
        return self.templates.get(name)

    def validate_params(self, template: Dict, params: Dict) -> Dict:
        """
        Validate and apply defaults to template parameters.

        Args:
            template: Template definition
            params: User-provided parameters

        Returns:
            Validated parameters with defaults applied

        Raises:
            ValueError: If required parameter missing or type mismatch
        """
        validated = {}
        param_specs = template.get('parameters', {})

        for param_name, spec in param_specs.items():
            if param_name in params:
                # Use provided value
                value = params[param_name]

                # Reason: Type coercion for CLI input
                param_type = spec.get('type', 'string')
                try:
                    value = self._coerce_type(value, param_type)
                except (ValueError, TypeError) as e:
                    raise ValueError(
                        f"Parameter '{param_name}' type error: {e}"
                    )

                validated[param_name] = value

            elif 'default' in spec:
                # Use default
                validated[param_name] = spec['default']

            elif spec.get('required', False):
                # Required but missing
                raise ValueError(
                    f"Missing required parameter: '{param_name}'"
                )

        return validated

    def _coerce_type(self, value: Any, param_type: str) -> Any:
        """
        Coerce value to specified type.

        Args:
            value: Input value
            param_type: Target type (string, integer, boolean, array, object)

        Returns:
            Coerced value
        """
        if param_type == 'string':
            return str(value)
        elif param_type == 'integer':
            return int(value)
        elif param_type == 'boolean':
            if isinstance(value, bool):
                return value
            if isinstance(value, str):
                return value.lower() in ('true', '1', 'yes')
            return bool(value)
        elif param_type == 'array':
            if isinstance(value, list):
                return value
            if isinstance(value, str):
                return json.loads(value)
            return list(value)
        elif param_type == 'object':
            if isinstance(value, dict):
                return value
            if isinstance(value, str):
                return json.loads(value)
            raise ValueError(f"Cannot convert {type(value)} to object")
        else:
            return value

    def render_query(self, template: Dict, params: Dict) -> str:
        """
        Render query with parameter substitution.

        Supports two substitution styles:
        - ${param} - String interpolation (for labels, properties)
        - $param - Cypher parameter (for values)

        Args:
            template: Template definition
            params: Validated parameters

        Returns:
            Rendered Cypher query string
        """
        query = template['query']

        # Reason: Handle ${param} style for label/property interpolation
        # These get substituted directly into the query string
        pattern = r'\$\{(\w+)\}'
        matches = re.findall(pattern, query)

        for match in matches:
            if match in params:
                # Reason: Sanitize for Cypher label/property names
                safe_value = self._sanitize_identifier(str(params[match]))
                query = query.replace(f'${{{match}}}', safe_value)

        return query

    def _sanitize_identifier(self, value: str) -> str:
        """
        Sanitize a value for use as Cypher identifier (label/property name).

        Reason: Prevent Cypher injection when interpolating into query

        Args:
            value: Raw identifier value

        Returns:
            Sanitized identifier
        """
        # Only allow alphanumeric and underscore
        sanitized = re.sub(r'[^a-zA-Z0-9_]', '', value)
        if not sanitized:
            raise ValueError(f"Invalid identifier: '{value}'")
        return sanitized

    def execute(
        self,
        client: Neo4jClient,
        template_name: str,
        params: Dict,
        timeout: int = DEFAULT_TIMEOUT_SECONDS
    ) -> Dict[str, Any]:
        """
        Execute a template with given parameters.

        Args:
            client: Neo4j client
            template_name: Name of template to execute
            params: Template parameters
            timeout: Query timeout

        Returns:
            Query results with metadata
        """
        template = self.get_template(template_name)
        if not template:
            # Reason: Use "not_found" status (not "error") for missing templates
            # This returns exit code 0 since it's a valid response, not a failure
            return {
                "status": "not_found",
                "operation": "template",
                "template_name": template_name,
                "error": f"Template not found: '{template_name}'",
                "available_templates": [t["name"] for t in self.list_templates()],
                "timestamp": datetime.now().isoformat() + 'Z'
            }

        try:
            # Validate and apply defaults
            validated_params = self.validate_params(template, params)

            # Render query with interpolation
            query = self.render_query(template, validated_params)

            # Execute query
            # Reason: Only pass Cypher parameters ($param style) to driver
            cypher_params = {
                k: v for k, v in validated_params.items()
                if f'${k}' in template['query'] and f'${{{k}}}' not in template['query']
            }

            result = execute_read(client, query, cypher_params, timeout)

            # Add template metadata to result
            result["template_name"] = template_name
            result["template_version"] = template.get("version", "1.0")
            result["parameters_applied"] = validated_params

            return result

        except ValueError as e:
            return {
                "status": "error",
                "operation": "template",
                "template_name": template_name,
                "error": str(e),
                "timestamp": datetime.now().isoformat() + 'Z'
            }


# ============================================================================
# DISCOVERY OPERATIONS
# ============================================================================

def discover_schema_patterns(client: Neo4jClient) -> Dict[str, Any]:
    """
    Analyze database schema and suggest template patterns.

    Args:
        client: Neo4j client

    Returns:
        Schema analysis with template suggestions
    """
    suggestions = []

    # Get node labels and counts
    labels_query = """
    CALL db.labels() YIELD label
    CALL apoc.cypher.run('MATCH (n:`' + label + '`) RETURN count(n) as count', {})
    YIELD value
    RETURN label, value.count as count
    ORDER BY value.count DESC
    LIMIT 20
    """

    try:
        result = execute_read(client, labels_query, timeout=30)

        for record in result.get("records", []):
            label = record.get("label")
            count = record.get("count", 0)

            if count > 0:
                suggestions.append({
                    "type": "node_query",
                    "label": label,
                    "count": count,
                    "suggested_template": f"""name: {label.lower()}_query
description: Query {label} nodes
parameters:
  limit:
    type: integer
    default: 100
query: |
  MATCH (n:{label})
  RETURN n
  LIMIT $limit
"""
                })

    except RuntimeError:
        # APOC not available, use simpler query
        labels_query = """
        MATCH (n)
        RETURN DISTINCT labels(n) AS labels, count(*) AS count
        ORDER BY count DESC
        LIMIT 20
        """
        result = execute_read(client, labels_query, timeout=30)

        for record in result.get("records", []):
            labels = record.get("labels", [])
            if labels:
                label = labels[0]
                count = record.get("count", 0)

                suggestions.append({
                    "type": "node_query",
                    "label": label,
                    "count": count,
                    "suggested_template": f"Query {label} nodes (count: {count})"
                })

    return {
        "status": "success",
        "operation": "discover",
        "suggestions": suggestions,
        "timestamp": datetime.now().isoformat() + 'Z'
    }


# ============================================================================
# CLI INTERFACE
# ============================================================================

def main():
    """Main entry point with argument parsing."""
    # ═══════════════════════════════════════════════════════════════════════════════
    # SUPPRESS NEO4J DRIVER WARNINGS
    # Issue: Neo4j driver outputs warnings to stdout before JSON, breaking parsing
    # Fix: Redirect driver warnings to stderr and suppress benign notifications
    # ═══════════════════════════════════════════════════════════════════════════════
    import warnings
    import logging

    # Suppress Python warnings from neo4j driver
    warnings.filterwarnings('ignore', category=DeprecationWarning, module='neo4j')
    warnings.filterwarnings('ignore', category=UserWarning, module='neo4j')

    # Suppress neo4j driver logging
    logging.getLogger('neo4j').setLevel(logging.ERROR)
    logging.getLogger('neo4j.io').setLevel(logging.ERROR)
    logging.getLogger('neo4j.pool').setLevel(logging.ERROR)
    logging.getLogger('neo4j.bolt').setLevel(logging.ERROR)

    parser = argparse.ArgumentParser(
        description='Neo4j Operations - Universal Claude Code Skill',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Operations:
  read          Execute raw Cypher query (read-only)
  schema        Get database schema (requires APOC)
  template      Execute a YAML-defined query template
  templates     List/validate available templates
  discover      Analyze schema and suggest templates

Examples:
  %(prog)s read --query="MATCH (n) RETURN labels(n), count(*) LIMIT 10"
  %(prog)s schema --sample-size=100
  %(prog)s templates --list
  %(prog)s template entity_pool --label=Employee --limit=50
  %(prog)s discover

Environment Variables:
  NEO4J_URI / NEO4J_URL     Connection URI (required)
  NEO4J_USERNAME            Database username (required)
  NEO4J_PASSWORD            Database password (required)
  NEO4J_DATABASE            Database name (default: neo4j)
  NEO4J_SCHEMA_SAMPLE_SIZE  Schema sample size (default: 100)
        '''
    )

    subparsers = parser.add_subparsers(dest='operation', help='Operation to perform')

    # ─────────────────────────────────────────────────────────────────────────────
    # READ OPERATION
    # ─────────────────────────────────────────────────────────────────────────────
    read_parser = subparsers.add_parser('read', help='Execute raw Cypher query')
    read_parser.add_argument('--query', '-q', required=True, help='Cypher query')
    read_parser.add_argument('--params', '-p', help='JSON parameters')
    read_parser.add_argument('--timeout', '-t', type=int, default=DEFAULT_TIMEOUT_SECONDS,
                            help=f'Query timeout in seconds (default: {DEFAULT_TIMEOUT_SECONDS})')

    # ─────────────────────────────────────────────────────────────────────────────
    # SCHEMA OPERATION
    # ─────────────────────────────────────────────────────────────────────────────
    schema_parser = subparsers.add_parser('schema', help='Get database schema')
    schema_parser.add_argument('--sample-size', type=int, help='Sample size for schema inference')

    # ─────────────────────────────────────────────────────────────────────────────
    # TEMPLATE OPERATION
    # ─────────────────────────────────────────────────────────────────────────────
    template_parser = subparsers.add_parser('template', help='Execute a query template')
    template_parser.add_argument('name', help='Template name')
    template_parser.add_argument('--timeout', '-t', type=int, default=DEFAULT_TIMEOUT_SECONDS)
    # Reason: Allow arbitrary parameters via --param=value syntax
    # Use REMAINDER to capture all args including those starting with --
    template_parser.add_argument('params', nargs=argparse.REMAINDER, metavar='--PARAM=VALUE',
                                help='Template parameters (e.g., --label=Employee)')

    # ─────────────────────────────────────────────────────────────────────────────
    # TEMPLATES OPERATION (list/validate)
    # ─────────────────────────────────────────────────────────────────────────────
    templates_parser = subparsers.add_parser('templates', help='List/validate templates')
    templates_parser.add_argument('--list', '-l', action='store_true', help='List available templates')
    templates_parser.add_argument('--validate', '-v', help='Validate a specific template')
    templates_parser.add_argument('--show', '-s', help='Show template definition')

    # ─────────────────────────────────────────────────────────────────────────────
    # DISCOVER OPERATION
    # ─────────────────────────────────────────────────────────────────────────────
    discover_parser = subparsers.add_parser('discover', help='Suggest templates from schema')
    discover_parser.add_argument('--suggest-templates', action='store_true', default=True,
                                help='Generate template suggestions')

    args = parser.parse_args()

    if not args.operation:
        parser.print_help()
        sys.exit(1)

    try:
        # ═══════════════════════════════════════════════════════════════════════════
        # OPERATION DISPATCH
        # ═══════════════════════════════════════════════════════════════════════════

        if args.operation == 'read':
            client = Neo4jClient()
            params = json.loads(args.params) if args.params else None
            result = execute_read(client, args.query, params, args.timeout)

        elif args.operation == 'schema':
            client = Neo4jClient()
            result = get_schema(client, args.sample_size)

        elif args.operation == 'template':
            client = Neo4jClient()

            # Parse template parameters from --param=value format
            template_params = {}
            for param in args.params or []:
                if '=' in param:
                    # Handle --param=value format
                    key, value = param.split('=', 1)
                    key = key.lstrip('-')
                    template_params[key] = value
                elif param.startswith('--'):
                    # Handle --flag format (boolean true)
                    key = param.lstrip('-')
                    template_params[key] = True

            engine = TemplateEngine()
            result = engine.execute(client, args.name, template_params, args.timeout)

        elif args.operation == 'templates':
            engine = TemplateEngine()

            if args.show:
                template = engine.get_template(args.show)
                if template:
                    result = {
                        "status": "success",
                        "operation": "templates",
                        "action": "show",
                        "template_name": args.show,
                        "template": template,
                        "source": str(engine.template_sources.get(args.show, "unknown")),
                        "timestamp": datetime.now().isoformat() + 'Z'
                    }
                else:
                    result = {
                        "status": "not_found",
                        "operation": "templates",
                        "template_name": args.show,
                        "error": f"Template not found: '{args.show}'",
                        "available": [t["name"] for t in engine.list_templates()],
                        "timestamp": datetime.now().isoformat() + 'Z'
                    }

            elif args.validate:
                template = engine.get_template(args.validate)
                if template:
                    # Basic validation checks
                    issues = []
                    if not template.get('query'):
                        issues.append("Missing 'query' field")
                    if not template.get('description'):
                        issues.append("Missing 'description' field")

                    result = {
                        "status": "success" if not issues else "warning",
                        "operation": "templates",
                        "action": "validate",
                        "template_name": args.validate,
                        "valid": len(issues) == 0,
                        "issues": issues,
                        "timestamp": datetime.now().isoformat() + 'Z'
                    }
                else:
                    result = {
                        "status": "not_found",
                        "operation": "templates",
                        "template_name": args.validate,
                        "error": f"Template not found: '{args.validate}'",
                        "timestamp": datetime.now().isoformat() + 'Z'
                    }

            else:  # Default: list
                templates = engine.list_templates()
                result = {
                    "status": "success",
                    "operation": "templates",
                    "action": "list",
                    "template_count": len(templates),
                    "templates": templates,
                    "discovery_locations": [str(d) for d in engine._get_default_dirs()],
                    "timestamp": datetime.now().isoformat() + 'Z'
                }

        elif args.operation == 'discover':
            client = Neo4jClient()
            result = discover_schema_patterns(client)

        else:
            raise ValueError(f"Unknown operation: {args.operation}")

        # Output JSON result to stdout
        print(json.dumps(result, indent=2, default=str))

        # Exit code based on status
        if result.get("status") == "success":
            sys.exit(0)
        elif result.get("status") == "not_found":
            sys.exit(0)  # Not found is not an error
        elif result.get("status") == "warning":
            sys.exit(0)  # Warnings are not errors
        else:
            sys.exit(1)

    except ValueError as e:
        # Configuration or validation error
        error_result = {
            "status": "error",
            "error": str(e),
            "error_type": "configuration",
            "operation": args.operation if hasattr(args, 'operation') else None,
            "timestamp": datetime.now().isoformat() + 'Z'
        }
        print(json.dumps(error_result, indent=2), file=sys.stderr)
        sys.exit(1)

    except RuntimeError as e:
        # Neo4j execution error
        error_result = {
            "status": "error",
            "error": str(e),
            "error_type": "execution",
            "operation": args.operation if hasattr(args, 'operation') else None,
            "timestamp": datetime.now().isoformat() + 'Z'
        }
        print(json.dumps(error_result, indent=2), file=sys.stderr)
        sys.exit(1)

    except Exception as e:
        # Unexpected error
        error_result = {
            "status": "error",
            "error": str(e),
            "error_type": "unexpected",
            "operation": args.operation if hasattr(args, 'operation') else None,
            "timestamp": datetime.now().isoformat() + 'Z'
        }
        print(json.dumps(error_result, indent=2), file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
