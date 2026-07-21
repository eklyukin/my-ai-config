---
name: Git Commit Helper
description: Generate a commit message by analyzing staged git diffs, following the title-only convention in rules/commit.md. Use when the user asks for help writing a commit message or reviewing staged changes.
---

# Git Commit Helper

Format and process are defined in `rules/commit.md` — read it first, this skill is just the workflow around it.

## Quick start

```bash
git status
git diff --staged
git diff --staged --stat
```

## Message format

Title only, no body, no trailers:

```
<type>[optional scope]: <brief description>
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore` (see `rules/commit.md` for definitions).

## Workflow

1. `git status` — see what's modified.
2. `git diff --staged` — understand the actual change, not just the file list.
3. Pick the type and (optional) scope that best matches the change.
4. Draft a single-line, imperative summary — no period at the end, no vague verbs like "update"/"fix stuff".
5. Show the user the commit title and the list of files to be added.
6. Wait for explicit confirmation before running `git commit`.
7. Stage only files touched in the current session — never a blanket `git add -A`/`git add .` without reviewing `git status` first.

## Examples

```
feat(auth): add JWT token validation
fix(api): handle null values in user profile
refactor(database): simplify query builder
docs(readme): document install.sh usage
test(parser): cover empty-input edge case
chore(deps): bump lodash to 4.17.21
```

## Don't

- Don't add a body or footer (no `BREAKING CHANGE:`, no `Co-Authored-By:`, no bullet lists under the title).
- Don't use past tense ("added feature") — use imperative ("add feature").
- Don't commit without showing the title and file list first.
- Don't invent a scope when the change touches the whole repo — omit it instead.
