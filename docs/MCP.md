# MCP servers

This repo ships a project-scoped [Model Context Protocol](https://modelcontextprotocol.io)
config (`.mcp.json` at the repo root). MCP-aware clients — Claude Code, Claude
Desktop, Cursor, VS Code — pick it up automatically when opened in this
directory. The config is checked in; **secrets are not** — the API token is read
from your environment at connect time.

## Apify

[Apify](https://apify.com) exposes its thousands of ready-made scrapers,
crawlers, and automation Actors through a hosted MCP server at
`https://mcp.apify.com`. The `.mcp.json` entry connects to it over streamable
HTTP:

```json
{
  "mcpServers": {
    "apify": {
      "type": "http",
      "url": "https://mcp.apify.com",
      "headers": {
        "Authorization": "Bearer ${APIFY_TOKEN}"
      }
    }
  }
}
```

`${APIFY_TOKEN}` is expanded from your environment, so the token never lands in
git. `*.env` and `Secrets.xcconfig` are already git-ignored.

### Setup

1. Get an API token from the [Apify Console](https://console.apify.com/settings/integrations)
   (**Settings → Integrations → API tokens**). It looks like
   `apify_api_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`.

2. Export it before launching your MCP client (add it to your shell profile or a
   git-ignored `.env` so it persists):

   ```bash
   export APIFY_TOKEN="apify_api_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
   ```

3. Open the project in your MCP client:
   - **Claude Code** — run `/mcp` to see the `apify` server and its status.
   - **Claude Desktop / Cursor / VS Code** — the server appears in the client's
     MCP/tools panel.

### Alternatives

- **OAuth instead of a token.** The hosted server also supports interactive
  OAuth. Drop the `headers` block from the `apify` entry and your client will
  prompt you to sign in on first connect. (Requires an interactive session —
  use the token method for headless/CI runs.)

- **Run the server locally over stdio** with the npm package instead of the
  hosted endpoint:

  ```json
  {
    "mcpServers": {
      "apify": {
        "command": "npx",
        "args": ["-y", "@apify/actors-mcp-server"],
        "env": { "APIFY_TOKEN": "${APIFY_TOKEN}" }
      }
    }
  }
  ```

See the [Apify MCP docs](https://docs.apify.com/platform/integrations/mcp) for
the full tool list and options.
