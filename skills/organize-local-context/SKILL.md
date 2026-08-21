---
name: organize-local-context
description: Audit uncommitted repository files and organize clear local-only plans, notes, project context, infrastructure records, and external-source material into the ignored .context/ structure. Use when the user asks to review or clean up uncommitted files according to the repository-context convention; do not use for ordinary code formatting or commit preparation.
---

# organize-local-context

Organize local-only artifacts without hiding or relocating legitimate product
changes. Follow the `repository-context` convention for the destination
structure, language, source records, and tracked-file boundaries.

## Safety Boundary

- Never run `git clean`, `git reset`, `git restore`, `git checkout`, or another
  command that discards working-tree content.
- Never move or rewrite staged files automatically.
- Never move modifications to tracked files automatically, including tracked
  `AGENTS.md`, `CLAUDE.md`, `docs/`, `plans/`, source code, configuration, or
  tests. Report them as product changes unless the user explicitly confirms
  that specific content is personal local context.
- Move an untracked file automatically only when its contents and purpose make
  the local-only classification unambiguous. Ask before moving an ambiguous
  file, a generated artifact that might belong to the project, or anything
  whose relocation could break references.
- Never copy credentials, tokens, cookies, private keys, or secret values into
  `.context/`. Stop and report the path if suspected secrets are found.
- Preserve every unrelated working-tree change.

## Workflow

1. Resolve the repository root and read repository-tracked instructions.
2. Read `.context/AGENTS.md` and only the local files needed to classify the
   current changes. If the scaffold is missing or incomplete, use the
   `repository-context` workflow to create it first.
3. Inspect all working-tree states with:

   ```bash
   git status --short --untracked-files=all
   git diff --name-status
   git diff --cached --name-status
   ```

4. Inspect the content of untracked candidate files. Do not classify from the
   filename alone. Separate files into:

   - safe local-context moves;
   - legitimate product or repository changes that remain untouched;
   - ambiguous files requiring one concise confirmation;
   - suspected secrets requiring an immediate stop for those files.

5. Move safe local-only artifacts to the matching destination:

   | Content | Destination |
   | --- | --- |
   | scoped project knowledge | `.context/contexts/<topic>.md` |
   | reusable personal documentation or notes | `.context/docs/<slug>.md` |
   | implementation plan | `.context/plans/YYYY-MM-DD-<slug>.md` |
   | environment and access procedures without secrets | `.context/INFRASTRUCTURE.md` |
   | Jira material | `.context/sources/jira/<stable-resource-slug>.md` |
   | Slack material | `.context/sources/slack/<channel-slug>.md` |
   | Vimeo material | `.context/sources/vimeo/<video-id-or-stable-slug>.md` |
   | Meet material | `.context/sources/meet/<meeting-id-or-date-slug>.md` |

6. Preserve content and useful provenance while normalizing it to the target
   document convention. Context documents are English. Source records may use
   English or the source's original language.
7. For Slack, maintain exactly one document per channel. Identify the channel
   by stable channel ID when available and merge new material into the existing
   channel document instead of creating another file. Do not discard existing
   valid content during a merge.
8. Update `.context/AGENTS.md` only when a moved document is broadly useful and
   should be discoverable from the canonical map. Do not list every source
   record individually.
9. Verify the result:

   ```bash
   git check-ignore -q .context/
   git status --short --untracked-files=all
   git diff --check
   ```

   Confirm that every moved artifact exists at its destination before removing
   its original untracked path and that no tracked content changed as a side
   effect.

## Report

Summarize:

- files moved and their destinations;
- files deliberately left as product changes;
- ambiguous files awaiting a decision;
- suspected-secret paths without exposing their contents;
- scaffold or map updates performed.

Do not commit the result unless the user separately requests a commit and then
confirms the exact proposed commit title and tracked file list.
