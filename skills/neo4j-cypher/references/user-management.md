# User Management Reference

Complete Cypher syntax for managing Neo4j users.

## User States

| State | Description |
|-------|-------------|
| `ACTIVE` | Default. User can log in and perform queries per their privileges. |
| `SUSPENDED` | Native users cannot log in. External (LDAP/OIDC) users can still log in but lose system-assigned roles. |

## SHOW USERS

```cypher
-- All users
SHOW USERS

-- Current user
SHOW CURRENT USER

-- With YIELD for filtering
SHOW USERS
YIELD user, roles, suspended, home
WHERE suspended = false
RETURN user, roles, home
ORDER BY user

-- Count users per role
SHOW USERS
YIELD user, roles
UNWIND roles AS role
RETURN role, count(*) AS user_count
ORDER BY user_count DESC
```

### SHOW USERS Output Columns

| Column | Description |
|--------|-------------|
| `user` | Username |
| `roles` | List of assigned roles |
| `passwordChangeRequired` | Whether password change is required on next login |
| `suspended` | Whether user is suspended |
| `home` | Home database (null = default) |

## CREATE USER

### Full Syntax

```
CREATE [OR REPLACE] USER username [IF NOT EXISTS]
  SET [PLAINTEXT | ENCRYPTED] PASSWORD 'password'
  [SET PASSWORD CHANGE [NOT] REQUIRED]
  [SET STATUS {ACTIVE | SUSPENDED}]
  [SET HOME DATABASE name]
```

### Examples

```cypher
-- Minimal
CREATE USER analyst SET PASSWORD 'changeme'

-- Full options
CREATE USER data_engineer
  SET PASSWORD 'initial_pass'
  SET PASSWORD CHANGE REQUIRED
  SET STATUS ACTIVE
  SET HOME DATABASE neo4j

-- Idempotent (skip if exists)
CREATE USER analyst IF NOT EXISTS SET PASSWORD 'changeme'

-- Replace (drop + recreate)
CREATE OR REPLACE USER analyst SET PASSWORD 'new_pass'

-- With encrypted password (from another Neo4j export)
CREATE USER migrated_user SET ENCRYPTED PASSWORD '$2a$10$...'
```

## ALTER USER

### Full Syntax

```
ALTER USER username [IF EXISTS]
  [SET [PLAINTEXT | ENCRYPTED] PASSWORD 'password']
  [SET PASSWORD CHANGE [NOT] REQUIRED]
  [SET STATUS {ACTIVE | SUSPENDED}]
  [SET HOME DATABASE name]
  [REMOVE HOME DATABASE]
```

### Examples

```cypher
-- Change password
ALTER USER analyst SET PASSWORD 'new_password'

-- Force password change on next login
ALTER USER analyst SET PASSWORD CHANGE REQUIRED

-- Suspend user
ALTER USER analyst SET STATUS SUSPENDED

-- Reactivate user
ALTER USER analyst SET STATUS ACTIVE

-- Change home database
ALTER USER analyst SET HOME DATABASE reporting

-- Remove home database (use default)
ALTER USER analyst REMOVE HOME DATABASE

-- Multiple changes at once
ALTER USER analyst
  SET PASSWORD 'temp_pass'
  SET PASSWORD CHANGE REQUIRED
  SET STATUS ACTIVE
```

## DROP USER

```cypher
-- Drop user
DROP USER analyst

-- Idempotent
DROP USER analyst IF EXISTS
```

Dropping a user removes them entirely. Their roles and privileges are not affected (they remain for other users with those roles).

## Auth Providers

Neo4j supports multiple authentication providers per user (Enterprise Edition).

### Native Authentication

Default provider. Passwords stored in Neo4j system database.

```cypher
-- Create with native auth (default)
CREATE USER local_user SET PASSWORD 'password123'

-- Explicitly specify native
ALTER USER local_user
  SET AUTH 'native' {SET PASSWORD 'new_pass'}
```

### LDAP Authentication

Authenticate against an external LDAP/Active Directory server.

```cypher
-- Create user with LDAP auth
CREATE USER ldap_user
  SET AUTH 'ldap' {SET ID 'cn=john.doe,ou=users,dc=company,dc=com'}

-- LDAP users can also have native password as fallback
ALTER USER ldap_user
  SET AUTH 'native' {SET PASSWORD 'fallback_pass'}
  SET AUTH 'ldap' {SET ID 'cn=john.doe,ou=users,dc=company,dc=com'}
```

### OIDC Authentication

Authenticate via OpenID Connect providers (Google, Azure AD, Okta, etc.).

```cypher
-- Create user with OIDC auth
CREATE USER oidc_user
  SET AUTH 'oidc-google' {SET ID 'user@company.com'}
```

### Multiple Auth Providers

A user can have multiple auth providers. They can log in with any configured provider.

```cypher
-- User with both native and LDAP
ALTER USER hybrid_user
  SET AUTH 'native' {SET PASSWORD 'local_pass'}
  SET AUTH 'ldap' {SET ID 'cn=hybrid,ou=users,dc=corp,dc=com'}
```

### Show Auth Configuration

```cypher
SHOW USERS
YIELD user, auth
WHERE user = 'analyst'
RETURN user, auth
```

## Common Patterns

### Bulk User Audit

```cypher
-- Users without roles (potential orphans)
SHOW USERS
YIELD user, roles
WHERE size(roles) = 0
RETURN user

-- Suspended users
SHOW USERS
YIELD user, suspended
WHERE suspended = true
RETURN user

-- Users requiring password change
SHOW USERS
YIELD user, passwordChangeRequired
WHERE passwordChangeRequired = true
RETURN user
```

### User Lifecycle

```cypher
-- 1. Create
CREATE USER new_hire SET PASSWORD 'welcome123' SET PASSWORD CHANGE REQUIRED;

-- 2. Assign roles
GRANT ROLE reader TO new_hire;

-- 3. User works...

-- 4. Suspend (on leave)
ALTER USER new_hire SET STATUS SUSPENDED;

-- 5. Reactivate
ALTER USER new_hire SET STATUS ACTIVE;

-- 6. Offboard
REVOKE ALL ROLES FROM new_hire;
DROP USER new_hire;
```
