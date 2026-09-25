# Copilot setup guide

Everything you need to reproduce this repository's GitHub Copilot configuration on your own
machine, and the reasoning behind each piece of it.

The repository ships its agent configuration as committed files, so most of it works the
moment you clone. This guide explains what those files do, what you still have to install
yourself, and how to extend the setup.

## Read in this order

| #   | Guide                                                  | What it covers                                                          |
| --- | ------------------------------------------------------ | ----------------------------------------------------------------------- |
| 1   | [Installing the CLI](01-install-cli.md)                | Install, authenticate, first session, the slash commands worth knowing   |
| 2   | [Custom instructions](02-instructions.md)              | `copilot-instructions.md`, path-scoped instructions, `AGENTS.md`         |
| 3   | [MCP servers](03-mcp-servers.md)                       | What MCP is, the servers this repo uses, how to add your own             |
| 4   | [Agents and skills](04-agents-and-skills.md)           | Custom agent profiles, agent skills, when to use which                   |
| 5   | [Hooks and plugins](05-hooks-and-plugins.md)           | Lifecycle hooks, the PHI guard in this repo, plugin marketplaces         |
| 6   | [GitHub automation](06-github-automation.md)           | Copilot code review, delegating work to Copilot, the CI/CD surface       |

## The five-minute version

```bash
# 1. Install and authenticate
npm install -g @github/copilot
copilot
# then, inside the session:
/login

# 2. Clone and trust this repository
git clone https://github.com/chapi-dev/dicom-squeeze.git
cd dicom-squeeze
copilot
# choose "Yes, and remember this folder for future sessions"

# 3. Confirm the committed configuration loaded
/env
```

`/env` should list the instruction files from `.github/`, the two repository skills, the two
custom agents, the hooks, and the MCP servers from `.github/mcp.json`. If any of them is
missing, [Installing the CLI](01-install-cli.md#troubleshooting) explains why.

## What is committed and what is not

| Concern            | Committed to this repo                            | Yours to configure locally                     |
| ------------------ | ------------------------------------------------- | ---------------------------------------------- |
| Repo instructions  | `.github/copilot-instructions.md`, `AGENTS.md`    | `~/.copilot/copilot-instructions.md`           |
| Path instructions  | `.github/instructions/*.instructions.md`          | `~/.copilot/instructions/`                     |
| MCP servers        | `.github/mcp.json`                                | `~/.copilot/mcp-config.json`, and any API keys |
| Custom agents      | `.github/agents/*.agent.md`                       | `~/.copilot/agents/`                           |
| Skills             | `.github/skills/*/SKILL.md`                       | `~/.copilot/skills/`                           |
| Hooks              | `.github/hooks/*.json` and their scripts          | `~/.copilot/hooks/`                            |
| Secrets            | **Never**                                         | Environment variables or your own MCP config   |

The split follows one rule: anything a teammate needs in order to get the same behaviour is
committed; anything personal or secret is not.

## A note on this repository

DICOM Squeeze is a mockup. The application is deliberately small so that the interesting
part — the automation and agent configuration around it — stays readable. If you are here
to copy a setup rather than to plan a DICOM archive, start at
[Custom instructions](02-instructions.md); that is where the leverage is.
