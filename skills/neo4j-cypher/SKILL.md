---
name: neo4j-cypher
description: "Neo4j Cypher reference with neo4j-cli execution. Invoke via /neo4j or /neo4j-cypher. Use for writing, optimizing, and validating Cypher 25 queries (MATCH, MERGE, WITH, CALL subqueries, UNWIND, LOAD CSV, QPEs, vector/fulltext search), graph pattern matching, slow-query tuning (EXPLAIN/PROFILE, indexes), HTTP API writes, YAML query templates, RBAC (users/roles/privileges/PBAC), Fivetran-loaded data, Neo4j permission audits, graph queries."
compatibility: Neo4j >= 2025.01 (safe baseline); Cypher 25
---

# Neo4j Cypher — CLI-First Reference

## Neuronet MCP in this environment

This environment connects Neo4j through the **Neuronet** MCP server, not a plain `neo4j` MCP server:
- Direct Cypher execution: `mcp__neo4j-neuronet__read_neo4j_cypher`, `mcp__neo4j-neuronet__write_neo4j_cypher`, `mcp__neo4j-neuronet__get_neo4j_schema` — use these wherever this skill (or its references) says `mcp__neo4j__read-cypher` / `write-cypher` / `get-schema`.
- Code search: `neuronet_code_search` is a separate Neuronet capability for searching indexed source code, not for querying this graph — see `rules/neo4j-graph-first.md`. Don't conflate the two.

Navigation index for Cypher authoring, execution, auth, access control, and graph operations. Depth lives in `references/` — load on demand.

**Sibling skills**: `neo4j-aura-api` (cloud management) · `neo4j-cli` (full CLI: Aura/Docker/Desktop/credentials)

> Absorbed the upstream `neo4j-cypher-skill` (Cypher 25 authoring) on 2026-07-09 — its references and schema scripts live here.

## Examples

```bash
neo4j-cli query --credential default :schema --format toon              # inspect schema first
neo4j-cli query --credential default 'MATCH (n) RETURN count(n) AS n'   # one-shot read
neo4j-cli query --credential default -d system 'SHOW USERS YIELD user RETURN user' --rw --max-rows 0
neo4j-cli query --credential default 'CREATE (n:Person {name:$n})' --param n=Alice --rw
```

More → [examples/neo4j-cli-examples.md](examples/neo4j-cli-examples.md) · [examples/api-examples.md](examples/api-examples.md)

## Execution Priority

| Priority | Method | Use When | Auth/Admin Ops |
|----------|--------|----------|----------------|
| 1. CLI | `neo4j-cli query` | **Default for all queries** — reads, writes, migrations, transactions, admin ops | Full support via `-d system --rw` |
| 2. Python | `neuronet_search()` (ADK) / Bolt driver | ADK agents (read), programmatic queries, batch operations | Read via `neuronet_search()`. Write via `neo4j-cli query --rw` or Bolt. |
| 3. MCP | `mcp__neo4j-neuronet__*` | Claude Code fallback — when neo4j-cli is unavailable | Keyword-filtered; see [references/mcp-tools.md](references/mcp-tools.md) |
| 4. Bash | `neo4j read/schema/template` | Template queries, schema inspection (HTTP API wrapper) | No admin support |

**Decision logic**: Use `neo4j-cli query` for everything (reads, writes, admin). Stored `dbms` credentials supply the connection (`--credential <name>`). ADK agents use `neuronet_search()` for reads. Fall back to MCP only when neo4j-cli is unavailable.

## 1. CLI — neo4j-cli query

`neo4j-cli` (neo4j-labs) drives Cypher over Bolt. It replaced `cypher-shell` as the default execution path (2026-07-09). Install: `brew install neo4j-labs/tap/neo4j-cli`.

### Quick Connect — stored credentials

Profiles live in the macOS Keychain (`neo4j-cli config get credential-storage` → `keyring`). List: `neo4j-cli credential dbms list`.

