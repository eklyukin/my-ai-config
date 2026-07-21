# GitHub API Patterns Quick Reference

Common patterns for using `gh api` effectively.

## REST API Basics

### HTTP Methods

```bash
# GET (default)
gh api repos/{owner}/{repo}

# POST
gh api repos/{owner}/{repo}/issues -f title="Bug" -f body="Description"

# PATCH
gh api repos/{owner}/{repo}/issues/123 -X PATCH -f state=closed

# PUT
gh api repos/{owner}/{repo}/topics -X PUT -f names='["topic1","topic2"]'

# DELETE
gh api repos/{owner}/{repo}/issues/123/labels/bug -X DELETE
```

### Field Parameters

```bash
# String field (-f)
gh api repos/{owner}/{repo}/issues -f title="Title"

# Typed field (-F) - numbers, booleans, JSON
gh api repos/{owner}/{repo}/issues -F number=123

# JSON field
gh api repos/{owner}/{repo}/issues -f labels='["bug","urgent"]'
```

## Placeholder Substitution

In a git repository, these are auto-replaced:
- `{owner}` - Repository owner
- `{repo}` - Repository name
- `{branch}` - Current branch

```bash
# These are equivalent inside a repo:
gh api repos/{owner}/{repo}/releases
gh api repos/myorg/myrepo/releases
```

## Common Endpoints

### Repository

```bash
# Get repo info
gh api repos/{owner}/{repo}

# Get README
gh api repos/{owner}/{repo}/readme

# Get languages
gh api repos/{owner}/{repo}/languages

# Get topics
gh api repos/{owner}/{repo}/topics

# Get contributors
gh api repos/{owner}/{repo}/contributors
```

### Issues & PRs

```bash
# List issues
gh api repos/{owner}/{repo}/issues

# Create issue
gh api repos/{owner}/{repo}/issues -f title="Title" -f body="Body"

# List PRs
gh api repos/{owner}/{repo}/pulls

# Get PR reviews
gh api repos/{owner}/{repo}/pulls/123/reviews

# List PR files
gh api repos/{owner}/{repo}/pulls/123/files
```

### Actions

```bash
# List workflows
gh api repos/{owner}/{repo}/actions/workflows

# List runs
gh api repos/{owner}/{repo}/actions/runs

# Get run details
gh api repos/{owner}/{repo}/actions/runs/12345678

# List artifacts
gh api repos/{owner}/{repo}/actions/artifacts
```

### Releases

```bash
# List releases
gh api repos/{owner}/{repo}/releases

# Get latest release
gh api repos/{owner}/{repo}/releases/latest

# Get release by tag
gh api repos/{owner}/{repo}/releases/tags/v1.0.0
```

## jq Filtering

### Extract Fields

```bash
# Single field
gh api repos/{owner}/{repo} --jq '.name'

# Multiple fields
gh api repos/{owner}/{repo} --jq '{name, description, stars: .stargazers_count}'

# From array
gh api repos/{owner}/{repo}/releases --jq '.[].tag_name'
```

### Filter Data

```bash
# Select by condition
gh api repos/{owner}/{repo}/issues --jq '.[] | select(.labels[].name == "bug")'

# Filter by state
gh api repos/{owner}/{repo}/pulls --jq '.[] | select(.state == "open")'

# Count items
gh api repos/{owner}/{repo}/issues --jq 'length'
```

### Format Output

```bash
# TSV for scripts
gh api repos/{owner}/{repo}/releases --jq '.[] | [.tag_name, .name] | @tsv'

# CSV
gh api repos/{owner}/{repo}/issues --jq '.[] | [.number, .title] | @csv'

# Custom format
gh api repos/{owner}/{repo}/pulls --jq '.[] | "#\(.number): \(.title)"'
```

## Pagination

```bash
# Get all pages
gh api repos/{owner}/{repo}/commits --paginate

# Get all and count
gh api repos/{owner}/{repo}/stargazers --paginate --jq 'length'

# Get all into JSON array
gh api repos/{owner}/{repo}/issues --paginate --slurp
```

## Caching

```bash
# Cache for 1 hour
gh api user --cache 1h

# Cache for 5 minutes
gh api repos/{owner}/{repo} --cache 5m
```

## GraphQL

### Basic Query

```bash
gh api graphql -f query='{ viewer { login name } }'
```

### With Variables

```bash
# String variables (-f)
gh api graphql -f owner='{owner}' -f name='{repo}' -f query='
  query($owner: String!, $name: String!) {
    repository(owner: $owner, name: $name) {
      stargazerCount
    }
  }
'

# Typed variables (-F)
gh api graphql -F first=10 -f query='
  query($first: Int!) {
    viewer {
      repositories(first: $first) {
        nodes { name }
      }
    }
  }
'
```

### Paginated GraphQL

```bash
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
```

### Common GraphQL Queries

```bash
# Repository details
gh api graphql -f query='
  query {
    repository(owner: "owner", name: "repo") {
      name
      description
      stargazerCount
      forkCount
      issues(states: OPEN) { totalCount }
      pullRequests(states: OPEN) { totalCount }
    }
  }
'

# User info
gh api graphql -f query='
  query {
    viewer {
      login
      name
      email
      repositories(first: 5) {
        nodes { nameWithOwner }
      }
    }
  }
'

# Organization repos
gh api graphql -f query='
  query {
    organization(login: "orgname") {
      repositories(first: 10) {
        nodes {
          name
          isPrivate
          defaultBranchRef { name }
        }
      }
    }
  }
'
```

## Error Handling

### Check Response

```bash
# Show headers for debugging
gh api repos/{owner}/{repo} --include

# Verbose mode
gh api repos/{owner}/{repo} --verbose

# Silent (no output)
gh api repos/{owner}/{repo}/issues -X POST -f title="Test" --silent
```

### Rate Limits

```bash
# Check remaining quota
gh api rate_limit --jq '.resources.core'

# Output: {"limit":5000,"remaining":4999,"reset":1234567890}
```

## Tips

1. **Use placeholders** - `{owner}` and `{repo}` work inside git repositories
2. **Cache read requests** - Use `--cache` for frequently accessed data
3. **Use jq filtering** - Filter server-side when possible, use `--jq` for formatting
4. **Paginate carefully** - Large datasets need `--paginate`
5. **Check rate limits** - Before batch operations, check `rate_limit` endpoint
6. **Use GraphQL** - For complex queries or when you need specific fields
