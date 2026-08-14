# Local Repository Context

When entering a Git repository, check for `_local/AGENTS.md`. If it exists, read it as supplementary local context after reading repository-tracked instructions. Treat remote/tracked instructions as authoritative in conflicts and report the conflict.

Read `_local/AGENTS.md` as a map. Load only the linked `_local/contexts/`, plans, infrastructure, or docs files needed for the current task; never load the entire `_local/` tree by default.

Keep all personal repository context inside `_local/`. Ensure `/_local/` is present in the repository's `.git/info/exclude`; never modify tracked `.gitignore`, `CLAUDE.md`, `AGENTS.md`, `docs/`, or `plans/` for local context. Use `_local/AGENTS.md` as the canonical file and `_local/CLAUDE.md` as a symlink to `AGENTS.md`.

When `_local/CHANGELOG.md` exists, start a non-blocking background agent at session start, if delegation is available, to run `git fetch --prune`, summarize new remote commits since its recorded `remote-head`, and update the local changelog. The agent must not checkout, merge, rebase, reset, pull, modify tracked files, or expose secrets.
