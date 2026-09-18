# Datadog MCP setup

The installers register the Xsolla Datadog US5 MCP globally for Claude and
Codex. The API and application keys are read from macOS Keychain only when the
MCP process starts. They are never written to this repository or either
client's configuration.

## Save the service-account keys

Run this in a separate terminal and paste each value at its hidden prompt:

```bash
printf "Paste DD_API_KEY: "
read -s DD_API_KEY_VALUE
echo
security add-generic-password -U \
  -s "my-ai-config.datadog" \
  -a "DD_API_KEY" \
  -w "$DD_API_KEY_VALUE"
unset DD_API_KEY_VALUE

printf "Paste DD_APPLICATION_KEY: "
read -s DD_APP_KEY_VALUE
echo
security add-generic-password -U \
  -s "my-ai-config.datadog" \
  -a "DD_APPLICATION_KEY" \
  -w "$DD_APP_KEY_VALUE"
unset DD_APP_KEY_VALUE
```

The configured endpoints are:

- Datadog API: `https://api.us5.datadoghq.com`
- Datadog MCP: `https://mcp.us5.datadoghq.com/v1/mcp`

## Install and verify

```bash
bash install.sh
bash install-codex.sh
claude mcp get datadog
codex mcp get datadog
```

Both entries use a local `mcp-remote` bridge. Its header placeholders are
expanded from environment variables populated from Keychain, so secret values
do not appear in process arguments. Completely quit and reopen Claude Desktop
and Codex Desktop after installation.

References:

- [Datadog MCP Server setup](https://docs.datadoghq.com/mcp_server/setup/)
- [Internal Datadog MCP Developer Setup Guide](https://xsolla.atlassian.net/wiki/spaces/ID/pages/24360910897/Datadog+MCP+Developer+Setup+Guide)
