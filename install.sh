#!/usr/bin/env bash
# Symlinks this repo's rules/skills/agents/commands/hooks into ~/.claude/.
# Idempotent: re-running always converges ~/.claude/* to match this repo.
#
# Never touches ~/.claude/settings.json or ~/.claude/rules/neo4j-graph-first.md —
# those are managed by the corporate MDM push, not this repo.
set -euo pipefail
shopt -s nullglob

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
MANIFEST="${CLAUDE_DIR}/.my-ai-config-manifest"
MANAGED_DIRS=(rules skills agents commands hooks)

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
