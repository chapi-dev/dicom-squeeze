# Contributing to DICOM Squeeze

Thanks for wanting to help. This document covers how to set up, what the review bar is, and
the handful of rules that are not negotiable.

## Setup

```bash
git clone https://github.com/chapi-dev/dicom-squeeze.git
cd dicom-squeeze
npm ci
npm run dev
```

Node 24 is the development target; `.nvmrc` pins it. CI also runs Node 20 and 22, so avoid
anything that only works on the newest runtime.

## The four gates

Run all of them before opening a pull request. CI runs exactly the same four, so a failure
here is a failure there.

```bash
npm run lint        # oxlint, not ESLint
npm run typecheck
npm run test
npm run build
```

Formatting is checked too:

```bash
npm run format      # fixes
npm run format:check
```

## Non-negotiables

### 1. Every number needs a source

Compression ratios, study sizes and storage prices are claims about the real world. Each
must come from a primary source — a standards document, a vendor datasheet, a published
study, or an official price list. Cite it in the pull request, with the date you retrieved
it. The template has a section for exactly this.

A plausible-looking invented figure is the worst possible contribution to this repository,
because nothing downstream will catch it.

### 2. Transfer syntax UIDs must be real

They are registered in DICOM PS3.6 and all begin with `1.2.840.10008.1.2`. Verify before
adding, and do not alter an existing one without checking the standard.

### 3. Lossy is never presented as safe

A lossy codec always carries `diagnosticallyAccepted: false` and is always visibly labelled
in the UI. This is the one mistake in this repository that could plausibly contribute to
clinical harm.

### 4. No patient data. Ever.

No DICOM files, no anonymised studies, no identifiers — not in code, not in tests, not in
fixtures, not in issues, not in screenshots. A `preToolUse` hook blocks agents from creating
files with DICOM extensions; please do not work around it.

### 5. No secrets

The app has no backend and needs no credentials. Secret scanning and push protection are
enabled.

### 6. Write in English

Code, comments, documentation, commit messages, pull request descriptions, issue titles. The
UI formats numbers with the `es-ES` locale because the audience is Spanish, but the words
are English.

## Architecture rules

**All arithmetic lives in `src/lib/`.** Components format and display; they never calculate.
If you catch yourself doing maths in a `.tsx` file, move it into `src/lib/` and write a unit
test for it.

`src/lib/` is pure: no React, no DOM, no I/O, no `Date.now()`, no `Math.random()`. Same
input, same output, always.

State lives in `App.tsx`. No context, no store, no reducer — the app has not earned any of
them.

## Testing

Every exported function in `src/lib/` needs tests covering the normal case, the boundary
(zero, empty, single element), the error case, and at least one **relational** assertion.

Relational assertions are the ones that earn their keep:

```ts
// Passes even when the sign is inverted somewhere upstream.
expect(cost).toBe(1234.56);

// States the actual requirement.
expect(coldMix).toBeLessThan(hotMix);
```

For components, query by role, label or text — never by class name or test id. Use
`fireEvent.change` for range inputs; `userEvent` keyboard interaction on a slider does not
work reliably in jsdom, and a test that silently asserts nothing is worse than no test.

Coverage thresholds are enforced. If a change drops coverage, add tests rather than lowering
the threshold.

## Dependencies

This app deliberately has no chart library, no state manager and no UI kit. Before adding a
dependency, write the justification in one sentence. If it does not survive that, do not add
it.

## Commits and pull requests

Conventional Commits:

```
feat: add HTJ2K lossy transfer syntax
fix: apply hot storage bands progressively rather than retroactively
docs: explain the per-hour versus per-month pricing trap
chore(deps): bump vite to 8.4.0
test: cover the zero-archive boundary in estimate()
ci: pin workflow permissions to least privilege
```

Keep pull requests focused. One concern per pull request; a formatting sweep mixed into a
behavioural change is very hard to review.

Fill in the template. The "Source citations" section is not decoration.

## Review

Reviewers prioritise, in order:

1. A number changed without a cited source.
2. Arithmetic that leaked out of `src/lib/` into a component.
3. A lossy codec presented as safe for primary diagnosis.
4. Missing tests for a change in `src/lib/`.
5. An accessibility regression.
6. An unjustified dependency.

Formatting opinions are not raised. Prettier already settled those.

Copilot reviews pull requests automatically, using the same instruction files that shape a
local CLI session. If you disagree with a Copilot comment, say so in the thread — that is a
legitimate outcome, and often a sign the instructions need sharpening.

## Working with Copilot

The repository ships instructions, agents, skills and hooks as committed files. See
[docs/copilot-setup/](docs/copilot-setup/).

Two skills encode the procedures most likely to go wrong:

```text
Use the /add-a-codec skill to add JPEG-LS near-lossless.
Use the /refresh-storage-prices skill to re-check the Azure prices.
```

## Reporting problems

- A defect: [bug report](https://github.com/chapi-dev/dicom-squeeze/issues/new?template=bug_report.yml)
- A wrong number: [data accuracy](https://github.com/chapi-dev/dicom-squeeze/issues/new?template=data_accuracy.yml)
- A vulnerability: see [SECURITY.md](SECURITY.md). Do not open a public issue.

## Code of conduct

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).
