# Cypher Authoring (Cypher 25)

Rules for **writing** Cypher, as opposed to executing it. Baseline: Neo4j >= 2025.01. Merged from the upstream `neo4j-cypher-skill` on 2026-07-09.

Rules for **writing** Cypher, as opposed to executing it. Baseline: Neo4j ≥ 2025.01. Merged from the upstream `neo4j-cypher-skill`.

## Defaults — apply to every query

1. `CYPHER 25` — first token; never repeat after `UNION` or inside subqueries
2. **Schema first** — inspect before writing (see protocol below); never guess label/property names
3. `MERGE` on a **constrained key only**; relationship `MERGE` only on already-bound endpoints
4. Label-free `MATCH (n)` forbidden unless `n` is already bound or followed by `WHERE n:$($label)`
5. `LIMIT 25` on exploratory reads; push `WITH n LIMIT` *before* high-cardinality ops (var-length traversals, fan-out MATCH, Cartesian products)
6. Comments are `//` — `--` is SQL and invalid
7. Return **named properties**, not full nodes or `RETURN *` (exception: schema/diagnostic queries)
8. `$parameters` always — never string-interpolate literals
9. `DETACH DELETE` — plain `DELETE` throws if the node has relationships
10. `(a)-[:R]-(b)` undirected matches both directions and double-counts; use directed unless truly unknown

## Style

| Element | Convention |
|---|---|
| Node labels | PascalCase `:Person` |
| Rel types | SCREAMING_SNAKE_CASE `:KNOWS` |
| Properties / vars | camelCase `firstName` |
| Clauses | UPPERCASE `MATCH` |
| Booleans / null | lowercase `true false null` |
| Strings | single-quoted (double only if it contains `'`) |

> Schema is truth. `:Person`, `:KNOWS`, `name` in any example are illustrative — substitute real names.

## Schema-First Protocol

**Priority order:**
1. `<db-name>-schema.json` in the project → read directly, skip live inspection. Full rules: [schema-guardrail.md](schema-guardrail.md).
2. Schema already in context → use it.
3. Otherwise inspect live — with `neo4j-cli` the built-in beats raw Cypher:

```bash
neo4j-cli query --credential default :schema --format toon   # labels, rel types, indexes, constraints
```

```cypher
-- Property types per label — prefer APOC
CALL apoc.meta.schema() YIELD value RETURN value;

-- No APOC and DB ≤ 100k nodes/rels only (expensive on large graphs)
CALL db.schema.nodeTypeProperties() YIELD nodeType, propertyName, propertyTypes, mandatory;
```

**Helper scripts** (in `scripts/`): `generate_schema.py` (live DB + APOC) · `define_schema.py` (no DB) · `import_neo4j_schema.py` (converts neo4j-graphrag / graph-schema-introspector output).

Validate before returning any query: label exists · rel type + direction correct · property belongs to that label · index `ONLINE`.

> ⚠️ On the Neuronet instance (~1B nodes) `db.schema.nodeTypeProperties()` and unfiltered `CALL db.labels()` + per-label counts are **very expensive**. Use `:schema`, `apoc.meta.schema()`, or sample with `MATCH (n:Label) RETURN n LIMIT 1`.

## Subqueries — cheat sheet

```
EXISTS  { (a)-[:R]->(b) }                        // boolean check
COUNT   { (a)-[:R]->(b) WHERE a.x > 0 }          // count
COLLECT { MATCH (a)-[:R]->(b) RETURN b.name }    // list (full MATCH+RETURN required, exactly one column)
CALL (p) { MATCH (p)-[:ACTED_IN]->(m) RETURN m } // correlated subquery (explicit import)
OPTIONAL CALL (p) { ... }                        // nullable subquery
```

`CALL { WITH x ... }` is deprecated → `CALL (x) { ... }`. Chained `OPTIONAL MATCH` for nested data → replace with `COLLECT { MATCH ... RETURN }`.

**Aggregation**: non-aggregating expressions in `RETURN`/`WITH` are implicit grouping keys — no `GROUP BY`. `count(n)` skips nulls, `count(*)` counts rows. `count()` is faster than `size(collect())`.

**`WITH` scope**: every variable not listed in `WITH` is dropped. `WITH *` carries all forward.

## Top Syntax Traps

| Wrong | Right |
|---|---|
| `-- comment` | `// comment` |
| `id(n)` | `elementId(n)` |
| `[:REL*1..5]` | `(()-[:REL]->()){1,5}` |
| `shortestPath((a)-[*]->(b))` | `SHORTEST 1 (a)(()-[]->()){1,}(b)` |
| `CALL { WITH x ... }` | `CALL (x) { ... }` |
| `SET n = {k:v}` (partial update) | `SET n += {k:v}` |
| `DELETE n` with relationships | `DETACH DELETE n` |
| `WHERE n.x = null` | `WHERE n.x IS NULL` |
| `toInteger(null)` throws | `toIntegerOrNull(null)` |
| `UNWIND list AS x WHERE x>5` | `UNWIND list AS x WITH x WHERE x>5` |
| `count(r WHERE r.x=5)` | `sum(CASE WHEN r.x=5 THEN 1 ELSE 0 END)` |
| `n.$key` dynamic property | `n[$key]` |
| `SET n:$label` | `SET n:$($label)` |
| ISO string with `Z` treated as UTC | **`Z` ≠ UTC in Neo4j** — it's an offset, indexed differently. Coerce: `datetime({datetime: datetime($iso), timezone: 'UTC'})` |
| `duration.inDays` | `duration.days` |

