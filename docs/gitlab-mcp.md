# GitLab MCP setup

The GitLab MCP provides read-only access to the self-hosted Xsolla GitLab from
Claude Code and Codex. It can inspect every project visible to the authenticated
GitLab user; it does not apply a separate project allowlist.

## Create the token

Create a legacy personal access token at `https://gitlab.loc` with only the
`read_api` scope. Do not enable `api`, repository write, administration, or
impersonation scopes.

Save the token in macOS Keychain without pasting it into an AI conversation:

```bash
printf "Paste GitLab token: " && read -s GITLAB_TOKEN && echo
security add-generic-password -U \
  -s "my-ai-config.gitlab" \
  -a "GITLAB_PERSONAL_ACCESS_TOKEN" \
  -w "$GITLAB_TOKEN"
unset GITLAB_TOKEN
```

Run `bash install.sh` and `bash install-codex.sh` afterward. Each configured MCP
process retrieves the token directly from Keychain at startup. The token value
is never written to `~/.claude.json`, `~/.codex/config.toml`, or this repository.

The MCP also runs with `GITLAB_PERMISSION_MODE=readonly`. This is defense in
depth: GitLab rejects writes because the token lacks write scope, and the MCP
does not expose its modifying tools.

## Verify

```bash
security find-generic-password \
  -s "my-ai-config.gitlab" \
  -a "GITLAB_PERSONAL_ACCESS_TOKEN" >/dev/null \
  && echo "GitLab token is present"
claude mcp list
codex mcp list
```

Both clients should list an enabled `gitlab` stdio server. Restart the desktop
applications after installation so new sessions load the server.
