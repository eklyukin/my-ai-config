# neo4j-cli Reference

Complete reference for `neo4j-cli` (from `neo4j-labs`), the "super CLI" for Neo4j. This skill uses its `query` subcommand as the default Cypher execution path (migrated from `cypher-shell` on 2026-07-09). Full CLI surface (Aura / Docker / Desktop / credentials / skills) is documented in the sibling `neo4j-cli` skill; this file focuses on querying.

## Installation

### Homebrew (macOS/Linux) — preferred

```bash
brew install neo4j-labs/tap/neo4j-cli
neo4j-cli --version
```

### Other installers

```bash
curl -sSfL https://neo4j.sh/install.sh | bash   # macOS/Linux one-liner
pipx install neo4j-cli                           # PyPI
npm install -g @neo4j-labs/cli                    # npm
# PowerShell: irm https://neo4j.sh/install.ps1 | iex
```

### Self-update

```bash
neo4j-cli update            # latest stable
neo4j-cli update check      # report availability, exit 1 if newer exists
```

No Java dependency (unlike `cypher-shell`) — `neo4j-cli` is a self-contained Go binary using the Bolt driver.

## Credentials

`neo4j-cli` stores connection profiles so `query` needs no connection flags. Storage defaults to the OS keyring (macOS Keychain); confirm with `neo4j-cli config get credential-storage` (should be `keyring`, not `insecure`).

### dbms credentials (Bolt connection profiles)

```bash
# Add a profile (values pulled from env vars so secrets are never typed literally)
neo4j-cli credential dbms add --name default \
  --uri "$NEO4J_URI" --username "$NEO4J_USERNAME" --password "$NEO4J_PASSWORD" \
  --database-name "$NEO4J_DATABASE" --rw

# List / set default / remove
neo4j-cli credential dbms list
neo4j-cli credential dbms use default
neo4j-cli credential dbms remove <name> --yes --force --rw
```

**Provisioned profiles for the Neuronet Aura instance (`6237b468`):**

| Credential | User | Scope |
|------------|------|-------|
| `default` | `aevseev` (admin role) | Read + write + **admin** (GRANT/REVOKE/SHOW USERS/ROLES/PRIVILEGES) |
| `neuronet` | `customgpt` (reader) | Read-only |

> Import an Aura-exported credentials file instead of flags: `neo4j-cli credential dbms add --env ./Neo4j-XXXX-Created-*.txt --rw`.

## Connection & Authentication

### Using a stored credential (preferred)

```bash
neo4j-cli query --credential default 'MATCH (n) RETURN count(n) AS n'
```

### Connection resolution (highest priority first)

1. `--uri` / `--username` (`-u`) / `--password` (`-p`) / `--database` (`-d`) flags
2. Env vars: `NEO4J_URI`, `NEO4J_USERNAME`, `NEO4J_PASSWORD`, `NEO4J_DATABASE`
3. `.env` file (auto-discovered by walking up to the git root)
4. `--credential <name>` or the default stored dbms credential
5. Built-in defaults: `neo4j://localhost:7687`, user `neo4j`, db `neo4j`

`http://` / `https://` URIs are auto-rewritten to `neo4j://` / `neo4j+s://`. Aura already uses `neo4j+s://…`.

### Env-var connection (prod gateway / cron — no keyring)

```bash
NEO4J_URI="$NEO4J_NEURONET_URI" NEO4J_USERNAME="$NEO4J_NEURONET_USERNAME_ADMINS" \
NEO4J_PASSWORD="$NEO4J_NEURONET_PASSWORD_ADMINS" NEO4J_DATABASE="$NEO4J_NEURONET_DATABASE" \
  neo4j-cli query 'MATCH (n) RETURN count(n)'
```

> On the prod gateway the unprefixed `NEO4J_*` names are what's exported. Verify with `env | grep '^NEO4J' | sed 's/=.*$/=…/' | sort` first — an empty URI yields a misleading `Failed to parse address: 'neo4j://'`.

### System database (admin)

Auth/admin commands run against the `system` database. Pass `-d system` **and `--rw`** (the EXPLAIN preflight write-classifies system commands, so even `SHOW USERS` needs `--rw`):

```bash
neo4j-cli query --credential default -d system 'SHOW USERS YIELD user RETURN user' --rw --max-rows 0
```

## Output Formats

| `--format` | Description |
|------------|-------------|
| `default` | Coloured table on a TTY; plain text when piped (auto-detect) |
| `table` | Force bordered table even when piped |
| `json` | `{columns, rows, truncated, arrays_truncated}` — best for `jq` |
| `toon` | Compact, agent-friendly (auto-selected under agent harnesses) |

