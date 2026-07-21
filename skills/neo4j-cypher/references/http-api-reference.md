# Neo4j Skill - API Reference

Complete reference for all Neo4j skill operations, parameters, and return values.

## Table of Contents

1. [read - Raw Cypher Query](#read---raw-cypher-query)
2. [schema - Database Schema](#schema---database-schema)
3. [template - Execute Query Template](#template---execute-query-template)
4. [templates - Manage Templates](#templates---manage-templates)
5. [discover - Schema Discovery](#discover---schema-discovery)
6. [Error Handling](#error-handling)
7. [Configuration Reference](#configuration-reference)
8. [Template YAML Specification](#template-yaml-specification)

---

## read - Raw Cypher Query

Execute any read-only Cypher query against the Neo4j database.

### Usage

```bash
neo4j read --query=CYPHER [--params=JSON] [--timeout=SECONDS]
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--query` | Yes | - | Cypher query string |
| `--params` | No | `{}` | Query parameters as JSON object |
| `--timeout` | No | `10` | Query timeout in seconds |

### Return Value

```json
{
  "status": "success",
  "operation": "read",
  "record_count": 5,
  "records": [
    {"name": "Alice", "email": "alice@example.com"},
    {"name": "Bob", "email": "bob@example.com"}
  ],
  "query_summary": {
    "result_available_after": 15,
    "result_consumed_after": 18
  },
  "retry_metadata": {
    "attempts": [
      {"attempt": 1, "success": true, "duration_ms": 156}
    ],
    "total_attempts": 1,
    "success": true
  },
  "timestamp": "2025-12-25T10:15:30.123456Z"
}
```

### Examples

```bash
# Simple query
neo4j read --query="MATCH (n:Person) RETURN n.name LIMIT 5"

# With parameters (prevents Cypher injection)
neo4j read \
    --query="MATCH (n:Person {email: \$email}) RETURN n.name" \
    --params='{"email": "user@example.com"}'

# Complex aggregation with timeout
neo4j read \
    --query="MATCH (n)-[r]->(m)
             RETURN labels(n)[0] AS from_label, type(r) AS rel_type, labels(m)[0] AS to_label, count(*) AS count
             ORDER BY count DESC" \
    --timeout=30
```

### Notes

- **Read-only**: Only read operations allowed (no CREATE, MERGE, DELETE, SET)
- **Parameters**: Always use `$param` syntax to prevent injection
- **Retry**: Transient errors (connection, timeout) automatically retried

---

## schema - Database Schema

Get database schema using APOC meta.schema inspection.

### Usage

```bash
neo4j schema [--sample-size=N]
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--sample-size` | No | `100` | Number of nodes to sample |

### Return Value

```json
{
  "status": "success",
  "operation": "schema",
  "sample_size": 100,
  "schema": {
    "Person": {
      "type": "node",
      "count": 5000,
      "labels": ["Person"],
      "properties": {
        "email": {"type": "STRING", "indexed": true},
        "name": {"type": "STRING"},
        "age": {"type": "INTEGER"}
      },
      "relationships": {
        "KNOWS": {"direction": "OUTGOING", "labels": ["Person"]},
        "WORKS_AT": {"direction": "OUTGOING", "labels": ["Company"]}
      }
    }
  },
  "retry_metadata": {...},
  "timestamp": "2025-12-25T10:15:30.123456Z"
}
```

### Examples

```bash
# Default sample (100 nodes - fast, good for large DBs)
neo4j schema

# Larger sample (more accurate, slower)
neo4j schema --sample-size=500

# Small sample (very fast, less accurate)
neo4j schema --sample-size=50
```

### Notes

- **Requires APOC**: This operation requires the APOC plugin installed
- **Sample size**: Larger samples = more accurate schema, slower query
- **Large databases**: Use `--sample-size=100` or less for DBs with 1M+ nodes

---

## template - Execute Query Template

Execute a YAML-defined query template with parameters.

### Usage

```bash
neo4j template <name> [--param1=value] [--param2=value] [--timeout=SECONDS]
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `name` | Yes | - | Template name |
| `--timeout` | No | `10` | Query timeout in seconds |
| `--<param>` | Varies | Defined in template | Template-specific parameters |

### Return Value

```json
{
  "status": "success",
  "operation": "read",
  "record_count": 50,
  "records": [...],
  "template_name": "entity_pool",
  "template_version": "1.0",
  "parameters_applied": {
    "label": "Person",
    "limit": 50
  },
  "retry_metadata": {...},
  "timestamp": "2025-12-25T10:15:30.123456Z"
}
```

### Examples

```bash
# Execute with required parameter
neo4j template nodes_by_label --label=Person

# With optional parameters
neo4j template entity_pool --label=Customer --status_value=Active --limit=200

# Array parameter (JSON format)
neo4j template entity_pool --label=Employee --exclude_values='["HR", "Legal"]'

# With custom timeout
neo4j template relationship_query --from_label=Person --relationship=KNOWS --to_label=Person --timeout=30
```

### Template Not Found Response

```json
{
  "status": "error",
  "operation": "template",
  "template_name": "nonexistent",
  "error": "Template not found: 'nonexistent'",
  "available_templates": ["entity_pool", "nodes_by_label", "relationship_query"],
  "timestamp": "2025-12-25T10:15:30.123456Z"
}
```

---

## templates - Manage Templates

List, show, or validate templates.

### Usage

```bash
neo4j templates [--list] [--show=NAME] [--validate=NAME]
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--list` | No | Default action | List available templates |
| `--show` | No | - | Show template definition |
| `--validate` | No | - | Validate template syntax |

### Return Value (--list)

```json
{
  "status": "success",
  "operation": "templates",
  "action": "list",
  "template_count": 3,
  "templates": [
    {
      "name": "entity_pool",
      "description": "Get entities with exclusion filters",
      "version": "1.0",
      "source": "/path/to/templates/entity_pool.yaml"
    }
  ],
  "discovery_locations": [
    ".claude/neo4j-templates",
    "/path/to/skill/templates"
  ],
  "timestamp": "2025-12-25T10:15:30.123456Z"
}
```

### Return Value (--show)

```json
{
  "status": "success",
  "operation": "templates",
  "action": "show",
  "template_name": "entity_pool",
  "template": {
    "name": "entity_pool",
    "description": "Get entities with exclusion filters",
    "version": "1.0",
    "parameters": {...},
    "query": "..."
  },
  "source": "/path/to/templates/entity_pool.yaml",
  "timestamp": "2025-12-25T10:15:30.123456Z"
}
```

### Return Value (--validate)

```json
{
  "status": "success",
  "operation": "templates",
  "action": "validate",
  "template_name": "entity_pool",
  "valid": true,
  "issues": [],
  "timestamp": "2025-12-25T10:15:30.123456Z"
}
```

---

## discover - Schema Discovery

Analyze database schema and suggest template patterns.

### Usage

```bash
neo4j discover [--suggest-templates]
```

### Return Value

```json
{
  "status": "success",
  "operation": "discover",
  "suggestions": [
    {
      "type": "node_query",
      "label": "Person",
      "count": 5000,
      "suggested_template": "name: person_query\ndescription: Query Person nodes\n..."
    },
    {
      "type": "node_query",
      "label": "Order",
      "count": 12000,
      "suggested_template": "name: order_query\n..."
    }
  ],
  "timestamp": "2025-12-25T10:15:30.123456Z"
}
```

---

## Error Handling

### Error Response Format

```json
{
  "status": "error",
  "operation": "read",
  "error": "Detailed error message",
  "error_type": "configuration|execution|unexpected",
  "timestamp": "2025-12-25T10:15:30.123456Z"
}
```

### Error Types

| Type | Description | Action |
|------|-------------|--------|
| `configuration` | Missing env vars, invalid config | Check configuration |
| `execution` | Neo4j query error, connection failed | Check query/connection |
| `unexpected` | Unexpected exception | Check logs |

### Retry Logic

Transient errors trigger automatic retry with exponential backoff:

| Attempt | Delay | Cumulative Time |
|---------|-------|-----------------|
| 1 | 0s | 0s |
| 2 | 2s | 2s |
| 3 | 4s | 6s |
| 4 | 8s | 14s |
| 5 | 16s | 30s |
| 6 | 32s | 62s |

**Retried errors**: `ServiceUnavailable`, `SessionExpired`, `TransientError`

**Not retried**: `AuthError`, `ClientError` (syntax errors, etc.)

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success, "not found", or warning (valid states) |
| 1 | Error (configuration, execution, etc.) |

---

## Configuration Reference

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `NEO4J_URI` | Yes* | - | Neo4j connection URI |
| `NEO4J_URL` | Yes* | - | Alias for NEO4J_URI |
| `NEO4J_USERNAME` | Yes | - | Database username |
| `NEO4J_PASSWORD` | Yes | - | Database password |
| `NEO4J_DATABASE` | No | `neo4j` | Database name |
| `NEO4J_SCHEMA_SAMPLE_SIZE` | No | `100` | Default schema sample size |

*Either `NEO4J_URI` or `NEO4J_URL` must be set.

### Config File

Location: `config/neo4j.conf`

```bash
# Neo4j connection
NEO4J_URI="bolt://localhost:7687"
NEO4J_USERNAME="neo4j"
NEO4J_PASSWORD="password"
NEO4J_DATABASE="neo4j"

# Skill settings
NEO4J_SCHEMA_SAMPLE_SIZE="100"
DEFAULT_TIMEOUT="10"
MAX_RETRIES="5"
```

### Precedence

1. Environment variables (highest)
2. Config file
3. Defaults (lowest)

---

## Template YAML Specification

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `query` | string | Cypher query with parameter placeholders |

### Optional Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | filename | Template identifier |
| `description` | string | `""` | Human-readable description |
| `version` | string | `"1.0"` | Template version |
| `parameters` | object | `{}` | Parameter definitions |

### Parameter Definition

```yaml
parameters:
  param_name:
    type: string|integer|boolean|array|object
    required: true|false
    default: <value>
    description: Human-readable description
```

### Parameter Types

| Type | Description | Example Value |
|------|-------------|---------------|
| `string` | Text value | `"Active"` |
| `integer` | Whole number | `100` |
| `boolean` | True/false | `true` |
| `array` | JSON array | `["a", "b"]` |
| `object` | JSON object | `{"key": "value"}` |

### Substitution Styles

| Style | Purpose | Example |
|-------|---------|---------|
| `${param}` | Label/property interpolation | `MATCH (n:${label})` |
| `$param` | Cypher parameter (driver) | `WHERE n.id = $id` |

**Security**: `${param}` values are sanitized to alphanumeric + underscore only.

---

## Performance Characteristics

### Connection Pooling

The Python driver maintains a connection pool:
- Pool size: 5 connections
- Connection timeout: 30 seconds
- Reused within process lifetime

### Query Timeouts

Default timeouts by operation:

| Operation | Default Timeout | Notes |
|-----------|-----------------|-------|
| `read` | 10s | Configurable via `--timeout` |
| `schema` | 30s | Schema inspection can be slow |
| `template` | 10s | Configurable |
| `discover` | 30s | May query multiple labels |

### Retry Overhead

With retries enabled (default), worst-case overhead for transient failures:
- 5 retries × 32s max delay = ~62 seconds
- Most transient issues resolve in 1-2 retries (<10 seconds)