| Credential | User | Scope |
|------------|------|-------|
| `default` | `aevseev` (admin role) | Read + write + **admin** (GRANT/REVOKE/SHOW) |
| `neuronet` | `customgpt` (reader) | Read-only |

```bash
neo4j-cli query --credential default 'MATCH (n) RETURN count(n) AS n'          # read
neo4j-cli query --credential default :schema --format toon                     # introspect
neo4j-cli query --credential default -d system 'SHOW USERS' --rw --max-rows 0  # admin
```

### The three gotchas

1. **`--rw` is required for writes AND system-DB reads.** The EXPLAIN preflight write-classifies system commands, so `SHOW USERS`/`SHOW PRIVILEGES` fail without `--rw`. When in doubt on a system-DB query, pass `--rw`.
2. **Multi-statement splits only on `;` at end of line.** A mid-line `;` is kept verbatim → `Expected exactly one statement`. Put each statement on its own line.
3. **Default 100-row print cap.** Pass `--max-rows 0` for full lists.

### Key flags

| Flag | Description |
|------|-------------|
| `-c, --credential <name>` | Stored dbms credential |
| `-d, --database <db>` | Target database (`system` for admin) |
| `--rw` | Allow writes (also needed for system-DB `SHOW`/`GRANT`/`REVOKE`) |
| `--param 'k=v'` | Parameter (repeatable, JSON auto-typed); `k:embed=<text>` binds an embedding vector |
| `--atomic` / `--continue-on-error` | One txn rolled back on failure / best-effort, exit non-zero |
| `--format json\|table\|toon` | Output (agents prefer `toon`/`json`) |
| `--max-rows 0` | Remove the 100-row cap |

### Access mode — Aura cluster routing (known gap)

The Neuronet Aura cluster (`6237b468`) is a **causal cluster**; concentrating bolt connections on the leader caused incident XEN-552 (2026-04-24).

> ⚠️ **`neo4j-cli` does NOT expose `--access-mode read`** (which `cypher-shell` had). Its driver routes read-classified transactions to followers, but there is no knob to force it. For **read-heavy batch scripts** where leader-pinning matters, use the Python `neo4j` driver with `session(default_access_mode="READ")` / `execute_read`. Ad-hoc reads via `neo4j-cli` are fine.

> Full CLI reference (installation, credentials, connection resolution, output formats, transactions, scripting, cypher-shell cheat sheet) → [references/neo4j-cli-guide.md](references/neo4j-cli-guide.md)

## 2. API — Python Bolt / HTTP

Python Bolt is **required for Aura admin** — the HTTP API returns `403` for admin commands.

```python
from neo4j import GraphDatabase
driver = GraphDatabase.driver('neo4j+s://INSTANCE_ID.databases.neo4j.io', auth=('neo4j', 'ADMIN_PASSWORD'))
with driver.session(database='system') as session:
    for record in session.run('SHOW USERS'):
        print(record)
driver.close()
```

> HTTP Query API (self-hosted + Aura data ops) → [references/http-api-reference.md](references/http-api-reference.md)

## 3. Python Tools (ADK Agents)

For Google ADK agents, use the shared tools from `agents/shared/tools/`:

```python
# Read — from shared.tools.neo4j_context
neuronet_search(query="MATCH (n:Person) RETURN n.name LIMIT 10")
```

```bash
# Write — no Python write tool; use neo4j-cli via Bash
neo4j-cli query --uri "$NEO4J_NEURONET_URI" --username "$NEO4J_NEURONET_WRITER_USERNAME" --password "$NEO4J_NEURONET_WRITER_PASSWORD" \
  'CREATE (n:Person {name: $name})' --param name=Alice --rw
```

## 4. MCP Tools (Claude Code Fallback)

Use MCP only when `neo4j-cli` is unavailable. Read/write tool split, the `read_neo4j_cypher` keyword filter (**not** a security boundary), admin routing rules, and the `neuronet_cypher` **205-row silent cap** with its pagination workaround are all documented in:

