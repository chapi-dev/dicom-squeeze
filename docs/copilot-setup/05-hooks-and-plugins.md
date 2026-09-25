# 5. Hooks and plugins

## Hooks

A hook runs a shell command at a lifecycle point in a Copilot session. Instructions ask the
agent to behave; hooks make behaviour mechanical.

### Where they live

| Location                                    | Scope              |
| ------------------------------------------- | ------------------ |
| `.github/hooks/*.json`                      | This repository    |
| `~/.copilot/hooks/*.json`                   | All your projects  |
| `hooks` field in `~/.copilot/settings.json` | All your projects  |
| Policy directories                          | Machine-wide, admin |

All sources are combined. When the same event appears in several, every entry runs.

**Hook configuration is read at startup.** Restart the CLI after editing one.

### Events

`sessionStart`, `sessionEnd`, `userPromptSubmitted`, `preToolUse`, `postToolUse`,
`agentStop`, `errorOccurred`.

### Format

```json
{
  "version": 1,
  "hooks": {
    "preToolUse": [
      {
        "type": "command",
        "bash": "./.github/hooks/guard-no-phi.sh",
        "powershell": "./.github/hooks/guard-no-phi.ps1",
        "timeoutSec": 10
      }
    ]
  }
}
```

Provide both `bash` and `powershell` so the hook works on every operating system; Copilot
picks the right one. `command` is a cross-platform fallback used when neither is present.

The hook receives a JSON payload on stdin and may write a single JSON object to stdout.

### What this repository ships

[`.github/hooks/quality-gate.json`](../../.github/hooks/quality-gate.json) registers two
hooks.

**`sessionStart`** warns if Node is not on `PATH`. Small, but it turns a confusing failure
twenty minutes later into a clear message at second zero.

**`preToolUse`** runs `guard-no-phi`, which inspects the tool call and denies it if it would
create or edit a file with a DICOM extension:

```bash
payload=$(cat)

if printf '%s' "$payload" | grep -Eiq '\.(dcm|dicom|ima)([^a-z0-9]|$)'; then
  printf '{"permissionDecision":"deny","permissionDecisionReason":"This repository must never contain DICOM imaging files."}'
fi
```

Note what it does **not** do. When the tool call is fine, the script prints nothing, and the
normal permission flow continues untouched. Emitting `{"permissionDecision":"allow"}` would
have auto-approved everything the hook saw — a guard that silently disables the confirmation
prompt is worse than no guard.

"No patient data" is the one rule in this repository that must not depend on an agent
choosing to follow it. That is exactly the kind of rule that belongs in a hook.

### Writing your own

Return values from a `preToolUse` hook:

| Output                                            | Effect                                 |
| ------------------------------------------------- | -------------------------------------- |
| Nothing, or unparseable                           | Falls through to default behaviour     |
| `{"permissionDecision":"allow"}`                  | Auto-approves. Use sparingly           |
| `{"permissionDecision":"deny","permissionDecisionReason":"…"}` | Blocks, and tells the agent why |
| `{"permissionDecision":"ask"}`                    | Forces the confirmation prompt         |

Emit **exactly one** decision object. Two `echo` calls concatenate into invalid JSON and the
whole output is discarded.

Progress lines are stripped before parsing, so they are safe to mix in:

```bash
echo '{"type": "progress", "message": "Checking policy..."}'
```

Test a hook by piping a payload into it:

```bash
echo '{"timestamp":1704614400000,"cwd":"/tmp","toolName":"bash","toolArgs":"{\"command\":\"ls\"}"}' \
  | ./.github/hooks/guard-no-phi.sh
```

Good candidates: auto-formatting after an edit, blocking writes outside the repository,
logging prompts for audit, playing a sound when a long task finishes.

### Troubleshooting

| Symptom               | Fix                                                                     |
| --------------------- | ------------------------------------------------------------------------ |
| Hook never fires      | Restart the CLI. Check the file is in `.github/hooks/` and is valid JSON |
| Hook times out        | Default is 30 s. Raise `timeoutSec`                                     |
| Output ignored        | Must be one JSON object. Compact it with `jq -c` or `ConvertTo-Json -Compress` |
| Script not executable | `chmod +x`, and check the shebang                                       |

## Plugins

A plugin bundles skills, agents, MCP servers and hooks into one installable unit, so a team
can share a whole setup rather than six separate files.

```text
/plugin
```

The dashboard lets you browse marketplaces, install, update and remove plugins. A plugin's
skills then appear in `/skills list` tagged with the plugin they came from; remove them by
managing the plugin, not the skill.

This repository ships no plugin. Its configuration is small enough to read directly, and
committed files are easier to review in a pull request than an opaque install step. Reach
for a plugin when you are distributing the same setup across many repositories.

## Further reading

- [Using hooks with Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/use-hooks)
- [Hooks reference](https://docs.github.com/en/copilot/reference/hooks-reference)
