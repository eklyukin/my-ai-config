# AI Agent Instructions

## Purpose

This repository is the source of truth for personal configuration shared
between Claude Code and Codex. Maintain compatibility with both clients and
preserve configuration outside the repository's explicit ownership boundary.

## Language and documentation

- Write repository documentation, rules, skills, comments, and commit messages
  in English unless a task explicitly requires another language.
- Keep `README.md` focused on users and installation.
- Keep this file focused on repository-wide AI behavior.
- `CLAUDE.md` is a compatibility entry point and must continue to direct Claude
  to this file. Do not maintain conflicting copies of the same instructions.

## Repository layout

- `rules/`: global behavioral and workflow rules.
- `skills/<name>/SKILL.md`: reusable skills for Claude and Codex.
- `agents/`: Claude-specific subagent definitions.
- `commands/`: Claude-specific commands.
- `hooks/`: Claude lifecycle hooks; Codex support depends on migration limits.
- `install.sh`: installs repository-managed Claude symlinks and MCP defaults.
- `install-codex.sh`: migrates shared configuration and restores Codex-native
  settings.

## Editing rules

1. Inspect the current file and related installer behavior before editing.
2. Keep changes narrowly scoped and preserve unrelated user, corporate, and
   client-native configuration.
3. Never store credentials, tokens, cookies, or private keys in this
   repository. Document only secret names or retrieval locations.
4. Do not replace `~/.claude/settings.json` or `~/.codex/config.toml` wholesale.
   Installer changes must merge or restore only explicitly owned entries.
5. A new skill must include valid YAML frontmatter with at least `name` and
   `description`, concise activation guidance, and any required license.
6. When changing shared skills or rules, account for both Claude and Codex
   syntax and migration behavior.
7. Keep global MCP defaults repository-managed and available from every project.
   The expected browser set is `playwright` and `chrome-devtools` for both
   clients, plus Codex-specific `computer-use` when available and the hosted
   Slack MCP endpoint without embedding its user token.

## Ownership boundary

This repository may create, replace, or remove only:

- Claude symlinks recorded in `~/.claude/.my-ai-config-manifest` and pointing
  into this repository;
- Claude hook command registrations explicitly listed in `HOOK_EVENTS`;
- user-scoped Claude MCP entries named `playwright` and `chrome-devtools`;
- the marked `my-ai-config-local-context` and `my-ai-config-browser` blocks in
  `~/AGENTS.md`;
- the Codex MCP entries named `computer-use` and `slack` installed by
  `install-codex.sh`;
- a converted Codex skill at `~/.agents/skills/<name>` only when the matching
  `~/.claude/skills/<name>` symlink is recorded in
  `~/.claude/.my-ai-config-manifest` and resolves inside this repository.

The Codex installer may temporarily regenerate shared files only when it first
snapshots and then restores unrelated Codex-native sections. Corporate
instruction blocks, unrelated MCP servers, project trust levels, plugins,
marketplaces, feature flags, shell policy, and all unlisted user settings are
outside this repository's ownership.

## Local context convention

Personal context for another repository belongs under that repository's ignored
`.context/` directory. Repository-tracked instructions remain authoritative.

- `.context/AGENTS.md` is the canonical local map.
- `.context/CLAUDE.md` is a symlink to `AGENTS.md`.
- Load only task-relevant files linked from `.context/AGENTS.md`.
- Store implementation plans in `.context/plans/`.
- Store the remote-aware local changelog in `.context/CHANGELOG.md`.
- Write every file under `.context/` in English, even when the user or task
  uses another language. Preserve exact identifiers and required quotations.
- Add `/.context/` to `.git/info/exclude`; do not modify tracked `.gitignore`
  for personal context.
- Never modify tracked `AGENTS.md`, `CLAUDE.md`, `docs/`, or `plans/` merely to
  store personal notes.

## Validation

Run checks proportional to the change. For installer, rule, or shared-skill
changes, the expected baseline is:

```bash
bash -n install.sh install-codex.sh hooks/*.sh
bash install.sh
bash install-codex.sh
git diff --check
```

Also verify the affected installed files under `~/.claude/` and
`~/.agents/skills/`. For MCP changes, inspect `claude mcp list` and
`codex mcp list`. Treat successful migration as insufficient when the migration
report contains a relevant `manual_fix_required` item.

## Git policy

- Use commit titles in the form `<type>[optional scope]: description`.
- Commit titles only: no body or trailers.
- Stage only reviewed files relevant to the current task.
- Always show the proposed title and file list, then wait for explicit user
  confirmation before committing.
- Never discard unrelated working-tree changes.
