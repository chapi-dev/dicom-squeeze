# 6. GitHub automation

What runs on GitHub itself: the CI/CD surface, Copilot code review, and how to hand work to
Copilot rather than doing it locally.

## Workflows

| Workflow                    | Trigger                        | What it does                                                |
| --------------------------- | ------------------------------ | ----------------------------------------------------------- |
| `ci.yml`                    | push to `main`, pull request   | Lockfile registry check, format, oxlint, typecheck, tests on Node 22/24/26, build |
| `codeql.yml`                | push, pull request, weekly     | CodeQL for TypeScript and for Actions workflows             |
| `deploy-appservice.yml`     | push to `main`, manual         | Builds for the domain root and deploys to Azure App Service |
| `deploy-pages.yml`          | push to `main`                 | Builds with the correct base path and deploys to Pages      |
| `dependency-review.yml`     | pull request                   | Blocks high-severity or disallowed-licence dependencies     |
| `dependabot-auto-merge.yml` | Dependabot pull request        | Auto-merges patch and minor updates once CI is green        |
| `pr-triage.yml`             | pull request                   | Applies path labels and a size label                        |
| `refresh-lockfile.yml`      | manual, monthly                | Regenerates `package-lock.json` on a clean runner and opens a pull request |
| `release.yml`               | tag `v*.*.*`                   | Re-runs the gates, packages `dist`, publishes a release     |
| `stale.yml`                 | daily                          | Marks and closes abandoned issues and pull requests         |

### The single required check

`ci.yml` ends with an aggregate `ci-passed` job that fails if any upstream job failed. Branch
protection requires only that job. Adding a Node version to the matrix therefore does not
require touching repository settings — a small thing that stops branch protection quietly
drifting out of date.

### Security posture

Every workflow declares `permissions: contents: read` at the top level, and each job widens
that only to what it needs. Only the two deploy jobs have `id-token: write`, and only the
Pages one has `pages: write`.

`pr-triage.yml` uses `pull_request_target`, which runs with write access against the base
branch. It never checks out or executes code from the pull request head — it only reads
metadata and applies labels. That distinction is the whole of the vulnerability class; keep
it in mind before adding a step there.

## Azure App Service

GitHub Pages serves the app from `/dicom-squeeze/`. The App Service deployment exists to
show the same build running at a domain root, which is the shape most real deployments take
and the one that exposes base-path bugs.

Two things make that work:

- `vite.config.ts` reads `BASE_PATH`. Pages passes `/dicom-squeeze/`, App Service passes `/`.
  Getting this wrong still serves the HTML with a 200 and fails only when the browser fetches
  the assets, so `deploy-appservice.yml` extracts the asset URLs out of the served page and
  requests each one.
- `deploy/server.mjs` is a static file server written against Node built-ins only. App Service
  on Linux will not serve a folder by itself; something has to listen on `$PORT`. Zero
  dependencies means the deployment package is the build output plus one file, with no install
  step on the server and no dependency surface to keep patched.

### Authentication

There is no publish profile and no client secret in this repository. An Entra app registration
holds a federated credential naming this repository and the `production` environment, and that
registration has `Website Contributor` on exactly one web app. Basic publishing credentials are
disabled on the app, so a publish profile would not work even if one leaked.

The workflow reads five repository **variables**, not secrets — they are resource identifiers,
and treating them as secrets would only make the logs harder to read:

| Variable | Meaning |
| --- | --- |
| `AZURE_CLIENT_ID` | App registration that the federated credential is attached to |
| `AZURE_TENANT_ID` | Entra tenant |
| `AZURE_SUBSCRIPTION_ID` | Target subscription |
| `AZURE_RESOURCE_GROUP` | Resource group holding the web app |
| `AZURE_WEBAPP_NAME` | Web app name |

### Reproducing it

```bash
az webapp create -g <rg> -p <plan> -n <app> --runtime "NODE:24-lts"
az webapp config set -g <rg> -n <app> --startup-file "node server.mjs" --always-on true

az ad app create --display-name gh-<app>-deploy
az role assignment create --assignee <appId> --role "Website Contributor" \
  --scope /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Web/sites/<app>
```

Then the federated credential — and this is the part worth reading carefully.

#### Getting the subject right

The subject has to match the `sub` claim the runner actually presents, and that claim is not
always the `repo:<owner>/<repo>:...` form the documentation examples use. Ask the repository
what it will send:

```bash
gh api repos/<owner>/<repo>/actions/oidc/customization/sub
```

```json
{
  "use_default": true,
  "use_immutable_subject": true,
  "sub_claim_prefix": "repo:chapi-dev@253938553/dicom-squeeze@1387553843"
}
```

With `use_immutable_subject` on, the prefix carries the numeric owner and repository IDs.
Those survive a rename and cannot be reused by someone who registers the freed-up name later,
which is the point of the feature — but it does mean a credential written against the plain
name never matches:

```bash
az ad app federated-credential create --id <appId> --parameters '{
  "name": "gh-env",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<owner>@<ownerId>/<repo>@<repoId>:environment:production",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

The suffix depends on how the job runs, not on what you would like it to be. A job declaring
`environment: production` sends `:environment:production`; one without sends
`:ref:refs/heads/main`. Getting either part wrong fails at login with **`AADSTS700213: No
matching federated identity record found for presented assertion subject`** — and helpfully,
the error quotes the exact subject that was presented, so the fix is usually to copy that
string into the credential verbatim.

If you add the ID-qualified credentials, delete any name-based ones you created first. They
can never match while immutable subjects are enabled, and leaving them behind re-opens the
name-reuse gap they exist to close.

### Why the deploy does not track Kudu's readiness

`az webapp deploy` defaults `--track-status` to `true`, which polls Kudu for the site's runtime
state after the package has landed. On the first deploy here that poll sat on
`Starting the site...` for eight minutes while the app was already answering `/healthz`, and
ran the job into its timeout. The workflow disables it. The deployment itself stays
synchronous, so a rejected package still fails the step; what is dropped is only a readiness
signal that had already proven unreliable.

What replaces it is a check against the running site, which is a stronger claim anyway: the
workflow compares the asset filenames the site serves against the ones this run built. Vite
fingerprints them by content, so a mismatch means the deployment did not take — something a
plain `200` from `/` cannot tell you.

Also budget generously. Kudu's cold warm-up on a Basic plan took 3m42s before the upload even
began.

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
