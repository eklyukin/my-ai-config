# Repository Protection & Enforcement API Reference

Comprehensive guide for managing branch protection rules, rulesets, and repository security settings via the GitHub API.

---

## Branch Protection Rules

Branch protection rules enforce workflows before changes can be merged to protected branches.

### Get Current Protection Rules

```bash
# Get branch protection for a specific branch
gh api repos/{owner}/{repo}/branches/main/protection

# Check if branch is protected
gh api repos/{owner}/{repo}/branches/main --jq '.protected'

# Get all branches with protection status
gh api repos/{owner}/{repo}/branches --jq '.[] | {name, protected}'
```

### Enable Full Branch Protection

```bash
# Comprehensive protection: require PRs, approvals, block force push, enforce for admins
gh api repos/{owner}/{repo}/branches/main/protection -X PUT --input - <<'EOF'
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": false,
  "lock_branch": false,
  "allow_fork_syncing": false
}
EOF
```

### Common Protection Configurations

#### Minimal Protection (Block Force Push + Deletion)

```bash
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
```

#### Require PR with 1 Approval

```bash
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
```

#### Require PR with 2 Approvals + Status Checks

```bash
gh api repos/{owner}/{repo}/branches/main/protection -X PUT --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["ci/build", "ci/test"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 2,
    "require_last_push_approval": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_linear_history": true,
  "required_conversation_resolution": true
}
EOF
```

#### Require Signed Commits

```bash
# Enable signed commit requirement
gh api repos/{owner}/{repo}/branches/main/protection/required_signatures -X POST

# Disable signed commit requirement
gh api repos/{owner}/{repo}/branches/main/protection/required_signatures -X DELETE

# Check if signed commits required
gh api repos/{owner}/{repo}/branches/main/protection/required_signatures
```

---

## Protection Settings Reference

### Required Pull Request Reviews

| Field | Type | Description |
|-------|------|-------------|
| `dismiss_stale_reviews` | boolean | Dismiss approvals when new commits pushed |
| `require_code_owner_reviews` | boolean | Require review from CODEOWNERS |
| `required_approving_review_count` | integer | Number of approvals required (1-6) |
| `require_last_push_approval` | boolean | Last pusher cannot approve their own PR |
| `dismissal_restrictions` | object | Who can dismiss reviews |
| `bypass_pull_request_allowances` | object | Who can bypass PR requirement |

### Required Status Checks

| Field | Type | Description |
|-------|------|-------------|
| `strict` | boolean | Require branch to be up-to-date before merge |
| `contexts` | array | List of status check names that must pass |
| `checks` | array | Status checks with app_id for more control |

### Branch Restrictions

| Field | Type | Description |
|-------|------|-------------|
| `users` | array | Users who can push (login names) |
| `teams` | array | Teams who can push (slug names) |
| `apps` | array | Apps that can push (slug names) |

### Other Settings

| Field | Type | Description |
|-------|------|-------------|
| `enforce_admins` | boolean | Apply rules to admins too |
| `allow_force_pushes` | boolean | Allow force pushes (dangerous!) |
| `allow_deletions` | boolean | Allow branch deletion |
| `block_creations` | boolean | Block creating matching branches |
| `required_linear_history` | boolean | Require linear history (no merge commits) |
| `required_conversation_resolution` | boolean | Require all conversations resolved |
| `lock_branch` | boolean | Make branch read-only |
| `allow_fork_syncing` | boolean | Allow fork sync for read-only branches |

---

## Modify Individual Settings

### Update Required Approvals Count

```bash
gh api repos/{owner}/{repo}/branches/main/protection/required_pull_request_reviews -X PATCH --input - <<'EOF'
{
  "required_approving_review_count": 2,
  "dismiss_stale_reviews": true
}
EOF
```

### Update Required Status Checks

```bash
gh api repos/{owner}/{repo}/branches/main/protection/required_status_checks -X PATCH --input - <<'EOF'
{
  "strict": true,
  "contexts": ["ci/build", "ci/test", "ci/lint"]
}
EOF
```

### Add/Remove Status Check Contexts

```bash
# Add contexts
gh api repos/{owner}/{repo}/branches/main/protection/required_status_checks/contexts -X POST --input - <<'EOF'
{
  "contexts": ["ci/security-scan"]
}
EOF

# Remove contexts
gh api repos/{owner}/{repo}/branches/main/protection/required_status_checks/contexts -X DELETE --input - <<'EOF'
{
  "contexts": ["ci/old-check"]
}
EOF
```

### Toggle Admin Enforcement

```bash
# Enable enforce for admins
gh api repos/{owner}/{repo}/branches/main/protection/enforce_admins -X POST

# Disable enforce for admins
gh api repos/{owner}/{repo}/branches/main/protection/enforce_admins -X DELETE

# Check status
gh api repos/{owner}/{repo}/branches/main/protection/enforce_admins --jq '.enabled'
```

