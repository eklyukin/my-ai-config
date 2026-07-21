# Read & Write Privileges Reference

Complete GRANT/DENY/REVOKE syntax for all graph privileges in Neo4j.

## General Syntax

```
GRANT|DENY privilege ON scope TO role_name
REVOKE [GRANT|DENY] privilege ON scope FROM role_name
```

Where:
- **privilege**: The action being allowed/denied (TRAVERSE, READ, MATCH, CREATE, DELETE, etc.)
- **scope**: The resource being targeted (GRAPH, DATABASE, DBMS)
- **role_name**: The role receiving the privilege

## Scope Syntax

```
ON GRAPH {* | graph_name[, ...]}
  [NODE {* | label[, ...]}]
  [RELATIONSHIP {* | type[, ...]}]
```

### Scope Examples

```cypher
-- All graphs, all elements
ON GRAPH *

-- Specific graph
ON GRAPH neo4j

-- Multiple graphs
ON GRAPH neo4j, analytics

-- Specific node labels
ON GRAPH neo4j NODE Employee, Department

-- Specific relationship types
ON GRAPH neo4j RELATIONSHIP WORKS_IN, MANAGES

-- All nodes
ON GRAPH neo4j NODES *

-- All relationships
ON GRAPH neo4j RELATIONSHIPS *
```

## Read Privileges

### TRAVERSE

Allows seeing that nodes/relationships exist (but not reading properties).

```cypher
-- Traverse all nodes on all graphs
GRANT TRAVERSE ON GRAPH * NODES * TO role_name

-- Traverse specific labels
GRANT TRAVERSE ON GRAPH neo4j NODE Employee TO role_name

-- Traverse relationships
GRANT TRAVERSE ON GRAPH neo4j RELATIONSHIP WORKS_IN TO role_name
```

### READ

Allows reading specific properties (requires TRAVERSE to actually reach the nodes).

```cypher
-- Read all properties on all nodes
GRANT READ {*} ON GRAPH * NODES * TO role_name

-- Read specific properties
GRANT READ {name, email, department} ON GRAPH neo4j NODE Employee TO role_name

-- Read all properties on relationships
GRANT READ {*} ON GRAPH neo4j RELATIONSHIPS * TO role_name

-- Read specific relationship properties
GRANT READ {since, weight} ON GRAPH neo4j RELATIONSHIP WORKS_IN TO role_name
```

### MATCH

Combination of TRAVERSE + READ. Most commonly used for granting read access.

```cypher
-- Full read access on all graphs (equivalent to reader role)
GRANT MATCH {*} ON GRAPH * TO role_name

-- Read specific properties on specific labels
GRANT MATCH {name, department} ON GRAPH neo4j NODE Employee TO role_name

-- Read all on specific graph
GRANT MATCH {*} ON GRAPH hr TO role_name

-- Nodes only (no relationship properties)
GRANT MATCH {*} ON GRAPH neo4j NODES * TO role_name
```

### Property Lists

```cypher
-- All properties
{*}

-- Specific properties
{name, email, department}

-- Single property
{name}
```

**Note**: `GRANT MATCH {*}` includes all current AND future properties. `GRANT MATCH {name, email}` only includes those two.

## Write Privileges

### CREATE

Create new nodes and relationships.

```cypher
-- Create anything on a graph
GRANT CREATE ON GRAPH neo4j TO role_name

-- Create specific node labels
GRANT CREATE ON GRAPH neo4j NODE Task TO role_name

-- Create specific relationships
GRANT CREATE ON GRAPH neo4j RELATIONSHIP ASSIGNED_TO TO role_name
```

### DELETE

Delete nodes and relationships.

```cypher
-- Delete anything on a graph
GRANT DELETE ON GRAPH neo4j TO role_name

-- Delete specific node labels
GRANT DELETE ON GRAPH neo4j NODE TempData TO role_name

-- Delete specific relationships
GRANT DELETE ON GRAPH neo4j RELATIONSHIP OLD_LINK TO role_name
```

### SET LABEL

Add labels to existing nodes.

```cypher
-- Set any label
GRANT SET LABEL * ON GRAPH neo4j TO role_name

-- Set specific labels
GRANT SET LABEL Verified, Approved ON GRAPH neo4j TO role_name
```

### REMOVE LABEL

Remove labels from nodes.

```cypher
-- Remove any label
GRANT REMOVE LABEL * ON GRAPH neo4j TO role_name

-- Remove specific labels
GRANT REMOVE LABEL Pending, Draft ON GRAPH neo4j TO role_name
```

### SET PROPERTY

Set/update property values.

```cypher
-- Set any property on any node
GRANT SET PROPERTY {*} ON GRAPH neo4j NODES * TO role_name

-- Set specific properties on specific labels
GRANT SET PROPERTY {status, updated_at} ON GRAPH neo4j NODE Task TO role_name

-- Set relationship properties
GRANT SET PROPERTY {weight} ON GRAPH neo4j RELATIONSHIP SIMILARITY TO role_name
```

