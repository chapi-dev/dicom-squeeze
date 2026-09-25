# 4. Agents and skills

Both customise how Copilot behaves, and they are easy to confuse.

| | Custom agent | Skill |
| --- | --- | --- |
| Answers | *Who* is doing the work | *How* a specific task is done |
| Shape | A persona with a tool allowlist | A procedure, plus optional scripts |
| Invoked | `/agent`, or by name in a prompt | `/skill-name`, or automatically by description match |
| Context | Runs in its own context window | Injected into the current context |
| Good for | Review, audit, research | Repeatable multi-step tasks |

Rule of thumb: if you would write it as a checklist, it is a skill. If you would write it as
a job description, it is an agent.

## Custom agents

### Where they live

| Location                                     | Scope              |
| -------------------------------------------- | ------------------ |
| `.github/agents/`                            | This repository    |
| `~/.copilot/agents/`                         | All your projects  |
| `agents/` in an org's `.github-private` repo | Whole organisation |

On a name collision, user-level beats repository-level, which beats organisation-level.

### Built-in agents

Copilot CLI ships with Explore, Task, General purpose, Code review, Research and Rubber
duck. Some, such as Rubber duck, are consulted automatically rather than invoked by you.

Write a custom agent when the built-ins lack **domain knowledge** — not when you simply want
different wording.

### The profile format

A `.agent.md` file with YAML frontmatter:

```markdown
---
name: data-source-auditor
description: Audits every hard-coded number in the estimation engine against a primary source. Use when a pull request changes a compression ratio, a study size, a storage price, or adds a new transfer syntax.
tools: ['read', 'search', 'web-search', 'fetch']
---

You audit the factual claims embedded in this repository's estimation engine.
...
```

| Property      | Required | Notes                                                              |
| ------------- | -------- | ------------------------------------------------------------------ |
| `name`        | No       | Defaults to the filename without `.agent.md`                       |
| `description` | **Yes**  | How Copilot decides whether to route to this agent. Be concrete    |
| `tools`       | No       | Allowlist. Omit for all tools. Include MCP tools as `server/tool`  |
| `mcp-servers` | No       | Servers available only to this agent                               |
| `model`       | No       | IDE surfaces only                                                  |

The `description` does the routing, so write it as a trigger rather than a summary. "Use
when a pull request changes a compression ratio" routes reliably; "helps with data" does not.

### What this repository ships

**`data-source-auditor`** — read-only, with web access. It checks every literal number in
the estimation engine against a primary source and reports `confirmed`, `plausible but
uncited`, `contradicted` or `unverifiable`. It exists because this repository's central
promise is that its figures are traceable, and that promise decays silently.

**`dicom-reviewer`** — full toolset. It reviews changes through a medical-imaging lens,
looking for clinically dangerous mistakes: a lossy codec presented as safe, a silent unit
error, arithmetic that escaped `src/lib/`. It is explicitly told what *not* to raise, which
is what keeps it from drowning a pull request in style comments.

### Using one

```text
/agent
```

Or name it in a prompt, and Copilot infers the routing:

```text
Use the dicom-reviewer agent to review my changes to the estimation engine.
```

Or from the command line:

```bash
copilot --agent=data-source-auditor --prompt "Audit src/lib/storage.ts against current Azure pricing."
```

## Skills

A skill is a folder containing `SKILL.md` and anything it references.

### Where they live

| Location                                              | Scope             |
| ----------------------------------------------------- | ----------------- |
| `.github/skills/`, `.claude/skills/`, `.agents/skills/` | This repository   |
| `~/.copilot/skills/`, `~/.agents/skills/`             | All your projects |

Directory names are lowercase with hyphens, and should match the skill's `name`.

### The format

```markdown
---
name: add-a-codec
description: Adds a new DICOM transfer syntax to the estimation engine, with a verified UID, a sourced compression range, and the tests and UI wiring that go with it. Use when asked to add, remove or change a codec in DICOM Squeeze.
---

# Adding a codec to DICOM Squeeze

## 1. Verify the transfer syntax UID
...
```

The file **must** be named `SKILL.md`. `name` and `description` are required;
`license` and `allowed-tools` are optional.

As with agents, `description` drives automatic selection. Say what the skill does *and* when
to use it.

### What this repository ships

**`add-a-codec`** — the full procedure for adding a transfer syntax: verify the UID against
DICOM PS3.6, find a sourced compression range, classify lossless versus lossy honestly, add
the entry, update the tests that assert row counts, run the gates, cite the source in the
pull request. Every one of those steps is a place someone would otherwise cut a corner.

**`refresh-storage-prices`** — how to re-query the Azure Retail Prices API and update
`src/lib/storage.ts`. It spends most of its length on three traps: the per-hour versus
per-month unit, the progressive volume bands, and the redundancy level. Those are the errors
that produce a confident answer that is wrong by orders of magnitude.

### Skills that run scripts

Copilot makes every file in a skill's directory available when the skill loads.

```text
.github/skills/image-convert/
├── SKILL.md
└── convert-svg-to-png.sh
```

`allowed-tools` in the frontmatter pre-approves tools so the skill does not prompt:

```yaml
allowed-tools: shell
```

> Only pre-approve `shell` or `bash` for a skill whose source you have read and trust.
> Doing so removes the confirmation step for running terminal commands, which is exactly the
> step that stops a prompt injection from executing arbitrary code on your machine.

### Managing skills

```text
/skills             # interactive list; enable or disable
/skills list
/skills info SKILL-NAME
/skills reload      # after adding one mid-session
/skills add PATH
/skills remove SKILL-DIRECTORY
```

Also available as `copilot skill …` subcommands for scripting, and `gh skill` in GitHub CLI
for searching, installing and publishing skills.

Community skills: [Awesome GitHub Copilot](https://awesome-copilot.github.com/skills/).

## Further reading

- [Creating custom agents](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/create-custom-agents)
- [Custom agents configuration reference](https://docs.github.com/en/copilot/reference/custom-agents-configuration)
- [Adding agent skills for Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills)
