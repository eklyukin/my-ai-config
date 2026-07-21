# GitHub PR Workflow Automation

`gh_pr_workflow.py` - Complete pull request lifecycle automation.

## Overview

Automates the full PR workflow: create PRs, wait for CI checks, request reviewers, and merge with various strategies. Designed for CI/CD pipelines and agent automation.

## Commands

| Command | Description |
|---------|-------------|
| `create` | Create a new PR |
| `status` | Get PR status for current branch |
| `checks` | Get CI check status |
| `wait` | Wait for CI checks to complete |
| `ready` | Mark draft PR as ready for review |
| `merge` | Merge the PR |
| `full` | Run full workflow (create, wait, merge) |

## Installation

Requires:
- Python 3.7+
- GitHub CLI (`gh`) authenticated

```bash
chmod +x gh_pr_workflow.py
```

## Usage

### Create PR

```bash
# Create with auto-fill from commits
python3 gh_pr_workflow.py create

# Create draft PR
python3 gh_pr_workflow.py create --draft

# Create with explicit title
python3 gh_pr_workflow.py create --title "Feature: Add login" --body "Description"

# Create targeting specific base branch
python3 gh_pr_workflow.py create --base develop

# JSON output
python3 gh_pr_workflow.py create --json --pretty
```

### Check Status

```bash
# Get PR status for current branch
python3 gh_pr_workflow.py status

# JSON output
python3 gh_pr_workflow.py status --json
```

### CI Checks

```bash
# Get current check status
python3 gh_pr_workflow.py checks

# Wait for checks to complete (default 30 min timeout)
python3 gh_pr_workflow.py wait

# Wait with custom timeout (1 hour)
python3 gh_pr_workflow.py wait --timeout 3600
```

### Mark Ready

```bash
# Mark draft PR as ready for review
python3 gh_pr_workflow.py ready
```

### Merge

```bash
# Squash merge (default)
python3 gh_pr_workflow.py merge

# Rebase merge
python3 gh_pr_workflow.py merge --merge-strategy rebase

# Regular merge
python3 gh_pr_workflow.py merge --merge-strategy merge

# Enable auto-merge (merges when checks pass)
python3 gh_pr_workflow.py merge --auto-merge
```

### Full Workflow

Run the complete workflow: create, wait for checks, request reviewers, merge.

```bash
# Basic: create, wait, merge
python3 gh_pr_workflow.py full

# With reviewers (waits for approval before merge)
python3 gh_pr_workflow.py full --reviewers user1,user2

# Draft PR with auto-merge
python3 gh_pr_workflow.py full --draft --auto-merge

# Skip waiting for checks
python3 gh_pr_workflow.py full --no-wait

# Full options
python3 gh_pr_workflow.py full \
  --title "Feature: New login" \
  --base develop \
  --reviewers alice,bob \
  --merge-strategy rebase \
  --timeout 3600
```

## Options

| Option | Description |
|--------|-------------|
| `--repo, -R` | Repository in format 'owner/name' |
| `--title, -t` | PR title |
| `--body, -b` | PR body |
| `--base` | Target branch for PR |
| `--draft` | Create as draft PR |
| `--reviewers` | Comma-separated list of reviewers |
| `--merge-strategy` | squash, rebase, or merge (default: squash) |
| `--auto-merge` | Enable auto-merge instead of immediate merge |
| `--timeout` | Check wait timeout in seconds (default: 1800) |
| `--no-wait` | Don't wait for CI checks |
| `--json` | Output as JSON |
| `--pretty` | Pretty-print JSON output |

## Output

### Human-readable (default)

```
Step 1: Creating PR...
  Created PR #123: https://github.com/owner/repo/pull/123

Step 2: Waiting for CI checks...
  [30s] 2/5 checks completed, 3 running...
  [60s] 4/5 checks completed, 1 running...
  [90s] 5/5 checks completed
  All checks passed in 95s

Step 3: Merging...
  Pull request #123 merged
```

### JSON output (`--json --pretty`)

```json
{
  "steps": [
    {
      "step": "create",
      "success": true,
      "pr_number": 123,
      "url": "https://github.com/owner/repo/pull/123"
    },
    {
      "step": "wait_checks",
      "success": true,
      "elapsed": 95,
      "failed": []
    },
    {
      "step": "merge",
      "success": true,
      "message": "Pull request #123 merged",
      "strategy": "squash",
      "auto": false
    }
  ],
  "success": true,
  "pr": {
    "number": 123,
    "title": "Feature: Add login",
    "url": "https://github.com/owner/repo/pull/123"
  }
}
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Error (command failed, checks failed, etc.) |

## Use Cases

### CI/CD Pipeline

```bash
# In GitHub Actions or other CI
python3 gh_pr_workflow.py full --no-wait --auto-merge
```

### Code Review Workflow

```bash
# Create PR and request review
python3 gh_pr_workflow.py create --draft
python3 gh_pr_workflow.py wait
python3 gh_pr_workflow.py ready
python3 gh_pr_workflow.py full --reviewers lead-dev,peer
```

### Automated Merge

```bash
# Wait for checks and merge if passing
python3 gh_pr_workflow.py wait && python3 gh_pr_workflow.py merge
```

## Error Handling

The script handles common errors:

- No PR for current branch
- CI checks failing
- Merge conflicts
- Permission issues
- Rate limiting

Failed operations return non-zero exit codes and descriptive error messages.

## Integration

### With Other Scripts

```bash
# Create PR, analyze if it fails
python3 gh_pr_workflow.py full || python3 gh_failed_run.py --pretty
```

### Piping JSON

```bash
# Get PR number for other commands
PR_NUM=$(python3 gh_pr_workflow.py status --json | jq -r '.number')
gh pr view $PR_NUM --web
```