---

## Remove Protection

```bash
# Remove ALL branch protection (dangerous!)
gh api repos/{owner}/{repo}/branches/main/protection -X DELETE

# Remove specific protections
gh api repos/{owner}/{repo}/branches/main/protection/required_status_checks -X DELETE
gh api repos/{owner}/{repo}/branches/main/protection/required_pull_request_reviews -X DELETE
gh api repos/{owner}/{repo}/branches/main/protection/restrictions -X DELETE
```

---

## Repository Rulesets (Modern API)

Rulesets are a newer, more flexible alternative to branch protection rules.

### List Rulesets

```bash
# List all rulesets
gh api repos/{owner}/{repo}/rulesets

# Get specific ruleset
gh api repos/{owner}/{repo}/rulesets/RULESET_ID
```

### Create Ruleset

```bash
gh api repos/{owner}/{repo}/rulesets -X POST --input - <<'EOF'
{
  "name": "Protect main branch",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/main"],
      "exclude": []
    }
  },
  "rules": [
    {"type": "deletion"},
    {"type": "non_fast_forward"},
    {"type": "pull_request", "parameters": {
      "required_approving_review_count": 1,
      "dismiss_stale_reviews_on_push": true,
      "require_last_push_approval": false
    }}
  ]
}
EOF
```

### Ruleset Rule Types

| Rule Type | Description |
|-----------|-------------|
| `creation` | Block creating matching refs |
| `update` | Block updating matching refs |
| `deletion` | Block deleting matching refs |
| `non_fast_forward` | Block force pushes |
| `pull_request` | Require PRs with reviews |
| `required_status_checks` | Require CI checks to pass |
| `commit_message_pattern` | Enforce commit message format |
| `commit_author_email_pattern` | Enforce author email format |
| `committer_email_pattern` | Enforce committer email format |
| `branch_name_pattern` | Enforce branch naming |
| `tag_name_pattern` | Enforce tag naming |
| `required_linear_history` | Require linear history |
| `required_signatures` | Require signed commits |

---

## Default Branch Settings

```bash
# Get default branch
gh api repos/{owner}/{repo} --jq '.default_branch'

# Change default branch
gh api repos/{owner}/{repo} -X PATCH -f default_branch=main

# Rename branch (creates rename operation)
gh api repos/{owner}/{repo}/branches/master/rename -X POST -f new_name=main
```

---

## Webhook Protection (Deploy Keys)

```bash
# List deploy keys
gh api repos/{owner}/{repo}/keys

# Add read-only deploy key
gh api repos/{owner}/{repo}/keys -X POST \
  -f title="CI Server" \
  -f key="ssh-rsa AAAA..." \
  -f read_only=true

# Delete deploy key
gh api repos/{owner}/{repo}/keys/KEY_ID -X DELETE
```

---

## Quick Reference - Common Operations

### Protect Main Branch (Standard)

```bash
# One-liner: Require PR, 1 approval, block force push, enforce for admins
gh api repos/{owner}/{repo}/branches/main/protection -X PUT \
  -F "required_pull_request_reviews[required_approving_review_count]=1" \
  -F "required_pull_request_reviews[dismiss_stale_reviews]=true" \
  -F "enforce_admins=true" \
  -F "allow_force_pushes=false" \
  -F "allow_deletions=false"
```

### Check Protection Status

```bash
# Quick check
gh api repos/{owner}/{repo}/branches/main/protection 2>/dev/null && echo "Protected" || echo "Not protected"

# Detailed status
gh api repos/{owner}/{repo}/branches/main/protection --jq '{
  enforce_admins: .enforce_admins.enabled,
  required_reviews: .required_pull_request_reviews.required_approving_review_count,
  dismiss_stale: .required_pull_request_reviews.dismiss_stale_reviews,
  force_push: .allow_force_pushes.enabled,
  deletions: .allow_deletions.enabled
}'
```

### Apply Same Protection to Multiple Branches

```bash
# Protect main, develop, and release branches
for branch in main develop release; do
  gh api repos/{owner}/{repo}/branches/$branch/protection -X PUT --input - <<'EOF'
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
  echo "Protected: $branch"
done
```

---

## Troubleshooting

### "Not Found" (404)

- Branch doesn't exist
- Repository is private and token lacks `repo` scope
- Organization settings block API access

### "Resource not accessible by integration"

- Token lacks `admin:repo` scope for protection APIs
- Need org admin permissions for org-level settings

### "Validation Failed"

- Invalid status check context names
- Conflicting settings (e.g., `allow_force_pushes: true` with signed commits)

### Required Scopes

For full branch protection API access:
```bash
gh auth login --scopes "repo,admin:repo_hook"
```

---

## See Also

- [GitHub Branch Protection Docs](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [Rulesets Documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
- [REST API Reference](https://docs.github.com/en/rest/branches/branch-protection)
