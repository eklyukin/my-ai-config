---
name: neo4j-aura-api
description: "Manage Neo4j Aura cloud databases via API. Use to create/list/pause/resume Aura instances or manage snapshots/backups via the Aura v1 API."
---

# Neo4j Aura API Management

This skill provides programmatic access to Neo4j Aura cloud database management through the v1 REST API.

## Prerequisites

### Authentication (OAuth2 Client Credentials)

The Aura API uses OAuth2 client credentials flow — NOT a static token.

**Step 1: Create API credentials** in [Aura Console](https://console.neo4j.io) → Account Settings → API Keys → Create. Save both values (secret shown only once).

**Step 2: Set environment variables:**
```bash
export NEO4J_AURA_CLIENT_ID="your-client-id"
export NEO4J_AURA_CLIENT_SECRET="your-client-secret"
```

**Step 3 (optional): Store in GCP Secret Manager:**
```bash
# Create secrets
echo -n "your-client-id" | gcloud secrets create claude_mcp_neo4j_aura_client_id \
  --data-file=- --project=xsolla-n8n-prod
echo -n "your-client-secret" | gcloud secrets create claude_mcp_neo4j_aura_client_secret \
  --data-file=- --project=xsolla-n8n-prod

# Fetch for local use
export NEO4J_AURA_CLIENT_ID=$(gcloud secrets versions access latest \
  --secret=claude_mcp_neo4j_aura_client_id --project=xsolla-n8n-prod)
export NEO4J_AURA_CLIENT_SECRET=$(gcloud secrets versions access latest \
  --secret=claude_mcp_neo4j_aura_client_secret --project=xsolla-n8n-prod)
```

**Auth flow** (handled automatically by `aura_api.py`):
```
POST https://api.neo4j.io/oauth/token
Authorization: Basic base64(client_id:client_secret)
Content-Type: application/x-www-form-urlencoded
Body: grant_type=client_credentials
→ Returns: access_token (valid 1 hour)
```

## Quick Start

> **Note**: The `aura_api.py` script lives in this skill's `scripts/` directory.
> When invoked from a project directory, use the full path:
> `python <skill-dir>/scripts/aura_api.py <command>`
> Or use the curl Quick Reference below for common operations.

**List all instances:**
```bash
python scripts/aura_api.py list
```

**Get instance details:**
```bash
python scripts/aura_api.py get <instance-id>
```

**Create backup (snapshot):**
```bash
python scripts/aura_api.py snapshot <instance-id> --wait
```

## Quick Reference (curl)

When using this skill from a project directory (not the skill directory), use these curl commands directly:

**Authenticate:**
```bash
# Fetch credentials from GCP Secret Manager
export NEO4J_AURA_CLIENT_ID=$(gcloud secrets versions access latest \
  --secret=claude_mcp_neo4j_aura_client_id --project=xsolla-n8n-prod)
export NEO4J_AURA_CLIENT_SECRET=$(gcloud secrets versions access latest \
  --secret=claude_mcp_neo4j_aura_client_secret --project=xsolla-n8n-prod)

# Get Bearer token
AURA_TOKEN=$(curl -s -X POST https://api.neo4j.io/oauth/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${NEO4J_AURA_CLIENT_ID}:${NEO4J_AURA_CLIENT_SECRET}" \
  -d "grant_type=client_credentials" | jq -r '.access_token')
```

**Check instance status:**
```bash
curl -s https://api.neo4j.io/v1/instances/<instance-id> \
  -H "Authorization: Bearer $AURA_TOKEN" | jq .
```

**List all instances:**
```bash
curl -s https://api.neo4j.io/v1/instances \
  -H "Authorization: Bearer $AURA_TOKEN" | jq '.data[] | {id, name, status}'
```

**Pause / Resume:**
```bash
# Pause
curl -s -X POST https://api.neo4j.io/v1/instances/<instance-id>/pause \
  -H "Authorization: Bearer $AURA_TOKEN" \
  -H "Content-Type: application/json" -d '{}'

# Resume
curl -s -X POST https://api.neo4j.io/v1/instances/<instance-id>/resume \
  -H "Authorization: Bearer $AURA_TOKEN" \
  -H "Content-Type: application/json" -d '{}'
```

**Create snapshot:**
```bash
curl -s -X POST https://api.neo4j.io/v1/instances/<instance-id>/snapshots \
  -H "Authorization: Bearer $AURA_TOKEN" \
  -H "Content-Type: application/json" -d '{}'
```

## Common Operations

### Instance Management

**Create new instance:**
```bash
python scripts/aura_api.py create \
  --name "production-db" \
  --region "us-central1" \
  --memory "8GB" \
  --tenant-id "<your-tenant-id>"
```

**Pause instance (save costs):**
```bash
python scripts/aura_api.py pause <instance-id>
```

**Resume paused instance:**
```bash
python scripts/aura_api.py resume <instance-id>
```

### Backup & Restore

**List all snapshots:**
```bash
python scripts/aura_api.py snapshots <instance-id>
```

**Create on-demand backup:**
```bash
python scripts/aura_api.py snapshot <instance-id>
```

**Wait for backup completion:**
```bash
python scripts/aura_api.py snapshot <instance-id> --wait
```

**Restore from snapshot:**
```bash
python scripts/aura_api.py restore <instance-id> <snapshot-id>
```

### Cross-Instance Copy / Overwrite ("Clone to existing")

> **The v1 API DOES support cross-instance copy** via the `overwrite` endpoint —
> it is the programmatic equivalent of the Aura Console's "Clone to existing"
> action. (Earlier versions of this skill incorrectly claimed cloning was
> console-only; that is wrong.) Use this to copy one instance's data into a
> **different, already-existing** instance — e.g. a weekly Prod→Test refresh.

**Endpoint:**
```
POST /v1/instances/{destInstanceId}/overwrite
Body: { "source_instance_id": "<src>", "source_snapshot_id": "<snap>" }
```

- `source_snapshot_id` is **optional**. Omit it and Aura **takes a fresh snapshot
  of the source automatically, then overwrites the destination** — so a full
  sync is a single idempotent call, no snapshot bookkeeping required.
- The destination's **connection URI and credentials are preserved** — clients
  pointed at the destination keep working across refreshes.
- This is **destructive on the destination** and runs **without confirmation**.
  Only ever target a scratch/test instance.

**Preconditions:**
- Destination instance must be **running** (resume it first if paused).
- Destination **storage must be ≥ the source's actual store size** (not just the
  source's provisioned limit). Check `neo4j_database_store_size_database` on the
  source via the metrics endpoint before sizing the destination.
- The source snapshot must be **exportable** (full, not differential). On-demand
  snapshots — including the one auto-taken when `source_snapshot_id` is omitted —
  are full/exportable. If you pass an explicit snapshot and get
  `Source snapshot ... is not exportable`, pick a full one.

**One-shot copy (latest data, auto-snapshot):**
```bash
python scripts/aura_api.py overwrite <dest-instance-id> --source-instance-id <src-instance-id>
```

**Copy from a specific historical snapshot:**
```bash
python scripts/aura_api.py overwrite <dest-instance-id> \
  --source-instance-id <src-instance-id> --source-snapshot-id <snap-id>
```

**curl:**
```bash
curl -s -X POST https://api.neo4j.io/v1/instances/<dest-instance-id>/overwrite \
  -H "Authorization: Bearer $AURA_TOKEN" -H "Content-Type: application/json" \
  -d '{"source_instance_id":"<src-instance-id>"}'
```

Poll `GET /v1/instances/<dest-instance-id>` until `status` returns to `running`;
the overwrite is complete then (it transits `overwriting` / `loading` first).

> ⚠️ **`overwrite` copies DATA ONLY** — *not* indexes/constraints — **and it resets
> the destination's in-DB auth** (destination-specific users are deleted). Verified
> live 2026-06-13. The Aura console clone/overwrite/restore docs describe the op
> purely as a *data* copy and never mention schema. Any sync built on `overwrite`
> MUST, once the dest is back to `running`, (1) recreate + re-grant its app user(s)
> and (2) replay the schema DDL. See **Gotchas #7–#12** below.

### Automated Prod→Test Sync (weekly refresh recipe)

Maintain a long-lived, prod-representative scratch instance (e.g. for profiling
candidate queries off the prod leader) by overwriting it from prod on a schedule.
This is one management-API call per run:

```bash
#!/usr/bin/env bash
set -euo pipefail
SRC_ID="6237b468"          # prod
DEST_ID="05010ab9"         # scratch / test
export NEO4J_AURA_CLIENT_ID=$(gcloud secrets versions access latest \
  --secret=claude_mcp_neo4j_aura_client_id --project=xsolla-n8n-prod)
export NEO4J_AURA_CLIENT_SECRET=$(gcloud secrets versions access latest \
  --secret=claude_mcp_neo4j_aura_client_secret --project=xsolla-n8n-prod)

# Ensure destination is running, then overwrite from prod's latest data.
python scripts/aura_api.py resume "$DEST_ID" || true
python scripts/aura_api.py overwrite "$DEST_ID" --source-instance-id "$SRC_ID"

# Poll until the destination returns to 'running'.
for _ in $(seq 1 120); do
  st=$(python scripts/aura_api.py get "$DEST_ID" | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['status'])")
  echo "status: $st"; [ "$st" = "running" ] && break; sleep 30
done
```

Deploy as a weekly Cloud Run job (see the `neuronet-cron` / `gcloud` skills). The
job's service account needs read access to the two `claude_mcp_neo4j_aura_client_*`
secrets. **The destination storage tier must already fit the source** — overwrite
cannot grow the destination.

## API Integration Patterns

### Using as Python Module

```python
import sys
sys.path.append('scripts')
from aura_api import (
    list_instances,
    create_snapshot,
    wait_for_snapshot,
    restore_snapshot
)

# List instances
instances = list_instances()
for instance in instances.get("data", []):
    print(f"Instance: {instance['name']} ({instance['id']})")

# Create backup and wait
result = create_snapshot(instance_id)
snapshot_id = result["data"]["snapshot_id"]

if wait_for_snapshot(instance_id, snapshot_id, timeout=600):
    print("Backup completed successfully")
```

### Async Operations Handling

Snapshot creation and restoration are **asynchronous**:

```python
# 1. Start operation
response = create_snapshot(instance_id)
snapshot_id = response["data"]["snapshot_id"]

# 2. Poll for completion
import time
while True:
    snapshot = get_snapshot(instance_id, snapshot_id)
    status = snapshot["data"]["status"]

    if status == "completed":
        break
    elif status == "failed":
        raise Exception(f"Snapshot failed: {snapshot}")

    time.sleep(10)
```

## Error Handling

**Common errors:**

- **401 Unauthorized:** Check `NEO4J_AURA_CLIENT_ID` and `NEO4J_AURA_CLIENT_SECRET` are set correctly
- **404 Not Found:** Verify instance ID exists
- **409 Conflict:** Instance is busy with another operation (wait and retry)
- **429 Rate Limited:** Wait period specified in `Retry-After` header

**Retry pattern:**
```python
import time
from urllib.error import HTTPError

def retry_request(func, max_retries=3):
    for attempt in range(max_retries):
        try:
            return func()
        except HTTPError as e:
            if e.code == 429:
                retry_after = int(e.headers.get('Retry-After', 5))
                time.sleep(retry_after)
            elif e.code >= 500:
                time.sleep(2 ** attempt)  # Exponential backoff
            else:
                raise
    raise Exception("Max retries exceeded")
```

## Reference Documentation

For detailed API specifications, see [api-endpoints.md](references/api-endpoints.md):

- Complete endpoint reference
- Request/response schemas
- Error codes and meanings
- Rate limit details
- Best practices

## Metrics & Monitoring (Datadog Integration)

Neo4j Aura exposes Prometheus-compatible metrics via a customer metrics API. This is used by Datadog for monitoring.

### Metrics Endpoint

```
https://customer-metrics-api.neo4j.io/api/v1/<tenant-id>/<instance-id>/metrics
```

**Known instances:**

| Instance | ID | Tenant ID | Metrics URL |
|---|---|---|---|
| Xsolla NeuroNet | `6237b468` | `d32bdc2c-9921-4be7-9541-166d0dff4ccf` | `https://customer-metrics-api.neo4j.io/api/v1/d32bdc2c-9921-4be7-9541-166d0dff4ccf/6237b468/metrics` |
| Xsolla NeuroNet AI Sandbox | `05010ab9` | `d32bdc2c-9921-4be7-9541-166d0dff4ccf` | `https://customer-metrics-api.neo4j.io/api/v1/d32bdc2c-9921-4be7-9541-166d0dff4ccf/05010ab9/metrics` |
| Xsolla Game Database | `12c0ec88` | `d32bdc2c-9921-4be7-9541-166d0dff4ccf` | `https://customer-metrics-api.neo4j.io/api/v1/d32bdc2c-9921-4be7-9541-166d0dff4ccf/12c0ec88/metrics` |

### Authentication for Metrics

The metrics endpoint uses a **separate** OAuth2 client credential (different from the management API).

**GCP Secrets (project: `xsolla-n8n-prod`):**
- `claude_mcp_neo4j_aura_datadog_client_id` — OAuth2 client ID for Datadog/metrics
- `claude_mcp_neo4j_aura_datadog_client_secret` — OAuth2 client secret for Datadog/metrics

**Fetch metrics with curl:**
```bash
# Get credentials
METRICS_CLIENT_ID=$(gcloud secrets versions access latest \
  --secret=claude_mcp_neo4j_aura_datadog_client_id --project=xsolla-n8n-prod)
METRICS_CLIENT_SECRET=$(gcloud secrets versions access latest \
  --secret=claude_mcp_neo4j_aura_datadog_client_secret --project=xsolla-n8n-prod)

# Authenticate
METRICS_TOKEN=$(curl -s -X POST https://api.neo4j.io/oauth/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${METRICS_CLIENT_ID}:${METRICS_CLIENT_SECRET}" \
  -d "grant_type=client_credentials" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

# Fetch metrics (Prometheus format)
curl -s "https://customer-metrics-api.neo4j.io/api/v1/d32bdc2c-9921-4be7-9541-166d0dff4ccf/6237b468/metrics" \
  -H "Authorization: Bearer $METRICS_TOKEN"
```

### Datadog Configuration

Datadog OpenMetrics check config for Neo4j Aura:

```yaml
init_config:

instances:
  - openmetrics_endpoint: https://customer-metrics-api.neo4j.io/api/v1/d32bdc2c-9921-4be7-9541-166d0dff4ccf/6237b468/metrics
    namespace: neo4j_aura
    timeout: 30
    metrics:
      - neo4j_.*
    auth_token:
      reader:
        type: oauth
        url: https://api.neo4j.io/oauth/token
        client_id: "ENC[GCP:claude_mcp_neo4j_aura_datadog_client_id]"
        client_secret: "ENC[GCP:claude_mcp_neo4j_aura_datadog_client_secret]"
        basic_auth: true
      writer:
        type: header
        name: Authorization
        value: "Bearer <TOKEN>"
```

### Key Metrics

**Storage (use for health checks):**
- `neo4j_database_store_size_database` — actual database disk usage in bytes
- `neo4j_aura_storage_limit` — provisioned storage limit in bytes (use for % calculation instead of hardcoding)

**Aura platform metrics:**
- `neo4j_aura_cpu_usage` / `neo4j_aura_cpu_limit` — CPU utilization vs provisioned limit
- `neo4j_aura_out_of_memory_errors_total` — OOM error count (should be 0)

**Bolt connections:**
- `neo4j_dbms_bolt_connections_running` — active Bolt connections
- `neo4j_dbms_bolt_connections_idle` — idle Bolt connections
- `neo4j_dbms_bolt_connections_opened_total` / `neo4j_dbms_bolt_connections_closed_total` — connection lifecycle counters

**Query performance:**
- `neo4j_db_query_execution_success_total` / `neo4j_db_query_execution_failure_total` — query counts
- `neo4j_db_query_execution_internal_latency_q50` / `q75` / `q99` — latency percentiles

**Page cache:**
- `neo4j_dbms_page_cache_hit_ratio_per_minute` — cache hit ratio (closer to 1.0 = better)
- `neo4j_dbms_page_cache_usage_ratio` — how full the page cache is
- `neo4j_dbms_page_cache_evictions_total` — eviction count

**JVM / GC:**
- `neo4j_dbms_vm_heap_used_ratio` — JVM heap usage ratio
- `neo4j_dbms_vm_gc_time_g1_young_generation_total` / `g1_old_generation_total` — GC time

**Database counters:**
- `neo4j_database_count_node` / `neo4j_database_count_relationship` — graph size
- `neo4j_database_transaction_committed_total` / `rollbacks_total` — transaction stats
- `neo4j_database_transaction_active_read` / `active_write` — concurrent transactions

> **Note:** Metric names use `neo4j_dbms_*` prefix for instance-level metrics (bolt, page cache, VM) and `neo4j_database_*` for database-level metrics. The old prefixes like `neo4j_bolt_*`, `neo4j_page_cache_*`, `neo4j_vm_memory_*` do NOT exist on the customer metrics API.

### Prometheus Line Format (CRITICAL for parsing)

The metrics endpoint returns data in **Prometheus exposition format** with a trailing timestamp:
```
metric_name{labels} value unix_timestamp
```
Example: `neo4j_database_store_size_database{aggregation="MAX",database="neo4j",instance_id="6237b468"} 400301189576.000000 1772341245330`

**CRITICAL: Do NOT use `awk '{print $2}'` in recipes** — the `$2` gets swallowed by shell/template interpolation when this SKILL.md is loaded as LLM prompt context (which is the primary use case for cron jobs and skill invocations). The `$(NF-1)` alternative has the same problem. **Always use the Python-based parsing approach below**, which saves metrics to a temp file and parses entirely within Python, immune to all `$` interpolation issues.

### Storage Health Check Recipe

**Quick storage-only check (Python-based, interpolation-safe):**
```bash
# Fetch metrics to temp file (avoids all shell $-interpolation issues)
curl -s "$METRICS_URL" -H "Authorization: Bearer $METRICS_TOKEN" > /tmp/neo4j_metrics.txt

python3 << 'PYEOF'
def get_metric(name):
    with open('/tmp/neo4j_metrics.txt') as f:
        for line in f:
            if line.startswith(name + '{') or line.startswith(name + ' '):
                parts = line.split()
                if len(parts) >= 3:
                    return float(parts[-2])
                elif len(parts) == 2:
                    return float(parts[-1])
    return None

used = get_metric('neo4j_database_store_size_database')
limit = get_metric('neo4j_aura_storage_limit')
if used is not None and limit is not None:
    gb = used / (1024**3)
    limit_gb = limit / (1024**3)
    pct = (used / limit) * 100
    print(f'Storage: {gb:.1f} GB / {limit_gb:.0f} GB ({pct:.1f}%)')
    if pct > 80: print('STATUS: WARNING')
    elif pct > 60: print('STATUS: ATTENTION')
    else: print('STATUS: HEALTHY')
else:
    print(f'ERROR: Could not parse metrics (store_size={used}, limit={limit})')
PYEOF
```

### Comprehensive Health Check Recipe

For automated daily health checks, fetch all key metrics in a single call.

**IMPORTANT:** This recipe uses a Python heredoc (`<< 'PYEOF'`) to parse metrics from a temp file. This approach is immune to `$` interpolation issues that break `awk`-based recipes when this SKILL.md is loaded as prompt context.

```bash
# Fetch metrics once, save to temp file
curl -s "$METRICS_URL" -H "Authorization: Bearer $METRICS_TOKEN" > /tmp/neo4j_metrics.txt

python3 << 'PYEOF'
import math
from datetime import datetime, timezone

def get_metric(name):
    """Extract metric value from Prometheus exposition format."""
    with open('/tmp/neo4j_metrics.txt') as f:
        for line in f:
            if line.startswith(name + '{') or line.startswith(name + ' '):
                parts = line.split()
                if len(parts) >= 3:
                    return float(parts[-2])  # value is second field, timestamp is last
                elif len(parts) == 2:
                    return float(parts[-1])
    return None

store_size = get_metric('neo4j_database_store_size_database')
storage_limit = get_metric('neo4j_aura_storage_limit')
cpu_usage = get_metric('neo4j_aura_cpu_usage')
cpu_limit = get_metric('neo4j_aura_cpu_limit')
heap_ratio = get_metric('neo4j_dbms_vm_heap_used_ratio')
oom_errors = get_metric('neo4j_aura_out_of_memory_errors_total')
bolt_running = get_metric('neo4j_dbms_bolt_connections_running')
bolt_idle = get_metric('neo4j_dbms_bolt_connections_idle')
cache_hit = get_metric('neo4j_dbms_page_cache_hit_ratio_per_minute')
node_count = get_metric('neo4j_database_count_node')
rel_count = get_metric('neo4j_database_count_relationship')
q50 = get_metric('neo4j_db_query_execution_internal_latency_q50')
q99 = get_metric('neo4j_db_query_execution_internal_latency_q99')

if cache_hit is None or str(cache_hit) == 'nan':
    cache_hit = 0.0

issues = []
rows = []

# Replace INSTANCE_NAME and INSTANCE_ID below with actual values when using
now = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')
print(f'## Neo4j Aura Daily Health Report — {now}')
print()
print(f'**Instance:** INSTANCE_NAME (`INSTANCE_ID`)')
print()

# Storage
if store_size is not None and storage_limit is not None:
    store_gb = store_size / (1024**3)
    limit_gb = storage_limit / (1024**3)
    store_pct = (store_size / storage_limit) * 100
    status = "WARNING" if store_pct > 80 else "ATTENTION" if store_pct >= 60 else "HEALTHY"
    rows.append(('**Storage**', f'{store_gb:.1f} GB / {limit_gb:.0f} GB ({store_pct:.1f}%)', status))
    if store_pct > 80: issues.append('Storage above 80%')
    elif store_pct >= 60: issues.append('Storage above 60% (attention)')
else:
    issues.append('Storage metrics unavailable (parse error)')
    rows.append(('**Storage**', 'PARSE ERROR', 'ERROR'))

# CPU
if cpu_usage is not None and cpu_limit is not None:
    cpu_pct = (cpu_usage / cpu_limit) * 100
    status = "WARNING" if cpu_pct > 90 else "ATTENTION" if cpu_pct >= 70 else "HEALTHY"
    rows.append(('**CPU**', f'{cpu_usage:.2f} / {cpu_limit:.2f} cores ({cpu_pct:.1f}%)', status))
    if cpu_pct > 90: issues.append('CPU above 90%')
    elif cpu_pct >= 70: issues.append('CPU above 70% (attention)')
else:
    issues.append('CPU metrics unavailable')
    rows.append(('**CPU**', 'UNAVAILABLE', 'ERROR'))

# Heap
if heap_ratio is not None:
    status = "WARNING" if heap_ratio > 0.85 else "ATTENTION" if heap_ratio >= 0.70 else "HEALTHY"
    rows.append(('**Heap**', f'{heap_ratio:.2%}', status))
    if heap_ratio > 0.85: issues.append('Heap above 85%')
    elif heap_ratio >= 0.70: issues.append('Heap above 70% (attention)')
else:
    issues.append('Heap metrics unavailable')
    rows.append(('**Heap**', 'UNAVAILABLE', 'ERROR'))

# OOM
if oom_errors is not None:
    status = "WARNING" if oom_errors > 0 else "HEALTHY"
    rows.append(('**OOM Errors**', f'{int(oom_errors)}', status))
    if oom_errors > 0: issues.append(f'{int(oom_errors)} OOM errors')
else:
    issues.append('OOM error metrics unavailable')
    rows.append(('**OOM Errors**', 'UNAVAILABLE', 'ERROR'))

# Bolt
if bolt_running is not None and bolt_idle is not None:
    rows.append(('**Bolt Connections**', f'{int(bolt_running)} running, {int(bolt_idle)} idle', 'OK'))

# Page cache
cache_status = "GOOD" if cache_hit > 0.90 else "OK" if cache_hit >= 0.70 else "POOR"
rows.append(('**Page Cache Hit Ratio**', f'{cache_hit:.2%}', cache_status))
if cache_status == "POOR": issues.append('Page cache hit ratio below 70% (poor)')

# Graph size
if node_count is not None and rel_count is not None:
    rows.append(('**Graph Size**', f'{int(node_count):,} nodes / {int(rel_count):,} relationships', '\u2014'))

# Query latency
if q50 is not None:
    if math.isnan(q50):
        rows.append(('**Query Latency p50**', 'N/A', 'UNAVAILABLE'))
    else:
        if q50 < 100:
            q50_status = 'HEALTHY'
        elif q50 <= 500:
            q50_status = 'ATTENTION'
            issues.append('Query latency p50 elevated (100-500ms)')
        else:
            q50_status = 'WARNING'
            issues.append('Query latency p50 > 500ms')
        rows.append(('**Query Latency p50**', f'{q50:.0f} ms', q50_status))
if q99 is not None:
    if math.isnan(q99):
        rows.append(('**Query Latency p99**', 'N/A', 'UNAVAILABLE'))
    else:
        if q99 < 10000:
            q99_status = 'HEALTHY'
        elif q99 <= 30000:
            q99_status = 'ATTENTION'
            issues.append('Query latency p99 elevated (10-30s)')
        else:
            q99_status = 'WARNING'
            issues.append('Query latency p99 > 30s')
        rows.append(('**Query Latency p99**', f'{q99:,.0f} ms', q99_status))

# Print markdown table
print('| Metric | Value | Status |')
print('|---|---|---|')
for metric, value, status in rows:
    print(f'| {metric} | {value} | {status} |')

print()
if issues:
    print(f'**Overall: ISSUES FOUND — {", ".join(issues)}**')
else:
    print('**Overall: All systems HEALTHY — no issues detected.**')
PYEOF
```

**Health status thresholds:**
- Storage: <60% HEALTHY, 60-80% ATTENTION, >80% WARNING (computed from `STORE_SIZE / STORAGE_LIMIT * 100`)
- CPU: <70% HEALTHY, 70-90% ATTENTION, >90% WARNING (computed from `CPU_USAGE / CPU_LIMIT * 100`)
- Heap: <0.70 HEALTHY, 0.70-0.85 ATTENTION, >0.85 WARNING (`HEAP_RATIO` is already a 0.0-1.0 ratio)
- OOM errors: 0 = HEALTHY, >0 = WARNING
- Page cache hit ratio: >0.90 GOOD, 0.70-0.90 OK, <0.70 POOR (`CACHE_HIT` is already a 0.0-1.0 ratio)
- Query latency p50: <100ms HEALTHY, 100-500ms ATTENTION, >500ms WARNING, NaN = UNAVAILABLE
- Query latency p99: <10s HEALTHY, 10-30s ATTENTION, >30s WARNING, NaN = UNAVAILABLE

### Remediation Guidance

When health checks surface warnings, use these actions:

| Warning | Likely Cause | Remediation |
|---|---|---|
| **Storage > 80%** | Data growth / large imports | Audit unused indexes (`SHOW INDEXES`), delete stale data, or request storage increase via Aura Console |
| **CPU > 90%** | Expensive queries / high concurrency | Review slow queries (`dbms.listQueries()`), add indexes, reduce concurrent writes |
| **Heap > 85%** | Large result sets / memory-hungry queries | Profile queries with `PROFILE`, reduce `LIMIT`-less queries, check for cartesian products |
| **OOM Errors > 0** | Query exceeded memory limit | Identify offending queries, add `LIMIT`, use `apoc.periodic.iterate` for batch ops |
| **Page Cache Hit Ratio < 70%** | Working set exceeds cache | Common after restart — wait for cache warmup; if persistent, consider instance upgrade |
| **Query Latency p99 > 30s** | Outlier slow queries (scans, no indexes) | Run `SHOW INDEXES`, check for missing indexes on frequently filtered properties; review recent Cypher for full-node scans |
| **Query Latency p50 > 500ms** | Systemic performance issue | Check CPU/heap first; if healthy, audit query patterns and index coverage |

### GCP Secrets Summary (Aura API)

| Secret Name | Purpose |
|---|---|
| `claude_mcp_neo4j_aura_client_id` | Management API (instances, snapshots) |
| `claude_mcp_neo4j_aura_client_secret` | Management API (instances, snapshots) |
| `claude_mcp_neo4j_aura_datadog_client_id` | Datadog/metrics integration (OAuth2 for Prometheus endpoint) |
| `claude_mcp_neo4j_aura_datadog_client_secret` | Datadog/metrics integration (OAuth2 for Prometheus endpoint) |
| `claude_mcp_neo4j_neuronet_uri` / `claude_mcp_neo4j_neuronet_writer_username` / `claude_mcp_neo4j_neuronet_writer_password` | **Bolt write** creds for prod NeuroNet (`neo4j+s://6237b468...`, user `neuronet_writer`). Use for bulk schema DDL via the Python driver / cypher-shell — see Gotcha #13. NOT an Aura management-API key. |

## Gotchas — Aura Cluster Operations

Hard-won lessons from the 2026-06-09 incident (instance `6237b468` "NeuroNet", user `customgpt` ran `apoc.meta.stats()` for 4.5 h, froze a read replica, caused hours of replication lag).

### 1. `apoc.meta.*` procedures are extremely expensive — never call them on a live production graph

`apoc.meta.stats()`, `apoc.meta.data()`, and `apoc.meta.schema()` perform **full-store scans** and are extremely page-cache-destructive. On a large graph they can run for hours, saturate the page cache with schema pages, and stall the apply pipeline on read replicas.

**Rules:**
- Do not expose these to integrations (e.g. CustomGPT, external agents) without query timeout guards.
- Cache schema results; do not let any caller invoke them on every request.
- Use `db.schema.visualization()` (bounded, fast) for schema introspection instead.
- If an integration must call `apoc.meta.*`, wrap it: set `dbms.transaction.timeout` per-query or proxy through a gateway that enforces timeouts.

### 2. `SHOW TRANSACTIONS` is server-local — you must land on the right member to see/kill a runaway

In an Aura cluster, reads route to secondaries and writes to the leader. `SHOW TRANSACTIONS` only returns transactions on the cluster member your session landed on. A runaway on a secondary is invisible from the leader session.

**To find a runaway on a secondary:**
1. Open a session in `READ` access mode (`--access-mode read` in cypher-shell, or `AccessMode.READ` in the driver).
2. Fire `SHOW TRANSACTIONS` several times — the cluster round-robins across secondaries, so you'll land on the target member eventually.
3. Deduplicate `transactionId` values across results to build the full picture.

**To find/kill a runaway WRITE transaction, you must land on the LEADER — use a WRITE-mode session, not a read tool.** Write transactions (bulk `MERGE`/`SET`, `apoc.periodic.iterate`, ingest jobs) execute **only on the leader**. A `READ`-mode session — including the `neo4j-neuronet` MCP read tool — routes to secondaries and round-robins across them, so it will **rarely or never** land on the leader; you can burn many attempts seeing only secondary transactions. Instead open a **`WRITE` access-mode** driver session (Python `GraphDatabase.driver(...).session(default_access_mode=neo4j.WRITE_ACCESS)`, or plain `cypher-shell` whose default mode is write): the driver routes it straight to the leader, where `SHOW TRANSACTIONS` + `TERMINATE` then see and kill the write runaways. Terminating another user's transaction needs the `TERMINATE TRANSACTION` privilege — use the real admin account (`neo4j_admin_username` / `neo4j_admin_password`), not the `reader`/`customgpt` MCP user.

> **Adding read replicas does NOT relieve a write pileup.** A second secondary spreads *read* load (fixes a Bolt-connection thundering herd / `NoThreadsAvailable` on a single member), but write transactions still all land on the one leader — long-held writes there keep pinning threads and inflating `q99` until you terminate them on the leader as above.

### 3. Detect and kill on the same member atomically

`transactionId` values (e.g. `neo4j-transaction-1234`) are **per-member** — the same integer may refer to different transactions on different members. Combine detect + kill in one statement so both operations land on the same server:

```cypher
// Detects and kills in a single round-trip on one member.
// ⚠️ Filter on elapsedTime.minutes (a NUMBER), NOT `elapsedTime > duration('PT30M')`.
// ⚠️ SHOW TRANSACTIONS must YIELD the columns WHERE/TERMINATE consume before chaining —
// omitting this YIELD is a syntax error, not a silent no-op.
SHOW TRANSACTIONS
YIELD transactionId, username, elapsedTime
WHERE username = $username AND elapsedTime.minutes > 30
TERMINATE TRANSACTIONS transactionId
YIELD transactionId, username, message
RETURN transactionId, username, message
```

Set `$username` to the account you're hunting — the **reader/`customgpt` MCP user** for a READ-mode runaway (section 2's secondary case), or the **writer/admin account** (`neo4j_admin_username`, or whichever account owns the ingest job) for a WRITE-mode runaway (section 2's leader case). `customgpt` is read-only and never owns a write transaction, so filtering on it during a write-pileup incident returns no rows and leaves the leader pinned.

Repeat the query in **READ** mode until it returns no rows — the session round-robins across secondaries, so it may take several runs to hit every member. In **WRITE** mode there is only one leader to land on, so a single run reaches it; if a confirmed write pileup still comes back empty, re-check whether the transaction already terminated rather than re-running for member coverage.

> **⚠️ CRITICAL — never filter with `elapsedTime > duration('PT30M')`.** Durations are **not order-comparable** in Cypher: the `>` operator on two durations returns **`null`**, not a boolean (a "month" has no fixed length, so durations have no total order). The `WHERE` then silently drops **every** row and `TERMINATE` kills **nothing** — while returning an empty result that looks exactly like "no runaways found". Confirmed live: `WHERE elapsedTime > duration('PT20M')` returned `[]` on a member that plainly held a 100-minute transaction. Always coerce to a number first: `elapsedTime.minutes > 30` (or `elapsedTime.seconds`, `.hours`). On an elapsed duration built from seconds only, `.minutes` returns **total** minutes (e.g. `103`), not minutes-mod-60 — so the threshold behaves as expected.

### 4. `TERMINATE TRANSACTIONS` sets a flag — long APOC procedures may not honour it

`TERMINATE TRANSACTIONS` sets a **termination flag** that the transaction is expected to poll. Some APOC procedures (notably `apoc.meta.stats`) do not check this flag frequently, so the transaction continues running even after the command returns a "Transaction terminated." success message.

**If the transaction won't die:**
- Keep firing the combined detect+kill query (above) in a loop; APOC eventually reaches a checkpoint.
- Last resort: trigger an **Aura pause → resume** on the instance via the Aura API or Console. This is the only hard kill. It causes ~2–5 min downtime.

```bash
# Hard kill via Aura API (last resort)
python scripts/aura_api.py pause 6237b468
# Wait for status = paused
python scripts/aura_api.py resume 6237b468
```

### 5. No `dbms.transaction.timeout` = runaways self-reap only on restart

If `dbms.transaction.timeout` is not set (or set to 0), queries run forever. Aura does not expose this setting directly — it must be requested via Neo4j support or worked around by:
- Proxy-side timeouts in the application layer.
- A kill-cron that periodically detects and terminates long-running transactions.

Instance `6237b468` had no effective timeout; the 4.5-hour runaway was only discovered from downstream replica-lag symptoms.

### 6. Replica lag is NOT in the Datadog Neo4j dashboard — it surfaces only in gateway logs

The Datadog monitors for instance `6237b468` report **primary-side** metrics only. Replica apply lag does not appear there.

**Replica lag is observable via:**
- Gateway application logs: look for `"Database 'neo4j' not up to the requested version"` — this is the version-delta error that surfaces when a read hits a lagging secondary.
- The Aura Console "Cluster" view (if available on your tier).

**Useful Datadog metrics when investigating a suspected runaway (primary-side):**
- `neo4j_aura.neo4j_aura_cpu_usage` / `neo4j_aura_cpu_limit` — sustained high CPU is a strong signal.
- `neo4j_db_query_execution_internal_latency_q99` — spiking p99 latency on the primary.
- `neo4j_dbms_page_cache_hit_ratio_per_minute` — a full-store scan drives this down sharply.
- `neo4j_dbms_page_cache_evictions_total` — rapid evictions accompany a page-cache-thrashing scan.

> **Note:** Several of the Neo4j Aura monitors were muted indefinitely as of the incident date. Verify alert routing before assuming degradation will page someone.

## Gotchas — Overwrite / Clone & Auth (2026-06-13 sandbox-sync session)

Hard-won from building the weekly Prod→Sandbox sync (`6237b468` → `05010ab9`). The `overwrite` endpoint is **not** a turnkey "representative clone" — it needs post-steps.

### 7. `overwrite` / clone copies DATA ONLY — replay the schema after every run

Verified live: a **completed** `overwrite` left the full dataset (~771M nodes; Account/CommsMessage/Employee counts matched prod) but only the **~20 app-bootstrap FULLTEXT/VECTOR + 2 default LOOKUP indexes and 0 constraints** — none of prod's ~3,144 RANGE/TEXT indexes or 767 constraints carried over. The Aura console clone/overwrite/restore docs describe the op purely as a *data* copy and never mention indexes/constraints/schema. (The "carries the full store incl. schema" behavior is **self-managed** `neo4j-admin database backup/restore`, NOT Aura's console clone/overwrite — don't conflate.) The op also exposes only a coarse status string (`overwriting`→`loading`→`running`), no % progress; an ~815 GiB overwrite took ~4.5h. **Fix:** after the overwrite reaches `running`, dump the source schema and replay it on the dest:
```cypher
// on SOURCE — dump:
SHOW CONSTRAINTS YIELD createStatement RETURN createStatement;
SHOW INDEXES YIELD createStatement, type, owningConstraint
  WHERE owningConstraint IS NULL AND type <> 'LOOKUP' RETURN createStatement;
// on DEST — replay each with IF NOT EXISTS, constraints FIRST (they auto-create
// their backing RANGE index), then the standalone indexes.
```

### 8. `overwrite` resets the destination's in-DB auth — recreate + re-grant your app users

The overwrite replaces the destination's `system` database with the **source's** users/roles, so any destination-specific user (e.g. a scratch-only writer) is **deleted**. It still *authenticates* (the Aura control-plane keeps the credential valid) but is `42NFF: permission/access denied` on everything, incl. data reads. **Fix:** after each overwrite, recreate + grant against `-d system`:
```cypher
CREATE USER `myuser` IF NOT EXISTS SET PASSWORD $pw SET PASSWORD CHANGE NOT REQUIRED SET STATUS ACTIVE;
GRANT ROLE `graphql_app_read_write_<destInstanceId>` TO `myuser`;
```

### 9. Built-in `publisher`/`editor` roles are INERT on Aura — use the instance-specific app role

On Aura the built-in `reader`/`editor`/`publisher`/`architect` roles carry **no DB-access grant** — granting `publisher` leaves the user `42NFF`-denied. DB access is wired through Aura's own **instance-specific** roles, suffixed with the instance id: `graphql_app_read_only_<id>`, `graphql_app_read_write_<id>`, `console_viewer_<id>`, `console_member_<id>`, `console_admin_pro_<id>`, `data_importer_<id>`. Grant the matching `graphql_app_read_write_<id>` to an app service account. Because the name embeds the instance id, you **cannot** pre-seed such a grant on a *different* instance and expect it to survive a clone/overwrite.

### 10. The scoped Aura admin role can't `SHOW … PRIVILEGES`

The `neo4j` admin user (role `console_admin_pro_<id>`) can `CREATE USER` / `GRANT ROLE` / `SHOW USERS` / `SHOW ROLES` / `SHOW DATABASE` and read/write any DB — but `SHOW USER <x> PRIVILEGES` and `SHOW ROLE <x> PRIVILEGES` return `42NFF`. Don't rely on privilege introspection to debug grants; test access empirically by connecting as the user.

### 11. `*_admins` secret names can mislead — verify the actual role

On this tenant, `claude_mcp_neo4j_neuronet_username_admins` / `_password_admins` (prod) resolve to the **read-only `customgpt`/`reader` user**, not an admin — the `_admins` suffix is misleading. (That reader CAN run `SHOW INDEXES`/`SHOW CONSTRAINTS`, so it's the correct least-privilege choice for a schema dump.) The real **sandbox** admin (`neo4j` user) is `claude_mcp_neo4j_sandbox_{uri,username,password}_admins`. Confirm with `SHOW CURRENT USER` rather than trusting the secret name.

### 12. `CREATE CONSTRAINT` blocks; `CREATE INDEX` is async — size timeouts accordingly

`CREATE INDEX` returns immediately and populates in the background. `CREATE CONSTRAINT` **blocks** until its backing index is built and uniqueness verified — on ~771M nodes that is ~10s *each*, so replaying 767 constraints serially takes ~2–3h. After a ~4.5h overwrite, a full schema replay needs a generous task timeout (the weekly cron uses 18h; a 6h overwrite-poll cap covers the overwrite).

## Gotchas — Index Cleanup & Bulk Schema DDL (2026-06-30 XEN-1145 session)

Hard-won from reducing the prod index count 3,329 → 1,524 (slack_channel_id fan-out + Fivetran staging cleanup).

### 13. `neuronet_cypher` blocks `apoc.*` AND accepts only ONE statement — use the Bolt driver for bulk DDL

The `neuronet_cypher` MCP tool has a production safety guard that **rejects any `apoc.*` procedure** with `"schema-introspection procedure blocked"` — verified for both `apoc.cypher.runMany` and `apoc.periodic.iterate` (the match is on the `apoc.` namespace, not just the meta procs). It **also rejects multi-statement queries**: `DROP INDEX a; DROP INDEX b;` → `"Expected exactly one statement per query but got: 2"`.

So you **cannot** bulk-drop hundreds of indexes through `neuronet_cypher`. Drive it through the **Python `neo4j` driver via `neuronet_bash`** (power-user) with the `claude_mcp_neo4j_neuronet_writer_*` Bolt creds, looping one `DROP INDEX \`name\` IF EXISTS` per call:

```python
import subprocess
from neo4j import GraphDatabase
def sec(n): return subprocess.check_output(["gcloud","secrets","versions","access","latest","--secret",n,"--project","xsolla-n8n-prod"]).decode().strip()
KEEP = ["Employee", "Account"]  # labels/rel-types whose indexes must be preserved — adjust as needed
drv = GraphDatabase.driver(sec("claude_mcp_neo4j_neuronet_uri"),
    auth=(sec("claude_mcp_neo4j_neuronet_writer_username"), sec("claude_mcp_neo4j_neuronet_writer_password")))
with drv.session() as s:
    names = [r["name"] for r in s.run("SHOW INDEXES YIELD name, properties, owningConstraint "
        "WHERE properties=['slack_channel_id'] AND owningConstraint IS NULL "
        "AND NOT labelsOrTypes[0] IN $keep RETURN name", keep=KEEP)]
    for n in names: s.run(f"DROP INDEX `{n}` IF EXISTS")
```

`DROP INDEX`/`DROP CONSTRAINT` are metadata-only and non-blocking; ~1,000 drops finish in well under a minute. Secrets stay in the shell (never echo them). cypher-shell (`/usr/bin/cypher-shell`) is also installed if you prefer `-f file.cypher`.

### 14. `SHOW INDEXES … YIELD … WHERE …` cannot be followed by `WITH` — only `RETURN`

`SHOW INDEXES YIELD name WHERE … WITH …` fails (`Invalid input 'WITH'`). Aggregate/transform in the `RETURN` itself (`RETURN x, count(*) …`) or wrap the whole thing in a driver-side loop. Same applies to `SHOW CONSTRAINTS`.

### 15. Every uniqueness/key constraint auto-creates a backing index — `SHOW INDEXES` counts them

A `UNIQUENESS` / `NODE_KEY` / `RELATIONSHIP_UNIQUENESS` constraint **owns** a backing RANGE index that shows up in `SHOW INDEXES` (with `owningConstraint` set). `EXISTENCE` / `PROPERTY_TYPE` constraints do **not** back an index. Consequence: the index count can never drop below the number of uniqueness/key constraints **without dropping constraints**. On this graph, 564 constraints → 476 backing indexes form a hard floor; any "get under N" target below that is impossible without removing uniqueness guarantees the ingest pipelines rely on for MERGE idempotency (dropping them risks duplicate nodes). Filter `owningConstraint IS NULL` before dropping; never drop a constraint-owned index directly. `DROP CONSTRAINT` removes the constraint *and* its backing index in one shot.

### 16. "Duplicate" indexes are usually composite-vs-single — key on the FULL property tuple before dropping

A label+`properties[0]` match (e.g. `Employee.hire_date` ×2) is NOT proof of a duplicate — one is often `[hire_date]` and the other a composite `[hire_date, …]`, or a different `type` (RANGE vs TEXT). Dedupe only on the exact `(entityType, type, full properties tuple)` key. On this graph the apparent dupes were all legitimate composite/single pairs — zero true duplicates.

### 17. Verify a "rename duplicate" property is actually dead before dropping its constraint/index

The ticket flagged `Account.salesforce-id` (hyphen, legacy) vs `salesforce_id` (underscore, new) as a safe dedup. Counting first: legacy populated on **all 282,435** Accounts, new on only **278,509** — the rename never finished, so the "legacy" key was *more* complete. Always `MATCH (n:Label) WHERE n.\`old\` IS NOT NULL RETURN count(n)` (uses the backing index, fast) before assuming a renamed property is droppable.

### 18. Staging labels (`zzz_/zzw_/zzy_`) carry their own constraints too

Raw Fivetran staging labels accrue both standalone indexes AND uniqueness constraints (auto-PKs). Drop the standalone indexes first (`owningConstraint IS NULL`), then the constraints (`DROP CONSTRAINT` clears their backing indexes). These tables are never queried by the graph, so both are safe. Longer-term, move staging to a dedicated Aura instance.

## Query Log Forwarding & Slow-Query Analysis (Business Critical tier)

On **Business Critical** (and higher) instances, Aura forwards `query.log` + `security.log` to a customer log sink — this is the supported "slow-query log". Use it to drive evidence-based index pruning (which indexes are actually hit).

**Enabling (tenant Admin, Aura Console):** Instance → **Logs → Log Forwarding** → forward `query.log` to **GCP Cloud Logging**. Aura provisions a forwarding SA (`log-forwarding-<id>@neo4j-cloud.iam.gserviceaccount.com`); grant it `roles/logging.logWriter` on the destination GCP project. **Exclude "start" entries** — the `elapsedTimeMs` lives only on the `event:"success"` completion record, so start entries just double the volume/cost (start/finished pairs are only useful for hung-query detection, already covered by `SHOW TRANSACTIONS` + CPU/page-cache metrics). Set the duration threshold low (~50–100 ms) for the first few days.

> The low-scope `claude_mcp_neo4j_aura_client_*` management key is **403 on `log-forwarding`, `logs`, and `metrics-integration`** endpoints — it can read instances/tenant only. Configuring log forwarding via the API needs an **Admin-scoped** Aura API key.

**Reading the logs** (land at `projects/<proj>/logs/neo4j-query.<instanceId>`):
```bash
gcloud logging read 'logName="projects/xsolla-n8n-prod/logs/neo4j-query.6237b468"' \
  --project xsolla-n8n-prod --limit 1000 --freshness=7d --format=json
```
`jsonPayload.message` is a **JSON string** (parse it) with: `elapsedTimeMs`, `event` (`success`/`failure`), `query` (full Cypher), `database`, `executingUser`, `pageHits`, `pageFaults`, `planning`, `executableQueryCacheHit`. Aggregate by query → map each to the `(label, property)` it filters/merges on → an index with **zero** observed hits over a full cron cycle (≥5–7 days, to catch hourly/daily/weekly jobs) is a safe drop candidate. Accumulate before analyzing — a single hour only sees the live gateway mix, not the periodic Fivetran/Salesforce/HiBob syncs.

## Limitations

**v1 API does NOT support:**
- ❌ Real-time metrics via management API (use metrics endpoint with Datadog creds)
- ❌ Logical subset / selective copy — `overwrite` copies the *entire* instance.
  For a subset you need a logical export (`neo4j-admin` dump of selected DBs, or
  APOC export of a subgraph), which is a separate, heavier pipeline.

**v1 API DOES support:**
- ✅ Instance lifecycle (create, pause, resume, delete)
- ✅ Snapshot management (create, list, get, restore)
- ✅ **Cross-instance copy / overwrite** ("Clone to existing") via
  `POST /v1/instances/{id}/overwrite` — see [Cross-Instance Copy](#cross-instance-copy--overwrite-clone-to-existing).
  Restoring *within* an instance uses the snapshot-scoped restore endpoint;
  copying *across* instances uses `overwrite`. Do not conflate the two.
- ✅ Instance details and status
- ✅ Multi-region operations

## Security Best Practices

1. **Never hardcode credentials** - Always use environment variables or secrets manager
2. **Use dedicated API keys** - Create API-specific client credentials in Aura Console
3. **Rotate credentials regularly** - Regenerate client secret periodically
4. **Validate instance IDs** - Double-check before deletion
5. **Monitor API usage** - Track rate limit consumption
6. **Secure credential storage** - Use GCP Secret Manager or equivalent in production

## Troubleshooting

**HTTP API vs Bolt connectivity:**

Neo4j Aura has two independent access layers:
- **Bolt protocol** (port 7687) — used by MCP, Python driver, cypher-shell
- **HTTP API** (`/db/{db}/query/v2`) — used by REST clients, neo4j-cypher skill

These use different gateways and one can fail while the other works.

Diagnosis steps:
1. Test Bolt: `mcp__neo4j-neuronet__read_neo4j_cypher` (Python: `neuronet_search(query="RETURN 1")` from `shared.tools.neo4j_context`) with `RETURN 1`
2. Test HTTP API: `curl -s -w '%{http_code}' https://<host>:7473/db/neo4j/query/v2 -H "Authorization: Basic <b64>" -H "Content-Type: application/json" -d '{"statement":"RETURN 1"}'`
3. Test Aura Management API: `curl https://api.neo4j.io/v1/instances/<id>` with Bearer token (check `status` field)

If Bolt works but HTTP returns 504:
- This is an Aura HTTP gateway issue, not a database problem
- Pause/resume the instance to restart the gateway (causes ~2-5 min downtime)
- Check [Neo4j Aura status page](https://status.neo4j.io/) for known incidents

**Auth not working:**
```bash
# Verify credentials are set
echo "Client ID: ${NEO4J_AURA_CLIENT_ID:0:8}..."
echo "Secret set: $([ -n "$NEO4J_AURA_CLIENT_SECRET" ] && echo yes || echo no)"

# Test with list command (auto-authenticates)
python scripts/aura_api.py list
```

**Snapshot taking too long:**
- Completion time scales with database size
- Large databases (>100GB) may take hours
- Use `--wait` flag for automatic polling
- Check snapshot status manually if needed

**Instance stuck in operation:**
- Check for ongoing operations: `python scripts/aura_api.py get <instance-id>`
- Wait for current operation to complete before new operations
- Some operations (upgrade, clone) can take extended time

## Integration Examples

**Backup before maintenance:**
```bash
#!/bin/bash
INSTANCE_ID="your-instance-id"

# Create backup
echo "Creating backup..."
SNAPSHOT_JSON=$(python scripts/aura_api.py snapshot $INSTANCE_ID --wait)
SNAPSHOT_ID=$(echo $SNAPSHOT_JSON | jq -r '.data.snapshot_id')

echo "Backup created: $SNAPSHOT_ID"

# Perform maintenance operations
echo "Running maintenance..."
# ... your maintenance commands ...

# Restore if something went wrong
if [ $? -ne 0 ]; then
  echo "Maintenance failed, restoring backup..."
  python scripts/aura_api.py restore $INSTANCE_ID $SNAPSHOT_ID
fi
```

**Scheduled snapshots:**
```python
#!/usr/bin/env python3
import sys
sys.path.append('scripts')
from aura_api import create_snapshot, wait_for_snapshot, list_instances

# Get all production instances
instances = list_instances()
prod_instances = [
    i for i in instances.get("data", [])
    if "prod" in i["name"].lower()
]

# Create snapshots for each
for instance in prod_instances:
    instance_id = instance["id"]
    print(f"Backing up {instance['name']}...")

    result = create_snapshot(instance_id)
    snapshot_id = result["data"]["snapshot_id"]

    if wait_for_snapshot(instance_id, snapshot_id, timeout=3600):
        print(f"✓ Backup complete: {snapshot_id}")
    else:
        print(f"✗ Backup failed for {instance['name']}")
```

## Tool Compatibility

| MCP Tool | Python Equivalent | Module |
|----------|-------------------|--------|
| `mcp__neo4j-neuronet__read_neo4j_cypher` | `neuronet_search()` | `shared.tools.neo4j_context` |

> **Note:** This skill primarily uses the Aura Management REST API (curl/Python `aura_api.py`), not MCP tools. The MCP tool reference is only for Bolt connectivity testing.
