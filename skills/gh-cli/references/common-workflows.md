# Common GitHub CLI Workflows

Step-by-step patterns for common GitHub operations.

## PR Workflow

### Feature Development

```bash
# 1. Create feature branch
git checkout -b feature/my-feature

# 2. Make changes and commit
git add .
git commit -m "Add feature"

# 3. Push branch
git push -u origin feature/my-feature

# 4. Create PR
gh pr create --fill --draft

# 5. Wait for CI
gh pr checks --watch

# 6. Mark ready for review
gh pr ready

# 7. Request reviewers
gh pr edit --add-reviewer username

# 8. After approval, merge
gh pr merge --squash --delete-branch
```

### Quick PR

```bash
# Create and auto-merge when checks pass
gh pr create --fill && gh pr merge --auto --squash
```

### PR Review

```bash
# Checkout PR locally
gh pr checkout 123

# Review changes
gh pr diff 123

# Approve
gh pr review 123 --approve

# Request changes
gh pr review 123 --request-changes --body "Please fix..."
```

## Issue Management

### Create and Track

```bash
# Create issue
gh issue create --title "Bug: X doesn't work" --label bug

# Assign to yourself
gh issue edit 123 --add-assignee @me

# Add to project (if using GitHub Projects)
gh issue edit 123 --add-project "Sprint 1"

# Work on issue (create branch)
gh issue develop 123 --checkout

# Close with comment
gh issue close 123 --comment "Fixed in #456"
```

### Triage

```bash
# List unassigned bugs
gh issue list --label bug --assignee ""

# List high priority
gh issue list --label priority-high --state open

# Batch add label
for i in 123 124 125; do gh issue edit $i --add-label reviewed; done
```

## Release Workflow

### Standard Release

```bash
# 1. Ensure main is up to date
git checkout main && git pull

# 2. Create tag
git tag v1.0.0
git push --tags

# 3. Create release with auto-notes
gh release create v1.0.0 --generate-notes --title "Release v1.0.0"

# 4. Upload artifacts
gh release upload v1.0.0 dist/*.zip dist/*.tar.gz

# 5. Verify
gh release view v1.0.0
```

### Pre-release

```bash
# Beta release
gh release create v1.0.0-beta.1 --prerelease --generate-notes

# Release candidate
gh release create v1.0.0-rc.1 --prerelease --generate-notes
```

### Hotfix Release

```bash
# 1. Create from specific commit
git tag v1.0.1 abc1234
git push --tags

# 2. Create release
gh release create v1.0.1 --notes "Hotfix: Critical bug fix" --title "Hotfix v1.0.1"
```

## CI/CD Debugging

### Find Failures

```bash
# List recent failed runs
gh run list --status failure --limit 5

# View specific run
gh run view 12345678

# Get failure logs
gh run view 12345678 --log-failed
```

### Rerun Workflows

```bash
# Rerun failed jobs only
gh run rerun 12345678 --failed

# Rerun entire workflow
gh run rerun 12345678
```

### Manual Trigger

```bash
# Trigger workflow
gh workflow run "Deploy"

# Trigger with inputs
gh workflow run "Deploy" -f environment=staging -f version=v1.0.0
```

### Monitor Run

```bash
# Watch until completion
gh run watch 12345678
```

## Secret Management

### Repository Secrets

```bash
# List secrets
gh secret list

# Set from environment
echo "$API_KEY" | gh secret set API_KEY

# Set from file
gh secret set DB_PASSWORD < password.txt
```

### Environment Secrets

```bash
# Set for production
echo "$PROD_KEY" | gh secret set API_KEY --env production

# List environment secrets
gh secret list --env production
```

## Repository Setup

### New Repository

```bash
# Create and clone
gh repo create my-project --public --clone

# Add files
cd my-project
echo "# My Project" > README.md
git add . && git commit -m "Initial commit"
git push -u origin main

# Configure
gh repo edit --enable-issues --enable-projects
```

### Fork Workflow

```bash
# Fork and clone
gh repo fork upstream/repo --clone

# Sync with upstream
gh repo sync

# Create PR to upstream
gh pr create --repo upstream/repo
```

## Code Search

### Security Scanning

```bash
# Find eval usage
gh search code "eval(" --language python --owner myorg

# Find hardcoded tokens
gh search code "api_key" --filename "*.py" --owner myorg

# Find TODO comments
gh search code "TODO" --repo myorg/myrepo
```

### Code Discovery

```bash
# Find implementations
gh search code "class MyClass" --language python

# Find config files
gh search code "database" --filename "*.yaml"
```

## Automation Patterns

### Batch Operations

```bash
# Close stale issues
for i in $(gh issue list --label stale --json number --jq '.[].number'); do
  gh issue close $i --comment "Closing stale issue"
done

# Add label to all open PRs
for pr in $(gh pr list --json number --jq '.[].number'); do
  gh pr edit $pr --add-label "needs-review"
done
```

### Conditional Operations

```bash
# Merge if checks pass
if gh pr checks 123 --json conclusion --jq 'all(.conclusion == "success")' | grep -q true; then
  gh pr merge 123 --squash
fi

# Alert on failure
gh run list --status failure --limit 1 --json url --jq '.[0].url' && \
  echo "Build failed!"
```

### JSON Processing

```bash
# Get PR numbers
gh pr list --json number --jq '.[].number'

# Get issue titles
gh issue list --json title --jq '.[].title'

# Complex filtering
gh pr list --json number,title,labels \
  --jq '.[] | select(.labels[].name == "bug") | .number'
```

## Tips

### Environment Variables

```bash
# Disable prompts for scripting
export GH_PROMPT_DISABLED=1

# Set default repo
export GH_REPO="owner/repo"

# Debug mode
export GH_DEBUG=1
```

### Non-Interactive Usage

```bash
# Always use --yes for confirmations
gh pr merge 123 --squash --yes

# Use --fill for auto-filling
gh pr create --fill

# Provide all required inputs
gh issue create --title "Title" --body "Body"
```

### Error Handling

```bash
# Check exit codes
gh pr merge 123 || echo "Merge failed"

# Silent failures
gh issue comment 123 --body "Update" 2>/dev/null

# Retry on failure
for i in 1 2 3; do
  gh api repos/{owner}/{repo} && break
  sleep 5
done
```
