#!/usr/bin/env python3
"""
Neo4j Aura API Client
Provides programmatic access to Neo4j Aura management operations.

Auth: Set NEO4J_AURA_CLIENT_ID + NEO4J_AURA_CLIENT_SECRET (OAuth2 client credentials).
Fallback: NEO4J_AURA_TOKEN (raw Bearer token, legacy).
"""

import os
import sys
import json
import time
import base64
import argparse
from typing import Optional, Dict, Any
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode

BASE_URL = "https://api.neo4j.io/v1"
TOKEN_URL = "https://api.neo4j.io/oauth/token"

# Module-level token cache
_cached_token: Optional[str] = None
_token_expiry: float = 0


def authenticate() -> str:
    """Exchange client credentials for a Bearer token (cached, 1h TTL)."""
    global _cached_token, _token_expiry

    if _cached_token and time.time() < _token_expiry - 60:
        return _cached_token

    client_id = os.getenv("NEO4J_AURA_CLIENT_ID")
    client_secret = os.getenv("NEO4J_AURA_CLIENT_SECRET")

    if not client_id or not client_secret:
        legacy = os.getenv("NEO4J_AURA_TOKEN")
        if legacy:
            _cached_token = legacy
            _token_expiry = time.time() + 3600
            return legacy
        print(
            "Error: Set NEO4J_AURA_CLIENT_ID + NEO4J_AURA_CLIENT_SECRET "
            "(or legacy NEO4J_AURA_TOKEN)",
            file=sys.stderr,
        )
        sys.exit(1)

    credentials = base64.b64encode(f"{client_id}:{client_secret}".encode()).decode()
    data = urlencode({"grant_type": "client_credentials"}).encode()
    req = Request(
        TOKEN_URL,
        data=data,
        headers={
            "Authorization": f"Basic {credentials}",
            "Content-Type": "application/x-www-form-urlencoded",
        },
        method="POST",
    )

    try:
        with urlopen(req) as response:
            result = json.loads(response.read().decode())
            _cached_token = result["access_token"]
            _token_expiry = time.time() + result.get("expires_in", 3600)
            return _cached_token
    except HTTPError as e:
        error_body = e.read().decode()
        print(f"Auth failed (HTTP {e.code}): {error_body}", file=sys.stderr)
        sys.exit(1)
    except (URLError, KeyError) as e:
        print(f"Auth error: {e}", file=sys.stderr)
        sys.exit(1)


def get_auth_token() -> str:
    """Get authentication token (delegates to authenticate())."""
    return authenticate()


def make_request(
    method: str,
    endpoint: str,
    data: Optional[Dict[str, Any]] = None,
    token: Optional[str] = None
) -> Dict[str, Any]:
    """Make HTTP request to Aura API."""
    if token is None:
        token = get_auth_token()

    url = f"{BASE_URL}{endpoint}"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Accept": "application/json"
    }

    request_data = json.dumps(data).encode('utf-8') if data else None
    req = Request(url, data=request_data, headers=headers, method=method)

    try:
        with urlopen(req) as response:
            response_data = response.read().decode('utf-8')
            return json.loads(response_data) if response_data else {}
    except HTTPError as e:
        error_body = e.read().decode('utf-8')
        print(f"HTTP Error {e.code}: {error_body}", file=sys.stderr)
        sys.exit(1)
    except URLError as e:
        print(f"URL Error: {e.reason}", file=sys.stderr)
        sys.exit(1)


def list_instances(tenant_id: Optional[str] = None) -> Dict[str, Any]:
    """List all Aura instances."""
    endpoint = "/instances"
    if tenant_id:
        endpoint += f"?tenantId={tenant_id}"
    return make_request("GET", endpoint)


def get_instance(instance_id: str) -> Dict[str, Any]:
    """Get details of a specific instance."""
    return make_request("GET", f"/instances/{instance_id}")


def create_instance(
    name: str,
    region: str,
    memory: str,
    tenant_id: str,
    cloud_provider: str = "gcp",
    instance_type: str = "professional"
) -> Dict[str, Any]:
    """Create a new Aura instance."""
    data = {
        "name": name,
        "region": region,
        "memory": memory,
        "tenant_id": tenant_id,
        "cloud_provider": cloud_provider,
        "type": instance_type,
        "version": "5"
    }
    return make_request("POST", "/instances", data)


def delete_instance(instance_id: str) -> Dict[str, Any]:
    """Delete an instance."""
    return make_request("DELETE", f"/instances/{instance_id}")


def pause_instance(instance_id: str) -> Dict[str, Any]:
    """Pause an instance."""
    return make_request("POST", f"/instances/{instance_id}/pause", {})


def resume_instance(instance_id: str) -> Dict[str, Any]:
    """Resume a paused instance."""
    return make_request("POST", f"/instances/{instance_id}/resume", {})


def list_snapshots(instance_id: str) -> Dict[str, Any]:
    """List all snapshots for an instance."""
    return make_request("GET", f"/instances/{instance_id}/snapshots")


def get_snapshot(instance_id: str, snapshot_id: str) -> Dict[str, Any]:
    """Get details of a specific snapshot."""
    return make_request("GET", f"/instances/{instance_id}/snapshots/{snapshot_id}")


def create_snapshot(instance_id: str) -> Dict[str, Any]:
    """Create an on-demand snapshot (backup) of an instance."""
    return make_request("POST", f"/instances/{instance_id}/snapshots", {})


