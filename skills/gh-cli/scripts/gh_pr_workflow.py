#!/usr/bin/env python3
"""
GitHub PR Workflow Automation

Complete pull request lifecycle automation: create, wait for checks,
request reviewers, and merge with various strategies.
"""

import argparse
import json
import subprocess
import sys
import time
from typing import Optional, Dict, List, Any


def run_gh_command(cmd: List[str], check: bool = True) -> subprocess.CompletedProcess:
    """
    Execute a gh CLI command.

    Args:
        cmd: List of command arguments to pass to gh
        check: Whether to raise on non-zero exit

    Returns:
        CompletedProcess result

    Raises:
        SystemExit: If command fails and check=True
    """
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=check
        )
        return result
    except subprocess.CalledProcessError as e:
        print(f"Error running: {' '.join(cmd)}", file=sys.stderr)
        print(f"Error: {e.stderr}", file=sys.stderr)
        if check:
            sys.exit(1)
        return e


def run_gh_json(cmd: List[str]) -> Any:
    """
    Execute gh command and parse JSON output.

    Args:
        cmd: Command arguments

    Returns:
        Parsed JSON data
    """
    result = run_gh_command(cmd)
    try:
        return json.loads(result.stdout) if result.stdout else {}
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON: {e}", file=sys.stderr)
        sys.exit(1)


def get_current_branch() -> str:
    """Get the current git branch name."""
    result = subprocess.run(
        ["git", "rev-parse", "--abbrev-ref", "HEAD"],
        capture_output=True,
        text=True,
        check=True
    )
    return result.stdout.strip()