> [references/mcp-tools.md](references/mcp-tools.md)

Key rules: `read_neo4j_cypher` for `SHOW *` and `GRANT MATCH/TRAVERSE/READ`; `write_neo4j_cypher` for everything else (its keyword filter blocks `CREATE`/`SET`/`DELETE`). `GRANT` targets **roles, not users**. Assigning privileges requires the `admin` role.

## Cypher Authoring (Cypher 25)

Rules for **writing** Cypher (vs. executing it). Baseline Neo4j ≥ 2025.01.

**Defaults — every query:** `CYPHER 25` first token · schema first, never guess names · `MERGE` on a constrained key only · no label-free `MATCH (n)` · `LIMIT 25` on exploratory reads · `//` comments (not `--`) · return **named properties**, not whole nodes · `$parameters` always · `DETACH DELETE` when rels exist.

**Style:** `:PascalCase` labels · `:SCREAMING_SNAKE` rel types · `camelCase` properties · UPPERCASE clauses · single-quoted strings.

**Schema first** — `neo4j-cli query --credential default :schema --format toon`, or `CALL apoc.meta.schema()`. Helper scripts: `scripts/generate_schema.py` (live DB), `scripts/define_schema.py` (no DB), `scripts/import_neo4j_schema.py`.

> ⚠️ On the Neuronet instance (~1B nodes), `db.schema.nodeTypeProperties()` and per-label count sweeps are **very expensive**. Use `:schema`, `apoc.meta.schema()`, or `MATCH (n:Label) RETURN n LIMIT 1`.

**Top traps:** `id(n)`→`elementId(n)` · `[:REL*1..5]`→`(()-[:REL]->()){1,5}` · `CALL { WITH x ...}`→`CALL (x) {...}` · `SET n = {}` (replaces) vs `SET n += {}` (merges) · `WHERE n.x = null`→`IS NULL` · `toInteger(null)` throws→`toIntegerOrNull()` · ISO `Z` suffix **≠ UTC** in Neo4j (coerce with `datetime({datetime: datetime($iso), timezone:'UTC'})`).

**Performance red flags:** `AllNodesScan` · `CartesianProduct` · `NodeByLabelScan` · `Eager`. An index only activates when the node has a **label**. `MERGE` without a constraint has no atomicity guarantee.

> Full section — defaults, subquery cheat sheet, 40+ trap table, version gates, Eager fixes, validation workflow, failure recovery, authoring checklist → [references/cypher-authoring.md](references/cypher-authoring.md)
> Deep dives → [references/cypher-syntax.md](references/cypher-syntax.md) · [references/syntax-traps.md](references/syntax-traps.md) · [references/performance.md](references/performance.md) · [references/indexes.md](references/indexes.md)

## Data & Query Patterns

**Fivetran-loaded nodes** (`zzz_` prefix): no relationships (use property-based joins) · properties prefixed with the label name · epoch-second timestamps · numeric status codes · **always sample first**.

**Fulltext search**: prefer a fulltext index over `CONTAINS` on large node sets — `CALL db.index.fulltext.queryNodes('workitem_body_fulltext', $term) YIELD node, score`.

**Safe casting**: `date()`/`toInteger()` throw on empty strings — guard with `CASE WHEN x IS NOT NULL AND x <> '' THEN ... ELSE null END`.

> Full patterns (Fivetran joins, fulltext indexes, null-safe casting, dedupe `OPTIONAL MATCH`, diacritics-safe comparison) → [references/data-patterns.md](references/data-patterns.md)

## Write Operations via HTTP API

**Credential tiers** — choose the right level:

| Operation | Credential | Secret Pattern |
|-----------|-----------|----------------|
| Data reads | MCP `read_neo4j_cypher` | Built-in, no secrets needed |
| Data writes (MERGE, SET, CREATE) | `neuronet_writer` (publisher) | `claude_mcp_neo4j_neuronet_writer_*` |
| Schema DDL (CREATE CONSTRAINT, INDEX) | Admin | `xenia-npc-neo4j-admin-*` |

