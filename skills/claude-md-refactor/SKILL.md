---
name: claude-md-refactor
description: Keeps a project's Claude Code documentation in the map-not-manual shape - a short root CLAUDE.md linking out to per-directory CLAUDE.md files, INFRASTRUCTURE.md, OVERCHANGE.md and plans/. Use when CLAUDE.md is too long or monolithic, when a subdirectory needs its own short context doc, when starting or finishing a design/implementation plan, when a significant architectural decision needs logging, or when the user says "refactor claude.md", "restructure docs", "add a CLAUDE.md for this dir", "log this decision", "write a plan for X", "update the plan".
---

# claude-md-refactor

Keep project documentation as a **map, not a manual**: a short root `CLAUDE.md` that links out, and detail living in the right place.

## Target structure

```
<repo root>/
├── CLAUDE.md              # short overview + links only (map)
├── INFRASTRUCTURE.md      # local/stage/prod envs: how to reach each, gotchas
├── OVERCHANGE.md          # append-only log of significant decisions/changes
├── plans/
│   └── YYYY-MM-DD-<slug>.md   # one file per design, updated after implementation
├── dir1/
│   └── CLAUDE.md          # short context for dir1
└── dir2/
    └── CLAUDE.md
```

## Root CLAUDE.md

Should stay short (rule of thumb: under ~100-150 lines). Contents:
- One or two paragraphs: what the project is
- Links to `INFRASTRUCTURE.md`, `OVERCHANGE.md`, `plans/`
- A list of subdirectories that have their own `CLAUDE.md`, with a one-line description each and a link
- Anything else genuinely needed on every task (commit rules, language, etc.)

Everything else belongs in one of the other files below — if you're about to add a paragraph of detail to root `CLAUDE.md`, stop and ask whether it belongs in a `dir/CLAUDE.md`, `INFRASTRUCTURE.md`, or a plan instead.

### Audit workflow

1. Read the current root `CLAUDE.md`.
2. Flag: lines over budget, sections that describe a single subdirectory in depth (candidate for `dir/CLAUDE.md`), sections that describe environments/access (candidate for `INFRASTRUCTURE.md`), stale links (pointing to files that don't exist), missing links (a `dir/CLAUDE.md` exists but root doesn't mention it).
3. Present findings and a proposed split to the user before editing anything.
4. On approval: move content out, leave a one-line link behind, re-verify line count.

## Per-directory CLAUDE.md

Applies only to **code directories** — modules, services, packages, apps in a monorepo. Not for `plans/`, docs folders, config-only directories, or anything without its own code-level conventions.

Holds short, dir-scoped context — not a full manual: what lives here, non-obvious conventions, gotchas a newcomer (or agent) would otherwise rediscover the hard way.

Create one when:
- A code directory has its own conventions/context that don't apply repo-wide, and
- That content would otherwise bloat the root `CLAUDE.md`, or is currently missing entirely and worth capturing.

Steps:
1. Draft the `dir/CLAUDE.md` content — short, specific to that directory.
2. Add/update the link + one-line description in the root `CLAUDE.md`'s subdirectory list.
3. Confirm the link resolves (file exists at the stated path).

## plans/

One file per planned unit of work, named `plans/YYYY-MM-DD-<slug>.md` (date = day the plan was written, get it with `date +%F`, never hardcode or guess it).

**Lifecycle — this is the important part, not just the naming convention:**

