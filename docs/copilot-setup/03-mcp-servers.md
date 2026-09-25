# 3. MCP servers

The Model Context Protocol is an open standard for giving a model access to external tools
and data. An MCP server exposes a set of tools; Copilot decides when to call them.

The GitHub MCP server is **built into Copilot CLI** and needs no configuration. Everything
below is about adding others.

## Where configuration lives

| Path                             | Scope                     | Precedence                         |
| -------------------------------- | ------------------------- | ---------------------------------- |
| `.mcp.json`                      | Project, per checkout     | Highest; usually gitignored        |
| `.github/mcp.json`               | Project, shared           | Committed, what this repo uses     |
| `~/.copilot/mcp-config.json`     | You, across all projects  | Lowest                             |

Copilot walks from your working directory up to the repository root, loading every
configuration file it finds. Definitions closer to the working directory win, and project
definitions beat your user configuration.

> `.vscode/mcp.json` is **not** read by Copilot CLI. It uses a `servers` top-level key that
> the CLI does not accept.

Project-level servers load only in a **trusted** directory. In an untrusted one they are
skipped without a message, which is indistinguishable from a broken config.

## What this repository ships

[`.github/mcp.json`](../../.github/mcp.json):

```json
{
  "mcpServers": {
    "microsoft-learn": {
      "type": "http",
      "url": "https://learn.microsoft.com/api/mcp",
      "tools": ["*"]
    },
    "playwright": {
      "type": "local",
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest", "--headless"],
      "tools": ["*"]
    }
  }
}
```

**Why these two.**

`microsoft-learn` gives the agent first-party Azure documentation, including current pricing
and storage-tier semantics. This repository hard-codes Azure Blob prices, and the rule is
that every number must be traceable — this server is how the agent verifies one without
guessing from training data.

`playwright` drives a headless browser. Because this is a UI whose entire output is numbers
rendered on screen, an agent that can only run unit tests cannot tell you that a card shows
`27K` where it should show `27.055`. A browser closes that gap.

Neither requires credentials, which is deliberate: a committed configuration should never
need a secret.

## Adding a server

From the terminal, which writes to `~/.copilot/mcp-config.json`:

```bash
# Local, stdio transport
copilot mcp add context7 -- npx -y @upstash/context7-mcp

# Remote, HTTP transport
copilot mcp add --transport http sentry https://mcp.sentry.dev/mcp

# With a header
copilot mcp add --transport http --header "Authorization: Bearer YOUR-TOKEN" \
  stripe https://mcp.stripe.com
```

Useful options: `--env KEY=VALUE`, `--tools a,b,c`, `--timeout MS`.

Inside a session, `/mcp add` opens a form. <kbd>Tab</kbd> moves between fields,
<kbd>Ctrl</kbd>+<kbd>S</kbd> saves, and the server starts immediately without a restart.

To share a server with the team, add it to `.github/mcp.json` and commit it.

## Managing servers

```text
/mcp                    # dashboard with status
/mcp list               # plain text
/mcp show SERVER-NAME   # status and the tools it exposes
/mcp edit SERVER-NAME
/mcp disable SERVER-NAME
/mcp delete SERVER-NAME
```

The same operations exist as `copilot mcp` subcommands for scripting.

Discovery from the GitHub MCP Registry is available behind the experimental flag:

```text
/experimental on
/mcp search playwright
```

## Configuration reference

**Local (stdio):**

```json
{
  "type": "local",
  "command": "npx",
  "args": ["@playwright/mcp@latest"],
  "env": { "API_KEY": "..." },
  "tools": ["*"]
}
```

Only `PATH` is inherited from your environment. Every other variable the server needs must
be declared in `env`.

**Remote (HTTP or SSE):**

```json
{
  "type": "http",
  "url": "https://mcp.example.com/mcp",
  "headers": { "Authorization": "Bearer ..." },
  "tools": ["*"]
}
```

`sse` is the deprecated legacy transport; prefer `http` for anything new.

`tools` accepts `"*"` for everything, or an explicit list. Narrowing it is worth doing for a
large server: fewer tools means less context spent on tool descriptions and fewer chances of
the model picking the wrong one.

## Security

- **Never commit a credential.** If a server needs a key, configure it in
  `~/.copilot/mcp-config.json` or inject it from an environment variable, and document the
  requirement here instead.
- **An MCP server is code you are running.** A malicious or compromised server can read
  whatever you let the agent read. Prefer first-party servers, and read the source of
  anything else.
- **Tool descriptions are attacker-controlled input.** A hostile server can embed prompt
  injection in a tool description. Narrow `tools` and keep the server list short.
- Organisation and enterprise policy can restrict which servers may run, via a registry URL
  and an allowlist. Those settings apply to the CLI.

## Further reading

- [Adding MCP servers for Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-mcp-servers)
- [GitHub MCP Registry](https://github.com/mcp)
- [About MCP](https://docs.github.com/en/copilot/concepts/context/mcp)
