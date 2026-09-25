# 6. GitHub automation

What runs on GitHub itself: the CI/CD surface, Copilot code review, and how to hand work to
Copilot rather than doing it locally.

## Workflows

| Workflow                    | Trigger                        | What it does                                                |
| --------------------------- | ------------------------------ | ----------------------------------------------------------- |
| `ci.yml`                    | push to `main`, pull request   | Format check, oxlint, typecheck, tests on Node 20/22/24, build |
| `codeql.yml`                | push, pull request, weekly     | CodeQL for TypeScript and for Actions workflows             |
| `deploy-pages.yml`          | push to `main`                 | Builds with the correct base path and deploys to Pages      |
| `dependency-review.yml`     | pull request                   | Blocks high-severity or disallowed-licence dependencies     |
| `dependabot-auto-merge.yml` | Dependabot pull request        | Auto-merges patch and minor updates once CI is green        |
| `pr-triage.yml`             | pull request                   | Applies path labels and a size label                        |
| `release.yml`               | tag `v*.*.*`                   | Re-runs the gates, packages `dist`, publishes a release     |
| `stale.yml`                 | daily                          | Marks and closes abandoned issues and pull requests         |

### The single required check

`ci.yml` ends with an aggregate `ci-passed` job that fails if any upstream job failed. Branch
protection requires only that job. Adding a Node version to the matrix therefore does not
require touching repository settings — a small thing that stops branch protection quietly
drifting out of date.

### Security posture

Every workflow declares `permissions: contents: read` at the top level, and each job widens
that only to what it needs. The Pages deploy job is the only one with `pages: write` and
`id-token: write`.

`pr-triage.yml` uses `pull_request_target`, which runs with write access against the base
branch. It never checks out or executes code from the pull request head — it only reads
metadata and applies labels. That distinction is the whole of the vulnerability class; keep
it in mind before adding a step there.

## Copilot code review

Copilot can review pull requests automatically.

### Enabling it

For a single pull request, request **Copilot** as a reviewer from the Reviewers menu.

To make it automatic, add a repository ruleset requiring Copilot review, or enable automatic
review in your personal or organisation Copilot settings. Either way it then runs on every
new pull request against the default branch.

```bash
gh pr create --title "feat: add HTJ2K lossy" --body "..." --reviewer copilot-pull-request-reviewer
```

### It reads this repository's instructions

Copilot code review uses `.github/copilot-instructions.md` and the path-scoped files under
`.github/instructions/`. That is why those files include an explicit review priority list
and an explicit "do not raise" list — the same configuration that shapes your CLI session
shapes the review comments your teammates receive.

## Delegating work to Copilot

### From the CLI

```text
/delegate
```

Sends the current session to GitHub. Copilot continues the work in a cloud environment and
opens a pull request. Use `--base` to target a branch other than the default.

### From an issue

Assign an issue to **Copilot**. It creates a branch, implements the change, and opens a
draft pull request linked to the issue. Well-scoped issues work; vague ones produce vague
pull requests.

```bash
gh issue create \
  --title "feat: add a JPEG-LS near-lossless option" \
  --body "Add the near-lossless JPEG-LS variant to src/lib/codecs.ts. Verify the transfer syntax UID against DICOM PS3.6 and cite the source. Follow .github/skills/add-a-codec." \
  --assignee copilot
```

### The cloud agent uses the same configuration

`.github/copilot-instructions.md`, `.github/instructions/`, `AGENTS.md`,
`.github/agents/`, `.github/skills/` and `.github/hooks/` are all read by the cloud agent as
well as by the CLI. One configuration, three surfaces: your terminal, the pull request
reviewer, and the cloud agent.

Two differences worth knowing: the cloud agent runs in an ephemeral Linux sandbox, so only
the `bash` field of a hook is honoured and `powershell` entries are ignored; and its outbound
network is firewalled to GitHub and Copilot hosts unless an administrator allows more.

## Pages deployment

The site deploys to `https://chapi-dev.github.io/dicom-squeeze/`.

Vite needs a `base` matching the repository name, which `vite.config.ts` reads from
`BASE_PATH`, and the deploy workflow sets from `github.event.repository.name`. Forking the
repository under a different name therefore keeps working without editing anything.

One-time setup, if you are recreating this repository:

```bash
gh api -X POST repos/OWNER/REPO/pages -f 'build_type=workflow'
```

Or in **Settings → Pages**, set the source to **GitHub Actions**.

## Repository settings worth replicating

```bash
# Merge hygiene
gh repo edit --enable-squash-merge --enable-auto-merge --delete-branch-on-merge
gh repo edit --enable-merge-commit=false --enable-rebase-merge=false

# Security
gh api -X PUT repos/OWNER/REPO/vulnerability-alerts
gh api -X PATCH repos/OWNER/REPO \
  -F 'security_and_analysis[secret_scanning][status]=enabled' \
  -F 'security_and_analysis[secret_scanning_push_protection][status]=enabled'
```

Branch protection on `main`: require the `CI passed` check, require a pull request, dismiss
stale approvals, and block force pushes and deletions.

## Further reading

- [Using Copilot code review](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/request-a-code-review/use-code-review)
- [Copilot cloud agent](https://docs.github.com/en/copilot/concepts/agents/cloud-agent/about-cloud-agent)
- [Publishing with a custom GitHub Actions workflow](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)
