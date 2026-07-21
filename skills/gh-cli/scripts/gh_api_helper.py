#!/usr/bin/env python3
"""
GitHub API Helper

Simplified API access with pre-built queries, pagination handling,
and common patterns for repository statistics and management.
"""

import argparse
import json
import subprocess
import sys
from typing import Optional, Dict, List, Any


def run_gh_api(
    endpoint: str,
    method: str = "GET",
    fields: Optional[Dict[str, str]] = None,
    jq: Optional[str] = None,
    paginate: bool = False,
    cache: Optional[str] = None,
    hostname: Optional[str] = None
) -> Any:
    """
    Execute a gh api command.

    Args:
        endpoint: API endpoint
        method: HTTP method
        fields: Field parameters (-f key=value)
        jq: jq filter expression
        paginate: Enable pagination
        cache: Cache duration (e.g., "1h")
        hostname: GitHub hostname for GHES

    Returns:
        Parsed JSON response
    """
    cmd = ["gh", "api", endpoint]

    if method != "GET":
        cmd.extend(["-X", method])
    if fields:
        for key, value in fields.items():
            cmd.extend(["-f", f"{key}={value}"])
    if jq:
        cmd.extend(["--jq", jq])
    if paginate:
        cmd.append("--paginate")
    if cache:
        cmd.extend(["--cache", cache])
    if hostname:
        cmd.extend(["--hostname", hostname])

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True
        )
        if not result.stdout.strip():
            return {}
        try:
            return json.loads(result.stdout)
        except json.JSONDecodeError:
            # Return raw output if not JSON
            return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"API Error: {e.stderr}", file=sys.stderr)
        return {"error": e.stderr}


def run_graphql(
    query: str,
    variables: Optional[Dict[str, Any]] = None,
    paginate: bool = False
) -> Any:
    """
    Execute a GraphQL query.

    Args:
        query: GraphQL query string
        variables: Query variables
        paginate: Enable pagination

    Returns:
        Query result
    """
    cmd = ["gh", "api", "graphql", "-f", f"query={query}"]

    if variables:
        for key, value in variables.items():
            # Use -F for typed variables, -f for strings
            if isinstance(value, (int, float, bool)):
                cmd.extend(["-F", f"{key}={value}"])
            else:
                cmd.extend(["-f", f"{key}={value}"])

    if paginate:
        cmd.append("--paginate")

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True
        )
        return json.loads(result.stdout) if result.stdout else {}
    except subprocess.CalledProcessError as e:
        print(f"GraphQL Error: {e.stderr}", file=sys.stderr)
        return {"error": e.stderr}


def get_repo_stats(repo: str) -> Dict[str, Any]:
    """
    Get comprehensive repository statistics.

    Args:
        repo: Repository in format 'owner/name'

    Returns:
        Repository statistics
    """
    owner, name = repo.split("/")

    query = """
    query($owner: String!, $name: String!) {
      repository(owner: $owner, name: $name) {
        name
        description
        url
        isPrivate
        isFork
        isArchived
        createdAt
        updatedAt
        pushedAt
        diskUsage
        stargazerCount
        forkCount
        watchers { totalCount }
        issues(states: OPEN) { totalCount }
        pullRequests(states: OPEN) { totalCount }
        defaultBranchRef { name }
        primaryLanguage { name }
        languages(first: 10) {
          edges {
            size
            node { name color }
          }
        }
        releases(first: 1, orderBy: {field: CREATED_AT, direction: DESC}) {
          nodes { tagName publishedAt }
        }
      }
    }
    """

    result = run_graphql(query, {"owner": owner, "name": name})

    if "error" in result:
        return result

    repo_data = result.get("data", {}).get("repository", {})

    return {
        "name": repo_data.get("name"),
        "description": repo_data.get("description"),
        "url": repo_data.get("url"),
        "private": repo_data.get("isPrivate"),
        "fork": repo_data.get("isFork"),
        "archived": repo_data.get("isArchived"),
        "created": repo_data.get("createdAt"),
        "updated": repo_data.get("updatedAt"),
        "pushed": repo_data.get("pushedAt"),
        "size_kb": repo_data.get("diskUsage"),
        "stars": repo_data.get("stargazerCount"),
        "forks": repo_data.get("forkCount"),
        "watchers": repo_data.get("watchers", {}).get("totalCount"),
        "open_issues": repo_data.get("issues", {}).get("totalCount"),
        "open_prs": repo_data.get("pullRequests", {}).get("totalCount"),
        "default_branch": repo_data.get("defaultBranchRef", {}).get("name"),
        "primary_language": repo_data.get("primaryLanguage", {}).get("name") if repo_data.get("primaryLanguage") else None,
        "languages": [
            {"name": edge["node"]["name"], "bytes": edge["size"]}
            for edge in repo_data.get("languages", {}).get("edges", [])
        ],
        "latest_release": repo_data.get("releases", {}).get("nodes", [{}])[0].get("tagName") if repo_data.get("releases", {}).get("nodes") else None
    }


