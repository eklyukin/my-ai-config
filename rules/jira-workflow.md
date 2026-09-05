# Jira Work Visibility

For non-trivial repository work, check whether the active `.context/plans/` document is linked to a Jira issue. If it is not linked, remind the user once at the planning-to-implementation boundary and offer to use the `jira-worklog` skill. Never create or update Jira work without first showing the proposed remote change and receiving explicit confirmation.

Write all Jira-facing text in English, including issue summaries, descriptions, acceptance criteria, comments, and transition notes. Preserve exact identifiers, code names, URLs, and required quotations.

When a Jira issue is linked and repository instructions do not conflict, name its branch exactly after the issue key, for example `PROJ-121`. Do not add a type prefix, agent prefix, or descriptive slug. If the issue belongs to an epic in the same repository, use the epic key as the epic branch name, create the issue branch from it, and target issue integration to that epic branch. Integrate the epic branch into the repository's normal default branch. If there is no epic, branch from and target the normal default branch.

Check local and remote branches before creating one. Reuse existing Jira-key branches safely. Pushes, pull requests, merges, Jira comments, issue creation, issue edits, and Jira transitions retain their normal confirmation requirements.
