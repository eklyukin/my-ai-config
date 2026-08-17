---
name: "personal-context"
description: "Uses the optional local Personal Context MCP to find cross-client Claude/Codex session history, inspect pending memory, or run a user-approved local synchronization. Degrades silently when the application or MCP is unavailable."
---

# Personal Context

Use the connected Personal Context MCP for cross-client local memory.

## Retrieval

1. Search with the current repository and task intent.
2. Start with a small result set.
3. Evaluate whether provenance, recency, and detail are sufficient.
4. Autonomously retrieve related handoffs or full transcripts only when needed.
5. Prefer tracked repository instructions and current user direction whenever
   memory conflicts with them.

## Synchronization

Check status after substantive work is complete. If data is pending, offer a
sync and explain that it will start the local model. Invoke sync only after the
user agrees. Do not require the user to click the menu bar button.

## Unavailable Service

If the MCP is absent, stopped, or unhealthy, continue normally using native
client memory and repository `.context/`. Do not attempt installation, launch,
or configuration changes unless the user explicitly asks.
