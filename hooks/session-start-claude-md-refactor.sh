#!/usr/bin/env bash
# SessionStart hook: read-only check for whether the repo at cwd has the
# claude-md-refactor scaffold (root CLAUDE.md, AGENTS.md symlink, INFRASTRUCTURE.md,
# plans/, plans/CHANGELOG.md). If anything is missing, inject a reminder so Claude
# considers bootstrapping via the claude-md-refactor skill instead of silently
# proceeding without it. Never creates/modifies anything itself.
#
# Fail-open: any uncertainty (not a git repo, can't parse input) means say nothing.

set -u

input="$(cat)"

cwd="$(printf '%s' "$input" | /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin).get("cwd",""))' 2>/dev/null)"
[ -z "$cwd" ] && cwd="$PWD"

repo_root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)"
[ -z "$repo_root" ] && exit 0   # not a git repo -> nothing to scaffold

missing=()

[ -f "$repo_root/CLAUDE.md" ] || missing+=("root CLAUDE.md")
[ -e "$repo_root/AGENTS.md" ] || missing+=("AGENTS.md symlink")
[ -f "$repo_root/INFRASTRUCTURE.md" ] || missing+=("INFRASTRUCTURE.md")
[ -d "$repo_root/plans" ] || missing+=("plans/")
[ -f "$repo_root/plans/CHANGELOG.md" ] || missing+=("plans/CHANGELOG.md")

[ "${#missing[@]}" -eq 0 ] && exit 0   # scaffold already complete, nothing to say

list="$(printf '%s, ' "${missing[@]}")"
list="${list%, }"

context="This repo is missing part of the claude-md-refactor scaffold: ${list}. Before or alongside other work this session, consider whether to bootstrap the missing piece(s) via the claude-md-refactor skill — use its own judgment/edge-case rules (e.g. plans/ and plans/CHANGELOG.md should be created as soon as they're missing, not deferred until a real plan/fix; ask the user before creating INFRASTRUCTURE.md content you'd have to guess at). This is a nudge, not a mandate — some repos genuinely don't need this structure."

python3 -c '
import json, sys
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": sys.argv[1],
    }
}))
' "$context"