**CALL subquery scope (Neo4j 5.23+)**: use `CALL () { ... } IN TRANSACTIONS` (explicit empty scope), not the deprecated `CALL { ... }`.
**MERGE ordering**: `ON CREATE SET` / `ON MATCH SET` must come BEFORE any general `SET`.

> [references/http-api-reference.md](references/http-api-reference.md) · [examples/api-examples.md](examples/api-examples.md) · bulk ops → [references/bulk-operations-gotchas.md](references/bulk-operations-gotchas.md)

## Template System

YAML templates define reusable parameterized Cypher queries. Precedence: project `.claude/neo4j-templates/` > skill `templates/` > user `~/.claude/neo4j-templates/`.

```bash
neo4j template entity_pool --label=Employee --limit=50   # Execute template
neo4j templates --list                                    # List available
neo4j discover                                            # Auto-suggest from schema
```

> Template YAML format and parameter types → [templates/README.md](templates/README.md)

## Graph Visualization

When a query returns bare node/relationship variables (not just properties), open the **Graph Explorer** mini-app:

```bash
open "http://localhost:5173/?query=$(echo -n 'MATCH (e)-[r]->(t) RETURN e, r, t LIMIT 50' | base64)"
```

**Requirements**: Vite dev server at `localhost:5173` + API at `localhost:3001`. Skip if not running.
**Tip**: include relationship variables in RETURN (`e, r, t` not `e, t`) so edges render.

## Configuration

Credential precedence: **Environment variables** > **GCP Secret Manager** > **Config file** (`config/neo4j.conf`) > Defaults.

```bash
export NEO4J_URI="neo4j+s://INSTANCE_ID.databases.neo4j.io"
export NEO4J_USERNAME="neo4j" && export NEO4J_PASSWORD="password"

# Or GCP auto-fetch (recommended)
export USE_GCP_SECRETS="auto" && export GCP_PROJECT_ID="ai-experiments-469513"
```

> GCP Secret Manager setup, service account impersonation, troubleshooting → [references/gcp-integration.md](references/gcp-integration.md)

## Prerequisites

- **Neo4j Enterprise Edition** required for roles, privileges, and PBAC (Community: basic user management only)
- Auth commands run against the **system database** (`-d system` for CLI, `database: "system"` for MCP)
- Requires **admin role** or specific privilege management permissions
- Neo4j 5.x+ recommended (PBAC requires 5.x)

## Auth Model

```
Users  -->  Roles  -->  Privileges  -->  Graph Resources
            (built-in or custom)         (databases, graphs, nodes, rels, properties)
```

**DENY always wins over GRANT.** If a user has roles with both GRANT and DENY on the same resource, access is denied.

| Command | Effect |
|---------|--------|
| `GRANT` | Allows an action |
| `DENY` | Explicitly blocks an action |
| `REVOKE` | Removes a previous GRANT or DENY |

### Privilege Hierarchy

```
ALL GRAPH PRIVILEGES
├── MATCH (= TRAVERSE + READ)
│   ├── TRAVERSE
│   └── READ
└── WRITE
    ├── CREATE / DELETE
    ├── SET LABEL / REMOVE LABEL
    ├── SET PROPERTY / REMOVE PROPERTY
    └── MERGE
```

## User Management

```cypher
SHOW USERS                                                    -- All users
SHOW CURRENT USER                                             -- Current user details
CREATE USER analyst SET PASSWORD 'changeme'
  SET PASSWORD CHANGE REQUIRED SET STATUS ACTIVE              -- Full create
ALTER USER analyst SET PASSWORD 'new_pass'                    -- Change password
ALTER USER analyst SET STATUS SUSPENDED                       -- Suspend
DROP USER analyst IF EXISTS                                   -- Drop
```

> Auth providers (LDAP, OIDC), multi-provider setup, full syntax → [references/user-management.md](references/user-management.md)

## Role Management

