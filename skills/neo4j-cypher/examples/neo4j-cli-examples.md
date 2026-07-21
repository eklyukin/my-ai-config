# neo4j-cli Examples

CLI-first workflow examples for common Neo4j operations using `neo4j-cli query`. Connection uses the stored `dbms` credentials `default` (admin) and `neuronet` (reader) — see [../references/neo4j-cli-guide.md](../references/neo4j-cli-guide.md) for setup.

## Quick Start

### Run a Query

```bash
# One-shot read via stored credential
neo4j-cli query --credential default \
  'MATCH (n) RETURN labels(n) AS label, count(*) AS cnt ORDER BY cnt DESC LIMIT 10'

# Schema first (always introspect before writing Cypher)
neo4j-cli query --credential default :schema --format toon
```

### Connect to a different Aura / ad-hoc instance

```bash
# Explicit flags override credential + env (URI auto-encrypts to neo4j+s://)
neo4j-cli query --uri neo4j+s://abc123.databases.neo4j.io -u neo4j -p 'AURA_PASSWORD' 'RETURN 1'

# Admin password for Neuronet Aura is in GCP Secret Manager: neo4j_admin_password
```

## Auth & Admin Operations

SHOW commands can also run via MCP `read_neo4j_cypher`. Write operations (GRANT/REVOKE/CREATE ROLE) require `neo4j-cli query -d system --rw` or a Python Bolt driver — there is no MCP write tool in all contexts, and the HTTP API returns 403 for admin operations on Aura. CLI is preferred for multi-statement scripts and migrations.

> **Remember**: on the `system` database, even `SHOW USERS`/`SHOW PRIVILEGES` are write-classified by the EXPLAIN preflight — always pass `--rw`.

### Create a Read-Only User

```bash
neo4j-cli query --credential default -d system --rw --atomic \
  "CREATE USER analytics_user SET PASSWORD 'initial_pass' SET PASSWORD CHANGE REQUIRED;
   CREATE ROLE analytics_reader;
   GRANT MATCH {*} ON GRAPH neo4j TO analytics_reader;
   GRANT ROLE analytics_reader TO analytics_user"
```

### Grant PUBLIC Access to New Labels

When a cron job creates new node labels that apps read via PUBLIC:

```bash
neo4j-cli query --credential default -d system --rw \
  "GRANT TRAVERSE ON GRAPH neo4j NODES NewLabel TO PUBLIC;
   GRANT READ {*} ON GRAPH neo4j NODES NewLabel TO PUBLIC;
   GRANT TRAVERSE ON GRAPH neo4j RELATIONSHIPS NEW_REL TO PUBLIC;
   GRANT READ {*} ON GRAPH neo4j RELATIONSHIPS NEW_REL TO PUBLIC"
```

### Audit User Privileges

```bash
# All privileges for a user
neo4j-cli query --credential default -d system \
  'SHOW USER analytics_user PRIVILEGES AS COMMANDS' --rw --max-rows 0

# Check for DENY rules (they override GRANT)
neo4j-cli query --credential default -d system --rw \
  "SHOW USER analytics_user PRIVILEGES YIELD access, action, resource WHERE access = 'DENIED' RETURN *"
```

### Show All Roles and Users

```bash
# Roles with assigned users
neo4j-cli query --credential default -d system 'SHOW POPULATED ROLES WITH USERS' --rw --max-rows 0

# Custom roles only
neo4j-cli query --credential default -d system --rw \
  'SHOW ROLES YIELD role, isBuiltIn WHERE isBuiltIn = false RETURN role'
```

### Suspend / Drop User

```bash
# Suspend (reversible)
neo4j-cli query --credential default -d system 'ALTER USER analyst SET STATUS SUSPENDED' --rw

# Drop (irreversible)
neo4j-cli query --credential default -d system 'DROP USER analyst IF EXISTS' --rw
```

### Department-Scoped Access (PBAC)

```bash
neo4j-cli query --credential default -d system --rw --atomic \
  "CREATE ROLE hr_reader;
   GRANT MATCH {*} ON GRAPH neo4j NODE Employee TO hr_reader WHERE n.department = 'HR';
   GRANT ROLE hr_reader TO hr_analyst"
```

## File-Based Query Execution

### Execute a Migration

```bash
# Single file (pipe it in)
neo4j-cli query --credential default --rw < migrations/001_add_indexes.cypher

# Multiple files in order, fail-fast
for f in migrations/*.cypher; do
  echo "Running: $f"
  neo4j-cli query --credential default --rw < "$f" || { echo "FAILED: $f"; exit 1; }
done
```

## Batch Operations with Transactions

### Atomic multi-statement (all-or-nothing)

```bash
neo4j-cli query --credential default --rw --atomic \
  "CREATE (a:Person {name:'Alice', department:'Engineering'});
   CREATE (b:Person {name:'Bob', department:'Engineering'});
   MATCH (a:Person {name:'Alice'}), (b:Person {name:'Bob'}) CREATE (a)-[:WORKS_WITH]->(b)"
```

### Batched UNWIND (row-batched transactions)

