---
name: preparing-for-demo
description: Build a verified 14-day personal work and code-review report from Jira, GitHub, and GitLab, then publish it privately in the user's Confluence space. Use when the user prepares for a demo or needs a fortnightly status summary.
---

# Preparing for Demo

Produce an evidence-backed summary of the user's own work across Jira, GitHub,
and GitLab, then create a private Confluence report. Source collection is
read-only: never create or update issues, comments, branches, pull requests,
merge requests, or other source objects. The only permitted remote write is the
Confluence report described below.

## Time window and identity

Use the rolling 14 calendar days ending now in the user's local timezone unless
the user supplies exact dates. State the inclusive start and end dates.

Resolve the authenticated user independently in every source. Prefer account
IDs returned by each API over matching display names. Do not attribute work to
the user merely because they were assigned, mentioned, or subscribed.

## Collect evidence

Query all three sources when they are available:

- **Jira:** issues completed during the window and assigned to the user; issues
  the user actively progressed during the window when supported by history,
  worklogs, or authored comments. Confirm completion from resolution or status
  history rather than current status alone. Treat `Won't do`, duplicate,
  cancelled, and equivalent non-delivery resolutions separately from completed
  work. Search the home project `IEO` first, but include the user's work from
  other accessible Jira projects.
- **GitHub:** pull requests authored and merged or closed during the window;
  authored pull requests updated during the window; submitted reviews and
  other attributable repository activity when the APIs expose it reliably.
  Use explicit cross-repository searches for both authored and reviewed pull
  requests; do not rely solely on the contribution calendar API, which can
  omit organization activity. Treat merged PRs as completed and closed-unmerged
  PRs separately.
- **GitLab:** merge requests authored and merged or closed during the window;
  authored merge requests updated during the window; attributable push,
  approval, review, discussion-note, or repository events available to the
  authenticated user.

Use connected MCP tools first. Safe read-only CLIs or APIs are acceptable
fallbacks. If a source is unavailable, continue with the others and identify
the missing source and reason. Never turn absence of evidence into zero work.

Follow repository-local context rules while retrieving external information.
In particular, refresh required `.context/sources/` records for successfully
read Jira issues without committing personal context.

## Code reviews

Collect code reviews as a separate report category, independent from authored
PRs and MRs. Include only review activity attributable to the authenticated
user and performed during the reporting window.

For GitHub, correlate submitted reviews with authored inline pull-request
review comments and general pull-request comments. For GitLab, correlate
approval or review events with authored merge-request discussion notes. Do not
classify comments on the user's own PR or MR as a code review unless there is
clear evidence that the user reviewed another contributor's changes.

Deduplicate repeated actions on the same PR or MR while preserving the action
dates, review states, and comment count. For every reviewed item report:

- repository and PR/MR title with a direct link;
- review action or outcome when available;
- `Comments: Yes (N)` when at least one attributable review comment exists;
- `Comments: No` only when the source was queried successfully and confirms
  that no attributable comments exist;
- `Comments: Unknown` when permissions or API limitations prevent a reliable
  determination.

An approval alone does not prove that comments were left. Conversely, an
authored inline or discussion comment is review activity even if no formal
approval or change-request event is available.

## Normalize and reconcile

Keep source URLs, issue keys, repository names, titles, timestamps, and status.
Extract Jira keys from branch names, PR/MR titles, descriptions, and linked
issues. Group records that clearly represent the same work item, but retain all
supporting links. Do not merge records based only on similar wording.

Distinguish:

- **Completed:** Jira issues resolved with a delivery resolution during the
  window and PRs/MRs merged during the window.
- **Worked on:** active Jira work and authored PRs/MRs with verified activity
  during the window that was not completed in it.
- **Code reviews:** reviewed PRs/MRs, reported separately even when related to
  completed or in-progress work.

Exclude automated dependency updates, bot activity, passive assignments, and
records with no attributable activity unless the user asks to include them.
Flag ambiguous ownership or completion instead of guessing.

## Report content

Write a concise report in the user's language with:

1. the exact reporting period and source coverage;
2. a short outcome summary;
3. completed work, grouped by Jira issue or coherent workstream;
4. other verified work in progress;
5. code reviews, with comment presence explicitly marked for every PR/MR;
6. source gaps or ambiguities;
7. an evidence list containing direct Jira, GitHub, and GitLab links.

Describe outcomes when supported by titles, descriptions, or issue context;
otherwise report the verified action without inventing business impact. Avoid
double-counting a Jira issue and its linked PR/MR as separate achievements.
Include useful totals, but keep counts secondary to the actual work.

## Publish to Confluence

After assembling and validating the report, create it in this fixed location:

- personal space: `~7120200d492039a19d4d6cb8bac1a7991bcc2c`;
- destination folder ID: `25187778991`;
- destination URL:
  `https://xsolla.atlassian.net/wiki/spaces/~7120200d492039a19d4d6cb8bac1a7991bcc2c/folder/25187778991`.

Use the inclusive reporting period as the complete page title in ISO date
format: `YYYY-MM-DD – YYYY-MM-DD`. Do not add a prefix, suffix, or report name.

The page must be private to the authenticated user. Before creating it, verify
that the destination is the specified personal space and determine whether the
available Confluence integration can apply or preserve a view restriction that
excludes every other user and group. After creation, verify the page location,
title, and effective restrictions. Do not treat membership in a personal space
as proof that an individual page is private.

If a page with the exact period title already exists in the destination,
refresh that page instead of creating a duplicate, but only after verifying
that it is the user's private report. Do not overwrite an unrelated or shared
page.

Prefer the connected Atlassian integration. If it can create the page but
cannot manage or inspect page restrictions, use the user's already-open,
authenticated browser to apply and verify the required restriction. If neither
route can guarantee private visibility, do not create or update the page;
return the complete report as a draft and state that publication was skipped
because privacy could not be assured.

On success, return the page title, direct Confluence link, reporting period,
and source coverage. Mention any unavailable source or unresolved ambiguity.
