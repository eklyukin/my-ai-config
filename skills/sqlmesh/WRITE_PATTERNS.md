# SQLMesh Write Patterns — Draft MR Workflow

For model structure and property syntax, see `MODEL_REFERENCE.md`.

## Naming conventions

| Layer | Pattern | Example |
|---|---|---|
| Branch | `{type}/{JIRA}` | `refactor/DWH-1234` |
| Commit | `{type}[{JIRA}]: {desc}` | `feat[DWH-1234]: add payment_metrics model` |
| MR title | `Draft: {type}[{JIRA}]: {desc}` | `Draft: refactor[DWH-1234]: reschedule revenue_main_revenue` |

Types: `feat` (new model), `refactor` (edit existing), `fix` (bug fix), `research` — all require a Jira code.

## MR title & description templates

Every MR opened by this skill MUST use these fixed templates verbatim, so all skill-created MRs share one style. Fill every `{placeholder}`; never omit a section.

**Title:** `Draft: {type}[{JIRA}]: {desc}`

**Description** (Markdown body passed to `create_merge_request`):

```markdown
## Jira
{JIRA}

## Summary
{one-line description of the change}

## Model
- Path: `projects/xsolla-dwh/models/{layer}/{schema}/{model}.sql`
- Dataset.model: `{schema}.{model}`
- Layer: {analytics|transfer}
- Type: {feat|refactor|fix|research}

## Change
{concrete change — e.g. cron '0 8 * * 1', owner XAA, added not_null audit on user_id}
```

## Workflow

1. Classify → type + layer. Stop if `raw` or `stage` layer (SKILL.md rule 1). Get Jira code (rule 4).
2. **Locate file** (edits): blob search `/projects/data-platform%2Fsqlmesh/search?scope=blobs&search=<term>` with `useUserCredentials:true`.
3. **Read file**: `/projects/data-platform%2Fsqlmesh/repository/files/<URL-ENCODED-PATH>/raw?ref=staging`.
4. Compose new content — see `MODEL_REFERENCE.md` for property syntax and examples.
5. `create_branch` → name `{type}/{JIRA}`, ref `staging`.
6. `create_commit` → message `{type}[{JIRA}]: {desc}`, `commitActions: [{action, file_path, content}]`.
7. `create_merge_request` → title + description from the **MR title & description templates** section above (fill every placeholder), targetBranch `staging`, `removeSourceBranch:true`.
8. Report MR link. CI runs `sqlmesh plan --explain --no-diff` + `sqlmesh format`. If the formatter makes changes, CI auto-pushes an `auto: Format models [...] [skip ci]` commit to the branch — this is expected.
9. Iterate via follow-up commits on the same branch. Abandon: close MR + delete branch.

## GitLab actions

| Action | `neuronet_gitlab` action |
|---|---|
| Create branch | `create_branch` |
| Create/update file | `create_commit` with `commitActions` |
| Open MR | `create_merge_request` |
| Close MR or retitle | `update_merge_request` |
| Delete branch | `delete_branch` |

No `draft` flag in the tool — set Draft via `Draft:` prefix in the MR title.

## Examples

- *"Schedule revenue_main_revenue every Monday 08:00 UTC (DWH-1234)"* → `refactor` → set `cron '0 8 * * 1'` → Draft MR.
- *"Add not_null audit on user_id to dwhp_analytics.foo (DWH-2000)"* → `refactor` → add audit → Draft MR.
- *"Create a view in dwhp_analytics (DWH-2100)"* → `feat` → new VIEW model → Draft MR.
- *"Change raw.x schedule"* → **refuse**: `raw` layer is DBA-owned.
