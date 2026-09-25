## What changed

<!-- Describe the change in one or two sentences, in English. -->

## Why

<!-- Link the issue this closes, e.g. "Closes #12", or explain the motivation. -->

## How to verify

<!-- The exact commands or clicks a reviewer should run. -->

```bash
npm ci
npm run lint && npm run typecheck && npm run test && npm run build
```

## Checklist

- [ ] `npm run lint`, `npm run typecheck`, `npm run test` and `npm run build` all pass locally
- [ ] New or changed behaviour in `src/lib/` is covered by a unit test
- [ ] Any new figure (compression ratio, study size, price) cites a primary source in a code comment or in the PR description
- [ ] No patient data, no real DICOM files and no personal information anywhere in the diff
- [ ] Documentation updated if the change affects setup, usage or the data model

## Source citations

<!--
Required when the PR introduces or modifies a number. One line per figure:

  src/lib/storage.ts — Hot LRS 0.0158 EUR/GB/month, Spain Central
  Source: Azure Retail Prices API, retrieved 2026-02-11
-->

## Screenshots

<!-- For UI changes. Delete this section otherwise. -->
