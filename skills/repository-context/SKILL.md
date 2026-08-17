---
name: repository-context
description: Maintains conflict-free local repository context for Claude and Codex under .context/, with .context/AGENTS.md as the canonical map, CLAUDE.md as its symlink, selective context files, infrastructure notes, implementation plans, and a remote-aware local changelog. Use when creating or updating local agent context, plans, infrastructure notes, changelog entries, or when repository-tracked CLAUDE.md, AGENTS.md, docs, or plans must remain untouched.
---

# repository-context

Keep personal agent context under `.context/` so it cannot conflict with files from the remote repository. Treat repository-tracked documentation as authoritative and never modify it as part of this workflow.

## Core Rules

1. Put every personal context artifact under `<repo>/.context/`.
2. Add `/.context/` to `<repo>/.git/info/exclude` before creating the scaffold. Do not modify the tracked `.gitignore` for this purpose.
3. Never modify, replace, rename, ignore, or symlink remote/tracked `CLAUDE.md`, `AGENTS.md`, `docs/`, `plans/`, or similar repository files.
4. Treat remote/tracked instructions as authoritative when they conflict with `.context/`.
5. Read `.context/AGENTS.md` as a map first. Load only the linked files needed for the current task; never load all of `.context/` by default.
6. Report a conflict between remote and local instructions, then follow the remote instruction.
7. Write every file under `.context/` in English, even when the user or task uses another language. Preserve exact identifiers and required quotations.

## Target Structure

```text
<repo>/
└── .context/
    ├── AGENTS.md                 # canonical local context map
    ├── CLAUDE.md -> AGENTS.md    # compatibility symlink for Claude
    ├── CHANGELOG.md              # local remote-aware decision/change log
    ├── INFRASTRUCTURE.md         # concrete environment and access notes
    ├── contexts/                 # task-selected context, not auto-loaded wholesale
    │   ├── frontend.md
    │   ├── backend.md
    │   └── deployment.md
    ├── docs/                     # optional personal notes
    └── plans/
        └── YYYY-MM-DD-<slug>.md
```

Create only context and docs files that carry useful information. Create `.context/plans/` and `.context/CHANGELOG.md` with the scaffold. Ask before creating `INFRASTRUCTURE.md` when its content would require guessing.

## Bootstrap Workflow

1. Resolve the repository root with `git rev-parse --show-toplevel`.
2. Inspect remote/tracked instruction and documentation files, but do not edit them.
3. Ensure the exact line `/.context/` exists in `.git/info/exclude`; create `.git/info/` or `exclude` if necessary.
4. Create `.context/AGENTS.md` as the canonical short English map.
5. Create `.context/CLAUDE.md` as a symlink to `AGENTS.md`:

   ```bash
   ln -sfn AGENTS.md .context/CLAUDE.md
   ```

6. Create `.context/CHANGELOG.md` and `.context/plans/` immediately when missing.
7. Create `.context/INFRASTRUCTURE.md` only from known or discoverable facts; ask the user about material unknowns instead of adding placeholders or guesses.
8. Verify that `.context/` is ignored, the symlink resolves, and no tracked file changed.

If `.context/AGENTS.md` and `.context/CLAUDE.md` already exist but the latter is not a symlink to `AGENTS.md`, do not overwrite either file. Show the discrepancy and ask which content to preserve.

## `.context/AGENTS.md`

Keep this canonical map short, normally under 100-150 lines. Include:

- one or two paragraphs describing the repository;
- a statement that remote/tracked instructions have priority;
- links to `.context/CHANGELOG.md`, `.context/INFRASTRUCTURE.md`, and `.context/plans/` when they exist;
- a list of available `.context/contexts/*.md` files with one-line descriptions;
- the session-start remote synchronization instruction below;
- genuinely universal local rules such as language or commit policy.

Do not copy remote documentation into the map. Link to remote documents when relevant and keep personal interpretation in `.context/contexts/`.

## Selective Context

Store scoped knowledge in `.context/contexts/<topic>.md` instead of creating local instruction files beside code directories. Link every context file from `.context/AGENTS.md` with a short description explaining when to read it.

For each task:

1. Read remote/tracked instructions first.
2. Read `.context/AGENTS.md`.
3. Select only context files relevant to the task.
4. Avoid reading unrelated context directories or documents.

## Plans

Use one file per unit of work: `.context/plans/YYYY-MM-DD-<slug>.md`. Obtain the date with `date +%F`; never guess it.

Write every plan in English. For planned work, record context, design, key decisions, and open questions before implementation. During implementation, record deviations. After implementation, record what was built and the final status. For a small direct fix, omit the Design section but still create the historical record.

Suggested structure:

```markdown
# <Title>

## Context
Why this work is needed.

## Design
Approach and key decisions. Omit for a small direct fix.

## Implementation
What was built, deviations, and follow-ups.

## Status
Planned | In progress | Done (YYYY-MM-DD)
```

## `.context/CHANGELOG.md`

Keep an append-only English-language local record of significant remote changes, local decisions, and completed plans. Record why a change matters rather than repeating a file-by-file diff.

Use entries such as:

```markdown
## YYYY-MM-DD - <short title> [PROJ-1234]
<One to three sentences explaining what changed and why. Link a local plan when relevant.>
```

The ticket tag is optional. Keep the chosen newest-first or oldest-first ordering consistent.

### Background Remote Synchronization

At the start of every session, when `.context/CHANGELOG.md` exists, start a background agent if agent delegation is available. Do not block the primary task waiting for synchronization.

Give the background agent this bounded job:

1. Run `git fetch --prune` to refresh remote refs without changing the working tree.
2. Determine the upstream/default remote branch and the last processed remote commit recorded in `.context/CHANGELOG.md`.
3. Review only the new commit log and relevant diffs.
4. Update `.context/CHANGELOG.md` with concise English entries describing what changed and why it matters locally.
5. Record the latest processed remote commit using `<!-- remote-head: <ref>@<sha> -->`.
6. Never checkout, merge, rebase, reset, pull, modify tracked files, or expose secrets.
7. If fetch or inspection fails, report the limitation without blocking the primary task or inventing an entry.

Pass only the required log and diffs to the background agent. If background delegation is unavailable, perform a brief read-only synchronization check inline and defer a large changelog update rather than flooding the main context.

Embed this standing instruction in `.context/AGENTS.md`:

```markdown
## Session Start
Start a background remote synchronization for `.context/CHANGELOG.md` without blocking the primary task. Refresh refs with `git fetch --prune`, summarize only remote commits since the recorded `remote-head`, update the local changelog and marker in English, and never change the working tree or tracked files. Remote instructions remain authoritative.
```

## Infrastructure

Use `.context/INFRASTRUCTURE.md` for concrete local, stage, and production information: URLs, ports, project or cluster IDs, access steps, deploy and rollback procedures, dashboards, logs, and operational gotchas.

Never write secret values. Record the secret manager or vault and exact credential name instead. Fill discoverable facts; ask about material unknowns rather than guessing.

## Completion Checks

- `git check-ignore -q .context/` succeeds.
- `.context/CLAUDE.md` resolves to `AGENTS.md`.
- `.context/AGENTS.md` links only to existing local files.
- Every `.context/` document is written in English.
- Only task-relevant local context was loaded.
- No tracked remote documentation was modified.
- Every completed implementation has a local plan record.
- Significant remote changes and decisions are reflected in `.context/CHANGELOG.md`.
