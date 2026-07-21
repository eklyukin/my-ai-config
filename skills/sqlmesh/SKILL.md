---
name: sqlmesh
description: >
  Helps analysts query and manage SQLMesh models (also called "data marts" or "tables")
  in the gitlab.loc data-platform/sqlmesh repo. Two modes:
  (1) READ — answer lookup questions directly from the repo: who owns a model, list my data marts,
  show active (not disabled) models, find which models depend on mine.
  (2) WRITE — turn a change request into a CONTRIBUTING.md-conformant Draft MR that CI validates with sqlmesh plan:
  edit cron/owner/grain/kind, add audits, create a new model.
  Triggers: "set table to auto-update / schedule", "set the table from this ticket to auto-update", "use this query for the table auto-update",
  "who owns this table", "show my data marts", "which data marts depend on mine", "how many active models",
  "add/edit/reschedule/re-own a model", "add audit", "open MR against data-platform/sqlmesh".
  Do NOT use to apply plans, run models against the warehouse, or edit raw/stage layer models.
---

# SQLMesh model management (Layer 1: read queries + author → Draft MR)

## Overview

Two operational modes:

**Read mode** — answer questions about models directly from the GitLab repo, no MR created. See `READ_PATTERNS.md` for API patterns.  
**Write mode** — turn a change request into a Draft MR; CI validates it with `sqlmesh plan`. See `WRITE_PATTERNS.md` for workflow and `MODEL_REFERENCE.md` for model structure.

**Vocabulary:** Users may call models "data marts" or "tables" — synonyms for SQLMesh models. Accept any term without correction. "Dataset" refers to the BigQuery schema (e.g. `dwhp_analytics`), not the model itself.

Repo: `data-platform/sqlmesh` (project_id 4741) · deploy branch: `master`  
Feature branches are created from `staging` and MRs target `staging` — only the DBA team merges `staging` → `master` for production releases.  
Model path: `projects/xsolla-dwh/models/<layer>/<schema>/<model>.sql`  
SQL dialect: BigQuery

## Layer access

Analysts may edit: `analytics` and `transfer` layers.  
**Not available for analyst edits:** `raw` and `stage` layers — DBA-owned.

## Hard rules

1. **`analytics` and `transfer` layers only.** Refuse edits to `raw` or `stage` layers — surface that as the reason.
2. **Draft MRs only. Never merge, never apply.** Prefix MR title with `Draft:`.
3. **Act as the requesting user.** Pass `useUserCredentials: true` on EVERY `neuronet_gitlab` call.
4. **Jira code is mandatory.** ASK if missing — never invent one, never use `auto`.
5. **Confirm before creating.** Restate model + change + type + Jira code; create only after user confirms.

## Code ownership

When the MR is opened, GitLab automatically assigns reviewers based on the files modified.
