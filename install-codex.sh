#!/usr/bin/env bash
# Runs OpenAI's migrate-to-codex Codex skill against ~/.claude/ and merges the
# result into ~/.codex/, then repairs the things that migrator overwrites
# wholesale instead of merging: ~/AGENTS.md and ~/.codex/config.toml.
#
# Why the repair step exists:
# - ~/AGENTS.md carries a corporate-managed Neuronet code-search block (same
#   role as ~/.claude/rules/neo4j-graph-first.md — pushed by MDM, not owned by
#   this repo). The migrator picks CLAUDE.md as the instruction source and
#   overwrites AGENTS.md with CLAUDE.md's shorter, Claude-only version of that
#   block, which points at a path (rules/neo4j-graph-first.md) Codex can't see.
# - ~/.codex/config.toml is rebuilt from scratch from Claude's settings on
#   every run, so it drops Codex-native `[projects."..."]` trust levels and
#   can write an invalid `model = "..."` (a Claude model alias like "sonnet"
#   isn't a real Codex model id).
#
# Safe to re-run: idempotent snapshot-then-restore, same pattern as install.sh.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_HOME="${HOME}/.codex"
CLAUDE_HOME="${HOME}/.claude"
AGENTS_MD="${HOME}/AGENTS.md"
CONFIG_TOML="${CODEX_HOME}/config.toml"
LOCAL_CONTEXT_RULE="${CLAUDE_HOME}/rules/local-context.md"
BROWSER_RULE="${CLAUDE_HOME}/rules/existing-browser.md"
COMPUTER_USE_CLIENT="${CODEX_HOME}/computer-use/Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient"
SLACK_MCP_URL="https://mcp.slack.com/mcp"
SLACK_MCP_TOKEN_ENV="SLACK_MCP_TOKEN"
VIMEO_MCP_URL="https://mcp.vimeo.com/mcp"

MIGRATOR="$(find "${CODEX_HOME}/vendor_imports/skills" -maxdepth 6 -name migrate-to-codex.py 2>/dev/null | head -1)"
if [ -z "${MIGRATOR}" ]; then
  echo "ERROR: migrate-to-codex.py not found under ${CODEX_HOME}/vendor_imports/skills/ — is the migrate-to-codex Codex skill installed?" >&2
  exit 1
fi

# --dry-run/--scan-only/--plan/--doctor/--validate-target don't touch disk —
# skip the repair step so it doesn't rewrite files for a no-op inspection run.
read_only=false
for arg in "$@"; do
  case "${arg}" in
    --dry-run|--scan-only|--plan|--doctor|--validate-target*) read_only=true ;;
  esac
done

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