Full 40+ table → [syntax-traps.md](syntax-traps.md)

## Performance

EXPLAIN/PROFILE red flags: `AllNodesScan` · `CartesianProduct` · `NodeByLabelScan` · `Eager`

**Fix `Eager`** (simplest that works): (1) add specific labels to MATCH nodes to remove read/write ambiguity; (2) `WITH collect(x) AS xs UNWIND xs AS x` before writing; (3) `CALL () { ... } IN TRANSACTIONS`.

**Index anchors** — an index only activates when the node has a **label**: `MATCH (n {p:$v})` never uses one, `MATCH (n:Label {p:$v})` does. `CONTAINS`/`ENDS WITH` need a TEXT index (RANGE doesn't support them). `MERGE` without a constraint has **no atomicity guarantee** (concurrent MERGEs can duplicate). Force a plan with `USING INDEX n:Label(prop)`.

Full anti-patterns → [performance.md](performance.md) · index types → [indexes.md](indexes.md)

## Version Gates

Default to the 2025.01-safe set when the version is unknown.

| Feature | Min version | Fallback |
|---|---|---|
| `CYPHER 25`, QPEs, `CALL (x) {}`, match modes, dynamic labels | 2025.01 | require 2025+ |
| `CONCURRENT TRANSACTIONS`, `REPORT STATUS` | 2025.01 | omit |
| Conditional `CALL` (`WHEN`/`THEN`/`ELSE`) | 2025.06 | branch app-side |
| `SEARCH` clause (vector/fulltext) | 2026.01 | `CALL db.index.vector.queryNodes(...)` (deprecated 2026.04) |
| `ACYCLIC` path mode | 2026.03 | post-filter distinct nodes |
| `string.indexOf/join/regexReplace()` | 2026.05 | `apoc.text.*` |
| **GRAPH TYPE** schema DDL | 2026.02 (PREVIEW) | individual `CREATE CONSTRAINT`/`INDEX` |

## Validation workflow

1. `EXPLAIN` before any write — catches syntax errors and missing indexes (`neo4j-cli` runs this automatically as the `--rw` preflight)
2. New read → test with `LIMIT 1` first
3. Write → verify the read half as `RETURN` before swapping in `SET`/`CREATE`/`DELETE`
4. `PROFILE` to measure db hits; resolve the red flags above

## Failure Recovery

- **0 results** → check param types; remove `WHERE` predicates one by one; `EXPLAIN` for index use; **verify the label exists** (see "Zero results?" in Troubleshooting)
- **TypeError** → `toIntegerOrNull()` / `toFloatOrNull()`; guard with `IS NOT NULL`
- **Variable out of scope** → not carried in `WITH`; use `count(*)` not `count(droppedVar)`
- **Timeout** → fix `AllNodesScan` → add early `LIMIT` → `CALL () {...} IN TRANSACTIONS OF 1000 ROWS`
- **`Cannot merge node using null property value`** → MERGE key resolved to null; validate params first
- **`IndexNotFoundError`** → `SHOW INDEXES YIELD name, state WHERE state <> 'ONLINE'`
- **DateTime mismatch** → `ZONED DATETIME >= date(...)` returns 0 rows; use `datetime()` or a `.year` accessor

## Authoring checklist

- [ ] Schema inspected or confirmed in context
- [ ] `CYPHER 25` prefix on every top-level query
- [ ] `$parameters` used (not literals)
- [ ] `LIMIT` on exploratory reads
- [ ] `EXPLAIN` run; red flags resolved
- [ ] Write half verified as `RETURN` before executing
- [ ] `MERGE` on a constrained key only
- [ ] No label-free `MATCH (n)`
- [ ] Named properties returned, not whole nodes

## Cypher docs (WebFetch)

| Need | URL |
|---|---|
| Clause semantics | `https://neo4j.com/docs/cypher-manual/25/clauses/{clause}/` |
| Function signatures | `https://neo4j.com/docs/cypher-manual/25/functions/{type}/` |
| QPE / paths | `https://neo4j.com/docs/cypher-manual/25/patterns/` |
| Index/constraint reference | `https://neo4j.com/docs/cypher-manual/25/indexes/` |
| Full cheat sheet | `https://neo4j.com/docs/cypher-cheat-sheet/25/all/` |

