# Neo4j Skill - Usage Examples

Real-world examples for common Neo4j query patterns and template usage.

## Table of Contents

1. [Schema Exploration](#schema-exploration)
2. [Raw Cypher Queries](#raw-cypher-queries)
3. [Template Usage](#template-usage)
4. [Creating Custom Templates](#creating-custom-templates)
5. [Error Handling](#error-handling)

---

## Schema Exploration

Understand your graph structure before querying.

### Quick Schema Overview

```bash
# Fast schema inspection (100 sample nodes)
neo4j schema --sample-size=100
```

### List Node Labels

```bash
neo4j read --query="
MATCH (n)
RETURN DISTINCT labels(n) AS labels, count(*) AS count
ORDER BY count DESC
LIMIT 20
"
```

### List Relationship Types

```bash
neo4j read --query="
MATCH ()-[r]->()
RETURN DISTINCT type(r) AS relationship, count(*) AS count
ORDER BY count DESC
LIMIT 20
"
```

### Explore Node Properties

```bash
# Get properties of a specific label
neo4j read --query="
MATCH (n:Person)
RETURN DISTINCT keys(n) AS properties
LIMIT 1
"

# Sample data from a node type
neo4j read --query="
MATCH (n:Person)
RETURN n
LIMIT 5
"
```

### Discover Templates

```bash
# Analyze schema and get template suggestions
neo4j discover
```

---

## Raw Cypher Queries

Execute any read-only Cypher query.

### Basic Node Queries

```bash
# Count nodes by label
neo4j read --query="MATCH (n:Person) RETURN count(n) AS total"

# Get nodes with specific property
neo4j read --query="
MATCH (n:Person)
WHERE n.status = 'Active'
RETURN n.name, n.email
LIMIT 10
"

# Pattern matching with parameters
neo4j read \
    --query="MATCH (n:Person {email: \$email}) RETURN n" \
    --params='{"email": "user@example.com"}'
```

### Relationship Queries

```bash
# Find connected nodes
neo4j read --query="
MATCH (a:Person)-[:KNOWS]->(b:Person)
RETURN a.name AS person, b.name AS knows
LIMIT 20
"

# Multi-hop traversal
neo4j read --query="
MATCH path = (a:Person)-[:KNOWS*1..3]-(b:Person)
WHERE a.name = 'Alice'
RETURN [n IN nodes(path) | n.name] AS connection_chain
LIMIT 10
"

# Relationship properties
neo4j read --query="
MATCH (a:Person)-[r:WORKED_WITH]->(b:Person)
RETURN a.name, b.name, r.since, r.projects
ORDER BY r.since DESC
LIMIT 10
"
```

### Aggregations

```bash
# Group by property
neo4j read --query="
MATCH (n:Person)
RETURN n.department AS department, count(*) AS count
ORDER BY count DESC
"

# Statistics
neo4j read --query="
MATCH (n:Order)
RETURN avg(n.amount) AS avg_amount,
       min(n.amount) AS min_amount,
       max(n.amount) AS max_amount,
       count(n) AS total_orders
"
```

### Complex Queries with Timeout

```bash
# Large aggregation with extended timeout
neo4j read \
    --query="
    MATCH (c:Customer)-[:PLACED]->(o:Order)-[:CONTAINS]->(p:Product)
    RETURN c.name, count(DISTINCT o) AS orders, collect(DISTINCT p.name) AS products
    ORDER BY orders DESC
    LIMIT 50
    " \
    --timeout=60
```

---

## Template Usage

Use pre-defined templates for common query patterns.

### List Available Templates

```bash
neo4j templates --list
```

### View Template Definition

```bash
neo4j templates --show=entity_pool
```

### Execute Templates

```bash
# Simple template execution
neo4j template nodes_by_label --label=Person

# With multiple parameters
neo4j template entity_pool \
    --label=Customer \
    --status_value=Active \
    --limit=100

# With exclusion filters
neo4j template entity_pool \
    --label=Employee \
    --exclude_property=department \
    --exclude_values='["HR", "Legal", "Finance"]'

# Relationship traversal
neo4j template relationship_query \
    --from_label=Person \
    --relationship=KNOWS \
    --to_label=Person \
    --max_depth=2
```

### Template Output Processing

```bash
# Save to file for further processing
neo4j template entity_pool --label=Customer > /tmp/customers.json

# Parse with jq
neo4j template entity_pool --label=Customer | jq '.record_count'

# Extract specific field
neo4j template entity_pool --label=Customer | jq '.records[].name'
```

---

## Creating Custom Templates

Create project-specific templates for your graph model.

### Step 1: Create Template Directory

```bash
mkdir -p .claude/neo4j-templates
```

### Step 2: Write Template YAML

```bash
cat > .claude/neo4j-templates/active_users.yaml << 'EOF'
name: active_users
description: Get active users with optional role filter
version: "1.0"

parameters:
  role:
    type: string
    default: ""
    description: Optional role to filter by
  limit:
    type: integer
    default: 100

query: |
  MATCH (u:User {status: 'active'})
  WHERE $role = '' OR u.role = $role
  RETURN u.id, u.name, u.email, u.role
  ORDER BY u.name
  LIMIT $limit
EOF
```

### Step 3: Verify Template

```bash
# Check it's discovered
neo4j templates --list

# Validate syntax
neo4j templates --validate=active_users
```

### Step 4: Use Template

```bash
# All active users
neo4j template active_users

# Filter by role
neo4j template active_users --role=admin --limit=50
```

### Template with Label Interpolation

For dynamic label queries:

```bash
cat > .claude/neo4j-templates/recent_items.yaml << 'EOF'
name: recent_items
description: Get recently created items of any type
version: "1.0"

parameters:
  label:
    type: string
    required: true
  days:
    type: integer
    default: 7
  limit:
    type: integer
    default: 50

query: |
  MATCH (n:${label})
  WHERE n.created_at >= datetime() - duration({days: $days})
  RETURN n
  ORDER BY n.created_at DESC
  LIMIT $limit
EOF
```

---

## Error Handling

Handle various error scenarios gracefully.

### Query Syntax Error

```bash
# Invalid Cypher
neo4j read --query="MATC (n) RETURN n"
```

**Output**:
```json
{
  "status": "error",
  "operation": "read",
  "error": "Neo4j error: Invalid input 'C': expected 'c/C' (line 1, column 4)",
  "error_type": "execution"
}
```

### Template Not Found

```bash
neo4j template nonexistent
```

**Output**:
```json
{
  "status": "error",
  "operation": "template",
  "template_name": "nonexistent",
  "error": "Template not found: 'nonexistent'",
  "available_templates": ["entity_pool", "nodes_by_label"]
}
```

### Missing Required Parameter

```bash
neo4j template entity_pool
# Missing --label parameter
```

**Output**:
```json
{
  "status": "error",
  "operation": "template",
  "template_name": "entity_pool",
  "error": "Missing required parameter: 'label'"
}
```

### Connection Retry

When connection fails temporarily, the skill automatically retries:

```json
{
  "status": "success",
  "operation": "read",
  "retry_metadata": {
    "attempts": [
      {"attempt": 1, "success": false, "error": "ServiceUnavailable", "duration_ms": 5023},
      {"attempt": 2, "success": false, "error": "ServiceUnavailable", "duration_ms": 5018},
      {"attempt": 3, "success": true, "duration_ms": 156}
    ],
    "total_attempts": 3,
    "success": true
  }
}
```

### Configuration Error

```bash
# Missing environment variables
unset NEO4J_PASSWORD
neo4j read --query="MATCH (n) RETURN n LIMIT 1"
```

**Output**:
```json
{
  "status": "error",
  "error": "Missing required environment variables: NEO4J_PASSWORD",
  "error_type": "configuration"
}
```

---

## Batch Processing Examples

### Process Multiple Labels

```bash
#!/bin/bash
# Process each node label in the database

LABELS=$(neo4j read --query="CALL db.labels() YIELD label RETURN label" | jq -r '.records[].label')

for LABEL in $LABELS; do
    echo "Processing: $LABEL"
    COUNT=$(neo4j read --query="MATCH (n:$LABEL) RETURN count(n) AS count" | jq '.records[0].count')
    echo "  Count: $COUNT"
done
```

### Export to CSV

```bash
# Export query results to CSV
neo4j read --query="
MATCH (p:Person)
RETURN p.name, p.email, p.department
LIMIT 1000
" | jq -r '.records[] | [.["p.name"], .["p.email"], .["p.department"]] | @csv' > people.csv
```

### Parallel Queries

```bash
# Run multiple queries in parallel
neo4j read --query="MATCH (p:Person) RETURN count(p)" &
neo4j read --query="MATCH (o:Order) RETURN count(o)" &
neo4j read --query="MATCH (c:Company) RETURN count(c)" &
wait
```
