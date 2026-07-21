#!/bin/bash
# update-check.sh — generic periodic version check for Claude Code skills.
#
# Auto-detects skill name, repo root, and VERSION path from $0 location.
# Works for any skill in the xsolla/claude-config repo (or forks).
#
# Output (one line, or nothing):
#   JUST_UPGRADED <old> <new>       — marker found from recent upgrade
#   UPGRADE_AVAILABLE <old> <new>   — remote VERSION differs from local
#   (nothing)                       — up to date, or check skipped
#
# Env overrides (for testing):
#   SKILL_ROOT_DIR   — override auto-detected skill root
#   SKILL_STATE_DIR  — override state directory
#
# Fallback config (for non-git installs):
#   SKILL_REPO       — GitHub owner/repo (default: xsolla/claude-config)
#   SKILL_PATH       — path within repo to skill dir (auto-detected)
set -euo pipefail

# ─── Resolve paths ────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
SKILL_DIR="${SKILL_ROOT_DIR:-$(cd "$SCRIPT_DIR/.." && pwd -P)}"
SKILL_NAME="$(basename "$SKILL_DIR")"

STATE_DIR="${SKILL_STATE_DIR:-$HOME/.claude/skill-versions/$SKILL_NAME}"
CACHE_FILE="$STATE_DIR/last-update-check"
MARKER_FILE="$STATE_DIR/just-upgraded-from"
VERSION_FILE="$SKILL_DIR/VERSION"

# GitHub repo for fallback API check
SKILL_REPO="${SKILL_REPO:-xsolla/claude-config}"

# ─── Auto-detect VERSION relative path ────────────────────────────────────────

find_git_root() {
  local dir="$1"
  while [ "$dir" != "/" ]; do
    if [ -d "$dir/.git" ]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

REPO_ROOT=""
REPO_ROOT=$(find_git_root "$SKILL_DIR" 2>/dev/null) || true

VERSION_REL_PATH=""
if [ -n "$REPO_ROOT" ]; then
  # Derive relative path from repo root to VERSION file
  VERSION_REL_PATH="${SKILL_DIR#$REPO_ROOT/}/VERSION"
elif [ -n "${SKILL_PATH:-}" ]; then
  VERSION_REL_PATH="$SKILL_PATH/VERSION"
fi

# ─── Force flag (busts cache) ────────────────────────────────────────────────

if [ "${1:-}" = "--force" ]; then
  rm -f "$CACHE_FILE"
fi

# ─── Step 1: Read local version ──────────────────────────────────────────────

LOCAL=""
if [ -f "$VERSION_FILE" ]; then
  LOCAL="$(cat "$VERSION_FILE" 2>/dev/null | tr -d '[:space:]')"
fi
if [ -z "$LOCAL" ]; then
  exit 0  # No VERSION file → skip check (pre-upgrade install)
fi

# ─── Step 2: Check "just upgraded" marker ─────────────────────────────────────

if [ -f "$MARKER_FILE" ]; then
  OLD="$(cat "$MARKER_FILE" 2>/dev/null | tr -d '[:space:]')"
  rm -f "$MARKER_FILE"
  mkdir -p "$STATE_DIR"
  echo "UP_TO_DATE $LOCAL" > "$CACHE_FILE"
  if [ -n "$OLD" ]; then
    echo "JUST_UPGRADED $OLD $LOCAL"
  fi
  exit 0
fi

# ─── Step 3: Check cache freshness (60 min TTL) ──────────────────────────────

if [ -f "$CACHE_FILE" ]; then
  CACHED="$(cat "$CACHE_FILE" 2>/dev/null || true)"

  STALE=$(find "$CACHE_FILE" -mmin +60 2>/dev/null || true)
  if [ -z "$STALE" ]; then
    # Cache is fresh
    case "$CACHED" in
      UP_TO_DATE*)
        CACHED_VER="$(echo "$CACHED" | awk '{print $2}')"
        if [ "$CACHED_VER" = "$LOCAL" ]; then
          exit 0  # confirmed up to date
        fi
        ;;
      UPGRADE_AVAILABLE*)
        CACHED_OLD="$(echo "$CACHED" | awk '{print $2}')"
        if [ "$CACHED_OLD" = "$LOCAL" ]; then
          echo "$CACHED"
          exit 0
        fi
        ;;
    esac
  fi
fi

# ─── Step 4: Slow path — fetch remote version ────────────────────────────────

mkdir -p "$STATE_DIR"

REMOTE=""

# Must have a relative path to check
if [ -z "$VERSION_REL_PATH" ]; then
  echo "UP_TO_DATE $LOCAL" > "$CACHE_FILE"
  exit 0
fi

# Strategy A: git-based (primary) — works if skill dir is inside a git repo
if [ -n "$REPO_ROOT" ]; then
  if git -C "$REPO_ROOT" fetch origin main --quiet --no-tags 2>/dev/null; then
    REMOTE=$(git -C "$REPO_ROOT" show origin/main:"$VERSION_REL_PATH" 2>/dev/null | tr -d '[:space:]') || true
  fi
fi

# Strategy B: gh api fallback (vendored installs without .git)
if [ -z "$REMOTE" ] && command -v gh &>/dev/null; then
  REMOTE=$(gh api repos/"$SKILL_REPO"/contents/"$VERSION_REL_PATH" -q '.content' 2>/dev/null | base64 -d 2>/dev/null | tr -d '[:space:]') || true
fi

# Validate: must look like a version number
if ! echo "$REMOTE" | grep -qE '^[0-9]+(\.[0-9]+)+$'; then
  # Invalid or empty — assume up to date (fail open)
  echo "UP_TO_DATE $LOCAL" > "$CACHE_FILE"
  exit 0
fi

# ─── Step 5: Compare versions ────────────────────────────────────────────────

if [ "$LOCAL" = "$REMOTE" ]; then
  echo "UP_TO_DATE $LOCAL" > "$CACHE_FILE"
  exit 0
fi

# Versions differ — upgrade available
echo "UPGRADE_AVAILABLE $LOCAL $REMOTE" > "$CACHE_FILE"
echo "UPGRADE_AVAILABLE $LOCAL $REMOTE"
