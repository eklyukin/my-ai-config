#!/usr/bin/env python3
"""
GitHub Release Manager

Automate release creation, asset management, and release comparison.
"""

import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Optional, Dict, List, Any


def run_gh_command(cmd: List[str], check: bool = True) -> subprocess.CompletedProcess:
    """Execute a gh CLI command."""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=check
        )
        return result
    except subprocess.CalledProcessError as e:
        if check:
            print(f"Error running: {' '.join(cmd)}", file=sys.stderr)
            print(f"Error: {e.stderr}", file=sys.stderr)
            sys.exit(1)
        return e


def run_gh_json(cmd: List[str]) -> Any:
    """Execute gh command and parse JSON output."""
    result = run_gh_command(cmd)
    try:
        return json.loads(result.stdout) if result.stdout else {}
    except json.JSONDecodeError:
        return {}


def calculate_checksum(file_path: str, algorithm: str = "sha256") -> str:
    """Calculate file checksum."""
    hash_func = getattr(hashlib, algorithm)()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            hash_func.update(chunk)
    return hash_func.hexdigest()


def list_releases(
    repo: Optional[str] = None,
    limit: int = 10
) -> List[Dict[str, Any]]:
    """
    List releases for a repository.

    Args:
        repo: Repository in format 'owner/name'
        limit: Maximum number of releases to return

    Returns:
        List of release data
    """
    cmd = [
        "gh", "release", "list",
        "--limit", str(limit),
        "--json", "tagName,name,isDraft,isPrerelease,publishedAt,author"
    ]
    if repo:
        cmd.extend(["--repo", repo])

    return run_gh_json(cmd)


def get_release(
    tag: str,
    repo: Optional[str] = None
) -> Optional[Dict[str, Any]]:
    """
    Get release details by tag.

    Args:
        tag: Release tag (e.g., v1.0.0)
        repo: Repository in format 'owner/name'

    Returns:
        Release data or None
    """
    cmd = [
        "gh", "release", "view", tag,
        "--json", "tagName,name,body,isDraft,isPrerelease,publishedAt,assets,author"
    ]
    if repo:
        cmd.extend(["--repo", repo])

    result = run_gh_command(cmd, check=False)
    if result.returncode != 0:
        return None

    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return None


def create_release(
    tag: str,
    title: Optional[str] = None,
    notes: Optional[str] = None,
    generate_notes: bool = True,
    draft: bool = False,
    prerelease: bool = False,
    target: Optional[str] = None,
    repo: Optional[str] = None
) -> Dict[str, Any]:
    """
    Create a new release.

    Args:
        tag: Release tag (e.g., v1.0.0)
        title: Release title
        notes: Release notes
        generate_notes: Auto-generate notes from commits
        draft: Create as draft
        prerelease: Mark as prerelease
        target: Target commitish (branch or SHA)
        repo: Repository in format 'owner/name'

    Returns:
        Created release data
    """
    cmd = ["gh", "release", "create", tag]

    if title:
        cmd.extend(["--title", title])
    if notes:
        cmd.extend(["--notes", notes])
    elif generate_notes:
        cmd.append("--generate-notes")
    if draft:
        cmd.append("--draft")
    if prerelease:
        cmd.append("--prerelease")
    if target:
        cmd.extend(["--target", target])
    if repo:
        cmd.extend(["--repo", repo])

    result = run_gh_command(cmd)

    # Parse the URL from output
    url = result.stdout.strip()

    return {
        "tag": tag,
        "title": title or tag,
        "url": url,
        "draft": draft,
        "prerelease": prerelease
    }


