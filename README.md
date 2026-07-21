# my-ai-config

Personal repository of rules/skills/agents/commands for Claude Code, deployed into `~/.claude/` via symlinks.

## Install

```bash
bash install.sh
```

The script symlinks the contents of `rules/`, `skills/`, `agents/`, `commands/`, `hooks/` into the matching directories under `~/.claude/`. Re-running is idempotent:

- if a file/skill was renamed or removed in the repo — the old symlink in `~/.claude/` is removed;
- if a symlink already exists — it's recreated (the repo's current version wins);
- if a real file (not a symlink) already sits at the target path — install.sh **leaves it alone** and prints a warning.

Remove everything install.sh set up:

```bash
bash uninstall.sh
```

## Codex compatibility

```bash
bash install-codex.sh
```

Runs OpenAI's `migrate-to-codex` Codex skill against `~/.claude/` and merges skills, MCP servers, and hooks into `~/.codex/`. That migrator rebuilds `~/AGENTS.md` and `~/.codex/config.toml` from scratch on every run, so the script also repairs what it overwrites: it restores the corporate-managed Neuronet code-search block in `~/AGENTS.md` (not owned by this repo, same as `~/.claude/rules/neo4j-graph-first.md`) and the `[projects."..."]` trust levels in `~/.codex/config.toml`, and drops any invalid Claude model alias (e.g. `sonnet`) the migrator wrote. Safe to re-run. Requires the `migrate-to-codex` Codex skill to already be installed (`~/.codex/vendor_imports/skills/`).

Codex has no equivalent of `agents/` (subagents) or this repo's `hooks/` — those aren't migrated.

## What this repo does NOT own

- `~/.claude/settings.json` — managed by the corporate MDM mechanism (hooks, env). Not touched by this install.sh.
- `~/.claude/rules/neo4j-graph-first.md` — also pushed by MDM (see `~/.claude/.xsolla-mdm-backup/`). Not included in this repo.
- `~/.claude/skills/gcloud` — an existing separate symlink into the corporate `claude-config`, unrelated to this install.sh.

## Adding something new

Drop a file/folder into the matching directory (`rules/`, `skills/<name>/SKILL.md`, `agents/<name>.md`, `commands/<name>.md`, `hooks/<name>.sh`) and re-run `bash install.sh`.

## Reusing skills from the corporate repo

The corporate `claude-config` (`skills/public/...`) holds the company's shared skill catalog. To use a specific skill from there alongside your personal ones, set up a separate symlink by hand (as already done for `gcloud`):

```bash
ln -s /path/to/claude-config/skills/public/<category>/<skill> ~/.claude/skills/<skill>
```

This is deliberately not automated by this repo's `install.sh` — this personal repo is only responsible for what lives inside it.