1. **At design time**: when the user is designing a non-trivial change, create the plan file with the design (context/problem, approach, key decisions, open questions).
2. **During implementation**: if the approach changes from what was planned, note it in the same file — don't silently drift from a stale plan.
3. **After implementation**: update the same file (don't create a new one) with what was actually built, deviations from the original design, and follow-ups. The plan becomes the historical record of "what we intended and what we shipped."

Suggested template:

```markdown
# <Title>

## Context
Why this work, what problem it solves.

## Design
Approach, key decisions, alternatives considered.

## Implementation
(filled in after the work is done)
What was actually built, deviations from the design above, follow-ups.

## Status
Planned | In progress | Done (YYYY-MM-DD)
```

## OVERCHANGE.md

Append-only log of significant decisions and changes — the "why", not the diff (git log already has the diff). Not every commit belongs here; only things a future reader would otherwise have to reconstruct from scattered PRs/conversations.

Entry format (newest at top or bottom — pick one and stay consistent within a project):

```markdown
## YYYY-MM-DD — <short title> [PROJ-1234]
<1-3 sentences: what changed and why. Link the relevant plans/*.md if one exists.>
```

The `[PROJ-1234]` ticket tag is optional — omit it when there's no Jira ticket for the change.

Add an entry when: an architectural decision is made, a significant dependency/approach is swapped, a plan in `plans/` is completed, or anything else that would confuse a future reader without the "why".

### Drafting an entry automatically

When it's time to log an entry (finishing a plan, wrapping up a significant change), draft it with a cheap model instead of writing it inline yourself:

1. Gather the ticket ID: check the current branch name for a Jira-style pattern (`[A-Z]+-[0-9]+`, e.g. `PROJ-1234`) via `git branch --show-current`; fall back to scanning recent commit messages on the branch if the branch name doesn't have one.
2. Gather the diff: `git diff main...HEAD` (or the relevant base branch) — the full set of changes this entry should cover, not just the latest commit.
3. Spawn a subagent with `model: "haiku"` (via the Agent tool), passing it the diff and ticket ID, asking it to write a 1-3 sentence OVERCHANGE.md entry in the format above — what changed and why, not a file-by-file listing.
4. Show the drafted entry to the user before appending — never append to OVERCHANGE.md without confirmation.

Haiku is deliberately the right tool here: this is a cheap summarization task (diff → prose), not something that needs the main model's reasoning budget.

## INFRASTRUCTURE.md

Reference doc for environments, with real concrete data — hostnames, URLs, ports, project/cluster IDs, dashboards — everything except actual credential values.

**Credentials rule: never write a secret value into this file.** Where a credential is needed, write a pointer instead: which secret manager (name the project/vault), and the exact secret/credential name to look up there. Same rule for API keys, tokens, passwords, connection strings with embedded passwords.

Suggested structure:

```markdown
# Infrastructure

## Local
How to run it, prerequisites, gotchas.

## Stage
- URL: ...
- Access: how to reach it (VPN/SSO/tunnel)
- Deploy: how to deploy
- Logs/monitoring: where to look
- Credentials: see <secret manager>, secret name `<name>`

## Production
- URL: ...
- Access: how to reach it
- Deploy: process, approvals needed
- Rollback: process
- Logs/monitoring: where to look
- Escalation: who/where
- Credentials: see <secret manager>, secret name `<name>`
```

When creating or updating this file: fill in every concrete field you can (URLs, IDs, access steps) — don't leave placeholders for things the user has already told you or that are discoverable from the repo/config. Only the credential *value* itself is off-limits; the secret manager location and credential name are not secrets and belong in the file.

## Edge cases

| Scenario | Handling |
|----------|----------|
| Root CLAUDE.md already short and well-linked | Nothing to do — say so, don't force a restructure |
| Subdirectory content is generic (applies repo-wide) | Keep it in root, don't split into a dir/CLAUDE.md |
| `plans/` doesn't exist yet | Create it on first plan, don't scaffold it preemptively |
| Plan file for today's date already exists for a different task | Don't overwrite — pick a distinct slug |
| OVERCHANGE.md doesn't exist yet | Create it with the entry format above on first real entry, not proactively |
| User asks to "update the plan" but implementation isn't done yet | Update the Design section, not Implementation — ask if unclear which phase this is |
| A credential value shows up while writing INFRASTRUCTURE.md (env file, terminal output, etc.) | Never transcribe it — write the secret manager name + credential name instead |
