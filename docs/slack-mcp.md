# Slack MCP setup

The installers register a read-only Slack MCP globally for Claude Code and
Codex. Its user token is retrieved from macOS Keychain when each MCP process
starts; it is never written to this repository or either client's config.

## 1. Create an internal Slack app

1. Open [Slack app management](https://api.slack.com/apps).
2. Select **Create New App**, then **From scratch**.
3. Give the app a name such as `Slack MCP` and select the target workspace.
4. Open **Agents** and enable **Slack Model Context Protocol (MCP) Server**.

Workspace policy may require an administrator to approve the app. Slack MCP
supports internal workspace apps and Marketplace-published apps.

## 2. Configure read-only user scopes

Under **OAuth & Permissions**, add these **User Token Scopes**:

```text
canvases:read
channels:history
channels:read
emoji:read
files:read
groups:history
groups:read
im:history
im:read
lists:read
mpim:history
mpim:read
reactions:read
search:read
search:read.files
search:read.im
search:read.mpim
search:read.private
search:read.public
search:read.users
usergroups:read
users:read
users:read.email
```

Omit `users:read.email` when email addresses are unnecessary. Do not add any
scope containing `write`; those scopes permit changes in Slack.

The token acts as the authorizing user and cannot see conversations that user
cannot access.

## 3. Configure the Postman callback

In **OAuth & Permissions**, add and save this Redirect URL:

```text
https://oauth.pstmn.io/v1/callback
```

Copy the app's **Client ID** and **Client Secret** from **Basic Information**.
Treat the Client Secret as a credential: do not put it in this repository or a
chat message.

## 4. Generate an xoxp token with Postman

Create a Postman collection, open **Authorization**, select **OAuth 2.0**, and
configure a new token:

| Field | Value |
| --- | --- |
| Token Name | `Slack Codex RO` |
| Grant Type | `Authorization Code` |
| Callback URL | `https://oauth.pstmn.io/v1/callback` |
| Authorize using browser | Off |
| Auth URL | `https://slack.com/oauth/v2_user/authorize` |
| Access Token URL | `https://slack.com/api/oauth.v2.user.access` |
| Client ID | The Slack app Client ID |
| Client Secret | The Slack app Client Secret |
| Client Authentication | `Send client credentials in body` |

Paste the selected scopes into Postman's **Scope** field as one
space-separated line:

```text
canvases:read channels:history channels:read emoji:read files:read groups:history groups:read im:history im:read lists:read mpim:history mpim:read reactions:read search:read search:read.files search:read.im search:read.mpim search:read.private search:read.public search:read.users usergroups:read users:read users:read.email
```

Select **Get New Access Token**, approve the workspace consent screen, and
then select **Use Token**. The resulting user token starts with `xoxp-`.

## 5. Save the token in macOS Keychain

Run the following in a separate terminal. Paste the `xoxp` token at the hidden
prompt; it must never be pasted into an AI chat:

```bash
printf "Paste the Slack xoxp token: " && read -s SLACK_SECRET && echo
security add-generic-password -U \
  -s "my-ai-config.slack" \
  -a "SLACK_MCP_XOXP_TOKEN" \
  -w "$SLACK_SECRET"
unset SLACK_SECRET

security find-generic-password \
  -s "my-ai-config.slack" \
  -a "SLACK_MCP_XOXP_TOKEN" >/dev/null \
  && echo "Slack token is configured"
```

Run `bash install.sh` and `bash install-codex.sh`, then completely quit and
reopen both desktop applications. Keychain persists across reboots, so this
step does not need to be repeated after restarting macOS.

The Keychain integration is macOS-specific. Other platforms require an
equivalent local secret-store launcher before these installer entries can be
used.

## 6. Verify

Confirm that the stdio server is registered:

```bash
claude mcp get slack
codex mcp get slack
```

Both entries should use `/bin/zsh -lc` to retrieve the token and start
`slack-mcp-server`. The token itself must not appear in either config.

The installer also supplies an explicit `SLACK_MCP_ENABLED_TOOLS` allowlist.
Only channel/user discovery, history, thread replies, search, unread retrieval,
and user-group reads are exposed. Posting, reactions, membership changes,
mark-as-read, and user-group writes remain unavailable even if future token
permissions are broadened accidentally.

After restarting the clients, ask either one to read an accessible Slack
channel or direct message. A read-only setup exposes Slack read/search tools
but no tools for sending, editing, reacting, uploading, or deleting content.

## Troubleshooting

- `redirect_uri did not match`: make the Postman Callback URL and Slack
  Redirect URL exactly `https://oauth.pstmn.io/v1/callback`.
- Postman OAuth timeout: turn **Authorize using browser** off and begin a new
  OAuth request; authorization codes cannot be reused.
- Slack tools are absent after setting the token: rerun both installers, quit
  the desktop clients with **Cmd-Q**, and reopen them.
- Access is denied for specific content: verify that the authorizing Slack user
  can access that conversation and that the corresponding read scope was
  approved.

References:

- [Slack MCP server overview](https://docs.slack.dev/ai/slack-mcp-server/)
- [Slack OAuth installation](https://docs.slack.dev/authentication/installing-with-oauth/)
- [Slack OAuth with Postman](https://docs.slack.dev/authentication/authorizing-with-postman/)