def get_current_pr(repo: Optional[str] = None) -> Optional[Dict[str, Any]]:
    """
    Get the PR for the current branch.

    Args:
        repo: Optional repository in format 'owner/name'

    Returns:
        PR data dict or None
    """
    cmd = [
        "gh", "pr", "view",
        "--json", "number,title,state,url,mergeable,isDraft,headRefName,baseRefName,reviews,statusCheckRollup"
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


def create_pr(
    title: Optional[str] = None,
    body: Optional[str] = None,
    base: Optional[str] = None,
    draft: bool = False,
    fill: bool = True,
    repo: Optional[str] = None
) -> Dict[str, Any]:
    """
    Create a new pull request.

    Args:
        title: PR title (optional if fill=True)
        body: PR body (optional if fill=True)
        base: Target branch
        draft: Create as draft
        fill: Auto-fill from commits
        repo: Optional repository

    Returns:
        Created PR data
    """
    cmd = ["gh", "pr", "create"]

    if fill:
        cmd.append("--fill")
    if title:
        cmd.extend(["--title", title])
    if body:
        cmd.extend(["--body", body])
    if base:
        cmd.extend(["--base", base])
    if draft:
        cmd.append("--draft")
    if repo:
        cmd.extend(["--repo", repo])

    # Get JSON output
    cmd.extend(["--json", "number,title,url,headRefName,baseRefName,isDraft"])

    result = run_gh_command(cmd)
    return json.loads(result.stdout)


def get_check_status(pr_number: int, repo: Optional[str] = None) -> Dict[str, Any]:
    """
    Get CI check status for a PR.

    Args:
        pr_number: PR number
        repo: Optional repository

    Returns:
        Dict with check statuses
    """
    cmd = [
        "gh", "pr", "checks", str(pr_number),
        "--json", "name,state,conclusion,startedAt,completedAt"
    ]
    if repo:
        cmd.extend(["--repo", repo])

    result = run_gh_command(cmd, check=False)
    if result.returncode != 0:
        return {"checks": [], "error": result.stderr}

    try:
        checks = json.loads(result.stdout)
        return {"checks": checks}
    except json.JSONDecodeError:
        return {"checks": [], "error": "Failed to parse checks"}


def wait_for_checks(
    pr_number: int,
    repo: Optional[str] = None,
    timeout: int = 1800,
    poll_interval: int = 30
) -> Dict[str, Any]:
    """
    Wait for CI checks to complete.

    Args:
        pr_number: PR number
        repo: Optional repository
        timeout: Maximum wait time in seconds (default 30 min)
        poll_interval: Time between status checks

    Returns:
        Final check status
    """
    start_time = time.time()
    print(f"Waiting for checks on PR #{pr_number}...")

    while True:
        elapsed = time.time() - start_time
        if elapsed > timeout:
            return {
                "success": False,
                "error": f"Timeout after {timeout} seconds",
                "checks": []
            }

        status = get_check_status(pr_number, repo)
        checks = status.get("checks", [])

        if not checks:
            print(f"  [{int(elapsed)}s] No checks found yet...")
            time.sleep(poll_interval)
            continue

        # Count states
        pending = sum(1 for c in checks if c.get("state") == "PENDING")
        in_progress = sum(1 for c in checks if c.get("state") == "IN_PROGRESS")
        completed = sum(1 for c in checks if c.get("state") in ["SUCCESS", "FAILURE", "ERROR", "NEUTRAL"])

        total = len(checks)
        running = pending + in_progress

        if running > 0:
            print(f"  [{int(elapsed)}s] {completed}/{total} checks completed, {running} running...")
            time.sleep(poll_interval)
            continue

        # All checks completed
        failed = [c for c in checks if c.get("conclusion") in ["FAILURE", "ERROR"]]
        success = len(failed) == 0

        return {
            "success": success,
            "checks": checks,
            "failed": [c["name"] for c in failed],
            "elapsed": int(elapsed)
        }


def mark_ready_for_review(pr_number: int, repo: Optional[str] = None) -> bool:
    """
    Mark a draft PR as ready for review.

    Args:
        pr_number: PR number
        repo: Optional repository

    Returns:
        Success status
    """
    cmd = ["gh", "pr", "ready", str(pr_number)]
    if repo:
        cmd.extend(["--repo", repo])

    result = run_gh_command(cmd, check=False)
    return result.returncode == 0


def request_reviewers(
    pr_number: int,
    reviewers: List[str],
    repo: Optional[str] = None
) -> bool:
    """
    Request reviewers for a PR.

    Args:
        pr_number: PR number
        reviewers: List of usernames
        repo: Optional repository

    Returns:
        Success status
    """
    cmd = ["gh", "pr", "edit", str(pr_number), "--add-reviewer", ",".join(reviewers)]
    if repo:
        cmd.extend(["--repo", repo])

    result = run_gh_command(cmd, check=False)
    return result.returncode == 0


def merge_pr(
    pr_number: int,
    strategy: str = "squash",
    delete_branch: bool = True,
    auto: bool = False,
    repo: Optional[str] = None
) -> Dict[str, Any]:
    """
    Merge a pull request.

    Args:
        pr_number: PR number
        strategy: Merge strategy (squash, rebase, merge)
        delete_branch: Delete branch after merge
        auto: Enable auto-merge
        repo: Optional repository

    Returns:
        Merge result
    """
    cmd = ["gh", "pr", "merge", str(pr_number), f"--{strategy}"]

    if delete_branch:
        cmd.append("--delete-branch")
    if auto:
        cmd.append("--auto")
    if repo:
        cmd.extend(["--repo", repo])

    result = run_gh_command(cmd, check=False)

    return {
        "success": result.returncode == 0,
        "message": result.stdout.strip() if result.stdout else result.stderr.strip()
    }


def get_review_status(pr_number: int, repo: Optional[str] = None) -> Dict[str, Any]:
    """
    Get review status for a PR.

    Args:
        pr_number: PR number
        repo: Optional repository

    Returns:
        Review status data
    """
    cmd = [
        "gh", "pr", "view", str(pr_number),
        "--json", "reviews,reviewRequests,reviewDecision"
    ]
    if repo:
        cmd.extend(["--repo", repo])

    return run_gh_json(cmd)


def full_workflow(
    title: Optional[str] = None,
    body: Optional[str] = None,
    base: Optional[str] = None,
    draft: bool = False,
    reviewers: Optional[List[str]] = None,
    wait_checks: bool = True,
    merge_strategy: str = "squash",
    auto_merge: bool = False,
    repo: Optional[str] = None,
    timeout: int = 1800
) -> Dict[str, Any]:
    """
    Execute full PR workflow: create, wait, review, merge.

    Args:
        title: PR title
        body: PR body
        base: Target branch
        draft: Create as draft
        reviewers: List of reviewers to request
        wait_checks: Wait for CI checks
        merge_strategy: Merge strategy
        auto_merge: Enable auto-merge
        repo: Optional repository
        timeout: Check wait timeout

    Returns:
        Workflow result
    """
    result = {
        "steps": [],
        "success": True,
        "pr": None
    }

    # Step 1: Create PR
    print("Step 1: Creating PR...")
    try:
        pr = create_pr(
            title=title,
            body=body,
            base=base,
            draft=draft,
            fill=True,
            repo=repo
        )
        result["pr"] = pr
        result["steps"].append({
            "step": "create",
            "success": True,
            "pr_number": pr["number"],
            "url": pr["url"]
        })
        print(f"  Created PR #{pr['number']}: {pr['url']}")
    except Exception as e:
        result["success"] = False
        result["steps"].append({
            "step": "create",
            "success": False,
            "error": str(e)
        })
        return result

    pr_number = pr["number"]

    # Step 2: Wait for checks
    if wait_checks:
        print("\nStep 2: Waiting for CI checks...")
        check_result = wait_for_checks(pr_number, repo, timeout)
        result["steps"].append({
            "step": "wait_checks",
            "success": check_result["success"],
            "elapsed": check_result.get("elapsed"),
            "failed": check_result.get("failed", [])
        })

        if not check_result["success"]:
            print(f"  CI checks failed: {check_result.get('failed', [])}")
            result["success"] = False
            return result
        print(f"  All checks passed in {check_result.get('elapsed', 0)}s")

    # Step 3: Mark ready for review (if draft)
    if draft:
        print("\nStep 3: Marking ready for review...")
        ready_success = mark_ready_for_review(pr_number, repo)
        result["steps"].append({
            "step": "ready",
            "success": ready_success
        })
        if ready_success:
            print("  PR marked ready for review")
        else:
            print("  Failed to mark ready")

    # Step 4: Request reviewers
    if reviewers:
        print(f"\nStep 4: Requesting reviewers: {', '.join(reviewers)}...")
        review_success = request_reviewers(pr_number, reviewers, repo)
        result["steps"].append({
            "step": "request_reviewers",
            "success": review_success,
            "reviewers": reviewers
        })
        if review_success:
            print("  Reviewers requested")
        else:
            print("  Failed to request reviewers")

    # Step 5: Merge (if auto-merge or no reviewers)
    if auto_merge or (not reviewers and not draft):
        print(f"\nStep 5: {'Enabling auto-merge' if auto_merge else 'Merging'}...")
        merge_result = merge_pr(
            pr_number,
            strategy=merge_strategy,
            delete_branch=True,
            auto=auto_merge,
            repo=repo
        )
        result["steps"].append({
            "step": "merge",
            "success": merge_result["success"],
            "message": merge_result["message"],
            "strategy": merge_strategy,
            "auto": auto_merge
        })
        if merge_result["success"]:
            print(f"  {merge_result['message']}")
        else:
            print(f"  Merge failed: {merge_result['message']}")
            result["success"] = False

    return result


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="GitHub PR Workflow Automation",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Commands:
  create    Create a new PR
  status    Get PR status for current branch
  checks    Get CI check status
  wait      Wait for CI checks to complete
  ready     Mark draft PR as ready for review
  merge     Merge the PR
  full      Run full workflow (create, wait, merge)

Examples:
  %(prog)s create --draft
  %(prog)s create --title "Feature" --base develop
  %(prog)s checks
  %(prog)s wait --timeout 3600
  %(prog)s merge --strategy squash
  %(prog)s full --reviewers user1,user2 --merge-strategy rebase
        """
    )

    parser.add_argument(
        "command",
        choices=["create", "status", "checks", "wait", "ready", "merge", "full"],
        help="Command to execute"
    )
    parser.add_argument(
        "--repo", "-R",
        help="Repository in format 'owner/name'"
    )
    parser.add_argument(
        "--title", "-t",
        help="PR title"
    )
    parser.add_argument(
        "--body", "-b",
        help="PR body"
    )
    parser.add_argument(
        "--base",
        help="Target branch for PR"
    )
    parser.add_argument(
        "--draft",
        action="store_true",
        help="Create as draft PR"
    )
    parser.add_argument(
        "--reviewers",
        help="Comma-separated list of reviewers"
    )
    parser.add_argument(
        "--merge-strategy",
        choices=["squash", "rebase", "merge"],
        default="squash",
        help="Merge strategy (default: squash)"
    )
    parser.add_argument(
        "--auto-merge",
        action="store_true",
        help="Enable auto-merge instead of immediate merge"
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=1800,
        help="Timeout for waiting on checks in seconds (default: 1800)"
    )
    parser.add_argument(
        "--no-wait",
        action="store_true",
        help="Don't wait for CI checks"
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

    # Check if gh CLI is installed
    try:
        subprocess.run(["gh", "--version"], capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("Error: gh CLI is not installed or not in PATH", file=sys.stderr)
        print("Install from: https://cli.github.com/", file=sys.stderr)
        sys.exit(1)

    reviewers = args.reviewers.split(",") if args.reviewers else None
    result = {}

    if args.command == "create":
        result = create_pr(
            title=args.title,
            body=args.body,
            base=args.base,
            draft=args.draft,
            fill=True,
            repo=args.repo
        )
        if not args.json_output:
            print(f"Created PR #{result['number']}: {result['url']}")

    elif args.command == "status":
        result = get_current_pr(args.repo)
        if not result:
            print("No PR found for current branch", file=sys.stderr)
            sys.exit(1)
        if not args.json_output:
            print(f"PR #{result['number']}: {result['title']}")
            print(f"  State: {result['state']}")
            print(f"  URL: {result['url']}")
            print(f"  Mergeable: {result.get('mergeable', 'unknown')}")

    elif args.command == "checks":
        pr = get_current_pr(args.repo)
        if not pr:
            print("No PR found for current branch", file=sys.stderr)
            sys.exit(1)
        result = get_check_status(pr["number"], args.repo)
        if not args.json_output:
            checks = result.get("checks", [])
            for check in checks:
                state = check.get("conclusion") or check.get("state", "UNKNOWN")
                print(f"  {check['name']}: {state}")

    elif args.command == "wait":
        pr = get_current_pr(args.repo)
        if not pr:
            print("No PR found for current branch", file=sys.stderr)
            sys.exit(1)
        result = wait_for_checks(pr["number"], args.repo, args.timeout)
        if not args.json_output:
            if result["success"]:
                print(f"All checks passed in {result['elapsed']}s")
            else:
                print(f"Checks failed: {result.get('failed', [])}")
                sys.exit(1)

    elif args.command == "ready":
        pr = get_current_pr(args.repo)
        if not pr:
            print("No PR found for current branch", file=sys.stderr)
            sys.exit(1)
        success = mark_ready_for_review(pr["number"], args.repo)
        result = {"success": success}
        if not args.json_output:
            print("PR marked ready for review" if success else "Failed to mark ready")

    elif args.command == "merge":
        pr = get_current_pr(args.repo)
        if not pr:
            print("No PR found for current branch", file=sys.stderr)
            sys.exit(1)
        result = merge_pr(
            pr["number"],
            strategy=args.merge_strategy,
            delete_branch=True,
            auto=args.auto_merge,
            repo=args.repo
        )
        if not args.json_output:
            print(result["message"])
            if not result["success"]:
                sys.exit(1)

    elif args.command == "full":
        result = full_workflow(
            title=args.title,
            body=args.body,
            base=args.base,
            draft=args.draft,
            reviewers=reviewers,
            wait_checks=not args.no_wait,
            merge_strategy=args.merge_strategy,
            auto_merge=args.auto_merge,
            repo=args.repo,
            timeout=args.timeout
        )

    # JSON output
    if args.json_output:
        if args.pretty:
            print(json.dumps(result, indent=2))
        else:
            print(json.dumps(result))


if __name__ == "__main__":
    main()
