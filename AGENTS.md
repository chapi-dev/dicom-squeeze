# AGENTS.md

This file is read by Copilot CLI, and by other agent tools that follow the `AGENTS.md`
convention. The authoritative, longer version of these rules lives in
[`.github/copilot-instructions.md`](.github/copilot-instructions.md); this is the short
form.

## Project

DICOM Squeeze is a mockup single-page app that estimates the storage and cost impact of
recompressing a radiology imaging archive to a different DICOM transfer syntax. It is not a
medical device, it processes no real imaging data, and it has no backend.

## Setup

```bash
npm ci
npm run dev
```

## Verification gates

Run all four before proposing a change. CI runs the same four.

```bash
npm run lint        # oxlint, not ESLint
npm run typecheck
npm run test
npm run build
```

## Rules that matter most

1. All arithmetic lives in `src/lib/`. Components display, they never calculate.
2. Every hard-coded number needs a primary source, cited in the pull request.
3. Transfer syntax UIDs must be real DICOM identifiers from PS3.6.
4. A lossy codec always carries `diagnosticallyAccepted: false`.
5. No patient data, no real DICOM files, no secrets. Anywhere.
6. Everything written — code, comments, docs, commits, pull requests — is in English.
7. Conventional Commits: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`, `ci:`.

## Repository layout

| Path                 | What it holds                                              |
| -------------------- | ---------------------------------------------------------- |
| `src/lib/`           | Pure estimation engine, fully unit tested                  |
| `src/components/`    | Presentational React components                            |
| `src/test/`          | Test setup and component tests                             |
| `.github/workflows/` | CI, CodeQL, Pages deploy, release, triage, stale           |
| `.github/agents/`    | Custom agent profiles                                      |
| `.github/skills/`    | Repeatable task procedures for agents                      |
| `docs/copilot-setup/`| How to reproduce the Copilot CLI setup for this repository |
