# Role Management Reference

Complete Cypher syntax for managing Neo4j roles.

## SHOW ROLES

### Syntax

```
SHOW [ALL | POPULATED] ROLE[S]
  [WITH USERS]
  [YIELD { * | field[, ...] } [ORDER BY field[, ...]] [SKIP n] [LIMIT n]]
  [WHERE expression]
  [RETURN field[, ...] [ORDER BY field[, ...]]]
```

### Examples

```cypher
-- All roles
SHOW ROLES

-- All roles with user assignments
SHOW ROLES WITH USERS

-- Only roles that have users assigned
SHOW POPULATED ROLES WITH USERS

-- Custom roles only (not built-in)
SHOW ROLES
YIELD role, isBuiltIn
WHERE isBuiltIn = false
RETURN role

-- Roles for a specific user
SHOW USERS
YIELD user, roles
WHERE user = 'analyst'
RETURN roles
```

### Output Columns

| Column | Description |
|--------|-------------|
| `role` | Role name |
| `isBuiltIn` | Whether it's a built-in role |
| `member` | User assigned (only with `WITH USERS`) |

## CREATE ROLE

### Syntax

```
CREATE [OR REPLACE] ROLE role_name [IF NOT EXISTS]
  [AS COPY OF source_role]
```

### Examples

```cypher
-- Basic role
CREATE ROLE data_reader

-- Idempotent
CREATE ROLE data_reader IF NOT EXISTS

-- Replace existing
CREATE OR REPLACE ROLE data_reader

-- Copy from existing role (copies all privileges)
CREATE ROLE senior_analyst AS COPY OF reader

-- Copy from custom role
CREATE ROLE team_lead AS COPY OF data_reader
```

### Copy Behavior

When using `AS COPY OF`:
- All privileges (GRANT and DENY) are copied from the source role
- User assignments are NOT copied
- The source role is not modified
- Works with both built-in and custom roles

## RENAME ROLE

```cypher
RENAME ROLE data_reader TO data_analyst
```

- Renames the role in place
- All privileges and user assignments are preserved
- Built-in roles cannot be renamed

## DROP ROLE

```cypher
-- Drop role
DROP ROLE data_analyst

-- Idempotent
DROP ROLE data_analyst IF EXISTS
```

- Dropping a role removes it from all users who had it
- Built-in roles can be dropped (except PUBLIC) but it's not recommended
- Privileges associated with the role are removed
- Users who only had this role will have no roles (except PUBLIC)

## GRANT ROLE TO USER

### Syntax

```
GRANT ROLE[S] role_name[, ...] TO user_name[, ...]
```

### Examples

```cypher
-- Single role to single user
GRANT ROLE data_reader TO analyst

-- Multiple roles to single user
GRANT ROLES reader, editor TO power_user

-- Single role to multiple users
GRANT ROLE viewer TO user_a, user_b, user_c

-- Multiple roles to multiple users
GRANT ROLES reader, editor TO user_a, user_b
```

## REVOKE ROLE FROM USER

### Syntax

```
REVOKE ROLE[S] role_name[, ...] FROM user_name[, ...]
```

### Examples

```cypher
-- Single
REVOKE ROLE editor FROM analyst

-- Multiple
REVOKE ROLES reader, editor FROM former_employee

-- All custom roles (requires knowing them first)
-- Step 1: Check roles
SHOW USERS YIELD user, roles WHERE user = 'analyst' RETURN roles;
-- Step 2: Revoke each
REVOKE ROLE data_reader FROM analyst;
REVOKE ROLE custom_writer FROM analyst;
```

## Custom Role Patterns

### Read-Only Analytics Role

```cypher
CREATE ROLE analytics_reader;
GRANT MATCH {*} ON GRAPH * TO analytics_reader;
-- No write privileges
```

### Graph-Scoped Writer

```cypher
CREATE ROLE hr_writer;
GRANT MATCH {*} ON GRAPH hr TO hr_writer;
GRANT WRITE ON GRAPH hr TO hr_writer;
-- No access to other graphs
```

### Restricted Admin (User Management Only)

```cypher
CREATE ROLE user_manager;
GRANT ACCESS ON DATABASE * TO user_manager;
GRANT USER MANAGEMENT ON DBMS TO user_manager;
-- Can create/alter/drop users but not roles or privileges
```

### Application Service Account Role

```cypher
CREATE ROLE app_service AS COPY OF publisher;
-- Publisher gives read + write + create new types
-- Add specific database access if needed
GRANT ACCESS ON DATABASE neo4j TO app_service;
```

### Monitoring Role (Read-Only + Transactions)

```cypher
CREATE ROLE monitor;
GRANT MATCH {*} ON GRAPH * TO monitor;
GRANT SHOW TRANSACTION (*) ON DATABASE * TO monitor;
-- Can read data and see running transactions
```

## Privilege Assignment via Roles

Roles are the containers for privileges. Privileges cannot be assigned directly to users.

```
User  --(has)--> Role  --(grants/denies)--> Privilege  --(on)--> Resource
```

### Checking Role Privileges

```cypher
-- See all privileges for a role
SHOW ROLE data_reader PRIVILEGES

-- As executable GRANT commands
SHOW ROLE data_reader PRIVILEGES AS COMMANDS

-- As REVOKE commands (useful for cleanup)
SHOW ROLE data_reader PRIVILEGES AS REVOKE COMMANDS
```

### Comparing Roles

```cypher
-- Side-by-side privilege comparison
SHOW ROLE reader PRIVILEGES AS COMMANDS
YIELD command AS reader_cmd
RETURN reader_cmd
UNION
SHOW ROLE editor PRIVILEGES AS COMMANDS
YIELD command AS editor_cmd
RETURN editor_cmd
```

## Best Practices

1. **Use custom roles** instead of modifying built-in roles
2. **Copy from built-in** as starting point: `CREATE ROLE custom AS COPY OF reader`
3. **Principle of least privilege**: Start with minimal access, add as needed
4. **Name conventions**: Use descriptive names like `department_access_level` (e.g., `hr_reader`, `finance_writer`)
5. **Audit regularly**: `SHOW POPULATED ROLES WITH USERS` to find unused roles
6. **Document custom roles**: Keep a record of what each custom role is for
7. **Don't modify PUBLIC**: Add privileges to custom roles, not PUBLIC
