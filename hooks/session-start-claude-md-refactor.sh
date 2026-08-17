#!/usr/bin/env bash
# SessionStart hook: detect the local-only .context/ context scaffold and tell
# Claude what to load or bootstrap. The hook is read-only and fail-open.

set -u

input="$(cat)"
cwd="$(printf '%s' "$input" | /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin).get("cwd",""))' 2>/dev/null)"
[ -z "$cwd" ] && cwd="$PWD"

repo_root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)"
[ -z "$repo_root" ] && exit 0

local_root="${repo_root}/.context"
missing=()

[ -f "${local_root}/AGENTS.md" ] || missing+=(".context/AGENTS.md")
[ -L "${local_root}/CLAUDE.md" ] && [ "$(readlink "${local_root}/CLAUDE.md")" = "AGENTS.md" ] || missing+=(".context/CLAUDE.md -> AGENTS.md")
[ -f "${local_root}/CHANGELOG.md" ] || missing+=(".context/CHANGELOG.md")
[ -d "${local_root}/plans" ] || missing+=(".context/plans/")

if [ "${#missing[@]}" -eq 0 ]; then
  context="Read ${local_root}/AGENTS.md as supplementary local context after repository-tracked instructions. Load only task-relevant files linked from it. Start its non-blocking background remote synchronization for .context/CHANGELOG.md when delegation is available; never change the working tree or tracked files."
else
  list="$(printf '%s, ' "${missing[@]}")"
  list="${list%, }"
  context="This repo is missing part of the local claude-md-refactor scaffold: ${list}. Use the claude-md-refactor skill to bootstrap it under .context/ only. Add /.context/ to .git/info/exclude, never modify remote/tracked CLAUDE.md, AGENTS.md, docs/, plans/, or .gitignore, and ask before creating INFRASTRUCTURE.md content that would require guessing."
fi

python3 -c '
import json, sys
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": sys.argv[1],
    }
}))
' "$context"
