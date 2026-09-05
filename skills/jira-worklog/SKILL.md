---
name: jira-worklog
description: Link implementation plans to Jira, create or update Jira work after approval, and coordinate Jira-key branches. Use when publishing planned work to Jira, recording progress, finishing a Jira task, or making repository work visible in Jira.
---

# Jira Worklog

Keep Jira aligned with the work actually planned and performed in the repository. Use a connected Jira or Atlassian MCP when available. If it is unavailable, prepare the same preview and explain what connection is missing; do not pretend that a remote write succeeded.

Write every Jira-facing text field in English, including summaries, descriptions, acceptance criteria, comments, labels with natural-language content, and transition notes. Translate the confirmed plan content when necessary while preserving exact identifiers, code names, URLs, and required quotations. This does not change the source-record language convention under `.context/sources/`.

## Load Context

1. Read repository-tracked instructions first.
2. Read only the relevant `.context/AGENTS.md` links, implementation plan, and `.context/contexts/jira.md` when they exist.
3. Discover Jira project, issue types, workflows, and existing issues with read-only calls. Do not guess values that cannot be discovered.
4. Never read credentials from files or store tokens, cookies, or secrets in `.context/`.

`.context/contexts/jira.md` may contain non-secret defaults such as the Jira site, project key, issue type, status mapping, and preferred default branch. Create or update it only with confirmed facts.

## Choose the Operation

- **Publish or link:** connect a confirmed `.context/plans/` plan to an existing Jira issue, or create a new issue when no suitable issue exists.
- **Progress:** summarize verified implementation progress and optionally update the linked issue.
- **Finish:** reconcile the implementation, tests, and integration state before proposing a final Jira comment or transition.

## Publish or Link

1. Read the confirmed plan and search Jira for possible duplicates using its title, repository, epic, and relevant identifiers.
2. Prefer linking an existing matching issue over creating a duplicate.
3. If no issue matches, prepare a creation preview containing project, issue type, summary, parent epic when applicable, description, acceptance criteria, and relevant links.
4. Show the proposed link or creation preview and wait for explicit confirmation before any Jira write.
5. After the confirmed write succeeds, add or update this section in the plan:

```markdown
## Jira
- Issue: PROJ-121
- URL: https://example.atlassian.net/browse/PROJ-121
- Parent epic: PROJ-100
- Repository branch: PROJ-121
- Target branch: PROJ-100
- Publication status: Linked
```

Use `None` for a confirmed absence of an epic. Do not invent placeholder keys or URLs.

6. Persist the useful Jira record at `.context/sources/jira/<ISSUE-KEY>.md`. Include the stable issue key, URL, retrieval timestamp with timezone, summary, status, parent, relevant links, and provenance. Update the same file on later retrievals.

## Record Progress

Derive progress from observable evidence: the linked plan, Git diff and commits, test results, and PR state. Prepare a concise Jira comment describing completed work, remaining work, blockers, and verification. Exclude hidden reasoning, secrets, irrelevant terminal output, and local absolute paths.

Show the comment and any field or status changes before writing them. Apply only the confirmed changes, then refresh the local Jira source record. Do not post a comment merely because a session started or ended.

## Finish Work

Reconcile the plan's Implementation and Status sections first. Verify the test and integration evidence required by the repository. Then preview the final comment and proposed Jira transition. A successful local implementation does not imply authorization to transition or close the Jira issue; wait for confirmation immediately before those writes.

## Jira Branch Convention

When repository instructions do not impose a conflicting convention:

- Name an issue branch exactly after its Jira key: `PROJ-121`.
- Name an epic branch exactly after its Jira key: `PROJ-100`.
- Do not add `feat/`, `fix/`, `codex/`, a description slug, or another prefix.
- If the issue belongs to an epic and both are implemented in the same repository, create the issue branch from the epic branch and target the issue PR or merge to the epic branch.
- Target the epic branch to the repository's normal default branch when completing the epic.
- If the issue has no epic, create it from and target it to the normal default branch.
- For work spanning repositories, use the same Jira-key branch only in repositories that actually change.

Fetch and inspect both local and remote branches before creating one. Reuse an existing matching branch safely; never recreate, overwrite, reset, or force-push it. Local branch or worktree creation may proceed as part of an explicitly requested implementation workflow. Pushes, PR creation, merges, and destructive branch operations always require their normal explicit authorization.

## Approval Boundary

Read-only Jira searches and local evidence gathering do not require confirmation. Always show a preview and receive explicit confirmation before creating or editing an issue, commenting, transitioning status, changing assignments or relationships, pushing a branch, opening a PR, or merging.
