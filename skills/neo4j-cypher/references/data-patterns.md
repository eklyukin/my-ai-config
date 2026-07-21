# Data & Query Patterns

Neuronet-specific data shapes and Cypher patterns: Fivetran-loaded nodes, fulltext index search, and null-safe type casting.

## Fivetran-Loaded Data Patterns

Nodes with `zzz_` prefix (e.g., `zzz_zip_request`) are synced via Fivetran:

- **No relationships** — Fivetran loads flat tables as standalone nodes. Use property-based joins instead.
- **Property naming** — Properties prefixed with label name: `zzz_zip_request_amount_usd` (not `amount_usd`)
- **Epoch timestamps** — Date fields are Unix epoch seconds: `datetime({epochSeconds: toInteger(n.prop)})`
- **Numeric status codes** — Status fields are integers (3=Completed, 4=Canceled), not strings
- **Always sample first** — `MATCH (n:zzz_zip_request) RETURN n LIMIT 1` to discover actual property names

```cypher
// Property-based join (no relationships exist)
MATCH (r:zzz_zip_request), (d:zzz_zip_department)
WHERE r.zzz_zip_request_department_id = d.zzz_zip_department_id
RETURN r, d LIMIT 10
```

## Fulltext Index Search

For text search across large node sets, use fulltext indexes instead of `CONTAINS` (which requires full scans). Fulltext indexes use Lucene and are orders of magnitude faster.

```cypher
// List available fulltext indexes
SHOW INDEXES WHERE type = 'FULLTEXT'

// Search a fulltext index (returns nodes + score)
CALL db.index.fulltext.queryNodes('workitem_body_fulltext', 'OTEL_EXPORTER')
YIELD node, score
RETURN node.key, node.summary, score
ORDER BY score DESC LIMIT 20

// Combine with property filters
CALL db.index.fulltext.queryNodes('workflow_body_fulltext', 'opentelemetry')
YIELD node, score
WHERE node.status = 'active'
RETURN node.name, score

// Exact phrase search (use quotes)
CALL db.index.fulltext.queryNodes('workitem_body_fulltext', '"OTEL_EXPORTER_OTLP_ENDPOINT"')
YIELD node, score
RETURN node.key, node.summary, score
```

**Key indexes in neuronet** (check with `SHOW INDEXES`):
- `workitem_body_fulltext` — Jira WorkItem body text
- `workflow_body_fulltext` — n8n Workflow JSON bodies

**When to use which**:
- `CONTAINS` — small result sets, exact substring, no fulltext index available
- Fulltext index — large node sets (10K+), keyword search, ranked results


## Safe Type Casting

`date()`, `datetime()`, `toFloat()`, `toInteger()` throw on empty strings. Always guard:

```cypher
-- BAD: throws on null or empty
account.start_date = date(row.start_date)

-- GOOD: null-safe
account.start_date = CASE WHEN row.start_date IS NOT NULL AND row.start_date <> ''
                          THEN date(row.start_date) ELSE null END
```


## Useful Cypher Patterns

**Deduplicate OPTIONAL MATCH results** — prevent multiple rows from creating duplicate relationships:
```cypher
// BAD: if multiple employees share a name, creates duplicate rels
OPTIONAL MATCH (emp:Employee) WHERE toLower(emp.full_name) = $name
WITH cs, emp ...

// GOOD: head(collect()) collapses to single row
OPTIONAL MATCH (emp:Employee) WHERE toLower(emp.full_name) = $name
WITH cs, head(collect(emp)) AS emp ...
```

**Diacritics-safe name comparison** — use `apoc.text.clean()` (strips diacritics + non-alphanumeric, lowercases):
```cypher
// BAD: 'garcía' != 'garcia'
WHERE toLower(c.last_name) IN $variants

// GOOD: 'García' → 'garcia' via apoc
WHERE apoc.text.clean(c.last_name) IN $variants
```
Note: `apoc.text.clean()` also strips hyphens/spaces, so Python-side variants must include alphanumeric-only forms too.
