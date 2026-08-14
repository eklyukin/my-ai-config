#!/usr/bin/env bash
# Symlinks this repo's rules/skills/agents/commands/hooks into ~/.claude/.
# Idempotent: re-running always converges ~/.claude/* to match this repo.
#
# Mostly never touches ~/.claude/settings.json or ~/.claude/rules/neo4j-graph-first.md —
# those are managed by the corporate MDM push, not this repo. The one scoped exception:
# this repo's own hooks/*.sh scripts need a hooks.<Event> entry in settings.json to
# actually run, so we merge just those entries in (see "register hook triggers" below) —
# every other key in settings.json is left untouched.
set -euo pipefail
shopt -s nullglob

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
MANIFEST="${CLAUDE_DIR}/.my-ai-config-manifest"
SETTINGS_JSON="${CLAUDE_DIR}/settings.json"
MANAGED_DIRS=(rules skills agents commands hooks)

# MCP servers owned by this repo and installed globally for Claude Code.
# install-codex.sh migrates them into Codex and adds Codex Desktop computer-use.

# hooks/<script>=<Event> it needs registered under in settings.json. Plain array,
# not an associative one — the default bash on macOS (3.2) predates declare -A.
# Add an entry here whenever a new hook script needs to actually fire.
HOOK_EVENTS=(
  "session-start-claude-md-refactor.sh=SessionStart"
)

mkdir -p "${CLAUDE_DIR}"

# Build the set of symlink targets this run of the repo should produce.
current_targets=()
for dir in "${MANAGED_DIRS[@]}"; do
  src_dir="${REPO_DIR}/${dir}"
  [ -d "${src_dir}" ] || continue
  for entry in "${src_dir}"/*; do
    name="$(basename "${entry}")"
    [ "${name}" = ".gitkeep" ] && continue
    current_targets+=("${CLAUDE_DIR}/${dir}/${name}")
  done
done

# Remove symlinks left over from a previous install that no longer correspond
# to anything in the repo (renamed/deleted skill, etc). Only touch symlinks
# that point into this repo — never a real file or a symlink owned by someone else.
if [ -f "${MANIFEST}" ]; then
  while IFS= read -r old_target; do
    [ -z "${old_target}" ] && continue
    if printf '%s\n' "${current_targets[@]:-}" | grep -qxF "${old_target}"; then
      continue
    fi
    if [ -L "${old_target}" ]; then
      resolved="$(readlink "${old_target}")"
      case "${resolved}" in
        "${REPO_DIR}"/*) rm "${old_target}"; echo "removed stale symlink: ${old_target}" ;;
      esac
    fi
  done < "${MANIFEST}"
fi

installed=()
for target in "${current_targets[@]:-}"; do
  [ -z "${target}" ] && continue
  dir="$(dirname "${target}")"
  name="$(basename "${target}")"
  src="${REPO_DIR}/$(basename "${dir}")/${name}"
  mkdir -p "${dir}"

  if [ -e "${target}" ] && [ ! -L "${target}" ]; then
    echo "WARN: ${target} exists and is not a symlink — skipping, not overwriting" >&2
    continue
  fi

  ln -sfn "${src}" "${target}"
  installed+=("${target}")
  echo "linked: ${target} -> ${src}"
done

printf '%s\n' "${installed[@]:-}" > "${MANIFEST}"

echo "Done. ${#installed[@]} item(s) linked into ${CLAUDE_DIR}."

# --- install this repo's global MCP servers for Claude Code ---
# These entries are intentionally user-scoped so they are available in every
# project. Replacing only the named entries keeps the operation idempotent and
# leaves all unrelated MCP configuration untouched.
if command -v claude >/dev/null 2>&1; then
  install_global_mcp() {
    name="$1"
    shift
    claude mcp remove --scope user "${name}" >/dev/null 2>&1 || true
    claude mcp add --scope user "${name}" -- "$@"
  }

  install_global_mcp playwright npx -y @playwright/mcp@latest
  install_global_mcp chrome-devtools npx -y chrome-devtools-mcp@latest
else
  echo "WARN: claude CLI not found — skipping global Claude MCP installation" >&2
fi

# --- register this repo's hook scripts under their required event in settings.json ---
# Scoped, idempotent merge: only adds a hooks.<Event> entry for scripts in HOOK_EVENTS
# whose command isn't already registered under that event. Every other key in
# settings.json — permissions, env, MDM-pushed hooks, etc. — is left byte-for-byte alone.
if command -v jq >/dev/null 2>&1; then
  if [ ! -f "${SETTINGS_JSON}" ]; then
    echo '{}' > "${SETTINGS_JSON}"
  fi
  for entry in "${HOOK_EVENTS[@]}"; do
    script="${entry%%=*}"
    event="${entry#*=}"
    hook_path="${CLAUDE_DIR}/hooks/${script}"
    [ -e "${hook_path}" ] || continue   # not installed this run (e.g. removed from repo)

    already_registered="$(jq -r --arg event "${event}" --arg cmd "${hook_path}" '
      [(.hooks[$event] // [])[] | .hooks[]? | select(.type == "command" and .command == $cmd)] | length > 0
    ' "${SETTINGS_JSON}")"

    if [ "${already_registered}" != "true" ]; then
      tmp_settings="$(mktemp)"
      jq --arg event "${event}" --arg cmd "${hook_path}" '
        .hooks[$event] = ((.hooks[$event] // []) + [{"hooks": [{"type": "command", "command": $cmd}]}])
      ' "${SETTINGS_JSON}" > "${tmp_settings}" && mv "${tmp_settings}" "${SETTINGS_JSON}"
      echo "registered hook: ${event} -> ${hook_path} (in ${SETTINGS_JSON})"
    fi
  done
else
  echo "WARN: jq not found — skipping hooks.<Event> registration in ${SETTINGS_JSON}; run manually or install jq and re-run" >&2
fi