def upload_assets(
    tag: str,
    files: List[str],
    checksums: bool = True,
    repo: Optional[str] = None
) -> Dict[str, Any]:
    """
    Upload assets to a release.

    Args:
        tag: Release tag
        files: List of file paths to upload
        checksums: Generate and upload checksum file
        repo: Repository in format 'owner/name'

    Returns:
        Upload result with checksums
    """
    result = {
        "tag": tag,
        "uploaded": [],
        "failed": [],
        "checksums": {}
    }

    # Calculate checksums first
    if checksums:
        for file_path in files:
            if os.path.isfile(file_path):
                checksum = calculate_checksum(file_path)
                result["checksums"][os.path.basename(file_path)] = checksum

    # Upload each file
    for file_path in files:
        if not os.path.isfile(file_path):
            result["failed"].append({
                "file": file_path,
                "error": "File not found"
            })
            continue

        cmd = ["gh", "release", "upload", tag, file_path, "--clobber"]
        if repo:
            cmd.extend(["--repo", repo])

        upload_result = run_gh_command(cmd, check=False)
        if upload_result.returncode == 0:
            result["uploaded"].append({
                "file": os.path.basename(file_path),
                "path": file_path,
                "checksum": result["checksums"].get(os.path.basename(file_path))
            })
        else:
            result["failed"].append({
                "file": file_path,
                "error": upload_result.stderr.strip()
            })

    # Create checksum file if enabled
    if checksums and result["checksums"]:
        checksum_content = "\n".join(
            f"{checksum}  {filename}"
            for filename, checksum in result["checksums"].items()
        )
        checksum_file = f"/tmp/checksums-{tag}.txt"
        with open(checksum_file, "w") as f:
            f.write(checksum_content + "\n")

        # Upload checksum file
        cmd = ["gh", "release", "upload", tag, checksum_file, "--clobber"]
        if repo:
            cmd.extend(["--repo", repo])
        run_gh_command(cmd, check=False)

        # Clean up
        os.remove(checksum_file)

    return result


def download_assets(
    tag: str,
    output_dir: str = ".",
    pattern: Optional[str] = None,
    repo: Optional[str] = None
) -> Dict[str, Any]:
    """
    Download release assets.

    Args:
        tag: Release tag
        output_dir: Output directory
        pattern: Glob pattern to filter assets
        repo: Repository in format 'owner/name'

    Returns:
        Download result
    """
    cmd = ["gh", "release", "download", tag, "-D", output_dir]
    if pattern:
        cmd.extend(["-p", pattern])
    if repo:
        cmd.extend(["--repo", repo])

    result = run_gh_command(cmd, check=False)

    return {
        "tag": tag,
        "output_dir": output_dir,
        "success": result.returncode == 0,
        "message": result.stdout.strip() or result.stderr.strip()
    }


def delete_release(
    tag: str,
    cleanup_tag: bool = False,
    repo: Optional[str] = None
) -> Dict[str, Any]:
    """
    Delete a release.

    Args:
        tag: Release tag
        cleanup_tag: Also delete the git tag
        repo: Repository in format 'owner/name'

    Returns:
        Deletion result
    """
    cmd = ["gh", "release", "delete", tag, "--yes"]
    if cleanup_tag:
        cmd.append("--cleanup-tag")
    if repo:
        cmd.extend(["--repo", repo])

    result = run_gh_command(cmd, check=False)

    return {
        "tag": tag,
        "success": result.returncode == 0,
        "message": result.stdout.strip() or result.stderr.strip()
    }


def compare_releases(
    tag1: str,
    tag2: str,
    repo: Optional[str] = None
) -> Dict[str, Any]:
    """
    Compare two releases (assets, dates, etc.).

    Args:
        tag1: First release tag (older)
        tag2: Second release tag (newer)
        repo: Repository in format 'owner/name'

    Returns:
        Comparison data
    """
    release1 = get_release(tag1, repo)
    release2 = get_release(tag2, repo)

    if not release1:
        return {"error": f"Release {tag1} not found"}
    if not release2:
        return {"error": f"Release {tag2} not found"}

    assets1 = {a["name"]: a for a in release1.get("assets", [])}
    assets2 = {a["name"]: a for a in release2.get("assets", [])}

    added_assets = [name for name in assets2 if name not in assets1]
    removed_assets = [name for name in assets1 if name not in assets2]
    common_assets = [name for name in assets1 if name in assets2]

    return {
        "from": tag1,
        "to": tag2,
        "release1": {
            "tag": release1["tagName"],
            "published": release1.get("publishedAt"),
            "asset_count": len(assets1)
        },
        "release2": {
            "tag": release2["tagName"],
            "published": release2.get("publishedAt"),
            "asset_count": len(assets2)
        },
        "assets": {
            "added": added_assets,
            "removed": removed_assets,
            "common": common_assets
        },
        "compare_url": f"https://github.com/{repo}/compare/{tag1}...{tag2}" if repo else None
    }


