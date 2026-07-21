#!/usr/bin/env bash
# Removes every symlink this repo's install.sh created in ~/.claude/, using
# the manifest written by install.sh. Never touches settings.json or
# rules/neo4j-graph-first.md (they were never in the manifest to begin with).
set -euo pipefail

CLAUDE_DIR="${HOME}/.claude"
MANIFEST="${CLAUDE_DIR}/.my-ai-config-manifest"

if [ ! -f "${MANIFEST}" ]; then
  echo "No manifest found at ${MANIFEST} — nothing to uninstall."
  exit 0
fi

removed=0
while IFS= read -r target; do
  [ -z "${target}" ] && continue
  if [ -L "${target}" ]; then
    rm "${target}"
    echo "removed: ${target}"
    removed=$((removed + 1))
  fi
done < "${MANIFEST}"

rm "${MANIFEST}"
echo "Done. ${removed} item(s) removed."