```bash
neo4j-cli query --credential default --rw \
  "CALL () {
     UNWIND range(1, 10000) AS i
     CREATE (n:TempNode {id: i, created: datetime()})
   } IN TRANSACTIONS OF 500 ROWS"
```

### Bulk Import from CSV

```bash
neo4j-cli query --credential default --rw \
  "LOAD CSV WITH HEADERS FROM 'file:///import/employees.csv' AS row
   CALL (row) {
     MERGE (e:Employee {employeeId: row.id})
     SET e.name = row.name, e.department = row.department, e.email = row.email
   } IN TRANSACTIONS OF 1000 ROWS"
```

## Parameter-Based Queries

```bash
# Single parameter
neo4j-cli query --credential default \
  'MATCH (n:Person {department: $dept}) RETURN n.name, n.email' \
  --param dept=Engineering

# Multiple parameters (typed — minAge parses as a number)
neo4j-cli query --credential default \
  'MATCH (n:Person {department: $dept}) WHERE n.age >= $minAge RETURN n.name' \
  --param dept=Engineering --param minAge=25

# List / map params
neo4j-cli query --credential default 'MATCH (n) WHERE n.id IN $ids RETURN n' --param 'ids=[1,2,3]'
```

## Database Switching

```bash
# Target a specific database per invocation with -d
neo4j-cli query --credential default -d system 'SHOW USERS YIELD user RETURN user' --rw --max-rows 0
neo4j-cli query --credential default -d neo4j 'MATCH (n:Person) RETURN count(n)'
```

## Combined CLI + MCP Workflows

Use CLI for multi-statement admin scripts, migrations, and all write/admin operations. Use MCP `read_neo4j_cypher` for quick reads and SHOW commands only.

### Workflow: Create User via CLI, Verify via MCP

```bash
# Step 1: Create user and grant role via CLI (atomic multi-statement)
neo4j-cli query --credential default -d system --rw --atomic \
  "CREATE USER app_reader SET PASSWORD 'secure_pass' SET PASSWORD CHANGE NOT REQUIRED;
   GRANT ROLE reader TO app_reader"
```

```
# Step 2: Verify via MCP (quick read)
mcp__neo4j-neuronet__read_neo4j_cypher(
  query: "SHOW USERS YIELD user, roles WHERE user = 'app_reader' RETURN user, roles",
  database: "system"
)
```

### Workflow: Grant Labels via CLI, Query Data via MCP

```bash
# Step 1: Grant access to new label (multi-statement — CLI preferred)
neo4j-cli query --credential default -d system --rw \
  "GRANT TRAVERSE ON GRAPH neo4j NODES MetricsDaily TO PUBLIC;
   GRANT READ {*} ON GRAPH neo4j NODES MetricsDaily TO PUBLIC"
```

```
# Step 2: Query the new data via MCP (convenience)
mcp__neo4j-neuronet__read_neo4j_cypher(
  query: "MATCH (m:MetricsDaily) RETURN m.date, m.value ORDER BY m.date DESC LIMIT 10"
)
```

## Export & Reporting

### Export Query Results

```bash
# Structured JSON (best for downstream processing)
neo4j-cli query --credential default --format json --max-rows 0 \
  'MATCH (p:Person)-[:WORKS_AT]->(c:Company)
   RETURN p.name AS name, p.email AS email, c.name AS company' | jq '.rows' > report.json

# Plain/TSV via piped output
neo4j-cli query --credential default \
  'MATCH (p:Person) RETURN p.name, p.email' > people.tsv
```

### Schema Report

```bash
echo "=== Schema (labels, rel types, indexes, constraints) ==="
neo4j-cli query --credential default :schema --format table

echo "=== Node label counts ==="
neo4j-cli query --credential default --max-rows 0 \
  'CALL db.labels() YIELD label
   CALL (label) { MATCH (n) WHERE label IN labels(n) RETURN count(n) AS cnt }
   RETURN label, cnt ORDER BY cnt DESC'
```

## Troubleshooting

### Connection Issues

```bash
# Test connectivity
neo4j-cli query --credential default 'RETURN 1' >/dev/null 2>&1 && echo "Connected" || echo "Failed"

# Driver-level diagnostics (connection/auth/routing) to stderr
neo4j-cli query --credential default 'RETURN 1' --debug
```

### Empty URI error

`Failed to parse address: 'neo4j://'` means the URI resolved empty (e.g. an unset env var). Verify:

```bash
env | grep '^NEO4J' | sed 's/=.*$/=…/' | sort
neo4j-cli credential dbms list   # confirm a stored profile exists
```

### Auth Failures

```bash
# Confirm who you are / your roles
neo4j-cli query --credential default -d system 'SHOW CURRENT USER YIELD user, roles RETURN user, roles' --rw

# Check if a user is suspended
neo4j-cli query --credential default -d system --rw \
  "SHOW USERS YIELD user, suspended WHERE user = 'target_user' RETURN *"
```

### Write blocked unexpectedly

`this command writes; pass --rw to allow it` — the EXPLAIN preflight classified the statement as a write. This is expected for real mutations **and** for system-DB `SHOW`/`GRANT`/`REVOKE`. Re-run with `--rw`.
