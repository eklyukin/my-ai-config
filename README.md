# my-ai-config

`my-ai-config` is a personal, repository-managed configuration for Claude Code
and Codex. It keeps reusable rules, skills, commands, hooks, and global MCP
defaults in one place and installs them without taking ownership of unrelated
user or corporate configuration.

## What is included

- shared coding and commit rules;
- reusable engineering, review, planning, frontend, infrastructure, and Neo4j
  skills;
- Claude Code commands, agents, and lifecycle hooks;
- Codex-compatible versions of the shared skills and instructions;
- global browser MCP defaults:
  - `playwright` for repeatable browser automation and UI tests;
  - `chrome-devtools` for inspecting an existing Chrome session;
  - `computer-use` for Codex Desktop when its local client is available;
- the `.context/` convention for conflict-free, repository-local personal
  context and implementation plans.

## Requirements

- macOS or another Unix-like environment with Bash;
- Git;
- Claude Code installed for Claude configuration;
- Codex installed for Codex configuration;
- `jq` for merging Claude hook registrations;
- the curated `migrate-to-codex` skill available to Codex.

If `migrate-to-codex` is not installed, ask Codex to install the curated skill:

```text
$skill-installer migrate-to-codex
```

Restart Codex after installation. The installer locates the bundled migration
script under `~/.codex/vendor_imports/skills/`.

## Installation

Clone the repository and enter it:

```bash
git clone https://github.com/eklyukin/my-ai-config.git
cd my-ai-config
```

Install the Claude Code configuration first:

```bash
bash install.sh
```

This creates managed symlinks under `~/.claude/` for repository content in
`rules/`, `skills/`, `agents/`, `commands/`, and `hooks/`. Re-running the
installer is safe and converges the managed symlinks to the current repository
state. Existing real files and symlinks not owned by this repository are not
overwritten.

The installer also:

- registers this repository's Claude hooks in `~/.claude/settings.json` while
  preserving unrelated settings;
- installs `playwright` and `chrome-devtools` as user-scoped Claude MCP
  servers.

Then install the Codex configuration:

```bash
bash install-codex.sh
```

The Codex installer migrates the Claude configuration into Codex, then restores
Codex-native settings that the migration tool does not own. In particular, it
preserves project trust levels, Codex MCP servers, marketplaces, plugins,
feature flags, shell policy, and the corporate Neuronet instruction block. It
also copies supporting files referenced by shared skills, installs the shared
`.context/` discovery rule, and registers Codex Desktop's `computer-use` MCP
when available.

Both installers are designed to be re-run after pulling repository updates.

## Verification

Check that the expected skills and MCP servers are visible:

```bash
test -f ~/.claude/skills/grill-me/SKILL.md
test -f ~/.agents/skills/grill-me/SKILL.md
claude mcp list
codex mcp list
```

The browser defaults should include `playwright` and `chrome-devtools` in both
clients, plus `computer-use` in Codex when Codex Desktop provides the local
client.

## Repository structure

```text
.
├── AGENTS.md          # canonical repository instructions for AI agents
├── CLAUDE.md          # Claude entry point; delegates to AGENTS.md
├── README.md          # user documentation
├── rules/             # shared behavioral and workflow rules
├── skills/            # reusable skills, one directory per skill
├── agents/            # Claude-specific subagent definitions
├── commands/          # Claude-specific commands
├── hooks/             # lifecycle hooks
├── install.sh         # Claude installer
├── install-codex.sh   # Codex migration and repair installer
└── uninstall.sh       # removes Claude symlinks managed by this repository
```

## Local repository context

The `repository-context` skill stores personal repository context under an
ignored `.context/` directory:

```text
.context/
├── AGENTS.md
├── CLAUDE.md -> AGENTS.md
├── CHANGELOG.md
├── INFRASTRUCTURE.md
├── contexts/
└── plans/
```

`.context/AGENTS.md` is the canonical map. Agents read only the linked files
needed for the current task, while tracked repository instructions always have
priority. The directory is excluded locally through `/.context/` in
`.git/info/exclude`; tracked `.gitignore`, `AGENTS.md`, `CLAUDE.md`, `docs/`,
and `plans/` are not modified to store personal context. Every document under
`.context/` is written in English regardless of the conversation language.

The `grill-me` workflow interviews the user before implementation, records the
confirmed agreement in `.context/plans/YYYY-MM-DD-<slug>.md`, and waits for a
separate instruction before changing product code.

## Adding or updating configuration

Add content to the matching repository directory:

- `rules/<name>.md` for shared rules;
- `skills/<name>/SKILL.md` for a skill;
- `agents/<name>.md` for a Claude subagent;
- `commands/<name>.md` for a Claude command;
- `hooks/<name>.sh` for a lifecycle hook.

When a hook needs automatic registration, add its event mapping to
`HOOK_EVENTS` in `install.sh`. After any change, run both installers and verify
the installed paths.

## Configuration ownership

The installers intentionally preserve configuration they do not own. Notable
examples include:

- unrelated keys in `~/.claude/settings.json`;
- the corporate-managed `neo4j-graph-first` rule;
- unrelated Claude skills and MCP servers;
- Codex project trust levels, native MCP servers, plugins, marketplaces,
  features, and shell policy.

Review `~/.codex/migrate-to-codex-report.txt` after migration for fields that
require manual compatibility review.

The repository owns only the Claude symlinks recorded in
`~/.claude/.my-ai-config-manifest`, its hook command registrations listed in
`HOOK_EVENTS`, the user-scoped Claude MCP entries named `playwright` and
`chrome-devtools`, the marked `my-ai-config-local-context` block in
`~/AGENTS.md`, the Codex `computer-use` MCP entry it registers, and a converted
Codex skill at `~/.agents/skills/<name>` only when the corresponding
`~/.claude/skills/<name>` symlink is recorded in the manifest and resolves
inside this repository. All other configuration must be preserved or restored
during installation.

## Uninstalling Claude symlinks

```bash
bash uninstall.sh
```

The uninstall script removes only Claude symlinks recorded as managed by this
repository. Codex migration output is not removed automatically because it is
merged with native Codex configuration.
