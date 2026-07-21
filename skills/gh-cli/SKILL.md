---
name: gh-cli
description: Comprehensive GitHub CLI skill for all gh operations - PR workflows, issue management, Actions debugging, releases, secrets, API access, and code search. Use this skill when working with GitHub from the command line for any task including repository management, pull requests, issues, workflow runs, releases, secrets, or direct API access. Includes powerful Python utilities for enhanced code search, workflow failure analysis, GitHub Pages, PR automation, release management, secret sync, and API helpers.
---

# GitHub CLI (gh) - Complete Reference

## Overview

The GitHub CLI (`gh`) brings GitHub to your terminal. This skill provides comprehensive command coverage plus powerful Python utilities for complex automation tasks.

**Prerequisites:**
- `gh` CLI installed ([cli.github.com](https://cli.github.com))
- Authenticated: `gh auth login`

**When to use this skill:**
- Creating/managing PRs and issues
- Debugging GitHub Actions failures
- Managing releases and assets
- Syncing secrets across repos
- Direct API access (REST/GraphQL)
- Code search across repositories

---

## Quick Reference

| Category | Command | Purpose |
|----------|---------|---------|
| Auth | `gh auth login` | Authenticate with GitHub |
| Auth | `gh auth status` | Check authentication state |
| Repo | `gh repo clone OWNER/REPO` | Clone repository |
| Repo | `gh repo view --json` | Get repo info as JSON |
| PR | `gh pr create --fill` | Create PR with auto-fill |
| PR | `gh pr list --json` | List PRs as JSON |
| PR | `gh pr merge --squash` | Squash merge PR |
| Issue | `gh issue create -t "Title"` | Create issue |
| Issue | `gh issue list --json` | List issues as JSON |
| Actions | `gh run list --status failure` | Find failed runs |
| Actions | `gh run view --log-failed` | Get failure logs |
| Actions | `gh workflow run NAME` | Trigger workflow |
| API | `gh api repos/{owner}/{repo}` | REST API call |
| API | `gh api graphql -f query='...'` | GraphQL query |
| Release | `gh release create TAG` | Create release |
| Secret | `gh secret set NAME` | Set repository secret |
| Protect | `gh api .../branches/main/protection` | Branch protection rules |

---

## Core Commands

### gh auth

Authenticate and manage GitHub credentials.

```bash
# Interactive login (browser)
gh auth login

# Non-interactive login with token (for CI/automation)
echo "$GH_TOKEN" | gh auth login --with-token

# Check auth status
gh auth status

# Get current token (for API use)
gh auth token

# Refresh credentials
gh auth refresh

# Login with specific scopes
gh auth login --scopes "repo,read:org,workflow"

# Switch between accounts
gh auth switch
```

### gh repo

Manage repositories.

```bash
# Clone repository
gh repo clone OWNER/REPO

# Clone with specific directory
gh repo clone OWNER/REPO ./target-dir

# View repo info (JSON for parsing)
gh repo view --json name,description,url,defaultBranchRef

# View different repo from anywhere
gh repo view OWNER/REPO --json name,url

# Create new repository (specify visibility to skip prompts)
gh repo create my-repo --public --clone
gh repo create my-repo --private --description "My repo"
gh repo create org/repo-name --private --description "Org repo"

# NOTE: --confirm flag is DEPRECATED - specify --public/--private instead

# Fork a repository
gh repo fork OWNER/REPO --clone

# List your repositories
gh repo list --json name,url,isPrivate --limit 50

# Edit repo settings
gh repo edit --description "New description"
gh repo edit --enable-issues=false
gh repo edit --visibility private

# Archive repository
gh repo archive OWNER/REPO

# Sync fork with upstream
gh repo sync
```

### gh pr

Work with pull requests.

```bash
# Create PR (auto-fill from commits)
gh pr create --fill

# Create draft PR
gh pr create --fill --draft

# Create with explicit title/body
gh pr create --title "Feature: Add login" --body "Description here"

# Create targeting specific base branch
gh pr create --base develop --fill

# List PRs (JSON for parsing)
gh pr list --json number,title,state,author,url

# List your PRs
gh pr list --author @me --json number,title,state

# View PR details
gh pr view 123 --json number,title,body,state,mergeable,reviews

# View PR in browser
gh pr view 123 --web

# Checkout PR locally
gh pr checkout 123

# Check CI status (critical for automation)
gh pr checks 123
gh pr checks 123 --json name,state,conclusion

# Wait for checks to complete (blocking)
gh pr checks 123 --watch

# View PR diff
gh pr diff 123

# Add comment
gh pr comment 123 --body "LGTM!"

# Request reviewers
gh pr edit 123 --add-reviewer username1,username2

# Add labels
gh pr edit 123 --add-label "ready-for-review"

# Merge PR (various strategies)
gh pr merge 123 --squash --delete-branch
gh pr merge 123 --rebase --delete-branch
gh pr merge 123 --merge --delete-branch

# Auto-merge when checks pass
gh pr merge 123 --squash --auto

# Close without merging
gh pr close 123

# Reopen closed PR
gh pr reopen 123

# Review PR
gh pr review 123 --approve
gh pr review 123 --comment --body "Looks good!"
gh pr review 123 --request-changes --body "Please fix X"
```

### gh issue

Manage issues.

```bash
# Create issue (interactive)
gh issue create

# Create issue (non-interactive)
gh issue create --title "Bug: Login fails" --body "Steps to reproduce..."

# Create with labels and assignee
gh issue create --title "Bug" --label bug,priority-high --assignee @me

# List issues (JSON for parsing)
gh issue list --json number,title,state,labels,assignees

# List your issues
gh issue list --assignee @me

# List by label
gh issue list --label bug --state open

# View issue
gh issue view 123 --json number,title,body,comments

# View in browser
gh issue view 123 --web

# Add comment
gh issue comment 123 --body "Working on this"

# Edit issue
gh issue edit 123 --title "New title"
gh issue edit 123 --add-label priority-high

# Close issue
gh issue close 123 --comment "Fixed in PR #456"

# Reopen issue
gh issue reopen 123

# Transfer to another repo
gh issue transfer 123 OWNER/OTHER-REPO
```

### gh browse

Open GitHub in browser or get URLs.

```bash
# Open repo home page
gh browse

# Get URL without opening (for automation)
gh browse --no-browser

# Open specific file
gh browse path/to/file.go

# Open file at specific line
gh browse path/to/file.go:42

# Open file on specific branch
gh browse path/to/file.go --branch feature-branch

# Open issue/PR by number
gh browse 123

# Open settings
gh browse --settings

# Open releases
gh browse --releases

# Open projects
gh browse --projects
```

---

## GitHub Actions Commands

### gh workflow

Manage workflows.

```bash
# List workflows
gh workflow list
gh workflow list --json name,state,id

# View workflow details
gh workflow view "CI"

# Run workflow manually
gh workflow run "CI"

# Run with inputs
gh workflow run "Deploy" -f environment=staging -f version=1.2.3

# Enable/disable workflow
gh workflow enable "CI"
gh workflow disable "CI"
```

### gh run

Monitor and manage workflow runs.

```bash
# List recent runs
gh run list --limit 10
gh run list --json databaseId,conclusion,url,displayTitle

# List failed runs
gh run list --status failure --limit 5

# List runs for specific workflow
gh run list --workflow "CI"

# View run details
gh run view 12345678
gh run view 12345678 --json jobs,conclusion,status

# Get failed job logs (critical for debugging)
gh run view 12345678 --log-failed

# Watch run in progress (blocking)
gh run watch 12345678

# Download artifacts
gh run download 12345678
gh run download 12345678 -n artifact-name -D ./output

# Rerun failed jobs only
gh run rerun 12345678 --failed

# Rerun entire run
gh run rerun 12345678

# Cancel running workflow
gh run cancel 12345678

# Delete run
gh run delete 12345678
```

### gh cache

Manage Actions cache.

```bash
# List caches
gh cache list
gh cache list --json key,sizeInBytes,createdAt

# Delete specific cache
gh cache delete "npm-cache-key"

# Delete all caches matching pattern
gh cache delete --all
```

---

## API Commands

### REST API

Direct access to GitHub REST API.

```bash
# GET request (default)
gh api repos/{owner}/{repo}

# Placeholders are auto-replaced in git repos
gh api repos/{owner}/{repo}/releases

# POST request
gh api repos/{owner}/{repo}/issues -f title="Bug" -f body="Description"

# PATCH request
gh api repos/{owner}/{repo}/issues/123 -X PATCH -f state=closed

# DELETE request
gh api repos/{owner}/{repo}/issues/123/labels/bug -X DELETE

# With pagination (fetch all pages)
gh api repos/{owner}/{repo}/commits --paginate

# Cache responses (faster repeated calls)
gh api user --cache 1h

# Include response headers
gh api repos/{owner}/{repo} --include

# Verbose mode (debug)
gh api repos/{owner}/{repo} --verbose

# Use specific hostname (for GHES)
gh api repos/{owner}/{repo} --hostname github.mycompany.com
```

### jq Filtering

Filter API responses with jq.

```bash
# Extract single field
gh api repos/{owner}/{repo} --jq '.name'

# Extract from array
gh api repos/{owner}/{repo}/pulls --jq '.[].title'

# Multiple fields
gh api repos/{owner}/{repo}/pulls --jq '.[] | {number, title, state}'

# Filter with conditions
gh api repos/{owner}/{repo}/issues --jq '.[] | select(.labels[].name == "bug") | .number'

# Count items
gh api repos/{owner}/{repo}/pulls --jq 'length'

# Format as TSV (for scripts)
gh api repos/{owner}/{repo}/releases --jq '.[] | [.tag_name, .name] | @tsv'

# Get nested data
gh api repos/{owner}/{repo} --jq '.owner.login'
```

### GraphQL API

Access GitHub GraphQL API.

```bash
# Simple query
gh api graphql -f query='{ viewer { login name } }'

# With variables (use -F for typed, -f for string)
gh api graphql -F owner='{owner}' -F name='{repo}' -f query='
  query($owner: String!, $name: String!) {
    repository(owner: $owner, name: $name) {
      description
      stargazerCount
      forkCount
    }
  }
'

# Paginated query
gh api graphql --paginate -f query='
  query($endCursor: String) {
    viewer {
      repositories(first: 100, after: $endCursor) {
        nodes { nameWithOwner }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
  }
'

# Get open issues with labels
gh api graphql -F owner='{owner}' -F name='{repo}' -f query='
  query($owner: String!, $name: String!) {
    repository(owner: $owner, name: $name) {
      issues(first: 10, states: OPEN) {
        nodes {
          number
          title
          labels(first: 5) {
            nodes { name }
          }
        }
      }
    }
  }
'
```

---

## Additional Commands

### gh release

Manage releases.

```bash
# Create release with auto-generated notes
gh release create v1.0.0 --generate-notes

# Create with title
gh release create v1.0.0 --title "Release v1.0.0" --generate-notes

# Create draft release
gh release create v1.0.0 --draft --generate-notes

# Create pre-release
gh release create v1.0.0-beta.1 --prerelease --generate-notes

# Create with specific notes
gh release create v1.0.0 --notes "## Changes\n- Feature A\n- Fix B"

# Upload assets
gh release upload v1.0.0 ./dist/*.zip

# Download assets
gh release download v1.0.0 -D ./output
gh release download v1.0.0 -p "*.tar.gz" -D ./output

# List releases
gh release list
gh release list --json tagName,name,publishedAt

# View release
gh release view v1.0.0 --json tagName,name,body,assets

# Delete release
gh release delete v1.0.0

# Edit release
gh release edit v1.0.0 --title "New Title"
```

### gh secret

Manage repository secrets.

```bash
# Set secret (reads from stdin for security)
echo "$SECRET_VALUE" | gh secret set MY_SECRET

# Set from file
gh secret set MY_SECRET < secret.txt

# Set with explicit value (less secure - visible in history)
gh secret set MY_SECRET --body "value"

# Set for specific environment
gh secret set PROD_KEY --env production < key.txt

# Set organization secret
gh secret set ORG_SECRET --org myorg

# List secrets
gh secret list
gh secret list --json name,updatedAt

# List environment secrets
gh secret list --env production

# Delete secret
gh secret delete MY_SECRET
```

### gh variable

Manage Actions variables.

```bash
# Set variable
gh variable set MY_VAR --body "value"

# Set from stdin
echo "value" | gh variable set MY_VAR

# Set for environment
gh variable set MY_VAR --env staging --body "staging-value"

# List variables
gh variable list
gh variable list --json name,value

# Delete variable
gh variable delete MY_VAR
```

### gh search

Search across GitHub.

```bash
# Search repositories
gh search repos "kubernetes" --language go --stars ">1000"

# Search issues
gh search issues "bug" --repo OWNER/REPO --state open

# Search PRs
gh search prs "fix" --review-requested @me

# Search code (basic - see Python tool for advanced)
gh search code "pattern" --filename "*.go"

# Search commits
gh search commits "fix bug" --author username

# Output as JSON
gh search repos "cli" --json fullName,description,stargazersCount
```

### gh gist

Manage gists.

```bash
# Create gist
gh gist create file.txt

# Create secret gist
gh gist create file.txt --secret

# Create with description
gh gist create file.txt --desc "My snippet"

# Create from multiple files
gh gist create file1.txt file2.py

# List gists
gh gist list
gh gist list --json id,description,files

# View gist
gh gist view GIST_ID

# Edit gist
gh gist edit GIST_ID

# Clone gist
gh gist clone GIST_ID

# Delete gist
gh gist delete GIST_ID
```

---

## Repository Protection & Enforcement

Protect branches from force pushes, require PRs, enforce reviews, and more via the API.

See: `references/repo-protection.md` for comprehensive documentation.

### Quick Protection Commands

```bash
# Check if branch is protected
gh api repos/{owner}/{repo}/branches/main/protection 2>/dev/null && echo "Protected" || echo "Not protected"

# View current protection settings
gh api repos/{owner}/{repo}/branches/main/protection --jq '{
  enforce_admins: .enforce_admins.enabled,
  required_reviews: .required_pull_request_reviews.required_approving_review_count,
  force_push_allowed: .allow_force_pushes.enabled,
  deletions_allowed: .allow_deletions.enabled
}'

# Standard protection: require PR, 1 approval, block force push, enforce for admins
gh api repos/{owner}/{repo}/branches/main/protection -X PUT --input - <<'EOF'
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF

# Minimal protection: just block force push and deletion
gh api repos/{owner}/{repo}/branches/main/protection -X PUT --input - <<'EOF'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF

# Remove all protection (dangerous!)
gh api repos/{owner}/{repo}/branches/main/protection -X DELETE
```

### Toggle Individual Settings

```bash
# Enable/disable admin enforcement
gh api repos/{owner}/{repo}/branches/main/protection/enforce_admins -X POST   # Enable
gh api repos/{owner}/{repo}/branches/main/protection/enforce_admins -X DELETE  # Disable

# Enable/disable signed commits requirement
gh api repos/{owner}/{repo}/branches/main/protection/required_signatures -X POST   # Enable
gh api repos/{owner}/{repo}/branches/main/protection/required_signatures -X DELETE  # Disable

# Update required approvals count
gh api repos/{owner}/{repo}/branches/main/protection/required_pull_request_reviews -X PATCH \
  -F "required_approving_review_count=2" \
  -F "dismiss_stale_reviews=true"

# Update required status checks
gh api repos/{owner}/{repo}/branches/main/protection/required_status_checks -X PATCH --input - <<'EOF'
{
  "strict": true,
  "contexts": ["ci/build", "ci/test"]
}
EOF
```

### Protection Settings Reference

| Setting | Description |
|---------|-------------|
| `enforce_admins` | Admins must also follow protection rules |
| `required_approving_review_count` | Number of approvals needed (1-6) |
| `dismiss_stale_reviews` | Dismiss approvals when new commits pushed |
| `require_code_owner_reviews` | Require review from CODEOWNERS |
| `require_last_push_approval` | Last pusher cannot self-approve |
| `allow_force_pushes` | Allow force pushes (dangerous!) |
| `allow_deletions` | Allow branch deletion |
| `required_linear_history` | Require linear history (no merges) |
| `required_conversation_resolution` | All PR comments must be resolved |
| `lock_branch` | Make branch read-only |

---

## Common Agent Workflows

### PR Workflow (Complete)

```bash
# 1. Create branch and make changes
git checkout -b feature/my-feature
# ... make changes ...
git add . && git commit -m "Add feature"
git push -u origin feature/my-feature

# 2. Create PR
gh pr create --fill --draft

# 3. Check CI status
gh pr checks --json name,state,conclusion

# 4. Wait for checks (blocking)
gh pr checks --watch

# 5. Mark ready for review
gh pr ready

# 6. Request reviewers
gh pr edit --add-reviewer username

# 7. After approval, merge
# NOTE: If you have uncommitted local changes, stash first!
# gh pr merge checks out the target branch locally after merge.
git stash  # Only if you have uncommitted changes
gh pr merge --squash --delete-branch
git stash pop  # Restore stashed changes

# Or auto-merge when checks pass
gh pr merge --squash --auto
```

**Common gotcha**: `gh pr merge` fails with "Your local changes would be overwritten by checkout" if you have unstaged/uncommitted changes in files that differ between branches. Always `git stash` before merging if your working tree is dirty.

### CI/CD Debugging Workflow

```bash
# 1. Find failed runs
gh run list --status failure --limit 5

# 2. Get failure details
gh run view RUN_ID --json jobs --jq '.jobs[] | select(.conclusion=="failure")'

# 3. Get error logs
gh run view RUN_ID --log-failed

# 4. Or use the Python tool for structured analysis
python3 scripts/gh_failed_run.py --repo OWNER/REPO --pretty

# 5. Rerun after fix
gh run rerun RUN_ID --failed
```

### Release Workflow

```bash
# 1. Ensure on main/master with latest changes
git checkout main && git pull

# 2. Create and push tag
git tag v1.0.0
git push --tags

# 3. Create release with auto-generated notes
gh release create v1.0.0 --generate-notes --title "Release v1.0.0"

# 4. Upload artifacts
gh release upload v1.0.0 dist/*.zip dist/*.tar.gz

# 5. Verify
gh release view v1.0.0 --json tagName,assets
```

### Secret Management Workflow

```bash
# 1. List current secrets
gh secret list

# 2. Set new secret (from environment variable)
echo "$API_KEY" | gh secret set API_KEY

# 3. Set for specific environment
echo "$PROD_DB_PASSWORD" | gh secret set DB_PASSWORD --env production

# 4. Verify (shows metadata only, not values)
gh secret list --json name,updatedAt
```

---

## Environment Variables

### Authentication

| Variable | Purpose |
|----------|---------|
| `GH_TOKEN` | Authentication token for github.com |
| `GITHUB_TOKEN` | Same as GH_TOKEN (alternative) |
| `GH_ENTERPRISE_TOKEN` | Token for GitHub Enterprise Server |
| `GH_HOST` | GitHub hostname (for GHES) |

### Context

| Variable | Purpose |
|----------|---------|
| `GH_REPO` | Default repository (`owner/repo` format) |

### Behavior

| Variable | Purpose |
|----------|---------|
| `GH_PROMPT_DISABLED=1` | Disable all interactive prompts |
| `GH_NO_UPDATE_NOTIFIER=1` | Disable update notifications |

### Debugging

| Variable | Purpose |
|----------|---------|
| `GH_DEBUG=1` | Enable debug output |
| `GH_DEBUG=api` | Show HTTP traffic details |

### Output

| Variable | Purpose |
|----------|---------|
| `NO_COLOR=1` | Disable ANSI colors |
| `GH_FORCE_TTY=1` | Force terminal-style output in pipes |

---

## Agent-Friendly Patterns

### Non-Interactive Flags

Always use these for automation:

```bash
# Auto-confirm prompts
gh pr merge 123 --yes

# Auto-fill from git
gh pr create --fill

# Skip editor
gh issue create --title "Title" --body "Body"

# Force non-interactive
GH_PROMPT_DISABLED=1 gh ...
```

### JSON Output for Parsing

Always use `--json` for machine-readable output:

```bash
# Bad (human-readable, hard to parse)
gh pr list

# Good (structured, parseable)
gh pr list --json number,title,state,url

# With jq filtering
gh pr list --json number,title --jq '.[] | "\(.number): \(.title)"'
```

### Error Handling

```bash
# Check exit codes
if ! gh pr checks 123; then
  echo "CI checks failed"
  exit 1
fi

# Check for specific conditions
if gh pr checks --json conclusion --jq '.[] | select(.conclusion!="success")' | grep -q .; then
  echo "Some checks did not pass"
fi
```

### Working with Different Repos

```bash
# Use -R flag to specify repo
gh pr list -R owner/other-repo

# Or set environment variable
export GH_REPO="owner/repo"
gh pr list
```

---

## Python Utilities

### Enhanced Code Search

`scripts/gh_code_search.py` - Advanced GitHub code search with filtering and formatting.

**Key features:**
- Multiple output formats (pretty, summary, json)
- Fork/private repo filtering
- Rate limit handling
- Result sorting

```bash
# Search with filtering
python3 scripts/gh_code_search.py "eval(" --language python --exclude-forks

# Summary by repository
python3 scripts/gh_code_search.py "TODO" --output summary

# JSON for automation
python3 scripts/gh_code_search.py "api_key" --output json
```

See: `references/README_gh_code_search.md`

### Workflow Failure Analysis

`scripts/gh_failed_run.py` - Analyze GitHub Actions failures with error extraction.

**Key features:**
- Finds most recent failed run
- Extracts error patterns from logs
- Structured JSON output

```bash
# Analyze current repo
python3 scripts/gh_failed_run.py --pretty

# Analyze specific repo
python3 scripts/gh_failed_run.py --repo owner/name --pretty
```

See: `references/README_gh_failed_run.md`

### GitHub Pages Management

`scripts/gh_pages_deploy.py` - Automate GitHub Pages deployment.

**Key features:**
- Enable/configure Pages
- Check deployment status
- Trigger rebuilds
- Generate workflow templates

```bash
# Enable Pages
python3 scripts/gh_pages_deploy.py enable owner/repo

# Check status
python3 scripts/gh_pages_deploy.py status owner/repo

# Trigger rebuild
python3 scripts/gh_pages_deploy.py rebuild owner/repo
```

See: `references/README_pages.md`

### PR Workflow Automation

`scripts/gh_pr_workflow.py` - Complete PR lifecycle automation.

**Key features:**
- Create PR with auto-fill
- Wait for CI checks
- Request reviewers
- Auto-merge when approved

```bash
# Create and wait for checks
python3 scripts/gh_pr_workflow.py create --wait-checks

# Full workflow: create, wait, merge
python3 scripts/gh_pr_workflow.py full --merge-strategy squash
```

See: `references/README_gh_pr_workflow.md`

### Release Manager

`scripts/gh_release_manager.py` - Release creation and asset management.

**Key features:**
- Create releases with auto-notes
- Upload assets with checksums
- Download/compare releases

```bash
# Create release
python3 scripts/gh_release_manager.py create v1.0.0 --generate-notes

# Upload assets
python3 scripts/gh_release_manager.py upload v1.0.0 dist/*.zip
```

See: `references/README_gh_release_manager.md`

### Secret Sync

`scripts/gh_secret_sync.py` - Secret management across repos.

**Key features:**
- Sync secrets source -> target
- Compare across environments
- Bulk update from file
- Dry-run mode

```bash
# Sync secrets between repos
python3 scripts/gh_secret_sync.py sync source/repo target/repo

# Compare environments
python3 scripts/gh_secret_sync.py compare --env staging --env production
```

See: `references/README_gh_secret_sync.md`

### API Helper

`scripts/gh_api_helper.py` - Simplified API access with common patterns.

**Key features:**
- Pre-built queries
- GraphQL templates
- Pagination handling
- Response caching

```bash
# Get repo stats
python3 scripts/gh_api_helper.py repo-stats owner/repo

# List contributors
python3 scripts/gh_api_helper.py contributors owner/repo
```

See: `references/README_gh_api_helper.md`

---

## Error Handling & Troubleshooting

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "Resource not accessible by integration" | Token lacks required scopes | `gh auth login --scopes "repo,workflow"` |
| "HTTP 403" | Rate limit or permissions | Check limits: `gh api rate_limit` |
| "HTTP 404" | Repo not found or no access | Verify repo exists and access |
| "No remote branch" | Branch not pushed | `git push -u origin BRANCH` |
| "GraphQL query error" | Invalid query syntax | Check field names in API docs |
| "local changes would be overwritten" on merge | Dirty working tree | `git stash` before `gh pr merge`, then `git stash pop` |

### Debugging Commands

```bash
# Check authentication
gh auth status

# Check API rate limit
gh api rate_limit --jq '.resources.core'

# Test API access
gh api user

# Enable debug mode
GH_DEBUG=1 gh pr list
GH_DEBUG=api gh api repos/{owner}/{repo}

# Check gh version
gh --version
```

---

## References

- Official Manual: https://cli.github.com/manual/
- GitHub Docs: https://docs.github.com/en/github-cli
- API Reference: https://docs.github.com/en/rest
- GraphQL Explorer: https://docs.github.com/en/graphql/overview/explorer
