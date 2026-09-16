# Xsolla Service Desk plugin

The internal `xsolla-service-desk` plugin provides one shared skill and MCP
server for Claude Code and Codex. It reads and submits Jira Service Management
customer-portal requests such as access, equipment, support, and incident
forms. It does not replace Atlassian Rovo MCP for ordinary Jira issues or
Confluence.

## Installation

Run the normal configuration installers while connected to the corporate
network and able to access `gitlab.loc`:

```bash
bash install.sh
bash install-codex.sh
```

They add the `xsolla-ai-infra` marketplace from
`https://gitlab.loc/new-metasites/ai-infra.git` and install
`xsolla-service-desk@xsolla-ai-infra` in both clients. The step is optional and
non-fatal when the internal repository is unavailable. Do not keep a second
`xsolla-service-desk@personal` installation enabled at the same time.

Start new Claude Code and Codex sessions after installation or updates.

## OAuth setup

Each Mac needs an Atlassian OAuth application configured for this plugin. Use:

- callback URL: `http://127.0.0.1:53682/oauth/callback`;
- scopes: `offline_access`, `read:servicedesk-request`,
  `write:servicedesk-request`, and `read:jira-user`.

From a checkout of the internal `ai-infra` repository, run:

```zsh
/bin/zsh plugins/xsolla-service-desk/scripts/configure-oauth.sh
```

Enter the OAuth client ID and secret only in that terminal prompt. The script
stores them in macOS Keychain. Never paste credentials or tokens into an AI
chat or commit them to this repository. Then ask the installed skill to connect
to Xsolla Service Desk and complete the browser authorization opened by its
`oauth_begin` tool.

## Verification

```bash
claude plugin list
codex plugin list
```

Both lists should contain `xsolla-service-desk@xsolla-ai-infra`. In a new
session, ask the assistant to check Xsolla Service Desk authorization or invoke
`/xsolla-service-desk:xsolla-service-desk` in Claude Code. Reading requests does
not authorize creating one. Every submission still requires an exact preview
and explicit confirmation.
