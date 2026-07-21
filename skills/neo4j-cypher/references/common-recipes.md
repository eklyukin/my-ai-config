# Common Recipes

End-to-end workflows for common auth/authz tasks.

## 1. Create Read-Only Analytics User

```cypher
CREATE USER analytics SET PASSWORD 'changeme' SET PASSWORD CHANGE REQUIRED;
CREATE ROLE analytics_reader;
GRANT MATCH {*} ON GRAPH * TO analytics_reader;
GRANT ROLE analytics_reader TO analytics;
```

## 2. Department-Scoped User (PBAC)

```cypher
CREATE USER hr_analyst SET PASSWORD 'changeme' SET PASSWORD CHANGE REQUIRED;
CREATE ROLE hr_only;
GRANT MATCH {*} ON GRAPH neo4j NODE Employee TO hr_only
  WHERE n.department = 'HR';
GRANT MATCH {*} ON GRAPH neo4j RELATIONSHIP REPORTS_TO TO hr_only;
GRANT ROLE hr_only TO hr_analyst;
```

## 3. Application Service Account

```cypher
CREATE USER app_backend SET PASSWORD 'strong_random_password' SET PASSWORD CHANGE NOT REQUIRED;
CREATE ROLE app_writer AS COPY OF publisher;
GRANT ROLE app_writer TO app_backend;
```

## 4. Audit All Permissions for a User

```cypher
-- See effective privileges
SHOW USER analyst_user PRIVILEGES AS COMMANDS;

-- See which roles
SHOW USERS YIELD user, roles WHERE user = 'analyst_user' RETURN roles;

-- See detailed privilege breakdown
SHOW USER analyst_user PRIVILEGES
YIELD role, access, action, resource, graph, segment
RETURN *;
```

## 5. Lock Down Production (Restrict Writes)

```cypher
-- Remove write from a role
REVOKE WRITE ON GRAPH production FROM app_role;

-- Only allow reads
GRANT MATCH {*} ON GRAPH production TO app_role;
```

## 6. Restrict Access to Specific Properties

```cypher
-- Hide salary from general readers
DENY READ {salary, ssn} ON GRAPH hr NODE Employee TO general_reader;

-- Only HR can see salary
GRANT READ {salary} ON GRAPH hr NODE Employee TO hr_role;
```

## 7. Reset a Role to Defaults

```cypher
-- Show what to revoke
SHOW ROLE custom_role PRIVILEGES AS REVOKE COMMANDS;

-- Execute the revoke commands, then re-grant as needed
```

## 8. Multi-Tenant Isolation

```cypher
CREATE ROLE tenant_acme;
GRANT MATCH {*} ON GRAPH shared NODE * TO tenant_acme
  WHERE n.tenant_id = 'acme';
GRANT MATCH {*} ON GRAPH shared RELATIONSHIP * TO tenant_acme
  WHERE r.tenant_id = 'acme';
```

## 9. Offboard a User

```cypher
-- 1. Check current roles
SHOW USERS YIELD user, roles WHERE user = 'former_employee' RETURN roles;

-- 2. Revoke all roles
REVOKE ROLE data_reader FROM former_employee;
REVOKE ROLE custom_writer FROM former_employee;

-- 3. Suspend (keeps audit trail) or drop
ALTER USER former_employee SET STATUS SUSPENDED;
-- OR: DROP USER former_employee;
```
