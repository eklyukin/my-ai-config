# Commit Creation Rules

## Message Format

Title only, no body:

```
<type>[optional scope]: <brief description>
```

### Allowed Types

- `feat` — new functionality
- `fix` — bug fix
- `refactor` — refactoring without behavior changes
- `docs` — documentation changes
- `test` — adding or modifying tests
- `chore` — other changes (dependencies, configuration, etc.)

### Scope (optional)

Specified in parentheses after type, for example: `feat(currencies-api): ...`

## Action Sequence

1. Run `git status` to view modified files
2. Show the user the commit title and list of files planned to be added
3. Wait for explicit user permission to create the commit
4. Add only the files that were worked on during the current session

## Restrictions

- DO NOT use body in commit message — title only
- DO NOT add files that were not modified in the current session
- DO NOT create a commit without explicit user confirmation
- DO NOT add `Co-Authored-By` or other trailers to the commit message