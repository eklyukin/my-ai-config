---
name: codex
description: Get a second, independent AI opinion from OpenAI Codex CLI alongside Claude — for planning, code review, or implementation review. Use when the user wants two AIs to independently draft a plan and compare, wants a Codex review of a diff, or wants an implementation reviewed by Codex after Claude builds it.
allowed-tools: Task, Bash, Read, Glob, Grep, AskUserQuestion
argument-hint: "<task description, or empty for review-only>"
---

# Codex: Second-Opinion AI

Uses the local `codex` CLI (authenticated via API key) as an independent second AI — not a subagent Claude controls, but a genuinely separate model whose output Claude compares against or merges with its own.

Three modes. Pick based on what the user asked for:

## Mode 1: Dual plan

When the user wants two independent takes on a design before committing to an approach.

1. Draft your own plan for the task first (don't look at Codex's yet — independence is the point).
2. Get Codex's independent plan, non-interactively, read-only (it must not touch files during this):
   ```bash
   codex exec --sandbox read-only "Draft an implementation plan for: <task description>. Do not write or modify any files. Output only the plan as markdown: approach, key decisions, risks/open questions."
   ```
   Timeout: 300000ms (5 minutes). If `codex` isn't installed or the command fails, say so and continue with just your own plan.
3. Present both plans side by side to the user — where they agree, where they diverge, and your recommendation on which to follow (or how to merge them). Don't silently pick one; the value is in showing the disagreement.

## Mode 2: Dual review

When the user wants a diff reviewed by both AIs, not just Claude.

1. Identify what changed:
   ```bash
   git diff --name-only
   git diff --name-only --cached
   git ls-files --others --exclude-standard
   ```
   If nothing changed, report "No changes detected" and stop.
2. Review the diff yourself first (use the `code-reviewer` skill's checklist).
3. Run Codex's review, non-interactively:
   ```bash
   codex review --uncommitted
   ```
   Or, if there are no uncommitted changes but there are unpushed commits:
   ```bash
   codex review --base <base-branch>
   ```
   `<base-branch>` is the PR target (e.g. `main`, `staging`) — detect from context. Timeout: 300000ms.

   **Important**: the interactive `codex -a never "prompt"` form does NOT work in non-TTY environments (fails with "stdin is not a terminal"). Always use `codex review --uncommitted` / `codex review --base`, which run non-interactively. See `references/review-focus.md` for what Codex evaluates against.

   If `codex` isn't installed or the command fails, show the error and continue with just your own review.
4. Present both sets of findings together, deduplicated — don't just concatenate. Flag anything only one of the two caught; that's the interesting signal, not the overlap.

## Mode 3: Implement, then Codex review

The original flow — when the user wants a task implemented and then checked by Codex before calling it done.

1. Delegate implementation to a subagent:
   ```
   Task(
     subagent_type: "general-purpose",
     prompt: "<task>\n\nYou are an implementation agent. Execute this development task in the current working directory.\n\nRules:\n- Read existing code before modifying — understand patterns first\n- Write clean, production-ready code following project conventions\n- Keep changes minimal and focused on the requested task\n- Test changes if a test framework is available (npm test, pytest, etc.)\n- Never commit or push changes\n\nAfter completion, provide a structured summary with: Files Changed, Key Decisions, and Caveats.",
     description: "Implement: <brief summary>"
   )
   ```
   If the task description is empty and there are already uncommitted/unpushed changes, skip straight to the review steps of Mode 2 instead (review-only). If there's nothing to implement and nothing changed, ask the user what they want.
2. Run Mode 2's review steps (2-4) against what the subagent produced.
3. Present: implementation summary, changed files, Codex review findings, recommended next steps if issues were found.

## Notes

- `codex exec --sandbox read-only` is deliberately read-only for Mode 1 — a "second opinion" call should never mutate the repo out from under the primary work. `codex review` is inherently read-only (it inspects a diff, doesn't edit).
- This depends on a locally authenticated `codex` CLI (API key), not on any MCP gateway tool. If `codex` is missing or fails, degrade gracefully — report the gap and continue with Claude's own output rather than blocking.
