# Built-in Roles Reference

Neo4j provides 6 built-in roles with predefined privilege sets.

## Capabilities Comparison

| Action | PUBLIC | reader | editor | publisher | architect | admin |
|--------|--------|--------|--------|-----------|-----------|-------|
| Change own password | x | x | x | x | x | x |
| View own details | x | x | x | x | x | x |
| View own transactions | x | x | x | x | x | x |
| Terminate own transactions | x | x | x | x | x | x |
| Access home database | x | x | x | x | x | x |
| Access all databases | | x | x | x | x | x |
| Read data | | x | x | x | x | x |
| View index/constraint | | x | x | x | x | x |
| Write/update/delete data | | | x | x | x | x |
| Create new property keys | | | | x | x | x |
| Create new node labels | | | | x | x | x |
| Create new relationship types | | | | x | x | x |
| Create/drop index/constraint | | | | | x | x |
| Create/delete users | | | | | | x |
| Manage roles | | | | | | x |
| Grant/deny/revoke privileges | | | | | | x |
| Create/drop/alter databases | | | | | | x |
| View all users/roles | | | | | | x |
| Manage transactions | | | | | | x |
| Execute admin procedures | | | | | | x |

## PUBLIC Role

Granted to **all users** automatically. Cannot be dropped or revoked.

### Default Privileges

```cypher
SHOW ROLE PUBLIC PRIVILEGES AS COMMANDS
```

| Privilege |
|-----------|
| `GRANT ACCESS ON HOME DATABASE TO PUBLIC` |
| `GRANT EXECUTE FUNCTION * ON DBMS TO PUBLIC` |
| `GRANT EXECUTE PROCEDURE * ON DBMS TO PUBLIC` |
| `GRANT LOAD ON ALL DATA TO PUBLIC` |

### Restore to Defaults

```cypher
-- First revoke all custom grants/denies (check with SHOW ROLE PUBLIC PRIVILEGES AS REVOKE COMMANDS)
GRANT ACCESS ON HOME DATABASE TO PUBLIC;
GRANT EXECUTE PROCEDURES * ON DBMS TO PUBLIC;
GRANT EXECUTE USER DEFINED FUNCTIONS * ON DBMS TO PUBLIC;
GRANT LOAD ON ALL DATA TO PUBLIC;
```

## reader Role

Read-only access on all graphs except system database.

### Privileges

```cypher
SHOW ROLE reader PRIVILEGES AS COMMANDS
```

| Privilege |
|-----------|
| `GRANT ACCESS ON DATABASE * TO reader` |
| `GRANT MATCH {*} ON GRAPH * NODE * TO reader` |
| `GRANT MATCH {*} ON GRAPH * RELATIONSHIP * TO reader` |
| `GRANT SHOW CONSTRAINT ON DATABASE * TO reader` |
| `GRANT SHOW INDEX ON DATABASE * TO reader` |

### Recreate

```cypher
DROP ROLE reader;
CREATE ROLE reader;
GRANT ACCESS ON DATABASE * TO reader;
GRANT MATCH {*} ON GRAPH * TO reader;
GRANT SHOW CONSTRAINT ON DATABASE * TO reader;
GRANT SHOW INDEX ON DATABASE * TO reader;
```

## editor Role

Read + write on existing data. Cannot create new labels, property keys, or relationship types.

### Privileges

| Privilege |
|-----------|
| `GRANT ACCESS ON DATABASE * TO editor` |
| `GRANT MATCH {*} ON GRAPH * NODE * TO editor` |
| `GRANT MATCH {*} ON GRAPH * RELATIONSHIP * TO editor` |
| `GRANT SHOW CONSTRAINT ON DATABASE * TO editor` |
| `GRANT SHOW INDEX ON DATABASE * TO editor` |
| `GRANT WRITE ON GRAPH * TO editor` |

### Recreate

