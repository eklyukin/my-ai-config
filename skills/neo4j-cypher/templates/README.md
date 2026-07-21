# Neo4j Query Templates

Create reusable query templates for your Neo4j graph database. Templates are YAML files that define parameterized Cypher queries.

## Quick Start

1. Create a YAML file in one of the template directories
2. Define your query with parameters
3. Execute with `neo4j template <name> --param=value`

## Template Locations

Templates are discovered from these locations (in precedence order):

| Location | Purpose | Precedence |
|----------|---------|------------|
| `.claude/neo4j-templates/` | Project-specific templates | Highest (overrides others) |
| `<skill>/templates/` | Skill-bundled templates | Medium |
| `~/.claude/neo4j-templates/` | User-level templates | Lowest |

## Template Format

```yaml
# Required fields
name: my_template           # Unique identifier
query: |                    # Cypher query (required)
  MATCH (n:${label})
  WHERE n.status = $status
  RETURN n LIMIT $limit

# Optional fields
description: Query nodes by label and status
version: "1.0"

# Parameter definitions
parameters:
  label:                    # Parameter name
    type: string            # Type: string, integer, boolean, array, object
    required: true          # Is this parameter mandatory?
    description: Node label to query
  status:
    type: string
    default: "Active"       # Default value if not provided
  limit:
    type: integer
    default: 100
```

## Parameter Substitution

Templates support two substitution styles:

### 1. String Interpolation (`${param}`)

Used for labels, property names, and other identifiers that become part of the query structure:

```yaml
query: |
  MATCH (n:${label})        # ${label} becomes the actual label name
  RETURN n.${property}      # ${property} becomes the actual property name
```

**Security**: Values are sanitized to prevent Cypher injection (only alphanumeric + underscore allowed).

### 2. Cypher Parameters (`$param`)

Used for values that are passed to the Neo4j driver as parameters (safe from injection):

```yaml
query: |
  MATCH (n:Person)
  WHERE n.name = $name      # $name is passed as a driver parameter
    AND n.age >= $min_age
  RETURN n
```

**Best Practice**: Use Cypher parameters (`$param`) for values whenever possible. Only use string interpolation (`${param}`) when you need to dynamically specify labels or property names.

## Parameter Types

| Type | Description | Example Value |
|------|-------------|---------------|
| `string` | Text value | `"Active"` |
| `integer` | Whole number | `100` |
| `boolean` | True/false | `true` or `false` |
| `array` | List of values | `["a", "b", "c"]` |
| `object` | Key-value map | `{"key": "value"}` |

## Example Templates

### Simple Node Query

```yaml
name: nodes_by_label
description: Query nodes by label with optional limit
version: "1.0"

parameters:
  label:
    type: string
    required: true
    description: Node label to query
  limit:
    type: integer
    default: 100

query: |
  MATCH (n:${label})
  RETURN n
  LIMIT $limit
```

**Usage**:
```bash
neo4j template nodes_by_label --label=Person --limit=50
```

### Filtered Entity Pool

```yaml
name: entity_pool
description: Get entities with exclusion filters
version: "1.0"

parameters:
  label:
    type: string
    required: true
  status_property:
    type: string
    default: "status"
  status_value:
    type: string
    default: "Active"
  exclude_property:
    type: string
    description: Property to use for exclusion
  exclude_values:
    type: array
    default: []

query: |
  MATCH (n:${label})
  WHERE n.${status_property} = $status_value
    AND NOT COALESCE(n.${exclude_property}, '') IN $exclude_values
  RETURN n
  ORDER BY n.name
```

**Usage**:
```bash
neo4j template entity_pool --label=Employee --exclude_property=department --exclude_values='["HR", "Finance"]'
```

### Relationship Traversal

```yaml
name: related_nodes
description: Find nodes connected by a relationship
version: "1.0"

parameters:
  from_label:
    type: string
    required: true
  relationship:
    type: string
    required: true
  to_label:
    type: string
    required: true
  depth:
    type: integer
    default: 1

query: |
  MATCH (a:${from_label})-[:${relationship}*1..${depth}]->(b:${to_label})
  RETURN a, b
  LIMIT 100
```

## CLI Commands

```bash
# List available templates
neo4j templates --list

# Show template definition
neo4j templates --show=my_template

# Validate a template
neo4j templates --validate=my_template

# Execute a template
neo4j template my_template --param1=value1 --param2=value2

# Discover templates from database schema
neo4j discover
```

## Debugging

### View Rendered Query

To see how your template renders:

```bash
# Check template definition
neo4j templates --show=my_template

# The output includes the raw query and parameter specs
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| `Template not found` | YAML not in search paths | Check template directories |
| `Missing required parameter` | Required param not provided | Add `--param=value` |
| `Invalid identifier` | Special chars in `${param}` | Use only alphanumeric/underscore |
| `PyYAML not installed` | Missing dependency | `pip install pyyaml` |

## Best Practices

1. **Use Cypher parameters for values** - Prevents injection, enables query caching
2. **Provide descriptions** - Help users understand what parameters do
3. **Set sensible defaults** - Reduce required parameters
4. **Validate early** - Use `neo4j templates --validate=name` before deployment
5. **Version your templates** - Track changes with the version field
6. **Keep queries focused** - One template per use case
