# Neo4j Aura API v1 - Endpoint Reference

Base URL: `https://api.neo4j.io/v1`

## Authentication

**OAuth2 client credentials flow:**
```
POST https://api.neo4j.io/oauth/token
Authorization: Basic base64(client_id:client_secret)
Content-Type: application/x-www-form-urlencoded
Body: grant_type=client_credentials
→ Returns: { "access_token": "...", "expires_in": 3600 }
```

Use the returned token in all API requests:
```
Authorization: Bearer <access_token>
```

Env vars: `NEO4J_AURA_CLIENT_ID` + `NEO4J_AURA_CLIENT_SECRET` (handled by `aura_api.py`).

## Instance Management

### List Instances
```
GET /instances
GET /instances?tenantId={tenantId}
```

Returns list of all instances, optionally filtered by tenant.

**Response:**
```json
{
  "data": [
    {
      "id": "instance-id",
      "name": "my-database",
      "status": "running",
      "tenant_id": "tenant-id",
      "cloud_provider": "gcp",
      "region": "us-central1",
      "memory": "8GB",
      "connection_url": "neo4j+s://xxxxx.databases.neo4j.io"
    }
  ]
}
```

### Get Instance Details
```
GET /instances/{instanceId}
```

Returns detailed information about a specific instance.

### Create Instance
```
POST /instances
```

**Request Body:**
```json
{
  "name": "my-database",
  "region": "us-central1",
  "memory": "8GB",
  "tenant_id": "tenant-id",
  "cloud_provider": "gcp",
  "type": "professional",
  "version": "5"
}
```

**Common Regions:**
- GCP: `us-central1`, `europe-west1`, `asia-southeast1`
- AWS: `us-east-1`, `eu-west-1`, `ap-southeast-1`

**Memory Sizes:** `2GB`, `8GB`, `16GB`, `32GB`, `64GB`, `128GB`, `256GB`, `384GB`

### Delete Instance
```
DELETE /instances/{instanceId}
```

Permanently deletes an instance. Cannot be undone.

### Pause Instance
```
POST /instances/{instanceId}/pause
```

**Request Body:** `{}`

Pauses instance to save costs. Data is preserved.

### Resume Instance
```
POST /instances/{instanceId}/resume
```

**Request Body:** `{}`

Resumes a paused instance.

## Snapshot (Backup) Management

### List Snapshots
```
GET /instances/{instanceId}/snapshots
```

Returns all snapshots for an instance, including automated and manual snapshots.

**Response:**
```json
{
  "data": [
    {
      "id": "snapshot-id",
      "timestamp": "2025-12-29T10:00:00Z",
      "status": "completed",
      "type": "manual"
    }
  ]
}
```

### Get Snapshot Details
```
GET /instances/{instanceId}/snapshots/{snapshotId}
```

Returns details about a specific snapshot.

### Create Snapshot (On-Demand Backup)
```
POST /instances/{instanceId}/snapshots
```

**Request Body:** `{}`

**Response (202 Accepted):**
```json
{
  "data": {
    "snapshot_id": "new-snapshot-id"
  }
}
```

**Important:** Snapshot creation is **asynchronous**. Poll status using GET /snapshots endpoint.

**Timing:** Completion time depends on database size. Large databases may take hours.

### Restore from Snapshot
```
POST /instances/{instanceId}/snapshots/{snapshotId}/restore
```

**Request Body:** `{}`

Restores instance data from a snapshot. This is a destructive operation - current data will be replaced. **This endpoint is instance-scoped** — it can only restore a snapshot back into the same instance it was taken from. To copy data *across* instances, use the `overwrite` endpoint below.

### Overwrite Instance (Cross-Instance Copy / "Clone to existing")
```
POST /instances/{instanceId}/overwrite
```

Overwrites the destination instance (`{instanceId}` in the path) with data from a source instance. This is the programmatic equivalent of the Console's "Clone to existing" action.

**Request Body:**
```json
{
  "source_instance_id": "6237b468",
  "source_snapshot_id": "<optional-snapshot-id>"
}
```

- `source_instance_id` (required) — the instance whose data to copy in.
- `source_snapshot_id` (optional) — a specific **exportable (full)** snapshot of the source. **If omitted, Aura takes a fresh snapshot of the source and uses it**, so a full sync is a single call.
- The destination must be **running** and its **storage must be ≥ the source's actual store size**.
- Destructive on the destination; runs **without confirmation**. The destination's connection URI/credentials are preserved.

Field names confirmed against the `neo4j/cli` source (`aura/internal/subcommands/instance/overwrite.go`): path `/instances/%s/overwrite`, body keys `source_instance_id` / `source_snapshot_id` (snake_case).

Poll `GET /instances/{instanceId}` until `status` returns to `running` (it transits `overwriting` / `loading`).

## Error Responses

### 401 Unauthorized
```json
{
  "errors": [
    {
      "message": "Invalid or expired token",
      "reason": "unauthorized"
    }
  ]
}
```

### 404 Not Found
```json
{
  "errors": [
    {
      "message": "DB not found: 24d18db5",
      "reason": "db-not-found"
    }
  ]
}
```

### 409 Conflict
```json
{
  "errors": [
    {
      "message": "The database is currently undergoing an operation: resuming",
      "reason": "ongoing-database-operation"
    }
  ]
}
```

Indicates instance is busy with another operation (cloning, upgrading, etc.).

### 429 Rate Limited
```json
{
  "errors": [
    {
      "message": "Rate limit exceeded",
      "reason": "rate-limited"
    }
  ]
}
```

**Headers:** `Retry-After: 5` (seconds to wait)

## Clone Operations

Two distinct flavors of "clone" are available via the v1 API:

**Clone to existing (overwrite)** — copy a source instance's data into an
existing destination instance, in place. Single call, preserves destination
URI/credentials. See [Overwrite Instance](#overwrite-instance-cross-instance-copy--clone-to-existing).
This is the right primitive for a recurring Prod→Test sync.

**Clone to new (create-from-snapshot)** — stand up a brand-new instance from a
source snapshot. The v1 REST API has no single "clone-to-new" call; compose it:
1. Create a snapshot of the source instance (or use an existing exportable one).
2. Create a new instance with the desired configuration.
3. Overwrite the new instance from the source snapshot.

Use clone-to-existing when you want a stable, long-lived target (stable URI);
use clone-to-new when you want an isolated throwaway with its own URI.

## Rate Limits

- Standard tier: 100 requests per 15 minutes
- Enterprise tier: 1000 requests per 15 minutes

Respect `Retry-After` header on 429 responses.

## Status Polling Pattern

For asynchronous operations (snapshots, restores), use this pattern:

```python
# 1. Initiate operation
response = create_snapshot(instance_id)
snapshot_id = response["data"]["snapshot_id"]

# 2. Poll until complete
while True:
    snapshot = get_snapshot(instance_id, snapshot_id)
    status = snapshot["data"]["status"]

    if status == "completed":
        break
    elif status == "failed":
        raise Exception("Operation failed")

    time.sleep(10)  # Wait 10 seconds between polls
```

## Best Practices

1. **Store tokens securely** - Use environment variables, never hardcode
2. **Handle async operations** - Always poll for completion status
3. **Implement retries** - Handle transient failures (502, 503, 504)
4. **Respect rate limits** - Use exponential backoff on 429 errors
5. **Validate before delete** - Double-check instance IDs before deletion
6. **Monitor snapshot age** - Snapshots may have retention limits