def get_contributors(repo: str, limit: int = 30) -> List[Dict[str, Any]]:
    """
    Get repository contributors.

    Args:
        repo: Repository in format 'owner/name'
        limit: Maximum contributors to return

    Returns:
        List of contributors
    """
    result = run_gh_api(
        f"repos/{repo}/contributors",
        jq=f".[:{limit}] | .[] | {{login, contributions, avatar_url, html_url}}"
    )

    if isinstance(result, str):
        # Parse line-by-line JSON
        contributors = []
        for line in result.strip().split("\n"):
            if line:
                try:
                    contributors.append(json.loads(line))
                except json.JSONDecodeError:
                    pass
        return contributors

    return result if isinstance(result, list) else []


def get_traffic(repo: str) -> Dict[str, Any]:
    """
    Get repository traffic statistics.

    Args:
        repo: Repository in format 'owner/name'

    Returns:
        Traffic data
    """
    views = run_gh_api(f"repos/{repo}/traffic/views")
    clones = run_gh_api(f"repos/{repo}/traffic/clones")
    referrers = run_gh_api(f"repos/{repo}/traffic/popular/referrers")
    paths = run_gh_api(f"repos/{repo}/traffic/popular/paths")

    return {
        "views": views if not isinstance(views, dict) or "error" not in views else None,
        "clones": clones if not isinstance(clones, dict) or "error" not in clones else None,
        "top_referrers": referrers if isinstance(referrers, list) else [],
        "top_paths": paths if isinstance(paths, list) else []
    }


def get_workflow_stats(repo: str) -> Dict[str, Any]:
    """
    Get GitHub Actions workflow statistics.

    Args:
        repo: Repository in format 'owner/name'

    Returns:
        Workflow statistics
    """
    # Get workflows
    workflows = run_gh_api(f"repos/{repo}/actions/workflows")

    # Get recent runs
    runs = run_gh_api(
        f"repos/{repo}/actions/runs",
        jq=".workflow_runs[:20] | .[] | {id, name, conclusion, created_at, run_number}"
    )

    # Parse runs
    run_list = []
    if isinstance(runs, str):
        for line in runs.strip().split("\n"):
            if line:
                try:
                    run_list.append(json.loads(line))
                except json.JSONDecodeError:
                    pass
    elif isinstance(runs, list):
        run_list = runs

    # Calculate stats
    conclusions = {}
    for run in run_list:
        conclusion = run.get("conclusion") or "in_progress"
        conclusions[conclusion] = conclusions.get(conclusion, 0) + 1

    return {
        "total_workflows": workflows.get("total_count", 0) if isinstance(workflows, dict) else 0,
        "workflows": [
            {"name": w["name"], "state": w["state"], "path": w["path"]}
            for w in workflows.get("workflows", [])
        ] if isinstance(workflows, dict) else [],
        "recent_runs": run_list,
        "run_stats": conclusions
    }


def get_rate_limit() -> Dict[str, Any]:
    """
    Get API rate limit status.

    Returns:
        Rate limit information
    """
    return run_gh_api("rate_limit")


