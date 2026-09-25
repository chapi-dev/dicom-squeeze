---
name: add-a-codec
description: Adds a new DICOM transfer syntax to the estimation engine, with a verified UID, a sourced compression range, and the tests and UI wiring that go with it. Use when asked to add, remove or change a codec in DICOM Squeeze.
---

# Adding a codec to DICOM Squeeze

A codec is a claim about the real world, so adding one is a research task before it is a
coding task. Work in this order.

## 1. Verify the transfer syntax UID

Every DICOM transfer syntax is registered in PS3.6 Annex A and begins with
`1.2.840.10008.1.2`. Confirm the UID and its exact registered name before writing any code.
If you cannot confirm it, stop and report that rather than guessing.

## 2. Find the compression range

Look for published ratios for the codec against the modalities this tool models. You want a
range, not a point — real-world ratios vary with anatomy, bit depth and reconstruction
kernel, so a single number would be misleading.

Record the source URL and the date you retrieved it. You will cite it in the pull request.

## 3. Classify it honestly

Set `kind` to `lossless` only if the codec is bit-exact. If it is irreversible, `kind` is
`lossy` and `diagnosticallyAccepted` **must** be `false`. Never soften this.

Set `cpuCost` relative to the existing entries, where RLE is 1 and JPEG 2000 is 4.

## 4. Add the entry

Append to the `CODECS` array in `src/lib/codecs.ts`, keeping the array ordered from weakest
to strongest compression. Write a one-line `notes` field that tells a planner something
they would not already know — a support caveat, a CPU trade-off, a modality where it
underperforms.

## 5. Add the tests

`src/lib/__tests__/codecs.test.ts` already asserts uniqueness of ids and UIDs, the UID
pattern, ratio ordering, and the lossy/lossless invariant. A correctly added codec passes
those automatically. Then add a test in `estimate.test.ts` that places the new codec
correctly relative to its neighbours, for example that it saves more than RLE and less than
lossy JPEG 2000.

## 6. Check the UI

The codec picker and the comparison table are both driven by the `CODECS` array, so a new
entry appears automatically. Verify that the badge renders the right colour and label, and
that the comparison table still fits without horizontal overflow at the narrowest supported
width. The App test asserts the exact row count — update it.

## 7. Run the gates

```bash
npm run lint && npm run typecheck && npm run test && npm run build
```

## 8. Write the pull request

State the UID, the source for the compression range with its retrieval date, and why the
codec is worth modelling. The pull request template has a "Source citations" section; fill
it in.