# --- snapshot what the migrator does not own, before it overwrites anything ---
projects_snapshot="${tmp_dir}/projects.toml"
: > "${projects_snapshot}"
if [ -f "${CONFIG_TOML}" ]; then
  awk '
    /^\[projects\./ { in_block=1 }
    in_block && /^\[/ && !/^\[projects\./ { in_block=0 }
    in_block { print }
  ' "${CONFIG_TOML}" > "${projects_snapshot}"
fi

# Preserve Codex-native MCP servers that have no Claude equivalent. The
# migrator rebuilds config.toml from Claude and would otherwise delete them.
mcp_snapshot="${tmp_dir}/mcp-servers.toml"
: > "${mcp_snapshot}"
if [ -f "${CONFIG_TOML}" ]; then
  awk '
    /^\[mcp_servers\./ { in_block=1 }
    in_block && /^\[/ && !/^\[mcp_servers\./ { in_block=0 }
    in_block { print }
  ' "${CONFIG_TOML}" > "${mcp_snapshot}"
fi

# Preserve Codex app/runtime configuration that has no Claude equivalent.
# The migrator rebuilds config.toml and otherwise drops installed marketplaces,
# enabled plugins, Codex feature flags, and the shell environment policy.
codex_native_snapshot="${tmp_dir}/codex-native.toml"
: > "${codex_native_snapshot}"
if [ -f "${CONFIG_TOML}" ]; then
  awk '
    /^\[features\]$/ || /^\[marketplaces\./ || /^\[plugins\./ || /^\[shell_environment_policy\]$/ { in_block=1 }
    in_block && /^\[/ && !/^\[features\]$/ && !/^\[marketplaces\./ && !/^\[plugins\./ && !/^\[shell_environment_policy\]$/ { in_block=0 }
    in_block { print }
  ' "${CONFIG_TOML}" > "${codex_native_snapshot}"
fi

neo4j_block_snapshot="${tmp_dir}/neo4j-block.md"
: > "${neo4j_block_snapshot}"
if [ -f "${AGENTS_MD}" ] && grep -q "neo4j-graph-first:start" "${AGENTS_MD}"; then
  sed -n '/neo4j-graph-first:start/,/neo4j-graph-first:end/p' "${AGENTS_MD}" > "${neo4j_block_snapshot}"
fi

[ -f "${AGENTS_MD}" ] && cp -f "${AGENTS_MD}" "${AGENTS_MD}.pre-codex-migration.bak"
[ -f "${CONFIG_TOML}" ] && cp -f "${CONFIG_TOML}" "${CONFIG_TOML}.pre-codex-migration.bak"

# --- run the real migration ---
python3 "${MIGRATOR}" --source "${CLAUDE_HOME}/" --target "${CODEX_HOME}/" "$@"

if [ "${read_only}" = true ]; then
  exit 0
fi

# The migrator converts SKILL.md but does not copy referenced support files.
# Copy those files only for Claude skill symlinks owned by this repository,
# while preserving the migrator's Codex-compatible SKILL.md conversion.
python3 - "${CLAUDE_HOME}" "${HOME}/.agents/skills" "${REPO_DIR}" <<'PYEOF'
import os
import shutil
import sys

claude_home, codex_skills, repository = map(os.path.realpath, sys.argv[1:])
claude_skills = os.path.join(claude_home, "skills")
repository_skills = os.path.join(repository, "skills") + os.sep

if os.path.isdir(claude_skills):
    for name in os.listdir(claude_skills):
        source_link = os.path.join(claude_skills, name)
        if not os.path.islink(source_link):
            continue
        source = os.path.realpath(source_link)
        if not source.startswith(repository_skills):
            continue
        target = os.path.join(codex_skills, name)
        if not os.path.isdir(target):
            continue
        copied = 0
        for root, directories, files in os.walk(source):
            directories[:] = [entry for entry in directories if not entry.startswith(".")]
            relative_root = os.path.relpath(root, source)
            target_root = target if relative_root == "." else os.path.join(target, relative_root)
            os.makedirs(target_root, exist_ok=True)
            for filename in files:
                if relative_root == "." and filename == "SKILL.md":
                    continue
                shutil.copy2(os.path.join(root, filename), os.path.join(target_root, filename))
                copied += 1
        if copied:
            print(f"repaired: {target} (copied {copied} supporting skill file(s))")
PYEOF

# Remove Codex skill directories generated from repository-managed Claude
# skills that were intentionally renamed. The migrator runs in merge mode and
# otherwise leaves these orphaned generated targets behind.
legacy_skill="${HOME}/.agents/skills/claude-md-refactor"
if [ -d "${legacy_skill}" ] && [ ! -e "${CLAUDE_HOME}/skills/claude-md-refactor" ]; then
  rm -rf -- "${legacy_skill}"
  echo "removed renamed Codex skill: ${legacy_skill}"
fi

# --- repair AGENTS.md: restore the cross-agent-managed neo4j block verbatim ---
if [ -s "${neo4j_block_snapshot}" ] && [ -f "${AGENTS_MD}" ]; then
  python3 - "${AGENTS_MD}" "${neo4j_block_snapshot}" <<'PYEOF'
import re
import sys

agents_path, block_path = sys.argv[1], sys.argv[2]
agents = open(agents_path).read()
block = open(block_path).read().rstrip("\n")
pattern = re.compile(r"<!-- neo4j-graph-first:start.*?neo4j-graph-first:end -->", re.DOTALL)
if pattern.search(agents):
    agents = pattern.sub(lambda _: block, agents, count=1)
else:
    agents = agents.rstrip("\n") + "\n\n" + block + "\n"
agents = re.sub(
    r"\n## MANUAL MIGRATION REQUIRED\n\nClaude-only instructions were copied into `AGENTS\.md`\. Remove Claude hooks, slash commands, and subagent assumptions before relying on this file in Codex\.\n",
    "\n",
    agents,
)
open(agents_path, "w").write(agents)
PYEOF
  echo "repaired: ${AGENTS_MD} (restored corporate neo4j-graph-first block)"
fi

# --- install the shared .context/ discovery rule for Codex ---
# Claude loads this file from ~/.claude/rules; Codex needs the same content in
# its global AGENTS.md. Replace only this repo's marked block.
if [ -f "${LOCAL_CONTEXT_RULE}" ] && [ -f "${AGENTS_MD}" ]; then
  python3 - "${AGENTS_MD}" "${LOCAL_CONTEXT_RULE}" <<'PYEOF'
import re
import sys

agents_path, rule_path = sys.argv[1], sys.argv[2]
agents = open(agents_path).read().rstrip("\n")
rule = open(rule_path).read().strip()
block = (
    "<!-- my-ai-config-local-context:start -->\n"
    + rule
    + "\n<!-- my-ai-config-local-context:end -->"
)
pattern = re.compile(
    r"\n?<!-- my-ai-config-local-context:start -->.*?"
    r"<!-- my-ai-config-local-context:end -->",
    re.DOTALL,
)
if pattern.search(agents):
    agents = pattern.sub("\n\n" + block, agents, count=1)
else:
    agents += "\n\n" + block
open(agents_path, "w").write(agents.strip() + "\n")
PYEOF
  echo "repaired: ${AGENTS_MD} (installed .context/ discovery rule)"
fi

# --- install the shared existing-browser rule for Codex ---
# Keep the browser policy global for both clients while replacing only this
# repository's explicitly owned marked block.
if [ -f "${BROWSER_RULE}" ] && [ -f "${AGENTS_MD}" ]; then
  python3 - "${AGENTS_MD}" "${BROWSER_RULE}" <<'PYEOF'
import re
import sys

agents_path, rule_path = sys.argv[1], sys.argv[2]
agents = open(agents_path).read().rstrip("\n")
rule = open(rule_path).read().strip()
block = (
    "<!-- my-ai-config-browser:start -->\n"
    + rule
    + "\n<!-- my-ai-config-browser:end -->"
)
pattern = re.compile(
    r"\n?<!-- my-ai-config-browser:start -->.*?"
    r"<!-- my-ai-config-browser:end -->",
    re.DOTALL,
)
if pattern.search(agents):
    agents = pattern.sub("\n\n" + block, agents, count=1)
else:
    agents += "\n\n" + block
open(agents_path, "w").write(agents.strip() + "\n")
PYEOF
  echo "repaired: ${AGENTS_MD} (installed existing-browser rule)"
fi

# --- repair config.toml: re-add project trust levels, drop invalid model id ---
if [ -f "${CONFIG_TOML}" ]; then
  python3 - "${CONFIG_TOML}" "${projects_snapshot}" <<'PYEOF'
import re
import sys

config_path, projects_path = sys.argv[1], sys.argv[2]
config = open(config_path).read()
config = re.sub(r'^model\s*=\s*".*"\n', "", config, flags=re.MULTILINE)
projects = open(projects_path).read().strip()
if projects:
    marker = 'personality = "friendly"\n'
    if marker in config:
        config = config.replace(marker, marker + "\n" + projects + "\n", 1)
    else:
        config = projects + "\n\n" + config
open(config_path, "w").write(config)
PYEOF
  echo "repaired: ${CONFIG_TOML} (restored [projects] trust levels, dropped Claude model alias)"
fi

# Re-add only MCP servers that the Claude migration did not produce. Existing
# migrated names win; Codex-only entries such as node_repl remain available.
if [ -s "${mcp_snapshot}" ] && [ -f "${CONFIG_TOML}" ]; then
  python3 - "${CONFIG_TOML}" "${mcp_snapshot}" <<'PYEOF'
import re
import sys

config_path, snapshot_path = sys.argv[1], sys.argv[2]
config = open(config_path).read().rstrip("\n")
snapshot = open(snapshot_path).read()
starts = list(re.finditer(r'^\[mcp_servers\.([^].]+)\]\s*$', snapshot, re.MULTILINE))
missing = []
for index, match in enumerate(starts):
    end = starts[index + 1].start() if index + 1 < len(starts) else len(snapshot)
    name = match.group(1)
    if not re.search(r'^\[mcp_servers\.' + re.escape(name) + r'\]\s*$', config, re.MULTILINE):
        missing.append(snapshot[match.start():end].strip("\n"))
if missing:
    config += "\n\n" + "\n\n".join(missing)
open(config_path, "w").write(config + "\n")
PYEOF
  echo "repaired: ${CONFIG_TOML} (restored Codex-native MCP servers missing from Claude migration)"
fi

# Restore Codex-native sections absent from the Claude-generated config.
if [ -s "${codex_native_snapshot}" ] && [ -f "${CONFIG_TOML}" ]; then
  python3 - "${CONFIG_TOML}" "${codex_native_snapshot}" <<'PYEOF'
import re
import sys

config_path, snapshot_path = sys.argv[1], sys.argv[2]
config = open(config_path).read().rstrip("\n")
snapshot = open(snapshot_path).read()
starts = list(re.finditer(r'^\[([^]]+)\]\s*$', snapshot, re.MULTILINE))
missing = []
for index, match in enumerate(starts):
    end = starts[index + 1].start() if index + 1 < len(starts) else len(snapshot)
    header = match.group(0).strip()
    if not re.search(r'^' + re.escape(header) + r'\s*$', config, re.MULTILINE):
        missing.append(snapshot[match.start():end].strip("\n"))
if missing:
    config += "\n\n" + "\n\n".join(missing)
open(config_path, "w").write(config + "\n")
PYEOF
  echo "repaired: ${CONFIG_TOML} (restored Codex marketplaces, plugins, features, and shell policy)"
fi

# Claude reserves the name "computer-use", so this Codex Desktop MCP cannot be
# stored in Claude's user configuration and migrated. Register it directly in
# Codex instead. The absolute command keeps it globally usable from any cwd.
if [ -x "${COMPUTER_USE_CLIENT}" ]; then
  codex mcp remove computer-use >/dev/null 2>&1 || true
  codex mcp add computer-use -- "${COMPUTER_USE_CLIENT}" mcp
else
  echo "WARN: Codex Desktop computer-use client not found — skipping global computer-use MCP" >&2
fi

# Register Slack's hosted MCP endpoint without storing credentials in
# config.toml. The user supplies a read-only xoxp token through the named
# environment variable; see docs/slack-mcp.md for the OAuth and desktop setup.
codex mcp remove slack >/dev/null 2>&1 || true
codex mcp add slack \
  --url "${SLACK_MCP_URL}" \
  --bearer-token-env-var "${SLACK_MCP_TOKEN_ENV}"

# Vimeo uses browser-based OAuth, so no token or client secret is stored here.
# Keep an existing matching entry to preserve its OAuth session across reruns.
if codex mcp get vimeo 2>/dev/null | grep -qF "url: ${VIMEO_MCP_URL}"; then
  echo "unchanged: Vimeo MCP (${VIMEO_MCP_URL})"
else
  codex mcp remove vimeo >/dev/null 2>&1 || true
  codex mcp add vimeo --url "${VIMEO_MCP_URL}"
fi

if command -v launchctl >/dev/null 2>&1 \
  && [ -n "$(launchctl getenv "${SLACK_MCP_TOKEN_ENV}")" ]; then
  echo "configured: Slack MCP (${SLACK_MCP_TOKEN_ENV} is available to desktop apps)"
else
  echo "NOTICE: Slack MCP requires ${SLACK_MCP_TOKEN_ENV}; follow ${REPO_DIR}/docs/slack-mcp.md" >&2
fi

echo "Done. Review ${CODEX_HOME}/migrate-to-codex-report.txt for remaining manual-review items."