def edit_release(
    tag: str,
    title: Optional[str] = None,
    notes: Optional[str] = None,
    draft: Optional[bool] = None,
    prerelease: Optional[bool] = None,
    repo: Optional[str] = None
) -> Dict[str, Any]:
    """
    Edit an existing release.

    Args:
        tag: Release tag
        title: New title
        notes: New notes
        draft: Change draft status
        prerelease: Change prerelease status
        repo: Repository in format 'owner/name'

    Returns:
        Edit result
    """
    cmd = ["gh", "release", "edit", tag]

    if title:
        cmd.extend(["--title", title])
    if notes:
        cmd.extend(["--notes", notes])
    if draft is not None:
        cmd.append("--draft" if draft else "--draft=false")
    if prerelease is not None:
        cmd.append("--prerelease" if prerelease else "--prerelease=false")
    if repo:
        cmd.extend(["--repo", repo])

    result = run_gh_command(cmd, check=False)

    return {
        "tag": tag,
        "success": result.returncode == 0,
        "message": result.stdout.strip() or result.stderr.strip()
    }


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="GitHub Release Manager",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Commands:
  list      List releases
  view      View release details
  create    Create a new release
  upload    Upload assets to a release
  download  Download release assets
  delete    Delete a release
  compare   Compare two releases
  edit      Edit a release