Row/array caps:

| Flag | Description |
|------|-------------|
| `--max-rows N` | Print cap (default **100**); `--max-rows 0` = unlimited. When capped, stderr warns and JSON sets `truncated=true` |
| `--truncate-arrays-over N` | Recursively cap arrays inside rows at N elements (`0` = off) |

Diagnostics (`--debug`, warnings, errors) always go to **stderr**, so stdout stays pipe-clean.

### Examples

```bash
# Table for humans
neo4j-cli query --credential default 'MATCH (n) RETURN labels(n) AS labels, count(*) AS c ORDER BY c DESC LIMIT 5' --format table

# JSON → jq pipeline
neo4j-cli query --credential default 'MATCH (p:Person) RETURN p.name AS name, p.email AS email' --format json | jq '.rows[]'

# Plain scalar (piped auto-detects) → grep
neo4j-cli query --credential default 'MATCH (p:Person) RETURN p.name' | grep Alice
```

## Query Execution

### Inline query (positional)

```bash
neo4j-cli query --credential default 'MATCH (n) RETURN count(n)'
```

### Piped from stdin (no positional argument)

```bash
echo 'MATCH (n) RETURN count(n)' | neo4j-cli query --credential default

# Multiple statements from a file
neo4j-cli query --credential default --rw < queries/report.cypher
cat migrations/*.cypher | neo4j-cli query --credential default --rw
```

### Multiple statements in one call

Statements split on a `;` at **end of line** only. A mid-line `;` is kept verbatim — so putting two statements on one line (`'RETURN 1; RETURN 2'`) fails with `Expected exactly one statement`. Put each statement on its own line ending with `;`. Each runs in its own transaction by default, failing fast on the first error.

```bash
# ✅ Correct — `;` at end of line
neo4j-cli query --credential default 'MATCH (n:Person) RETURN count(n) AS people;
MATCH (m:Movie) RETURN count(m) AS movies'

# ❌ Fails — mid-line `;` kept verbatim as a single (invalid) statement
neo4j-cli query --credential default 'MATCH (n:Person) RETURN count(n); MATCH (m:Movie) RETURN count(m)'
```

Multiple result sets render as a JSON array (`--format json`) or stacked blocks (`--format table`/`toon`).

## Parameters

`--param` is repeatable; a value that parses as JSON is typed accordingly, otherwise it's a string.

```bash
# String and typed (array) params
neo4j-cli query --credential default 'MATCH (p:Person {name: $name}) RETURN p' --param name=Alice
neo4j-cli query --credential default 'RETURN $ids AS ids' --param 'ids=[1,2,3]'
neo4j-cli query --credential default 'RETURN $cfg AS cfg' --param 'cfg={"limit":10,"active":true}'

# Embedding vector param (sent to the configured embedding provider, bound to $q)
neo4j-cli query --credential default \
  "CALL db.index.vector.queryNodes('plot_idx', 5, \$q) YIELD node, score RETURN node.title, score" \
  --param 'q:embed=sci-fi movies'
```

## Transactions

`neo4j-cli` has **no interactive `:begin`/`:commit`/`:rollback` REPL**. Control transactions with flags:

| Flag | Behavior |
|------|----------|
| (default) | Each statement in its own transaction; fail-fast on first error |
| `--atomic` | All statements in **one** transaction; roll back if any fails |
| `--continue-on-error` | Non-atomic: report each failure, run the rest, exit non-zero at the end (mutually exclusive with `--atomic`) |

```bash
# Atomic migration — all-or-nothing (statements newline-separated)
neo4j-cli query --credential default --rw --atomic 'CREATE (:Person {name:"Alice"});
CREATE (:Person {name:"Bob"})'

# Best-effort bulk import
cat migrations/*.cypher | neo4j-cli query --credential default --rw --continue-on-error
```

For row-batched large writes inside a single statement, use Cypher's `CALL () { … } IN TRANSACTIONS OF N ROWS` (Neo4j 5.23+ empty-scope form):

```cypher
CALL () {
  UNWIND range(1, 1000) AS i
  CREATE (n:Temp {id: i})
} IN TRANSACTIONS OF 100 ROWS;
```

## The `--rw` write gate

Without `--rw`, `query` runs an `EXPLAIN` preflight and **blocks any statement classified as a write**. Pass `--rw` for:

