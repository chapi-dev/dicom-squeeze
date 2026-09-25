# 2. Custom instructions

Custom instructions are Markdown files that Copilot injects into its context automatically.
They are the highest-leverage configuration in this repository: they cost nothing to
maintain and they change every answer you get.

## Where Copilot CLI looks

Copilot reads instructions from all of these, and combines them:

| Location                                       | Scope                    | Committed? |
| ---------------------------------------------- | ------------------------ | ---------- |
| `.github/copilot-instructions.md`              | This repository          | Yes        |
| `.github/instructions/**/*.instructions.md`    | Matching paths only      | Yes        |
| `AGENTS.md` (git root and cwd)                 | This repository          | Yes        |
| `CLAUDE.md`, `GEMINI.md`                       | Cross-tool compatibility | Optional   |
| `~/.copilot/copilot-instructions.md`           | All your projects        | No         |
| `~/.copilot/instructions/**/*.instructions.md` | All your projects        | No         |
| `$COPILOT_CUSTOM_INSTRUCTIONS_DIRS`            | Extra directories        | No         |

Inspect and toggle what actually loaded with `/instructions`.

## Repository-wide instructions

[`.github/copilot-instructions.md`](../../.github/copilot-instructions.md) applies to every
prompt in this repository. It covers what the project is, the stack, the commands, the
architecture, the non-negotiables, and what to prioritise in a review.

### What makes one work

**Be specific about what is unusual.** Copilot already knows React. It does not know that
this repository uses oxlint rather than ESLint, or that `npm run lint` will therefore not
behave the way it expects. Spend your words on the surprises.

**State prohibitions, not just preferences.** "No patient data, ever" is actionable.
"Follow best practices" is not.

**Give commands verbatim.** An agent that has to guess the test command will guess wrong at
least once.

**Explain the architectural rule and the reason.** This repository's central rule is that
all arithmetic lives in `src/lib/`. Saying so is useful; saying *why* — because a number
computed inside JSX is untested by construction — makes the agent apply the rule to cases
you did not anticipate.

**Say what to ignore.** Telling a reviewer to skip formatting opinions is what stops a
review turning into forty comments about quote style.

## Path-scoped instructions

Files under `.github/instructions/` apply only to the paths in their `applyTo` glob. This
keeps each prompt focused instead of loading every rule in the repository every time.

```markdown
---
applyTo: 'src/lib/**/*.ts'
description: Rules for the pure estimation engine.
---

# Estimation engine

Everything under `src/lib/` is pure TypeScript...
```

This repository ships five:

| File                                       | `applyTo`                              | What it enforces                                     |
| ------------------------------------------ | -------------------------------------- | ---------------------------------------------------- |
| `estimation-engine.instructions.md`        | `src/lib/**/*.ts`                      | Purity, data-source citation, numeric safety          |
| `react-ui.instructions.md`                 | `src/components/**`, `src/App.tsx`, …  | No arithmetic in components, Tailwind tokens, a11y    |
| `tests.instructions.md`                    | `**/*.test.ts(x)`, `src/test/**`       | Query by role, relational assertions, coverage floor  |
| `workflows.instructions.md`                | `.github/workflows/**`                 | Least-privilege permissions, timeouts, `npm ci`       |
| `documentation.instructions.md`            | `**/*.md`                              | English, sentence case, cite primary sources          |

Multiple globs go in one comma-separated string:

```yaml
applyTo: 'src/components/**/*.tsx,src/App.tsx,src/main.tsx'
```

## `AGENTS.md`

[`AGENTS.md`](../../AGENTS.md) is a cross-tool convention read by Copilot CLI and by several
other agent tools. This repository keeps it short and points at
`.github/copilot-instructions.md` for the full version, so there is one place to edit rather
than two copies to drift apart.

## Personal instructions

Anything that is about *you* rather than about the project belongs in
`~/.copilot/copilot-instructions.md`:

```markdown
# Personal preferences

- Explain the reasoning before showing a diff.
- Never run `git push --force` without asking first.
- Prefer `rg` over `grep`.
```

Do not put these in the repository. Your teammates did not agree to them.

## Generating a starting point

For a repository with no instructions yet:

```text
/init
```

Copilot reads the codebase and drafts a `copilot-instructions.md`. Treat it as a first
draft — it describes what it sees, which is not the same as what you want enforced.

## Testing that an instruction works

Ask for something the instruction should prevent:

```text
Add a new codec called "SuperZip" with a 40:1 lossless ratio.
```

With this repository's instructions loaded, Copilot should refuse to invent the transfer
syntax UID and should challenge the claim of a 40:1 lossless ratio. If it happily writes the
code, the instruction is either not loading or not specific enough.

## Further reading

- [Adding custom instructions for Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions)
- [About customizing Copilot responses](https://docs.github.com/en/copilot/concepts/response-customization)
