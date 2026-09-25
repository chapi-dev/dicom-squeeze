# DICOM Squeeze — repository instructions

## What this project is

DICOM Squeeze is a **mockup** single-page web application. It estimates what a lossless
recompression campaign would do to a radiology imaging archive: how much capacity it
reclaims, how much the storage bill drops, and how long the transcode takes to pay back.

It does **not** read, write, transcode or transmit real DICOM data. It is a planning
calculator, not a medical device and not a PACS component.

## Stack

| Concern    | Choice                                        |
| ---------- | --------------------------------------------- |
| Runtime    | Node 24 for local development, Node 22/24/26 in CI; minimum 22.12 |
| Framework  | React 19 with function components and hooks   |
| Language   | TypeScript, strict, no `any`                  |
| Build      | Vite 8                                        |
| Styling    | Tailwind CSS v4 via `@tailwindcss/vite`       |
| Linting    | oxlint (`npm run lint`) — **not** ESLint      |
| Formatting | Prettier (`npm run format`)                   |
| Tests      | Vitest + Testing Library (`npm run test`)     |
| Deployment | GitHub Pages via GitHub Actions               |

## Commands

```bash
npm ci              # install exactly what the lockfile says
npm run dev         # local dev server
npm run lint        # oxlint
npm run typecheck   # tsc -b --noEmit
npm run test        # vitest run
npm run test:coverage
npm run build       # tsc -b && vite build
npm run format      # prettier --write .
```

Before opening a pull request, run all four gates: `lint`, `typecheck`, `test`, `build`.

## Architecture

```
src/
  lib/          Pure TypeScript. No React, no DOM, no I/O. This is the model.
    codecs.ts       DICOM transfer syntaxes and their compression characteristics
    modalities.ts   Modality profiles: average study size and compressibility
    storage.ts      Storage tiers, banded pricing, tier mixes
    estimate.ts     The estimation engine that combines the three above
    format.ts       Display helpers (es-ES locale)
  components/   Presentational React components. No business logic.
  App.tsx       State container: owns the inputs, calls estimate(), renders panels.
```

The rule that matters: **all arithmetic lives in `src/lib/`**. Components format and display,
they never calculate. If you find yourself doing maths inside a `.tsx` file, move it into
`src/lib/` and write a unit test for it.

## Non-negotiables

1. **Every number is traceable.** Compression ratios, study sizes and storage prices must
   come from a primary source — a standards document, a vendor datasheet, a published study,
   or an official price list. Cite the source in a code comment or in the pull request body.
   Never invent a plausible-looking figure.
2. **Transfer syntax UIDs must be real.** They are registered identifiers in DICOM PS3.6.
   Do not make one up, and do not alter an existing one without checking the standard.
3. **Lossless and lossy are not interchangeable.** A lossy codec must always carry
   `diagnosticallyAccepted: false` and must be visibly labelled in the UI.
4. **No patient data, ever.** No real DICOM files, no anonymised studies, no identifiers, not
   in the code, not in tests, not in fixtures, not in issues.
5. **No secrets in the repository.** This app has no backend and needs no credentials.
6. **Prose is written in English.** Code, comments, documentation, commit messages, pull
   request descriptions and issue titles. The UI itself formats numbers with the `es-ES`
   locale because the target audience is Spanish, but the words are English.

## Conventions

- Commit messages follow Conventional Commits: `feat:`, `fix:`, `docs:`, `chore:`,
  `refactor:`, `test:`, `ci:`.
- Exported functions and non-obvious types carry a short TSDoc comment explaining the
  *why*, not the *what*.
- Prefer `type` imports (`import type { Foo }`) — `verbatimModuleSyntax` is on.
- Components are named exports; `App` is the only default export.
- Keep components under roughly 120 lines. Split before that becomes a problem.
- Do not add a dependency without a reason that survives a sentence of justification.
  This app deliberately has no chart library, no state manager and no UI kit.

## When reviewing a pull request

Prioritise, in this order:

1. A number changed without a cited source.
2. Arithmetic that leaked out of `src/lib/` into a component.
3. A lossy codec presented as if it were safe for primary diagnosis.
4. Missing unit tests for a change in `src/lib/`.
5. An accessibility regression: unlabelled controls, lost focus order, colour used as the
   only signal.
6. A new dependency that is not justified.

Ignore pure formatting opinions. Prettier already settled those.
