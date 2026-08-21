# Local Repository Context

When entering a Git repository, check for `.context/AGENTS.md`. If it exists, read it as supplementary local context after reading repository-tracked instructions. Treat remote/tracked instructions as authoritative in conflicts and report the conflict.

Read `.context/AGENTS.md` as a map. Load only the linked `.context/contexts/`, plans, infrastructure, docs, or source files needed for the current task; never load the entire `.context/` tree by default.

Create `.context/contexts/`, `.context/docs/`, `.context/plans/`, and `.context/sources/{jira,slack,vimeo,meet}/` as part of the default scaffold. Whenever the user asks you to inspect an external source, save the useful retrieved information under `.context/sources/<provider>/` during the same task. Write a source record in English or in the source's original language; do not translate retrieved content solely to enforce the general English convention. Check the saved record before querying the source again, but refresh it when missing, stale, incomplete, or when current data is requested. Maintain exactly one `.context/sources/slack/<channel-slug>.md` document per Slack channel and update it instead of creating per-request files. Include the stable source ID, URL when available, retrieval timestamp with timezone, useful facts, and provenance. Never store credentials or tokens.

Keep all personal repository context inside `.context/`. Ensure `/.context/` is present in the repository's `.git/info/exclude`; never modify tracked `.gitignore`, `CLAUDE.md`, `AGENTS.md`, `docs/`, or `plans/` for local context. Use `.context/AGENTS.md` as the canonical file and `.context/CLAUDE.md` as a symlink to `AGENTS.md`.

Write every file under `.context/` in English, including maps, plans, scoped context, infrastructure notes, personal docs, and changelog entries. This requirement applies even when the user or task uses another language; preserve exact identifiers and required quotations.

When `.context/CHANGELOG.md` exists, start a non-blocking background agent at session start, if delegation is available, to run `git fetch --prune`, summarize new remote commits since its recorded `remote-head`, and update the local changelog in English. The agent must not checkout, merge, rebase, reset, pull, modify tracked files, or expose secrets.
