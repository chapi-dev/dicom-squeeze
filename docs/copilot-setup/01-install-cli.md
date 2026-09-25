# 1. Installing GitHub Copilot CLI

## Prerequisites

| Requirement       | Notes                                                                 |
| ----------------- | --------------------------------------------------------------------- |
| Node.js 22+       | This repository pins Node 24 in `.nvmrc`                              |
| npm 10+           | Ships with Node                                                       |
| A Copilot licence | Copilot Pro, Pro+, Business or Enterprise                             |
| PowerShell 7+     | Windows only, and only if you want the hooks in this repo to run      |

On Windows, install PowerShell 7 with `winget install Microsoft.PowerShell` and restart the
terminal. The `pwsh --version` command should then work.

## Install

```bash
npm install -g @github/copilot
```

Verify:

```bash
copilot --version
```

## Authenticate

Start a session and log in:

```bash
copilot
```

```text
/login
```

Follow the device-code flow in the browser. To check which account is active later:

```text
/user
```

If you have more than one GitHub account — a personal one and a work one, say — this matters
more than it looks. Copilot will create pull requests as whichever account is active.

## First session in this repository

```bash
git clone https://github.com/chapi-dev/dicom-squeeze.git
cd dicom-squeeze
copilot
```

Copilot asks whether you trust the folder. Choose **"Yes, and remember this folder for
future sessions"** if you do.

This matters beyond convenience: **project-level MCP servers, skills and agents are only
loaded in a trusted directory.** In an untrusted one they are silently skipped, which looks
exactly like a broken configuration.

## Confirm the configuration loaded

```text
/env
```

You should see:

- Instruction files: `.github/copilot-instructions.md`, `AGENTS.md`, and five files from
  `.github/instructions/`
- Skills: `add-a-codec`, `refresh-storage-prices`
- Agents: `data-source-auditor`, `dicom-reviewer`
- Hooks: `quality-gate.json`
- MCP servers: `microsoft-learn`, `playwright`, plus the built-in GitHub server

Narrower checks:

```text
/instructions      # list and toggle instruction files
/skills list
/agent
/mcp list
```

## Slash commands worth knowing

| Command            | Why you want it                                                              |
| ------------------ | ----------------------------------------------------------------------------- |
| `/init`            | Generates a starting `copilot-instructions.md` for a repository that has none |
| `/plan`            | Produces an implementation plan before any code is written                    |
| `/review`          | Runs the code review agent over your changes                                  |
| `/security-review` | Analyses staged and unstaged changes for vulnerabilities                      |
| `/diff`            | Reviews what has changed in the working tree                                  |
| `/delegate`        | Hands the session to GitHub; Copilot opens a pull request for it              |
| `/pr`              | Operates on the pull request for the current branch                           |
| `/context`         | Shows context-window usage when a session starts feeling sluggish             |
| `/compact`         | Summarises history to reclaim context                                         |
| `/resume`          | Reopens an earlier session with its context intact                            |
| `/env`             | Shows every piece of configuration that actually loaded                       |

Two keyboard shortcuts that repay learning: <kbd>Shift</kbd>+<kbd>Tab</kbd> cycles into plan
mode, and <kbd>Esc</kbd> <kbd>Esc</kbd> interrupts a running turn.

Prefix any input with `!` to run it as a shell command without involving the model:

```text
!npm run test
```

## Working on this repository with Copilot

A prompt that uses the committed configuration well:

```text
Add HTJ2K lossy (1.2.840.10008.1.2.4.202) to the codec list using the /add-a-codec skill.
Verify the UID against DICOM PS3.6 before writing any code, and cite your source.
```

The skill supplies the procedure, `copilot-instructions.md` supplies the constraints, and
`.github/instructions/estimation-engine.instructions.md` applies automatically because the
change touches `src/lib/`.

## Troubleshooting

| Symptom                                    | Cause and fix                                                                                        |
| ------------------------------------------ | ----------------------------------------------------------------------------------------------------- |
| `/env` shows no project MCP servers        | The folder is not trusted. Restart and accept the trust prompt, or run `/add-dir .`                  |
| Skills or agents missing from `/env`       | Same trust problem, or a malformed YAML frontmatter block. Check `name` and `description` are present |
| An instruction file is ignored             | `applyTo` glob does not match the file you are editing. Check it with `/instructions`                |
| Hooks never fire                           | Hook configuration is read at startup. Restart the CLI                                               |
| PowerShell hooks fail on Windows           | PowerShell 7 is not installed or not on `PATH`. Run `pwsh --version`                                 |
| Prompt mode ignores project MCP servers    | Set `GITHUB_COPILOT_PROMPT_MODE_WORKSPACE_MCP=true`, since `-p` cannot show a trust prompt            |

## Further reading

- [Using GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/use-copilot-cli)
- [Installing GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/install-copilot-cli)
- [CLI command reference](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference)
