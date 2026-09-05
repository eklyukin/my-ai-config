---
name: slack-work-update
description: Draft a concise Slack update about completed work and next steps, or rewrite a user-provided update into clear Slack-ready English. Use when the user asks to prepare, polish, shorten, or restructure a work update for Slack. Produces text only and never posts it.
---

# Slack Work Update

Produce a polished message the user can copy into Slack. Never send, schedule, or save a Slack draft, even when Slack tools are connected. The deliverable is text only.

## Choose the Mode

- **Draft:** build an update from confirmed work evidence supplied by the user or available in the current repository context.
- **Edit:** improve a user-provided draft while preserving its facts, intent, links, mentions, acknowledgements, and commitments.

Default to English. Use another language only when the user explicitly requests it.

## Ground the Content

Use the user's statements as the primary source. When the user asks to assemble an update from completed work, inspect only relevant evidence such as the active `.context/plans/` document, saved Jira records, completed commits, test results, and pull-request state. Do not claim that something shipped, works, or is complete unless the available evidence supports it.

Do not invent metrics, business impact, ownership, deadlines, links, mentions, or next steps. If a missing fact materially changes the message, mark the exact gap outside the Slack-ready text or ask one concise question. Otherwise produce the best complete draft directly.

## Write the Update

Match the direct, practical style of an internal engineering update:

1. Lead with the main outcome or artifact, not the implementation process.
2. Summarize what changed and why it matters in short paragraphs or bullets.
3. Put links next to the relevant system, document, dashboard, task, or channel.
4. Credit collaborators only when their contribution and mention are confirmed.
5. Add a short `What's next` section when concrete follow-up work exists.
6. End with a clear request for feedback or action only when one is useful.

Prefer a compact message that remains readable on mobile. Usually use two to five shipped outcomes and two to five next steps. Do not force every section when the source material does not support it.

## Edit a Provided Draft

- Preserve the original meaning and all verified details.
- Correct grammar, agreement, spelling, and awkward phrasing without making the voice overly formal or promotional.
- Remove repetition, filler, and implementation trivia that obscures the result.
- Split run-on text into scannable bullets and paragraphs.
- Keep established product names and technical terms unchanged unless clearly erroneous.
- Preserve Slack user and channel IDs, URLs, and attribution. Do not manufacture mentions from plain names.
- Surface a factual ambiguity instead of silently changing it.

## Slack Formatting

Return native Slack mrkdwn rather than GitHub Markdown:

- bold: `*text*`, never `**text**`;
- link: `<https://example.com|label>`, never `[label](url)`;
- user mention: `<@U123456>`;
- channel mention: `<#C123456>`;
- bullets: `• item` or `- item`;
- no Markdown headings; use a short bold line instead.

When the source contains Slack-export links around a user or channel name, preserve the target and convert it to a real mention only if the stable Slack ID is known. Otherwise retain a normal labeled link so the message does not tag the wrong person or channel.

## Output

Return one final Slack-ready version in a fenced plain-text block for easy copying. Do not add commentary inside that block. If useful, put a very short note about unresolved factual gaps after the block. Do not provide multiple stylistic variants unless the user asks for them.
