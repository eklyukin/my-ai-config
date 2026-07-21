# Bulk Operations Gotchas

Hard-won lessons from deleting 315M relationships on Neo4j Aura (128GB RAM, 1TB storage, business-critical tier).

## Approach Comparison

| Approach | Rate | Notes |
|----------|------|-------|
| MCP `read_neo4j_cypher` | TIMEOUT | Cannot count/scan 300M+ rels |
| Python Bolt per-node loop | ~1,700/s | Network RTT bottleneck (1.4s/query) |
| Python Bolt UNWIND batch | Varies | Works for ~50 nodes; >500K rels per tx = timeout |
| Concurrent Python workers | ~1,700/s | **No benefit** — server-side lock contention |
| Brute-force LIMIT+DELETE | ~1,750/s | Simple, works, slow |
| `CALL {} IN TRANSACTIONS` | Stalls | Initial MATCH scans all rels before batching |
| **APOC `periodic.iterate`** | **~11,600/s** | **Best option** — 7x faster, server-side |

## APOC periodic.iterate

### Pattern

```cypher
CALL apoc.periodic.iterate(
  'MATCH ()-[r:INSTANCE_OF]->() RETURN r',
  'DELETE r',
  {batchSize: 50000, parallel: false, iterateList: true}
) YIELD batches, total, timeTaken, errorMessages
RETURN batches, total, timeTaken, errorMessages
```

### Gotchas

1. **Requires admin user** (`neo4j`). The `neuronet_writer` (publisher role) gets "Failed to obtain connection towards WRITE server" when calling APOC procedures that spawn internal write transactions.

2. **Client timeout after ~20 minutes**. APOC runs server-side but the Python Bolt client's read socket times out. The server continues processing. Solution: auto-retry loop.

3. **Idempotent re-issue**. When the client reconnects and re-issues `periodic.iterate`, it just starts a new scan. Already-deleted rels won't be found, so it naturally picks up where the last run left off.

4. **Monitor with SHOW TRANSACTIONS**. From a separate session:
   ```cypher
   SHOW TRANSACTIONS
   YIELD transactionId, currentQuery, elapsedTime
   WHERE currentQuery CONTAINS 'INSTANCE_OF'
   RETURN transactionId, elapsedTime
   ```

5. **COUNT queries timeout during deletes**. Don't try `MATCH ()-[r:INSTANCE_OF]->() RETURN count(r)` while APOC is running — lock contention causes timeout.

6. **`parallel: false` is safer**. `parallel: true` can cause deadlocks on heavy DELETE operations. Use false for reliability.

## CALL {} IN TRANSACTIONS

### Gotchas

1. **Neo4j 5.23+ syntax**: Use `CALL (var) { ... } IN TRANSACTIONS OF N ROWS` (explicit scope), not the deprecated `CALL { WITH var ... }`.

2. **Stalls on large scans**. The outer MATCH must complete the scan before feeding rows to the batched inner CALL. For 300M+ rels, the initial scan takes 20+ minutes before any deletes start.

3. **Requires implicit transaction**. Python driver must use `session.run()` directly, not inside a manual `session.begin_transaction()`.

## Brute-Force DELETE

```cypher
MATCH ()-[r:INSTANCE_OF]->()
WITH r LIMIT 50000
DELETE r
RETURN count(r) AS deleted
```

### Gotchas

1. **Each batch rescans**. No cursor — every batch starts from scratch. Not a problem since deleted rels won't be found.

2. **Optimal chunk size**: 50K-100K for Aura. Larger = longer transaction hold time. Smaller = more RTT overhead.

3. **Concurrent workers don't help**. Server-side relationship locking serializes parallel DELETE operations. 8 threads ≈ 1 thread in throughput.

## Deduplication Pattern: Verify Structure First

**Always diagnose the duplication pattern before writing the dedup query.**

```cypher
-- Step 1: Check if dups are same pair or many targets
MATCH (m:SourceNode)-[r:REL_TYPE]->(t:TargetNode)
WHERE elementId(m) = $some_id
WITH m, t, count(r) AS cnt
RETURN elementId(t) AS target, cnt
ORDER BY cnt DESC
LIMIT 10
```

If every (source, target) pair has count=1 but the source has many rels, the problem is **fan-out to many targets**, not **duplicate rels to the same target**. This changes the grouping:

- **Same-pair dups**: `WITH m, t, collect(r) AS rels WHERE size(rels) > 1`
- **Fan-out dups**: `WITH m, collect(r) AS rels WHERE size(rels) > 1`

## Throughput Expectations (Aura Business-Critical, 128GB)

| Operation | Throughput |
|-----------|-----------|
| Single-writer DELETE | ~1,700 rels/s |
| APOC iterate DELETE | ~11,600 rels/s |
| MERGE (create or match) | ~2,000-5,000 nodes/s |
| Property SET (batch) | ~10,000-20,000/s |

These are approximate — varies by node/rel size, property count, and index load.