### REMOVE PROPERTY

Remove properties from nodes/relationships (set to null).

```cypher
-- Remove any property
GRANT REMOVE PROPERTY {*} ON GRAPH neo4j TO role_name

-- Remove specific properties
GRANT REMOVE PROPERTY {temp_flag} ON GRAPH neo4j NODE * TO role_name
```

### MERGE

Allows MERGE operations (create if not exists, match if exists). Requires both CREATE and MATCH privileges.

```cypher
-- MERGE on nodes
GRANT MERGE {*} ON GRAPH neo4j NODES * TO role_name

-- MERGE on specific labels
GRANT MERGE {name, id} ON GRAPH neo4j NODE Employee TO role_name
```

**Note**: MERGE implicitly requires MATCH privilege on the same scope. Granting MERGE without MATCH will fail at runtime.

### WRITE

All write operations combined (CREATE + DELETE + SET LABEL + REMOVE LABEL + SET PROPERTY + REMOVE PROPERTY).

```cypher
-- All write on a graph
GRANT WRITE ON GRAPH neo4j TO role_name

-- All write on all graphs
GRANT WRITE ON GRAPH * TO role_name
```

### ALL GRAPH PRIVILEGES

All read AND write privileges combined (MATCH + WRITE).

```cypher
-- Everything on a graph
GRANT ALL GRAPH PRIVILEGES ON GRAPH neo4j TO role_name

-- Everything on all graphs
GRANT ALL GRAPH PRIVILEGES ON GRAPH * TO role_name
```

## DENY Privileges

DENY uses the same syntax as GRANT but blocks access. **DENY always wins over GRANT.**

```cypher
-- Deny reading salary
DENY READ {salary, ssn} ON GRAPH hr NODE Employee TO general_role

-- Deny writing to production
DENY WRITE ON GRAPH production TO dev_role

-- Deny deleting anything
DENY DELETE ON GRAPH * TO safe_writer_role
```

### DENY + GRANT Interaction

```cypher
-- Role A: GRANT READ {*} ON GRAPH hr TO role_a
-- Role B: DENY READ {salary} ON GRAPH hr TO role_b
-- User with both roles: can read everything EXCEPT salary
```

## REVOKE Privileges

```cypher
-- Revoke a GRANT
REVOKE GRANT READ {salary} ON GRAPH hr NODE Employee FROM role_name

-- Revoke a DENY
REVOKE DENY READ {salary} ON GRAPH hr NODE Employee FROM role_name

-- Revoke both GRANT and DENY (if you don't know which)
REVOKE READ {salary} ON GRAPH hr NODE Employee FROM role_name
```

## Show Privileges

```cypher
-- All privileges for a role
SHOW ROLE role_name PRIVILEGES

-- As executable commands
SHOW ROLE role_name PRIVILEGES AS COMMANDS

-- As revoke commands (for cleanup)
SHOW ROLE role_name PRIVILEGES AS REVOKE COMMANDS

-- For a specific user (effective privileges across all roles)
SHOW USER username PRIVILEGES AS COMMANDS

-- Filter by action type
SHOW ROLE role_name PRIVILEGES
YIELD access, action, resource, graph, segment
WHERE action = 'read'
RETURN *
```

## Database-Level Privileges

Beyond graph privileges, there are database-level privileges:

```cypher
-- Access a database
GRANT ACCESS ON DATABASE neo4j TO role_name

-- Access all databases
GRANT ACCESS ON DATABASE * TO role_name

-- Index management
GRANT INDEX MANAGEMENT ON DATABASE neo4j TO role_name
GRANT SHOW INDEX ON DATABASE neo4j TO role_name

-- Constraint management
GRANT CONSTRAINT MANAGEMENT ON DATABASE neo4j TO role_name
GRANT SHOW CONSTRAINT ON DATABASE neo4j TO role_name

-- Name management (create new labels/types/property keys)
GRANT NAME MANAGEMENT ON DATABASE neo4j TO role_name

-- Transaction management
GRANT SHOW TRANSACTION (*) ON DATABASE neo4j TO role_name
GRANT TERMINATE TRANSACTION (*) ON DATABASE neo4j TO role_name
GRANT TRANSACTION MANAGEMENT (*) ON DATABASE neo4j TO role_name

-- Start/stop databases
GRANT START ON DATABASE neo4j TO role_name
GRANT STOP ON DATABASE neo4j TO role_name

-- All database privileges
GRANT ALL ON DATABASE neo4j TO role_name
```

## DBMS-Level Privileges

System-wide privileges:

```cypher
-- User management
GRANT USER MANAGEMENT ON DBMS TO role_name

-- Role management
GRANT ROLE MANAGEMENT ON DBMS TO role_name

-- Privilege management
GRANT PRIVILEGE MANAGEMENT ON DBMS TO role_name

-- All DBMS privileges (includes all of above)
GRANT ALL DBMS PRIVILEGES ON DBMS TO role_name
```
