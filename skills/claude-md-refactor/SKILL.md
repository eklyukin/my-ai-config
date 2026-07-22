---
name: claude-md-refactor
description: Keeps a project's Claude Code (and Codex, via AGENTS.md symlinks) documentation in the map-not-manual shape - a short root CLAUDE.md linking out to per-directory CLAUDE.md files, INFRASTRUCTURE.md, and plans/ (including plans/CHANGELOG.md). Use when CLAUDE.md is too long or monolithic, when a subdirectory needs its own short context doc, when starting or finishing a design/implementation plan or a small fix, when a significant architectural decision needs logging, or when the user says "refactor claude.md", "restructure docs", "add a CLAUDE.md for this dir", "log this decision", "write a plan for X", "update the plan".
---

# claude-md-refactor

Keep project documentation as a **map, not a manual**: a short root `CLAUDE.md` that links out, and detail living in the right place.

**These files are local-only, never committed.** `CLAUDE.md` (root and per-directory), `INFRASTRUCTURE.md`, `plans/` (including `plans/CHANGELOG.md`) are personal working docs, not shared team documentation. Before creating any of them for the first time in a repo, check whether they're already git-ignored; if not, add them to that repo's `.gitignore` (or `.git/info/exclude` if you don't want to touch a tracked `.gitignore`) before or alongside creating the file.

**Every `CLAUDE.md` gets an `AGENTS.md` symlink.** Codex (and other non-Claude agents) reads `AGENTS.md`, not `CLAUDE.md`. Whenever you create a root or per-directory `CLAUDE.md`, immediately create `AGENTS.md` next to it as a symlink to `CLAUDE.md` (`ln -sfn CLAUDE.md AGENTS.md` from that directory) so both names resolve to the same content. The symlink itself is also local-only — covered by the same git-ignore step above.

### Pre-existing CLAUDE.md / AGENTS.md

A repo may already have a root (or per-directory) `CLAUDE.md` and/or `AGENTS.md` that this skill didn't create — possibly committed, possibly team-shared. Before touching either file, check state first:

1. `git ls-files --error-unmatch CLAUDE.md` (and same for `AGENTS.md`) to see if it's tracked by git.
2. If **tracked** (committed team documentation): don't assume the local-only/gitignore rule applies. Stop and ask the user whether to (a) treat it as shared team documentation and edit it in place without gitignoring, or (b) migrate it to the local-only pattern (`git rm --cached`, add to `.gitignore`). Don't decide this silently either way.
3. If **untracked** and `AGENTS.md` is a plain file (not a symlink) with content diverging from `CLAUDE.md`: don't overwrite either. Flag both files to the user and ask which is the source of truth before reconciling into the symlink structure.
4. If **untracked** and `AGENTS.md` is already a symlink to `CLAUDE.md` (or vice versa): nothing to do, structure already matches the target.

## Target structure

```
<repo root>/
├── CLAUDE.md              # short overview + links only (map)
├── AGENTS.md              # symlink -> CLAUDE.md, for Codex/non-Claude agents
├── INFRASTRUCTURE.md      # local/stage/prod envs: how to reach each, gotchas
├── plans/
│   ├── CHANGELOG.md       # append-only log of significant decisions/changes
│   └── YYYY-MM-DD-<slug>.md   # one file per unit of work (design or fix), updated after implementation
├── dir1/
│   ├── CLAUDE.md          # short context for dir1
│   └── AGENTS.md          # symlink -> CLAUDE.md
└── dir2/
    ├── CLAUDE.md
    └── AGENTS.md          # symlink -> CLAUDE.md
```

## Root CLAUDE.md

Should stay short (rule of thumb: under ~100-150 lines). Contents:
- One or two paragraphs: what the project is
- Links to `INFRASTRUCTURE.md`, `plans/CHANGELOG.md`, `plans/`
- A list of subdirectories that have their own `CLAUDE.md`, with a one-line description each and a link
- The session-start changelog line (see [plans/CHANGELOG.md](#planschangelogmd)) so any agent reading this file — Claude or Codex via `AGENTS.md` — picks it up
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
2. Create `dir/AGENTS.md` as a symlink to `CLAUDE.md`.
3. Add/update the link + one-line description in the root `CLAUDE.md`'s subdirectory list.
4. Confirm the link resolves (file exists at the stated path).

## plans/

One file per unit of work, named `plans/YYYY-MM-DD-<slug>.md` (date = day the file was written, get it with `date +%F`, never hardcode or guess it). This covers non-trivial design work planned up front **and** small fixes implemented directly — `plans/` is the record of everything shipped, not just what went through plan mode first.

**Lifecycle — this is the important part, not just the naming convention:**

1. **At design time** (non-trivial change planned up front): create the file with the design (context/problem, approach, key decisions, open questions) before implementation starts.
2. **During implementation**: if the approach changes from what was planned, note it in the same file — don't silently drift from a stale plan.
3. **After every implementation, including small one-off fixes with no prior design step**: create the file if it doesn't exist yet, or update it if it does, with what was actually built, deviations from any original design, and follow-ups. Skip the `## Design` section for a small fix where there was no design step. The file becomes the historical record of "what we intended and what we shipped" for that unit of work.

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

## plans/CHANGELOG.md

Append-only log of significant decisions and changes, living inside `plans/` — the "why", not the diff (git log already has the diff). Not every commit belongs here; only things a future reader would otherwise have to reconstruct from scattered PRs/conversations.

Create `plans/` and this file together as soon as either is missing — part of the scaffold to bootstrap, not something to defer until there's a real entry to log.

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
3. Spawn a subagent with `model: "haiku"` (via the Agent tool), passing it the diff and ticket ID, asking it to write a 1-3 sentence `plans/CHANGELOG.md` entry in the format above — what changed and why, not a file-by-file listing.
4. Show the drafted entry to the user before appending — never append to `plans/CHANGELOG.md` without confirmation.

Haiku is deliberately the right tool here: this is a cheap summarization task (diff → prose), not something that needs the main model's reasoning budget.

### Keeping it current at the start of every session

`plans/CHANGELOG.md` should never go stale, and this has to work whether the agent reading the repo is Claude Code or Codex — so the mechanism lives in the doc content itself, not in a Claude-only hook. Whenever you create or update the root `CLAUDE.md`, make sure it carries this standing instruction (Codex picks it up too, via the `AGENTS.md` symlink):

```markdown
## Session start
Before starting other work, check `plans/CHANGELOG.md` against `git log` on the current branch since its last entry.
If commits exist that aren't reflected yet, draft an entry with a cheap/fast model (e.g. Haiku) summarizing what changed
and why, show it to the user, and append on confirmation. Skip silently if nothing's changed since the last entry.
```

This makes the update-at-session-start behavior part of the project's own instructions rather than something bolted onto one specific tool. On Claude Code there's also a standing `SessionStart` hook (`~/.claude/hooks/session-start-claude-md-refactor.sh`, registered in `~/.claude/settings.json`) that does a read-only check of the repo at session start and nudges Claude to consider bootstrapping any missing piece of the scaffold (root `CLAUDE.md`/`AGENTS.md`, `INFRASTRUCTURE.md`, `plans/`, `plans/CHANGELOG.md`) — it never creates or edits files itself, it only injects a reminder. That hook is a Claude Code-only enforcement layer on top, not a substitute for the instruction embedded in `CLAUDE.md` above, since Codex has no equivalent hook mechanism and only ever sees what's written into `AGENTS.md`.

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
| Root/dir `CLAUDE.md` or `AGENTS.md` already exists and is tracked by git | Don't assume local-only — see [Pre-existing CLAUDE.md / AGENTS.md](#pre-existing-claudemd--agentsmd) |
| Plain (non-symlink) `AGENTS.md` already exists with content that diverges from `CLAUDE.md` | Don't overwrite — flag it and ask which is the source of truth |
| `plans/` doesn't exist yet | Create it (with `plans/CHANGELOG.md`) as soon as it's missing — part of the scaffold, not gated on a first plan/fix |
| Plan/fix file for today's date already exists for a different task | Don't overwrite — pick a distinct slug |
| A trivial fix has no meaningful "design" to record | Still write the `plans/YYYY-MM-DD-<slug>.md` file after implementation, just skip the `## Design` section |
| `plans/CHANGELOG.md` doesn't exist yet | Create it (empty, with just the entry-format comment/header) as soon as it's missing — same as `plans/` above |
| User asks to "update the plan" but implementation isn't done yet | Update the Design section, not Implementation — ask if unclear which phase this is |
| A credential value shows up while writing INFRASTRUCTURE.md (env file, terminal output, etc.) | Never transcribe it — write the secret manager name + credential name instead |