```cypher
SHOW ROLES                                           -- All roles
SHOW POPULATED ROLES WITH USERS                      -- Roles with assigned users
CREATE ROLE data_reader                              -- Create
CREATE ROLE senior_analyst AS COPY OF reader         -- Copy from existing
RENAME ROLE data_reader TO data_analyst              -- Rename
DROP ROLE data_analyst IF EXISTS                     -- Drop
GRANT ROLE data_reader TO analyst_user               -- Assign
REVOKE ROLE editor FROM analyst_user                 -- Revoke
```

> Full syntax and custom role patterns → [references/role-management.md](references/role-management.md)

## Built-in Roles

| Role | Read | Write | New Labels/Types | Index/Constraint | Admin |
|------|------|-------|-------------------|------------------|-------|
| `PUBLIC` | - | - | - | - | - |
| `reader` | all | - | - | view | - |
| `editor` | all | existing | - | view | - |
| `publisher` | all | all | create | view | - |
| `architect` | all | all | create | manage | - |
| `admin` | all | all | create | manage | full |

```cypher
SHOW ROLE reader PRIVILEGES AS COMMANDS        -- View role's privileges
SHOW USER analyst PRIVILEGES AS COMMANDS       -- View user's effective privileges
```

> Exact privilege sets and recreation Cypher → [references/built-in-roles.md](references/built-in-roles.md)

## Privilege Management

```cypher
-- Read
GRANT TRAVERSE ON GRAPH * NODES * TO role                          -- See nodes exist
GRANT READ {name, email} ON GRAPH neo4j NODE Employee TO role      -- Read specific props
GRANT MATCH {*} ON GRAPH * TO role                                 -- TRAVERSE + READ

-- Write
GRANT CREATE ON GRAPH neo4j TO role
GRANT SET PROPERTY {status} ON GRAPH neo4j NODE Task TO role
GRANT WRITE ON GRAPH neo4j TO role                                 -- All write operations

-- DBMS administration
GRANT SHOW USER ON DBMS TO auditor_role                            -- also SHOW ROLE / SHOW PRIVILEGE

-- Show / Revoke
SHOW ROLE data_reader PRIVILEGES AS COMMANDS
SHOW ROLE data_reader PRIVILEGES AS REVOKE COMMANDS                -- Get revoke commands
REVOKE GRANT READ {salary} ON GRAPH hr NODE Employee FROM data_reader
```

> Complete syntax, scoping, MERGE details → [references/privilege-read-write.md](references/privilege-read-write.md)

## Property-Based Access Control (PBAC)

```cypher
GRANT MATCH {*} ON GRAPH hr NODE Employee TO engineering_reader
  WHERE n.department = 'Engineering'

DENY READ {*} ON GRAPH docs NODE Document TO basic_reader
  WHERE n.classification = 'SECRET'
```

**Supported predicates**: `=`, `IS NULL`, `IS NOT NULL`, `IN [list]`, `OR`

> Performance considerations and advanced examples → [references/property-based-access-control.md](references/property-based-access-control.md)

## Common Recipes

1. **Read-only analytics user** — user + role with `GRANT MATCH {*} ON GRAPH *`
2. **Department-scoped user (PBAC)** — role with `WHERE n.department = 'HR'`
3. **Application service account** — `CREATE ROLE AS COPY OF publisher` + no password change
4. **Audit user permissions** — `SHOW USER x PRIVILEGES AS COMMANDS`
5. **Lock down production** — `REVOKE WRITE` + `GRANT MATCH {*}` only
6. **Hide sensitive properties** — `DENY READ {salary, ssn}` on specific labels
7. **Reset a role** — `SHOW ROLE x PRIVILEGES AS REVOKE COMMANDS` then re-grant
8. **Multi-tenant isolation** — PBAC with `WHERE n.tenant_id = 'acme'`
9. **Enable PUBLIC read on new labels** — `GRANT TRAVERSE + READ` after cron deploys new labels
10. **Bulk grant for a new mini-app mutation set** — enumerate `(action, label/rel)` pairs via the table below; batch every GRANT in one parent message (parallel `neuronet_cypher`) or one `neo4j-cli query -d system --rw` call — do NOT serialize. Verify with `SHOW PRIVILEGES ... WHERE segment CONTAINS 'Foo'` (**not** `segment = ...`). Pattern used on N4J-1217 / N4J-1223.

