---
name: grilling
description: Relentlessly interviews the user one decision at a time to expose assumptions and sharpen a plan, design, architecture, product idea, or implementation approach. Use when the user explicitly asks to be grilled or invokes grill-me, and finish by writing the confirmed plan to .context/plans/ before any implementation.
---

# Grilling

Interview the user until every material branch of the decision tree has been considered and both sides share the same understanding.

## Interview Workflow

1. Restate the goal and identify the first unresolved decision.
2. Ask exactly one decision question at a time.
3. Include a recommended answer and its main tradeoff with every question.
4. Wait for the user's answer before asking the next dependent question.
5. Update the decision tree mentally as answers settle prerequisites and expose new branches.
6. Continue until no material decisions, assumptions, acceptance criteria, or risks remain unresolved.

Do not ask the user for facts that can be discovered from the filesystem, repository, configured tools, or other available evidence. Inspect those facts directly. Decisions remain the user's: present each decision and wait for an answer.

Do not edit product code, configuration, remote documentation, or tracked files during the interview.

## Reaching Agreement

When the decision tree appears complete:

1. Summarize the agreed goal, decisions, scope, acceptance criteria, risks, and implementation outline.
2. Ask the user to confirm that shared understanding has been reached.
3. If the user identifies a gap, resume the one-question-at-a-time interview.
4. Only after explicit confirmation, create the plan described below.

## Required Local Plan

Before any implementation:

1. Resolve the Git repository root. If the current directory is not in a Git repository, use the current workspace root.
2. Ensure `/.context/` is listed in the repository's `.git/info/exclude`. Do not modify tracked `.gitignore`.
3. Ensure `.context/plans/` exists. Do not modify remote/tracked `plans/`, `docs/`, `CLAUDE.md`, or `AGENTS.md`.
4. Obtain the date by running `date +%F`; never guess or hardcode it.
5. Create `.context/plans/YYYY-MM-DD-<descriptive-slug>.md`. If the path already exists for a different task, choose a distinct slug and never overwrite it.
6. Write the confirmed agreement in English regardless of the interview language, using this structure:

```markdown
# <Title>

## Context
Goal, problem, and relevant facts.

## Agreed Decisions
Settled choices and important tradeoffs.

## Scope
Included and explicitly excluded work.

## Acceptance Criteria
Observable completion conditions.

## Risks and Open Follow-ups
Known risks; there should be no unresolved blocker hidden here.

## Implementation Outline
Ordered implementation and verification approach.

## Status
Ready for implementation (YYYY-MM-DD)
```

7. Show the user the created plan path and a concise summary.
8. Stop and wait for a separate implementation instruction. Creating the plan is not authorization to implement it.

If the `.context/` scaffold is missing or inconsistent, follow the installed `repository-context` rules to bootstrap or repair it without touching remote/tracked documentation.

Adapted from Matt Pocock's `grilling` skill under the MIT License. See `LICENSE.txt`.
