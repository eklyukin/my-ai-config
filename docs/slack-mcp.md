# Slack MCP for Codex Desktop

`install-codex.sh` registers Slack's hosted MCP endpoint globally:

```text
https://mcp.slack.com/mcp
```

The configuration references `SLACK_MCP_TOKEN`; it never writes the token to
this repository or `~/.codex/config.toml`. Complete the steps below once after
installation.

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

## 5. Make the token available to Codex Desktop

Run the following in a separate terminal. Paste the `xoxp` token at the hidden
prompt; it must never be pasted into an AI chat:

```bash
printf "Paste the Slack xoxp token: " && read -s SLACK_SECRET && echo
launchctl setenv SLACK_MCP_TOKEN "$SLACK_SECRET"
unset SLACK_SECRET

if [[ -n "$(launchctl getenv SLACK_MCP_TOKEN)" ]]; then
  echo "Slack token is configured"
else
  echo "Slack token was not configured"
fi
```

Completely quit Codex Desktop with **Cmd-Q**, then reopen it so the app inherits
the variable. The `launchctl` value belongs to the current macOS login session;
repeat this step after signing out or restarting macOS.

On a non-macOS desktop session, set `SLACK_MCP_TOKEN` in the environment that
launches Codex.

## 6. Verify

Confirm that the endpoint is registered:

```bash
codex mcp get slack
```

The output should show:

```text
transport: streamable_http
url: https://mcp.slack.com/mcp
bearer_token_env_var: SLACK_MCP_TOKEN
```

After restarting Codex Desktop, ask it to read one accessible Slack channel or
direct message. A read-only setup exposes Slack read/search tools but no tools
for sending, editing, reacting, uploading, or deleting content.

## Troubleshooting

- `redirect_uri did not match`: make the Postman Callback URL and Slack
  Redirect URL exactly `https://oauth.pstmn.io/v1/callback`.
- Postman OAuth timeout: turn **Authorize using browser** off and begin a new
  OAuth request; authorization codes cannot be reused.
- Slack tools are absent after setting the token: quit Codex Desktop with
  **Cmd-Q** and reopen it.
- Access is denied for specific content: verify that the authorizing Slack user
  can access that conversation and that the corresponding read scope was
  approved.

References:

- [Slack MCP server overview](https://docs.slack.dev/ai/slack-mcp-server/)
- [Slack OAuth installation](https://docs.slack.dev/authentication/installing-with-oauth/)
- [Slack OAuth with Postman](https://docs.slack.dev/authentication/authorizing-with-postman/)
