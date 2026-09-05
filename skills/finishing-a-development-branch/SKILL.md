---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work - verifies tests, reconciles the .context/plans/ doc for this work, then presents structured options for merge, PR, or cleanup
---

# Finishing a Development Branch

## Overview

Guide completion of development work by presenting clear options and handling chosen workflow.

**Core principle:** Verify tests → Reconcile plan and Jira → Resolve target → Present options → Execute choice → Clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## The Process

### Step 1: Verify Tests

**Before presenting options, verify tests pass:**

```bash
# Run project's test suite
npm test / cargo test / pytest / go test ./...
```

**If tests fail:**
```
Tests failing (<N> failures). Must fix before completing:

[Show failures]

Cannot proceed with merge/PR until tests pass.
```

Stop. Don't proceed to Step 2.

**If tests pass:** Continue to Step 2.

### Step 2: Reconcile the plan

Check `.context/plans/` for a file covering this work (see the `repository-context` skill for the naming convention `.context/plans/YYYY-MM-DD-<slug>.md` and lifecycle). Create and update this file in English regardless of the conversation language.

- **No matching plan exists:** Create one now — Context (task), Design (what was decided), Implementation (what was actually built, deviations from the discussion, follow-ups), Status: Done. Don't skip this just because the plan wasn't written up front — the record of task → design → what shipped → why is the point, not the timing.
- **A plan exists but has no Implementation section filled in:** Fill it in — what was actually built, any deviations from the original design and why, follow-ups.
- **A plan exists and is already up to date:** Nothing to do here.

### Step 3: Reconcile Jira Visibility

Read the plan's Jira section and verify that its issue key, parent epic, repository branch, and target branch match reality.

- If the plan is linked, use `jira-worklog` to prepare a progress or finish preview from verified implementation, test, and PR evidence. Wait for explicit confirmation before commenting on or transitioning the Jira issue.
- If the plan is not linked, remind the user once and offer to publish or link it with `jira-worklog`. This reminder does not by itself block technical branch completion.

### Step 4: Determine Target Branch

If the current branch is a Jira issue key and its linked issue belongs to an epic implemented in this repository, the target branch is the exact epic key. The issue PR or merge targets that epic branch. When finishing the epic branch, target the repository's normal default branch. A Jira issue without an epic targets the normal default branch.

```bash
# Fallback when no linked Jira relationship determines the target
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

Check local and remote refs before acting. Do not infer an epic solely from similarly named branches. Repository-tracked branch instructions take priority if they conflict.

### Step 5: Present Options

Present exactly these 4 options:

```
Implementation complete. What would you like to do?

1. Merge back to <target-branch> locally
2. Push and create a Pull Request targeting <target-branch>
3. Keep the branch as-is (I'll handle it later)
4. Discard this work

Which option?
```

**Don't add explanation** - keep options concise.

### Step 6: Execute Choice

#### Option 1: Merge Locally

```bash
# Switch to target branch
git checkout <target-branch>

# Pull latest
git pull

# Merge feature branch
git merge <feature-branch>

# Verify tests on merged result
<test command>

# If tests pass
git branch -d <feature-branch>
```

Then: Cleanup worktree (Step 7)

#### Option 2: Push and Create PR

```bash
# Push branch
git push -u origin <feature-branch>

# Create PR
gh pr create --base <target-branch> --title "<title>" --body "$(cat <<'EOF'
## Summary
<2-3 bullets of what changed>

## Test Plan
- [ ] <verification steps>
EOF
)"
```

Then: Cleanup worktree (Step 7)

#### Option 3: Keep As-Is

Report: "Keeping branch <name>. Worktree preserved at <path>."

**Don't cleanup worktree.**

#### Option 4: Discard

**Confirm first:**
```
This will permanently delete:
- Branch <name>
- All commits: <commit-list>
- Worktree at <path>

Type 'discard' to confirm.
```

Wait for exact confirmation.

If confirmed:
```bash
git checkout <target-branch>
git branch -D <feature-branch>
```

Then: Cleanup worktree (Step 7)

### Step 7: Cleanup Worktree

**For Options 1, 2, 4:**

Check if in worktree:
```bash
git worktree list | grep $(git branch --show-current)
```

If yes:
```bash
git worktree remove <worktree-path>
```

**For Option 3:** Keep worktree.

## Quick Reference

| Option | Merge | Push | Keep Worktree | Cleanup Branch |
|--------|-------|------|---------------|----------------|
| 1. Merge locally | ✓ | - | - | ✓ |
| 2. Create PR | - | ✓ | ✓ | - |
| 3. Keep as-is | - | - | ✓ | - |
| 4. Discard | - | - | - | ✓ (force) |

## Common Mistakes

**Skipping test verification**
- **Problem:** Merge broken code, create failing PR
- **Fix:** Always verify tests before offering options

**Skipping the plan reconciliation**
- **Problem:** `.context/plans/` drifts from reality — the next person (or agent) reads a plan that describes the original design but not what was actually shipped or why it changed
- **Fix:** Always create or update the plan in Step 2, even for work that wasn't planned up front

**Open-ended questions**
- **Problem:** "What should I do next?" → ambiguous
- **Fix:** Present exactly 4 structured options

**Automatic worktree cleanup**
- **Problem:** Remove worktree when might need it (Option 2, 3)
- **Fix:** Only cleanup for Options 1 and 4

**No confirmation for discard**
- **Problem:** Accidentally delete work
- **Fix:** Require typed "discard" confirmation

## Red Flags

**Never:**
- Proceed with failing tests
- Merge without verifying tests on result
- Delete work without confirmation
- Force-push without explicit request
- Finish work without reconciling its plan doc

**Always:**
- Verify tests before offering options
- Create or update the English `.context/plans/` doc for this work
- Present exactly 4 options
- Get typed confirmation for Option 4
- Clean up worktree for Options 1 & 4 only

## Pairs with

- **using-git-worktrees** — cleans up the worktree created by that skill
- **repository-context** — owns the `.context/plans/` naming convention, English-language requirement, and lifecycle this skill reconciles against