```cypher
DROP ROLE editor;
CREATE ROLE editor;
GRANT ACCESS ON DATABASE * TO editor;
GRANT MATCH {*} ON GRAPH * TO editor;
GRANT WRITE ON GRAPH * TO editor;
GRANT SHOW CONSTRAINT ON DATABASE * TO editor;
GRANT SHOW INDEX ON DATABASE * TO editor;
```

## publisher Role

Editor + can create new labels, property keys, and relationship types.

### Privileges

Adds to editor:
| Additional Privilege |
|-----------|
| `GRANT NAME MANAGEMENT ON DATABASE * TO publisher` |

### Recreate

```cypher
DROP ROLE publisher;
CREATE ROLE publisher;
GRANT ACCESS ON DATABASE * TO publisher;
GRANT MATCH {*} ON GRAPH * TO publisher;
GRANT WRITE ON GRAPH * TO publisher;
GRANT NAME MANAGEMENT ON DATABASE * TO publisher;
GRANT SHOW CONSTRAINT ON DATABASE * TO publisher;
GRANT SHOW INDEX ON DATABASE * TO publisher;
```

## architect Role

Publisher + create/drop indexes and constraints.

### Privileges

Adds to publisher:
| Additional Privilege |
|-----------|
| `GRANT CONSTRAINT MANAGEMENT ON DATABASE * TO architect` |
| `GRANT INDEX MANAGEMENT ON DATABASE * TO architect` |

### Recreate

```cypher
DROP ROLE architect;
CREATE ROLE architect;
GRANT ACCESS ON DATABASE * TO architect;
GRANT MATCH {*} ON GRAPH * TO architect;
GRANT WRITE ON GRAPH * TO architect;
GRANT NAME MANAGEMENT ON DATABASE * TO architect;
GRANT SHOW CONSTRAINT ON DATABASE * TO architect;
GRANT CONSTRAINT MANAGEMENT ON DATABASE * TO architect;
GRANT SHOW INDEX ON DATABASE * TO architect;
GRANT INDEX MANAGEMENT ON DATABASE * TO architect;
```

## admin Role

Full control over everything including user/role/database management.

### Privileges

```cypher
SHOW ROLE admin PRIVILEGES AS COMMANDS
```

| Privilege |
|-----------|
| `GRANT ACCESS ON DATABASE * TO admin` |
| `GRANT ALL DBMS PRIVILEGES ON DBMS TO admin` |
| `GRANT CONSTRAINT MANAGEMENT ON DATABASE * TO admin` |
| `GRANT INDEX MANAGEMENT ON DATABASE * TO admin` |
| `GRANT LOAD ON ALL DATA TO admin` |
| `GRANT MATCH {*} ON GRAPH * NODE * TO admin` |
| `GRANT MATCH {*} ON GRAPH * RELATIONSHIP * TO admin` |
| `GRANT NAME MANAGEMENT ON DATABASE * TO admin` |
| `GRANT SHOW CONSTRAINT ON DATABASE * TO admin` |
| `GRANT SHOW INDEX ON DATABASE * TO admin` |
| `GRANT START ON DATABASE * TO admin` |
| `GRANT STOP ON DATABASE * TO admin` |
| `GRANT TRANSACTION MANAGEMENT (*) ON DATABASE * TO admin` |
| `GRANT WRITE ON GRAPH * TO admin` |

### Recreate

```cypher
DROP ROLE admin;
CREATE ROLE admin;
GRANT ALL DBMS PRIVILEGES ON DBMS TO admin;
GRANT TRANSACTION MANAGEMENT ON DATABASE * TO admin;
GRANT START ON DATABASE * TO admin;
GRANT STOP ON DATABASE * TO admin;
GRANT MATCH {*} ON GRAPH * TO admin;
GRANT WRITE ON GRAPH * TO admin;
GRANT LOAD ON ALL DATA TO admin;
GRANT ALL ON DATABASE * TO admin;
```

If the admin role is corrupted and you're locked out, use `neo4j-admin server recover` from the command line.