def search_code(
    query: str,
    repo: Optional[str] = None,
    language: Optional[str] = None,
    path: Optional[str] = None,
    limit: int = 30
) -> List[Dict[str, Any]]:
    """
    Search code across GitHub.

    Args:
        query: Search query
        repo: Limit to repository
        language: Filter by language
        path: Filter by path
        limit: Maximum results

    Returns:
        Search results
    """
    search_query = query
    if repo:
        search_query += f" repo:{repo}"
    if language:
        search_query += f" language:{language}"
    if path:
        search_query += f" path:{path}"

    result = run_gh_api(
        f"search/code?q={search_query}&per_page={limit}",
        cache="5m"
    )

    if isinstance(result, dict) and "items" in result:
        return [
            {
                "repository": item["repository"]["full_name"],
                "path": item["path"],
                "url": item["html_url"],
                "score": item.get("score")
            }
            for item in result["items"]
        ]

    return []


def create_issue(
    repo: str,
    title: str,
    body: Optional[str] = None,
    labels: Optional[List[str]] = None,
    assignees: Optional[List[str]] = None
) -> Dict[str, Any]:
    """
    Create an issue.

    Args:
        repo: Repository in format 'owner/name'
        title: Issue title
        body: Issue body
        labels: Label names
        assignees: Assignee usernames

    Returns:
        Created issue data
    """
    fields = {"title": title}
    if body:
        fields["body"] = body
    if labels:
        fields["labels"] = json.dumps(labels)
    if assignees:
        fields["assignees"] = json.dumps(assignees)

    return run_gh_api(
        f"repos/{repo}/issues",
        method="POST",
        fields=fields
    )


def get_user_info(username: Optional[str] = None) -> Dict[str, Any]:
    """
    Get user information.

    Args:
        username: GitHub username (default: authenticated user)

    Returns:
        User information
    """
    endpoint = f"users/{username}" if username else "user"
    return run_gh_api(endpoint, cache="1h")


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="GitHub API Helper",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Commands:
  repo-stats    Get repository statistics
  contributors  List repository contributors
  traffic       Get traffic statistics (requires push access)
  workflows     Get workflow statistics
  rate-limit    Check API rate limit
  search        Search code
  user          Get user information
  raw           Execute raw API call

