# MCP Tools (Claude Code Fallback)


Use MCP only when `neo4j-cli` is unavailable in Claude Code (e.g., missing binary, env vars not set).

## Read Queries

```
mcp__neo4j-neuronet__read_neo4j_cypher(
  query: "MATCH (n:Person) RETURN n.name LIMIT 10"
)
```

## Write Queries

```
mcp__neo4j-neuronet__write_neo4j_cypher(
  query: "CREATE (n:Person {name: 'Alice'})"
)
```

## System Database Queries

```
mcp__neo4j-neuronet__read_neo4j_cypher(
  query: "SHOW USERS",
  database: "system"
)
```

**Admin ops via MCP**: The read tool has a client-side keyword filter — it blocks any query containing `CREATE`, `SET`, or `DELETE` keywords. This means:
- `read_neo4j_cypher`: Use for `SHOW USERS/ROLES/PRIVILEGES`, `GRANT MATCH/TRAVERSE/READ`. Returns `[]` on success.
- `write_neo4j_cypher`: Use for `GRANT CREATE`, `GRANT SET PROPERTY`, `REVOKE`, `CREATE ROLE`, `DROP ROLE`. Returns `{"system_updates": N}` on success.
- **Parallel calls by tool**:
  - `mcp__neo4j-neuronet__*` — fire GRANT/REVOKE one at a time; sibling-tool-call errors cascade in that MCP server.
  - `mcp__neuronet__neuronet_cypher` (Neuronet gateway, admin role) — parallel admin writes are fine; verified 2026-05-21 batching 9 GRANTs in one parent message against live Aura. When applying N>3 related GRANTs (e.g. a new mini-app's label set), batch them in a single turn rather than serializing — saves N−1 round-trips to the system DB.
  - `neo4j-cli query -d system --rw` — pass N statements separated by `;` (end-of-line) to commit them; add `--atomic` to run them in one transaction.
- Works (no blocked keywords): `GRANT MATCH/TRAVERSE/READ`, `REVOKE MATCH/TRAVERSE/READ`
- Blocked even for REVOKE: `REVOKE ... DELETE ...`, `REVOKE ... SET PROPERTY ...` — use `neo4j-cli query -d system --rw` instead
- **Not blocked but mutating**: `MERGE`, `REMOVE`, `DROP` — exercise caution; use `neo4j-cli query --rw` for these if safety is required

**GRANT targets roles, not users**: `GRANT ... TO role_name` — check user's roles first with `SHOW USERS WHERE user = 'username'`.

**ASSIGN PRIVILEGE requires admin role**: The `neuronet_writer`/`reader` users cannot GRANT. The MCP connection (user `aevseev`, role `admin`) can.

## `neuronet_cypher` 205-row cap (CRITICAL)

The `neuronet_cypher` MCP tool **silently caps results at ~205 rows per call**, regardless of the `limit` parameter (the schema advertises default 100, max 500 — both lie for any query that returns >205 rows). There is no error; the tool just truncates and returns. Naive `SKIP 500` paging then leaves rows 206–500 silently missing.

**Workaround for datasets >200 rows** — paginate with explicit Cypher `SKIP n` clauses in **200-row batches**:

```cypher
MATCH (n:zzz_gitlab_project) RETURN n
ORDER BY n.ts DESC, n.id ASC   // stable secondary sort — keeps batch boundaries deterministic
SKIP 0  LIMIT 200               // batch 1: rows   1–200
SKIP 200 LIMIT 200              // batch 2: rows 201–400
SKIP 400 LIMIT 200              // batch 3: rows 401–600 ...
```

After merging, **dedupe by primary key** — adjacent batches can overlap if the underlying data shifts mid-pagination.

**Overflow handling**: When a single response is too large for the conversation token budget, the tool **auto-saves it to** `.claude-config/projects/<project>/tool-results/mcp-neuronet-neuronet_cypher-*.txt` with wrapper format `[{"type":"text","text":"<inner JSON>"}]` — parse the inner JSON to get `{records: [...]}`. The underlying result is **still capped at 205**, even when written to the overflow file.