def restore_snapshot(instance_id: str, snapshot_id: str) -> Dict[str, Any]:
    """Restore an instance from one of its OWN snapshots (same-instance only)."""
    return make_request("POST", f"/instances/{instance_id}/snapshots/{snapshot_id}/restore", {})


def overwrite_instance(
    instance_id: str,
    source_instance_id: str,
    source_snapshot_id: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Overwrite a destination instance with data from a source instance
    (the API equivalent of the Console's "Clone to existing").

    - instance_id: destination (gets overwritten; URI/creds preserved).
    - source_instance_id: where the data comes from.
    - source_snapshot_id: optional exportable (full) snapshot of the source.
      If omitted, Aura takes a fresh snapshot of the source and uses it.

    Destructive on the destination, no confirmation. Destination must be
    running and its storage must be >= the source's actual store size.
    """
    body: Dict[str, Any] = {"source_instance_id": source_instance_id}
    if source_snapshot_id:
        body["source_snapshot_id"] = source_snapshot_id
    return make_request("POST", f"/instances/{instance_id}/overwrite", body)


def wait_for_snapshot(instance_id: str, snapshot_id: str, timeout: int = 300, interval: int = 10) -> bool:
    """
    Poll snapshot status until complete or timeout.
    Returns True if completed, False if timeout.
    """
    start_time = time.time()
    while time.time() - start_time < timeout:
        snapshot = get_snapshot(instance_id, snapshot_id)
        status = snapshot.get("data", {}).get("status", "unknown")

        print(f"Snapshot status: {status}", file=sys.stderr)

        if status == "completed":
            return True
        elif status == "failed":
            print(f"Snapshot failed: {snapshot}", file=sys.stderr)
            return False

        time.sleep(interval)

    print(f"Timeout waiting for snapshot after {timeout}s", file=sys.stderr)
    return False


def main():
    parser = argparse.ArgumentParser(description="Neo4j Aura API Client")
    subparsers = parser.add_subparsers(dest="command", help="Command to execute")

    # List instances
    list_parser = subparsers.add_parser("list", help="List instances")
    list_parser.add_argument("--tenant-id", help="Filter by tenant ID")

    # Get instance
    get_parser = subparsers.add_parser("get", help="Get instance details")
    get_parser.add_argument("instance_id", help="Instance ID")

    # Create instance
    create_parser = subparsers.add_parser("create", help="Create instance")
    create_parser.add_argument("--name", required=True, help="Instance name")
    create_parser.add_argument("--region", required=True, help="Region")
    create_parser.add_argument("--memory", required=True, help="Memory size (e.g., 8GB)")
    create_parser.add_argument("--tenant-id", required=True, help="Tenant ID")
    create_parser.add_argument("--cloud-provider", default="gcp", help="Cloud provider")
    create_parser.add_argument("--type", default="professional", help="Instance type")

    # Pause instance
    pause_parser = subparsers.add_parser("pause", help="Pause instance")
    pause_parser.add_argument("instance_id", help="Instance ID")

    # Resume instance
    resume_parser = subparsers.add_parser("resume", help="Resume instance")
    resume_parser.add_argument("instance_id", help="Instance ID")

    # List snapshots
    snapshots_parser = subparsers.add_parser("snapshots", help="List snapshots")
    snapshots_parser.add_argument("instance_id", help="Instance ID")

    # Create snapshot
    snapshot_parser = subparsers.add_parser("snapshot", help="Create snapshot")
    snapshot_parser.add_argument("instance_id", help="Instance ID")
    snapshot_parser.add_argument("--wait", action="store_true", help="Wait for completion")

    # Restore snapshot
    restore_parser = subparsers.add_parser("restore", help="Restore from a snapshot (same-instance only)")
    restore_parser.add_argument("instance_id", help="Instance ID")
    restore_parser.add_argument("snapshot_id", help="Snapshot ID")

    # Overwrite instance from another instance (cross-instance copy / "clone to existing")
    overwrite_parser = subparsers.add_parser(
        "overwrite", help="Overwrite a destination instance with a source instance's data"
    )
    overwrite_parser.add_argument("instance_id", help="Destination instance ID (gets overwritten)")
    overwrite_parser.add_argument(
        "--source-instance-id", required=True, dest="source_instance_id",
        help="Source instance to copy data from"
    )
    overwrite_parser.add_argument(
        "--source-snapshot-id", dest="source_snapshot_id",
        help="Optional exportable (full) source snapshot; omit to auto-snapshot the source"
    )

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    # Execute command
    result = None
    if args.command == "list":
        result = list_instances(args.tenant_id)
    elif args.command == "get":
        result = get_instance(args.instance_id)
    elif args.command == "create":
        result = create_instance(
            args.name, args.region, args.memory, args.tenant_id,
            args.cloud_provider, args.type
        )
    elif args.command == "pause":
        result = pause_instance(args.instance_id)
    elif args.command == "resume":
        result = resume_instance(args.instance_id)
    elif args.command == "snapshots":
        result = list_snapshots(args.instance_id)
    elif args.command == "snapshot":
        result = create_snapshot(args.instance_id)
        if args.wait and result.get("data", {}).get("snapshot_id"):
            snapshot_id = result["data"]["snapshot_id"]
            if wait_for_snapshot(args.instance_id, snapshot_id):
                result = get_snapshot(args.instance_id, snapshot_id)
    elif args.command == "restore":
        result = restore_snapshot(args.instance_id, args.snapshot_id)
    elif args.command == "overwrite":
        result = overwrite_instance(
            args.instance_id, args.source_instance_id, args.source_snapshot_id
        )

    # Output result
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