### Recipe: Query to Minimum Privileges

| Query Clause | Required Privilege |
|---|---|
| `MATCH (n:Label)` | `TRAVERSE ON GRAPH * NODES Label` |
| `n.prop` in MATCH/WHERE/RETURN | `READ {prop} ON GRAPH * NODES Label` |
| `SET n.prop = val` | `SET PROPERTY {prop} ON GRAPH * NODES Label` |
| `MERGE (n:Label {key: $v})` | `TRAVERSE` + `READ {key}` + `CREATE` + `SET PROPERTY {key}` |
| `CREATE (n:Label {…})` | `CREATE ON GRAPH * NODES Label` + `SET PROPERTY` per prop |
| `DELETE n` | `DELETE ON GRAPH * NODES Label` |
| `SET n:NewLabel` | `SET LABEL NewLabel ON GRAPH *` |

**Tip**: prefer MATCH over MERGE when nodes are guaranteed to exist — avoids needing CREATE/SET PROPERTY grants.

> Complete end-to-end workflows → [references/common-recipes.md](references/common-recipes.md)

## Troubleshooting

Quick hits — full detail in [references/troubleshooting.md](references/troubleshooting.md):

- **Permission denied** → `SHOW USER x PRIVILEGES AS COMMANDS`; check for `DENIED` access rows first
- **Zero results** → the label may be wrong, not the data missing. Enumerate `CALL db.labels()` and check for renamed/versioned variants (`:JiraPlan` vs `:Plan`) before declaring absence
- **`SHOW PRIVILEGES`** → **always filter** (unfiltered returns ~3.5k rows). Post-GRANT, verify with `segment CONTAINS 'Foo'`, **not** `segment = ...` — Aura replication lag makes exact-match reads return a stale subset
- **Query monitoring (Aura)** → `dbms.listQueries()` is removed; use `SHOW TRANSACTIONS`
- **Syntax** → `SHOW ...` needs `YIELD` before `WHERE`/`RETURN`; `NODES`/`RELATIONSHIPS` need a label/type or `*`

## Audit Logging

Neuronet uses `(:AuditLog)` nodes to track write mutations, linked as `(entity)-[:HAS_AUDIT]->(audit:AuditLog)`.

- **Actor convention**: `cron:{JOB}` · `n8n:{WORKFLOW_ID}` · `manual:{USER}` · `api:{SERVICE}`
- **Never store** `tax_salary`, `desired_tax_salary`, `ssn`, `password` in `previousValue`/`newValue` — use `"[REDACTED]"`
- **Retention**: entries older than 90 days archive weekly to BigQuery (`neuronet.audit_log_archive`) and are deleted from Neo4j

> Schema, creation patterns, batch tradeoffs, cron audit queries → [references/audit-logging-patterns.md](references/audit-logging-patterns.md)

## Reference Files

**Cypher authoring** (merged from `neo4j-cypher-skill`):

| File | Scope |
|------|-------|
| [cypher-authoring.md](references/cypher-authoring.md) | Defaults, style, schema-first protocol, subqueries, version gates, validation, failure recovery, checklist |
| [cypher-syntax.md](references/cypher-syntax.md) | Full syntax: clauses, patterns, functions, QPEs, dynamic labels, SEARCH, conditional CALL |
| [syntax-traps.md](references/syntax-traps.md) | 40+ syntax trap table |
| [performance.md](references/performance.md) | Anti-patterns, text vs fulltext indexes, Eager fixes, label inference, parallel runtime |
| [indexes.md](references/indexes.md) | Index types, constraints, MERGE lock semantics, Lucene syntax |
| [advanced-patterns.md](references/advanced-patterns.md) | REPEATABLE ELEMENTS, allReduce, multi-stop QPE, DAG critical path, cycle detection |
| [apoc.md](references/apoc.md) | APOC Core: refactoring, virtual graph, merge helpers, path expanders, triggers |
| [schema-guardrail.md](references/schema-guardrail.md) | `<db>-schema.json` rules, synonym resolution, validation gates |
| [graph-type.md](references/graph-type.md) | **PREVIEW (2026.02+)** GRAPH TYPE DDL |

