# GitHub API Helper

`gh_api_helper.py` - Simplified API access with pre-built queries.

## Overview

Provides easy access to common GitHub API operations including repository statistics, contributors, traffic data, and workflow stats. Also supports raw API calls with pagination.

## Commands

| Command | Description |
|---------|-------------|
| `repo-stats` | Get comprehensive repository statistics |
| `contributors` | List repository contributors |
| `traffic` | Get traffic statistics (views, clones) |
| `workflows` | Get GitHub Actions workflow statistics |
| `rate-limit` | Check API rate limit status |
| `search` | Search code across GitHub |
| `user` | Get user information |
| `raw` | Execute raw API call |

## Installation

Requires:
- Python 3.7+
- GitHub CLI (`gh`) authenticated

```bash
chmod +x gh_api_helper.py
```

## Usage

### Repository Statistics

Get comprehensive stats including stars, forks, issues, languages, and latest release.

```bash
# Basic usage
python3 gh_api_helper.py repo-stats owner/repo

# JSON output
python3 gh_api_helper.py repo-stats owner/repo --json --pretty
```

**Output:**
```
Repository: repo
Description: A great project
URL: https://github.com/owner/repo
Stars: 1234
Forks: 567
Open Issues: 23
Open PRs: 5
Primary Language: Python
Latest Release: v1.2.0
```

### Contributors

```bash
# Top contributors
python3 gh_api_helper.py contributors owner/repo

# Limit results
python3 gh_api_helper.py contributors owner/repo --limit 10
```

### Traffic

Requires push access to the repository.

```bash
python3 gh_api_helper.py traffic owner/repo
```

**Output:**
```
Traffic for owner/repo:
  Views: 1234 (567 unique)
  Clones: 89 (45 unique)
  Top referrers: 5
```

### Workflow Statistics

```bash
python3 gh_api_helper.py workflows owner/repo
```

**Output:**
```
Workflows for owner/repo:
  Total workflows: 3
    - CI (active)
    - Deploy (active)
    - Codeql (active)

Recent run stats: {'success': 15, 'failure': 3, 'cancelled': 2}
```

### Rate Limit

Check API rate limits before running batch operations.

```bash
python3 gh_api_helper.py rate-limit
```

**Output:**
```
API Rate Limits:
  Core: 4532/5000
  Search: 28/30
  GraphQL: 4890/5000
```

### Search Code

```bash
# Basic search
python3 gh_api_helper.py search "pattern"

# Search in specific repo
python3 gh_api_helper.py search "TODO" --repo owner/repo

# Filter by language
python3 gh_api_helper.py search "async def" --language python

# Filter by path
python3 gh_api_helper.py search "config" --path "*.yaml"

# Limit results
python3 gh_api_helper.py search "pattern" --limit 10
```

### User Information

```bash
# Current user
python3 gh_api_helper.py user

# Specific user
python3 gh_api_helper.py user octocat
```

### Raw API Calls

Execute any API endpoint with optional jq filtering and pagination.

```bash
# Simple GET
python3 gh_api_helper.py raw repos/owner/repo/releases

# With jq filter
python3 gh_api_helper.py raw repos/owner/repo/commits --jq ".[].sha"

# With pagination
python3 gh_api_helper.py raw repos/owner/repo/stargazers --paginate
```

## Options

| Option | Description |
|--------|-------------|
| `--repo, -R` | Repository in format 'owner/name' |
| `--limit` | Maximum results (default: 30) |
| `--language` | Filter by language (search) |
| `--path` | Filter by path (search) |
| `--jq` | jq filter for raw API |
| `--paginate` | Enable pagination (raw) |
| `--json` | JSON output |
| `--pretty` | Pretty-print JSON |

## JSON Output Examples

### repo-stats

```json
{
  "name": "repo",
  "description": "A great project",
  "url": "https://github.com/owner/repo",
  "private": false,
  "fork": false,
  "archived": false,
  "stars": 1234,
  "forks": 567,
  "watchers": 100,
  "open_issues": 23,
  "open_prs": 5,
  "default_branch": "main",
  "primary_language": "Python",
  "languages": [
    {"name": "Python", "bytes": 150000},
    {"name": "JavaScript", "bytes": 25000}
  ],
  "latest_release": "v1.2.0"
}
```

### contributors

```json
[
  {
    "login": "user1",
    "contributions": 523,
    "avatar_url": "https://...",
    "html_url": "https://github.com/user1"
  }
]
```

## Use Cases

### Pre-commit Check

```bash
# Check rate limit before batch operations
python3 gh_api_helper.py rate-limit --json | jq '.resources.core.remaining'
```

### Repository Report

```bash
# Generate JSON report
python3 gh_api_helper.py repo-stats owner/repo --json --pretty > report.json
```

### Find Code Patterns

```bash
# Security scan
python3 gh_api_helper.py search "eval(" --language python --limit 100
```

### Monitor Workflows

```bash
# Check recent failures
python3 gh_api_helper.py workflows owner/repo --json | jq '.run_stats'
```

## GraphQL Support

The tool uses GraphQL internally for complex queries like `repo-stats`. You can also execute raw GraphQL:

```bash
# Via raw command
python3 gh_api_helper.py raw graphql --jq '.data.viewer.login'
```

## Caching

Some endpoints use caching to reduce API calls:
- User info: 1 hour cache
- Search: 5 minute cache

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Error (API error, missing arguments, etc.) |
