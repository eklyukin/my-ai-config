# Changelog

All notable changes to this skill will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.5.0] - 2026-07-07

### Added
- Two trigger phrases added to the `description` `Triggers:` line so the skill auto-invokes on the ticket-driven auto-update flow: `"set the table from this ticket to auto-update"` and `"use this query for the table auto-update"` (scoped to the auto-update context). Requested by a.sidorov.

### Changed
- Narrowed the `"use this query"` trigger to `"use this query for the table auto-update"` to prevent false-positive routing from unrelated SQL/query workflows (Salesforce SOQL, Neo4j, generic SQL debugging).

## [0.4.1] - 2026-07-07

### Changed
- Code ownership section no longer names a specific `ps_analytics` code owner — reviewers are assigned automatically by GitLab based on the files modified.
- This is now the sole `sqlmesh` skill — the near-duplicate `skills/public/xsolla/sqlmesh/` copy was removed to eliminate drift.

## [0.4.0] - 2026-07-02

### Changed
- Fixed MR title + description templates in `WRITE_PATTERNS.md` (new **MR title & description templates** section) so every skill-created MR shares one style: `## Jira` / `## Summary` / `## Model` / `## Change`. Workflow step 7 now points at the template.

### Removed
- Removed the `## Post-workflow` section from `SKILL.md` (the mandatory `/reflect` call) — it risked users making uncontrolled skill changes.

## [0.3.0] - 2026-06-29

### Changed
- MR target branch changed from `master` to `staging` — all analyst MRs target `staging`; feature branches created from `staging`.
- Code ownership section added: `ps_analytics` models → @n.tsintsov as code owner.
- File reads use `ref=staging` (was `ref=master`).
- `create_merge_request` now explicitly sets `targetBranch: staging`.
- CI auto-format behavior documented in WRITE_PATTERNS.md.
- Removed dataset access pre-flight check (not yet implemented).

## [0.2.0] - 2026-06-04

### Changed
- `cron` is now documented as **always UTC** (was "project's configured timezone") — convert local times to UTC.
- A Jira code is **mandatory for analysts**; the codeless `auto` type is no longer offered through this skill (reserved for automation/generated commits).

## [0.1.0] - 2026-06-04

### Added
- Initial release. Layer 1 SQLMesh model authoring for `data-platform/sqlmesh`: classify → locate → read → edit (BigQuery dialect) → branch + commit + Draft MR via `neuronet_gitlab` (`useUserCredentials`).
- Enforces CONTRIBUTING.md conventions (`{type}/{JIRA}` branch, `{type}[{JIRA}]: {desc}` commit/MR, `auto` codeless type) and the `*_analytics`-only analyst-scope guardrail.
- Draft-only / never-merge / never-apply safety rules; CI `sqlmesh plan` validates each MR.