**Execution, auth & ops:**

| File | Scope |
|------|-------|
| [neo4j-cli-guide.md](references/neo4j-cli-guide.md) | Full CLI reference: install, credentials, connection, output, transactions |
| [mcp-tools.md](references/mcp-tools.md) | MCP read/write split, keyword filter, admin routing, 205-row cap workaround |
| [troubleshooting.md](references/troubleshooting.md) | Permission denied, zero results, SHOW PRIVILEGES gotchas, syntax errors |
| [data-patterns.md](references/data-patterns.md) | Fivetran nodes, fulltext search, safe casting, dedupe + diacritics patterns |
| [http-api-reference.md](references/http-api-reference.md) | HTTP Query API: params, return structures, errors |
| [user-management.md](references/user-management.md) | User CRUD, auth providers, states |
| [role-management.md](references/role-management.md) | Role CRUD, assignment, custom patterns |
| [built-in-roles.md](references/built-in-roles.md) | 6 built-in roles, privilege sets, recreation Cypher |
| [privilege-read-write.md](references/privilege-read-write.md) | Read/write privilege syntax with scoping |
| [property-based-access-control.md](references/property-based-access-control.md) | PBAC WHERE clauses, predicates, performance |
| [common-recipes.md](references/common-recipes.md) | End-to-end auth workflows |
| [audit-logging-patterns.md](references/audit-logging-patterns.md) | AuditLog creation patterns, batch tradeoffs |
| [bulk-operations-gotchas.md](references/bulk-operations-gotchas.md) | APOC iterate, CALL IN TRANSACTIONS, bulk DELETE |
| [gcp-integration.md](references/gcp-integration.md) | GCP Secret Manager, service account impersonation |

**Examples**: [neo4j-cli-examples.md](examples/neo4j-cli-examples.md) (CLI workflows, admin ops, migrations) · [api-examples.md](examples/api-examples.md) (HTTP API workflows)

## Important Notes

- **Enterprise Edition** required for roles, privileges, and PBAC. Community: basic user/password only.
- **DENY always wins** over GRANT. Check for DENY rules first when debugging access.
- **System database**: for CLI use `-d system --rw`, for MCP use `database: "system"`.
- **Aura rejects admin queries over HTTP with `403`** — use `neo4j-cli query -d system --rw` or the Python Bolt driver.
- **CREATE with properties** requires both `CREATE` and `SET PROPERTY` grants.

## Tool Compatibility Matrix

| Operation | Python (ADK agents) | MCP (Claude Code) | Neuronet Bot |
|-----------|--------------------|--------------------|--------------|
| Neo4j read | `neuronet_search(query=...)` | `mcp__neo4j-neuronet__read_neo4j_cypher` | `mcp__neo4j-neuronet__read_neo4j_cypher` |
| Neo4j write | `neo4j-cli query --rw` via Bash | `write_neo4j_cypher` (if available) or `neo4j-cli query --rw` | `mcp__neo4j-neuronet__write_neo4j_cypher` |
| Neo4j schema | `neo4j-cli query :schema` via Bash | `mcp__neo4j-neuronet__get_neo4j_schema` | `mcp__neo4j-neuronet__get_neo4j_schema` |
| Admin ops | `neo4j-cli query -d system --rw` | `neo4j-cli query -d system --rw` | `neo4j-cli query -d system --rw` |

## Post-Workflow

**ALWAYS run `/reflect` after completing this skill's workflow** to capture learnings and propose skill improvements.
