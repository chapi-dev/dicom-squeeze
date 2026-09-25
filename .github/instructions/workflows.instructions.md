---
applyTo: '.github/workflows/**/*.yml,.github/*.yml,.github/*.yaml'
description: Rules for GitHub Actions workflows and repository automation.
---

# GitHub Actions

## Security

- **Pin permissions explicitly.** Every workflow declares a top-level
  `permissions: contents: read` and each job widens it only to what that job needs. Never
  rely on the default token permissions.
- **`pull_request_target` runs with write access against the base branch.** Never check out
  and execute code from the pull request head in such a workflow. The triage workflow here
  only reads metadata and applies labels, which is safe; keep it that way.
- **Pin third-party actions to a full commit SHA**, with the human-readable version in a
  trailing comment: `uses: org/action@<40-char-sha> # v3.1.0`. A tag is mutable, so anyone
  who controls the upstream repository can change what your workflow executes. CodeQL's
  `actions/unpinned-tag` query fails the build if you use a bare tag, and Dependabot still
  updates SHA pins as long as the version comment is present. Actions under the `actions/`
  and `github/` organisations are exempt — GitHub serves those immutably.
- Never write a secret into a step that echoes its input. Pass secrets through `env`.

## Reliability

- Every job sets `timeout-minutes`. A hung runner should fail, not burn an hour.
- Use `concurrency` with `cancel-in-progress: true` for CI, and `false` for deployment —
  cancelling a half-finished Pages deploy leaves the site in an unknown state.
- Node version comes from `.nvmrc` via `node-version-file`, except in the test matrix where
  the whole point is to vary it. One source of truth for the default.
- Always `npm ci`, never `npm install`, in CI.
- Keep the aggregate `ci-passed` job as the single required status check. Adding a matrix
  entry should not require editing branch protection.

## Style

- Job and step names read as sentences: "Lint, typecheck and format", not "lint".
- Comment anything non-obvious, especially a workaround. A future reader should not have to
  reverse-engineer why a step exists.
- Prefer one clear step over a clever compound command.