Examples:
  %(prog)s list
  %(prog)s create v1.0.0 --generate-notes
  %(prog)s upload v1.0.0 dist/*.zip
  %(prog)s download v1.0.0 -D ./output
  %(prog)s compare v0.9.0 v1.0.0
        """
    )

    parser.add_argument(
        "command",
        choices=["list", "view", "create", "upload", "download", "delete", "compare", "edit"],
        help="Command to execute"
    )
    parser.add_argument(
        "tag",
        nargs="?",
        help="Release tag (e.g., v1.0.0)"
    )
    parser.add_argument(
        "files",
        nargs="*",
        help="Files to upload (for upload command)"
    )
    parser.add_argument(
        "--repo", "-R",
        help="Repository in format 'owner/name'"
    )
    parser.add_argument(
        "--title", "-t",
        help="Release title"
    )
    parser.add_argument(
        "--notes", "-n",
        help="Release notes"
    )
    parser.add_argument(
        "--generate-notes",
        action="store_true",
        help="Auto-generate release notes"
    )
    parser.add_argument(
        "--draft",
        action="store_true",
        help="Create as draft release"
    )
    parser.add_argument(
        "--prerelease",
        action="store_true",
        help="Mark as prerelease"
    )
    parser.add_argument(
        "--target",
        help="Target commitish (branch or SHA)"
    )
    parser.add_argument(
        "--output-dir", "-D",
        default=".",
        help="Output directory for downloads"
    )
    parser.add_argument(
        "--pattern", "-p",
        help="Pattern to filter assets"
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=10,
        help="Maximum releases to list"
    )
    parser.add_argument(
        "--no-checksums",
        action="store_true",
        help="Don't generate checksums for uploads"
    )
    parser.add_argument(
        "--cleanup-tag",
        action="store_true",
        help="Delete git tag when deleting release"
    )
    parser.add_argument(
        "--compare-to",
        help="Second tag for comparison"
    )
    parser.add_argument(
        "--json",
        action="store_true",
        dest="json_output",
        help="Output as JSON"
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print JSON output"
    )

    args = parser.parse_args()

    # Check gh CLI
    try:
        subprocess.run(["gh", "--version"], capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("Error: gh CLI is not installed", file=sys.stderr)
        sys.exit(1)

    result = {}

    if args.command == "list":
        result = list_releases(args.repo, args.limit)
        if not args.json_output:
            for rel in result:
                status = []
                if rel.get("isDraft"):
                    status.append("draft")
                if rel.get("isPrerelease"):
                    status.append("prerelease")
                status_str = f" ({', '.join(status)})" if status else ""
                print(f"{rel['tagName']}: {rel.get('name', '')}{status_str}")

    elif args.command == "view":
        if not args.tag:
            print("Error: tag is required", file=sys.stderr)
            sys.exit(1)
        result = get_release(args.tag, args.repo)
        if not result:
            print(f"Release {args.tag} not found", file=sys.stderr)
            sys.exit(1)
        if not args.json_output:
            print(f"Tag: {result['tagName']}")
            print(f"Name: {result.get('name', '')}")
            print(f"Published: {result.get('publishedAt', 'N/A')}")
            print(f"Draft: {result.get('isDraft', False)}")
            print(f"Prerelease: {result.get('isPrerelease', False)}")
            print(f"\nAssets ({len(result.get('assets', []))}):")
            for asset in result.get("assets", []):
                print(f"  - {asset['name']} ({asset.get('size', 0)} bytes)")

    elif args.command == "create":
        if not args.tag:
            print("Error: tag is required", file=sys.stderr)
            sys.exit(1)
        result = create_release(
            tag=args.tag,
            title=args.title,
            notes=args.notes,
            generate_notes=args.generate_notes,
            draft=args.draft,
            prerelease=args.prerelease,
            target=args.target,
            repo=args.repo
        )
        if not args.json_output:
            print(f"Created release: {result['url']}")

    elif args.command == "upload":
        if not args.tag:
            print("Error: tag is required", file=sys.stderr)
            sys.exit(1)
        if not args.files:
            print("Error: files are required", file=sys.stderr)
            sys.exit(1)
        result = upload_assets(
            tag=args.tag,
            files=args.files,
            checksums=not args.no_checksums,
            repo=args.repo
        )
        if not args.json_output:
            print(f"Uploaded {len(result['uploaded'])} files to {args.tag}")
            for f in result["uploaded"]:
                print(f"  + {f['file']}")
            for f in result["failed"]:
                print(f"  x {f['file']}: {f['error']}")

    elif args.command == "download":
        if not args.tag:
            print("Error: tag is required", file=sys.stderr)
            sys.exit(1)
        result = download_assets(
            tag=args.tag,
            output_dir=args.output_dir,
            pattern=args.pattern,
            repo=args.repo
        )
        if not args.json_output:
            if result["success"]:
                print(f"Downloaded assets to {args.output_dir}")
            else:
                print(f"Download failed: {result['message']}")

    elif args.command == "delete":
        if not args.tag:
            print("Error: tag is required", file=sys.stderr)
            sys.exit(1)
        result = delete_release(
            tag=args.tag,
            cleanup_tag=args.cleanup_tag,
            repo=args.repo
        )
        if not args.json_output:
            if result["success"]:
                print(f"Deleted release {args.tag}")
            else:
                print(f"Failed: {result['message']}")

    elif args.command == "compare":
        if not args.tag or not args.compare_to:
            print("Error: two tags required (--compare-to)", file=sys.stderr)
            sys.exit(1)
        result = compare_releases(args.tag, args.compare_to, args.repo)
        if not args.json_output:
            if "error" in result:
                print(f"Error: {result['error']}")
                sys.exit(1)
            print(f"Comparing {result['from']} -> {result['to']}")
            print(f"\nAssets added: {len(result['assets']['added'])}")
            for name in result['assets']['added']:
                print(f"  + {name}")
            print(f"\nAssets removed: {len(result['assets']['removed'])}")
            for name in result['assets']['removed']:
                print(f"  - {name}")
            if result.get("compare_url"):
                print(f"\nCompare URL: {result['compare_url']}")

    elif args.command == "edit":
        if not args.tag:
            print("Error: tag is required", file=sys.stderr)
            sys.exit(1)
        result = edit_release(
            tag=args.tag,
            title=args.title,
            notes=args.notes,
            draft=args.draft if args.draft else None,
            prerelease=args.prerelease if args.prerelease else None,
            repo=args.repo
        )
        if not args.json_output:
            if result["success"]:
                print(f"Updated release {args.tag}")
            else:
                print(f"Failed: {result['message']}")

    # JSON output
    if args.json_output:
        if args.pretty:
            print(json.dumps(result, indent=2))
        else:
            print(json.dumps(result))


if __name__ == "__main__":
    main()