1. Real data mutations (`CREATE`, `MERGE`, `SET`, `DELETE`, `REMOVE`).
2. Schema DDL (`CREATE INDEX`/`CONSTRAINT`).
3. **System-DB admin reads** — `SHOW USERS`/`SHOW ROLES`/`SHOW PRIVILEGES`/`GRANT`/`REVOKE` all get write-classified, so they fail without `--rw` even though `SHOW *` only reads.

> On an interactive TTY `--rw` is auto-applied. Under an agent harness (Claude Code, Cursor, Codex…) or any non-interactive/piped context it must be **explicit** — this is why every admin example here passes `--rw`.

## Access mode — Aura cluster routing (known gap)

The Neuronet Aura cluster (`Xsolla NeuroNet`, `6237b468`) is a **causal cluster**: leader takes writes, followers serve reads asynchronously. Concentrating bolt connections on the leader caused incident XEN-552 (2026-04-24).

> ⚠️ **`neo4j-cli` does NOT expose `--access-mode read`** (which `cypher-shell` had). Its Bolt driver routes read-classified transactions to followers by default, but there's no knob to force read routing, and a query the driver treats as a write pins to the leader. For **read-heavy batch scripts** where leader-pinning matters, drop to the Python `neo4j` driver with `session(default_access_mode="READ")` / `execute_read`. Ad-hoc reads through `neo4j-cli` are fine — one read connection does not reproduce XEN-552.

See `~/.neuronet/shared-memory/neo4j-aura-consistency.md` and `@docs/neo4j.md` for the full routing model.

## Scripting Patterns

### Health check

```bash
neo4j-cli query --credential default 'RETURN 1' >/dev/null 2>&1 && echo OK || echo FAILED
```

### Exit-code branching

```bash
if neo4j-cli query --credential default 'MATCH (n) RETURN count(n)' >/dev/null; then
  echo "Query succeeded"
else
  echo "Query failed"
fi
```

### Batch file execution

```bash
for f in migrations/*.cypher; do
  echo "Running: $f"
  neo4j-cli query --credential default --rw < "$f" || { echo "FAILED: $f"; exit 1; }
done
```

### Export to CSV / JSON

```bash
# CSV-ish via piped plain output
neo4j-cli query --credential default 'MATCH (p:Person) RETURN p.name, p.email, p.department' > people_export.tsv

# Structured JSON
neo4j-cli query --credential default 'MATCH (p:Person) RETURN p.name AS name, p.email AS email' \
  --format json --max-rows 0 | jq '.rows' > people.json
```

### Schema inspection

```bash
# Built-in introspection (preferred — run before writing Cypher)
neo4j-cli query --credential default :schema --format toon

# Or raw SHOW commands
neo4j-cli query --credential default 'SHOW INDEXES YIELD name, type, labelsOrTypes, properties'
neo4j-cli query --credential default 'SHOW CONSTRAINTS YIELD name, type, labelsOrTypes, properties'
```

### Admin operations (system database — note `-d system --rw`)

```bash
# List users (unlimited)
neo4j-cli query --credential default -d system 'SHOW USERS YIELD user RETURN user' --rw --max-rows 0

# Create user
neo4j-cli query --credential default -d system \
  "CREATE USER analyst SET PASSWORD 'changeme' SET PASSWORD CHANGE REQUIRED" --rw

# Grant role
neo4j-cli query --credential default -d system 'GRANT ROLE reader TO analyst' --rw

# Show a user's effective privileges
neo4j-cli query --credential default -d system 'SHOW USER analyst PRIVILEGES AS COMMANDS' --rw
```

## Command history

`neo4j-cli` logs commands (secrets redacted) to `history.jsonl` alongside its config:

```bash
neo4j-cli history list --limit 20
neo4j-cli history list --format json
neo4j-cli config set history-enabled false --rw   # opt out
```

## cypher-shell → neo4j-cli cheat sheet

| cypher-shell | neo4j-cli |
|--------------|-----------|
| `cypher-shell -a URI -u U -p P 'Q'` | `neo4j-cli query --uri URI -u U -p P 'Q'` |
| `-d system` | `-d system` (+ `--rw` for SHOW/GRANT/REVOKE) |
| `-P "k => v"` | `--param k=v` |
| `-f file.cypher` | `neo4j-cli query < file.cypher` |
| `--format plain` / `verbose` | `--format json`/`table`/`toon` |
| `--access-mode read` | *(no equivalent — use Python driver for forced read routing)* |
| `:begin`/`:commit` | `--atomic` (single-call multi-statement) |
| `--fail-at-end` | `--continue-on-error` |
| (writes implicit) | `--rw` required |
| (env vars only) | `--credential <name>` (Keychain-stored profiles) |
