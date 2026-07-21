# Troubleshooting


## Permission Denied

```cypher
SHOW USER problem_user PRIVILEGES AS COMMANDS;
SHOW USER problem_user PRIVILEGES YIELD access, action, resource WHERE access = 'DENIED' RETURN *;
```

## Locked Out

Use `neo4j-admin server recover` from the server command line to reset admin password.

## Query Monitoring (Aura)

`dbms.listQueries()` is **removed in Neo4j 5.x / Aura**. Use `SHOW TRANSACTIONS` instead — but it only shows currently running transactions, not historical query logs. Historical logs are only available via the Aura Console UI.

## Common Syntax Errors

| Error | Fix |
|-------|-----|
| `expected an identifier or '*'` after `NODES` | Add label: `NODES Employee` or `NODES *` |
| `expected an identifier or '*'` after `RELATIONSHIPS` | Add type: `RELATIONSHIPS HAS_AUDIT` or `RELATIONSHIPS *` |
| `Invalid input 'RETURN'` after `SHOW CONSTRAINTS WHERE` | Must use `SHOW CONSTRAINTS YIELD name, labelsOrTypes WHERE ... RETURN name` — YIELD is required before WHERE/RETURN |
| `Invalid input 'RETURN'` after `SHOW INDEXES WHERE` | Same fix: add `YIELD name, labelsOrTypes, ...` before WHERE |
| `Invalid input 'RETURN'` after `SHOW PRIVILEGES WHERE` | Same fix: `SHOW ROLE x PRIVILEGES YIELD action, access, segment WHERE ...` |

## Zero results? Verify the label before declaring data missing

A query that returns **zero rows may simply be hitting the wrong label** — a stale/legacy label (e.g. `:Plan`) can coexist with the canonical one (e.g. `:JiraPlan`) that actually holds the data. Declaring "the graph data doesn't exist" off a wrong-label query is a misleading blocker call. Before reporting absence:

1. Enumerate the actual labels: `CALL db.labels() YIELD label RETURN label ORDER BY label;`
2. Cross-check the label you queried for renamed/versioned/domain-specific variants (`:JiraPlan` vs `:Plan`, `:SlackChannel` vs `:Channel`, etc.).
3. Re-run against the canonical label before concluding anything.
4. If several labels plausibly match, query each and report counts so the consumer can choose.

Incident: `MATCH (p:Plan)` returned only stale `#program-*` nodes, while the canonical `:JiraPlan` label (from the "Plans Everywhere" ingest) held ~126k `IN_PLAN` edges — a false "no graph data" block that was retracted after a user tip.

## `SHOW PRIVILEGES` gotchas

- **Always filter.** An unfiltered `SHOW PRIVILEGES` (or `WHERE role = 'PUBLIC'` alone) returns thousands of rows on the Neuronet Aura instance (~3.5k+) and easily exceeds the `neuronet_cypher` 82 KB response cap — the tool then auto-spills to a `tool-results/*.txt` overflow file, which costs a follow-up `Read`/`Grep` pass to consume. Scope every audit query to a segment substring or a small action set up front:

  ```cypher
  // GOOD — narrow filter
  SHOW PRIVILEGES YIELD role, action, access, segment
  WHERE role = 'PUBLIC' AND segment CONTAINS 'RoutingBinding'
  RETURN action, access, segment ORDER BY action;
  ```

- **Post-GRANT verification: prefer `CONTAINS` over exact `=`.** Immediately after a GRANT, querying with `WHERE segment = 'NODE(Foo)'` has been observed to return a subset of the actual privileges (only the pre-existing rows, missing the just-granted action). Re-running the same query with `segment CONTAINS 'Foo'` returns the full set. Root cause is most likely Aura leader→follower replication lag on the system DB — admin writes commit on the leader and the immediate read may route to a follower that hasn't replicated yet (see [[neo4j-aura-consistency]]). Use `CONTAINS` as the safe default for verification, and don't burn a turn on `SHOW CURRENT USER` / `SHOW ROLES` debugging if a fresh `=` query looks short — re-issue with `CONTAINS` first.