Examples:
  %(prog)s repo-stats owner/repo
  %(prog)s contributors owner/repo --limit 10
  %(prog)s traffic owner/repo
  %(prog)s workflows owner/repo
  %(prog)s rate-limit
  %(prog)s search "pattern" --repo owner/repo --language python
  %(prog)s user
  %(prog)s user octocat
  %(prog)s raw repos/owner/repo/releases
        """
    )

    parser.add_argument(
        "command",
        choices=["repo-stats", "contributors", "traffic", "workflows",
                 "rate-limit", "search", "user", "raw"],
        help="Command to execute"
    )
    parser.add_argument(
        "args",
        nargs="*",
        help="Command arguments"
    )
    parser.add_argument(
        "--repo", "-R",
        help="Repository in format 'owner/name'"
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=30,
        help="Maximum results"
    )
    parser.add_argument(
        "--language",
        help="Filter by language (for search)"
    )
    parser.add_argument(
        "--path",
        help="Filter by path (for search)"
    )
    parser.add_argument(
        "--jq",
        help="jq filter for raw API calls"
    )
    parser.add_argument(
        "--paginate",
        action="store_true",
        help="Enable pagination for raw API calls"
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

    if args.command == "repo-stats":
        repo = args.args[0] if args.args else args.repo
        if not repo:
            print("Error: repository required", file=sys.stderr)
            sys.exit(1)
        result = get_repo_stats(repo)
        if not args.json_output:
            print(f"Repository: {result.get('name')}")
            print(f"Description: {result.get('description', 'N/A')}")
            print(f"URL: {result.get('url')}")
            print(f"Stars: {result.get('stars', 0)}")
            print(f"Forks: {result.get('forks', 0)}")
            print(f"Open Issues: {result.get('open_issues', 0)}")
            print(f"Open PRs: {result.get('open_prs', 0)}")
            print(f"Primary Language: {result.get('primary_language', 'N/A')}")
            print(f"Latest Release: {result.get('latest_release', 'N/A')}")
            return

    elif args.command == "contributors":
        repo = args.args[0] if args.args else args.repo
        if not repo:
            print("Error: repository required", file=sys.stderr)
            sys.exit(1)
        result = get_contributors(repo, args.limit)
        if not args.json_output:
            print(f"Top contributors for {repo}:")
            for contrib in result:
                print(f"  {contrib.get('login')}: {contrib.get('contributions')} contributions")
            return

    elif args.command == "traffic":
        repo = args.args[0] if args.args else args.repo
        if not repo:
            print("Error: repository required", file=sys.stderr)
            sys.exit(1)
        result = get_traffic(repo)
        if not args.json_output:
            views = result.get("views", {}) or {}
            clones = result.get("clones", {}) or {}
            print(f"Traffic for {repo}:")
            print(f"  Views: {views.get('count', 'N/A')} ({views.get('uniques', 'N/A')} unique)")
            print(f"  Clones: {clones.get('count', 'N/A')} ({clones.get('uniques', 'N/A')} unique)")
            print(f"  Top referrers: {len(result.get('top_referrers', []))}")
            return

    elif args.command == "workflows":
        repo = args.args[0] if args.args else args.repo
        if not repo:
            print("Error: repository required", file=sys.stderr)
            sys.exit(1)
        result = get_workflow_stats(repo)
        if not args.json_output:
            print(f"Workflows for {repo}:")
            print(f"  Total workflows: {result.get('total_workflows', 0)}")
            for wf in result.get("workflows", []):
                print(f"    - {wf['name']} ({wf['state']})")
            print(f"\nRecent run stats: {result.get('run_stats', {})}")
            return

    elif args.command == "rate-limit":
        result = get_rate_limit()
        if not args.json_output:
            core = result.get("resources", {}).get("core", {})
            search = result.get("resources", {}).get("search", {})
            graphql = result.get("resources", {}).get("graphql", {})
            print("API Rate Limits:")
            print(f"  Core: {core.get('remaining', 'N/A')}/{core.get('limit', 'N/A')}")
            print(f"  Search: {search.get('remaining', 'N/A')}/{search.get('limit', 'N/A')}")
            print(f"  GraphQL: {graphql.get('remaining', 'N/A')}/{graphql.get('limit', 'N/A')}")
            return

    elif args.command == "search":
        query = " ".join(args.args) if args.args else ""
        if not query:
            print("Error: search query required", file=sys.stderr)
            sys.exit(1)
        result = search_code(query, args.repo, args.language, args.path, args.limit)
        if not args.json_output:
            print(f"Search results for '{query}':")
            for item in result:
                print(f"  {item['repository']}: {item['path']}")
            print(f"\nTotal: {len(result)} results")
            return

    elif args.command == "user":
        username = args.args[0] if args.args else None
        result = get_user_info(username)
        if not args.json_output:
            print(f"User: {result.get('login')}")
            print(f"Name: {result.get('name', 'N/A')}")
            print(f"Company: {result.get('company', 'N/A')}")
            print(f"Location: {result.get('location', 'N/A')}")
            print(f"Public repos: {result.get('public_repos', 0)}")
            print(f"Followers: {result.get('followers', 0)}")
            return

    elif args.command == "raw":
        endpoint = args.args[0] if args.args else None
        if not endpoint:
            print("Error: endpoint required", file=sys.stderr)
            sys.exit(1)
        result = run_gh_api(endpoint, jq=args.jq, paginate=args.paginate)

    # JSON output
    if args.json_output or args.command == "raw":
        if args.pretty:
            print(json.dumps(result, indent=2))
        else:
            print(json.dumps(result))


if __name__ == "__main__":
    main()
