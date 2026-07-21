# Property-Based Access Control (PBAC) Reference

PBAC extends Neo4j's privilege model with WHERE clauses on GRANT/DENY statements, enabling fine-grained access based on node and relationship properties.

**Requires**: Neo4j 5.x Enterprise Edition

## Syntax

```
GRANT|DENY privilege ON scope TO role_name
  WHERE predicate
```

The `WHERE` clause filters which nodes/relationships the privilege applies to, based on their properties.

## Supported Predicates

| Predicate | Syntax | Example |
|-----------|--------|---------|
| Equality | `n.prop = value` | `WHERE n.department = 'Engineering'` |
| IS NULL | `n.prop IS NULL` | `WHERE n.deleted_at IS NULL` |
| IS NOT NULL | `n.prop IS NOT NULL` | `WHERE n.approved_by IS NOT NULL` |
| IN list | `n.prop IN [values]` | `WHERE n.status IN ['active', 'pending']` |
| OR | `pred OR pred` | `WHERE n.dept = 'Eng' OR n.dept = 'Ops'` |

**Note**: The variable `n` refers to the node being accessed. For relationships, use `r`.

## Examples

### Restrict by Department

```cypher
-- Only Engineering department employees visible
GRANT MATCH {*} ON GRAPH neo4j
  NODE Employee
  TO engineering_reader
  WHERE n.department = 'Engineering'
```

### Restrict by Status

```cypher
-- Only active records
GRANT MATCH {*} ON GRAPH neo4j
  NODE *
  TO active_only_reader
  WHERE n.status = 'active'

-- Multiple allowed statuses
GRANT MATCH {*} ON GRAPH neo4j
  NODE Task
  TO team_viewer
  WHERE n.status IN ['open', 'in_progress', 'review']
```

### Deny Access to Classified Data

```cypher
-- Block access to secret documents
DENY READ {*} ON GRAPH docs
  NODE Document
  TO basic_reader
  WHERE n.classification = 'SECRET'

-- Block access to deleted (soft-delete) records
DENY MATCH {*} ON GRAPH neo4j
  NODE *
  TO standard_user
  WHERE n.deleted_at IS NOT NULL
```

### Multiple Departments (OR)

```cypher
GRANT MATCH {*} ON GRAPH neo4j
  NODE Employee
  TO cross_team_reader
  WHERE n.department = 'Engineering' OR n.department = 'Product'
```

### Write Restrictions

```cypher
-- Only allow writing to own department's data
GRANT SET PROPERTY {status, notes} ON GRAPH neo4j
  NODE Task
  TO team_writer
  WHERE n.team = 'backend'

-- Allow creating only active nodes
GRANT CREATE ON GRAPH neo4j
  NODE Task
  TO task_creator
  WHERE n.status = 'open'
```

### Relationship-Level PBAC

```cypher
-- Only see relationships created after a date
GRANT TRAVERSE ON GRAPH neo4j
  RELATIONSHIP ASSIGNED_TO
  TO recent_viewer
  WHERE r.created_at IS NOT NULL
```

## Performance Considerations

PBAC predicates add runtime filtering. Consider these guidelines:

### Index Properties Used in Predicates

Properties referenced in WHERE clauses benefit from indexes:

```cypher
-- Create index on the property used in PBAC
CREATE INDEX dept_index FOR (n:Employee) ON (n.department)
```

### Predicate Complexity

| Complexity | Example | Performance |
|------------|---------|-------------|
| Simple equality | `n.dept = 'Eng'` | Fast (index-friendly) |
| IS NULL / IS NOT NULL | `n.deleted IS NULL` | Fast |
| IN list (small) | `n.status IN ['a', 'b']` | Fast |
| IN list (large) | `n.id IN [1..1000]` | Slower |
| Multiple OR | `n.a = 1 OR n.b = 2` | Moderate |

### Best Practices

1. **Keep predicates simple**: Simple equality checks are fastest
2. **Index PBAC properties**: Create indexes on properties used in WHERE clauses
3. **Limit IN list size**: Keep IN lists under 100 values
4. **Test performance**: Run EXPLAIN on queries to verify plan isn't degraded
5. **Document PBAC rules**: Keep a record of which roles have which PBAC restrictions

## Combining PBAC with Standard Privileges

PBAC can coexist with standard (non-PBAC) privileges on the same role:

```cypher
-- Standard: read all Department nodes
GRANT MATCH {*} ON GRAPH neo4j NODE Department TO hr_role;

-- PBAC: but only HR department employees
GRANT MATCH {*} ON GRAPH neo4j NODE Employee TO hr_role
  WHERE n.department = 'HR';

-- Standard: read all WORKS_IN relationships
GRANT MATCH {*} ON GRAPH neo4j RELATIONSHIP WORKS_IN TO hr_role;
```

## Common Patterns

### Multi-Tenant Access

```cypher
-- Tenant-scoped access
CREATE ROLE tenant_acme;
GRANT MATCH {*} ON GRAPH shared
  NODE *
  TO tenant_acme
  WHERE n.tenant_id = 'acme';
GRANT MATCH {*} ON GRAPH shared
  RELATIONSHIP *
  TO tenant_acme
  WHERE r.tenant_id = 'acme';
```

### Data Classification Levels

```cypher
-- Public data: everyone
GRANT MATCH {*} ON GRAPH neo4j NODE * TO public_role
  WHERE n.classification = 'public';

-- Internal: employees
GRANT MATCH {*} ON GRAPH neo4j NODE * TO employee_role
  WHERE n.classification IN ['public', 'internal'];

-- Confidential: managers
GRANT MATCH {*} ON GRAPH neo4j NODE * TO manager_role
  WHERE n.classification IN ['public', 'internal', 'confidential'];

-- Secret: admins get full access (no WHERE clause)
GRANT MATCH {*} ON GRAPH neo4j TO admin_role;
```

### Time-Based Visibility (via property)

```cypher
-- Only see records that have been published
GRANT MATCH {*} ON GRAPH cms
  NODE Article
  TO viewer_role
  WHERE n.published_at IS NOT NULL;
```

## Viewing PBAC Privileges

```cypher
-- See all privileges including WHERE clauses
SHOW ROLE tenant_acme PRIVILEGES

-- As commands (includes WHERE clause)
SHOW ROLE tenant_acme PRIVILEGES AS COMMANDS
```

## Limitations

- WHERE clause only supports the predicates listed above (no complex expressions, no function calls)
- Cannot reference other nodes or relationships in the predicate (only the current node/rel properties)
- PBAC predicates are evaluated at runtime for every matching node/rel access
- Cannot use PBAC on DBMS-level or database-level privileges (only graph-level)
