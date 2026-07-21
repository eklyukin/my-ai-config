---
name: code-reviewer
description: Review a diff or pull request against this repo's own standards (rules/code-style.md) and general correctness/security checks. Use when reviewing pull requests, providing code feedback, or checking code quality before a commit/PR.
---

# Code Reviewer

The actual standard is `rules/code-style.md` — read it first. This skill is the checklist for applying it, plus general correctness/security checks that apply regardless of language.

## Workflow

1. `git diff` (or the PR diff) — review the actual change, not just file names.
2. Walk the checklist below.
3. Report findings ranked by severity (correctness/security first, style last). Don't pad the review with nitpicks if nothing substantial was found — say so.

## Checklist

### Against `rules/code-style.md`

- **Boy Scout Principle** — did the change fix obvious nearby issues (bad names, dead code) without scope-creeping into unrelated files?
- **SOLID** — any new class/module taking on more than one reason to change? Any modification that should have extended rather than edited existing behavior?
- **Self-documenting code** — do names carry intent without needing a comment? Are the comments that do exist explaining *why*, not *what*?
- **YAGNI** — any abstraction, config option, or generalization added for a hypothetical future need rather than the task at hand?
- **Don't over-engineer** — new abstractions for a single call site, error handling for scenarios that can't occur, speculative extensibility?
- **DRY vs YAGNI** — real 3+ occurrence duplication left unextracted? Or, conversely, a premature abstraction forced onto two merely-similar cases?
- **Testable code** — dependencies passed in vs constructed internally? Hidden global state or side effects that would make this hard to test?

### General correctness & security

- Off-by-one / boundary conditions, null/empty/None handling
- Error handling: failures surfaced or silently swallowed?
- Input validation at trust boundaries (user input, external APIs) — and *not* over-validated at internal boundaries that don't need it
- Injection risks: SQL, command, template/XSS — parameterized queries, no string-built shell commands from untrusted input
- Secrets: no hardcoded credentials/tokens/keys in the diff (see the `secret-handoff` skill if a secret needs to move around)
- Concurrency: race conditions, missing locks/atomicity where shared state is mutated
- Tests: does the diff include tests for the new behavior, and do they cover the actual edge cases (not just the happy path)?

## Output format

```markdown
## Review: <file or PR>

### Must fix
- <finding> — <file:line> — <why it's a problem>

### Should consider
- <finding> — <file:line>

### Nit
- <finding> — <file:line>
```

Omit a section entirely if it's empty — don't write "Must fix: none" filler.
