---
applyTo: 'src/lib/**/*.ts'
description: Rules for the pure estimation engine.
---

# Estimation engine

Everything under `src/lib/` is pure TypeScript. Treat it as the model layer of the app.

## Hard rules

- **No React, no DOM, no I/O, no globals.** If a function needs `window`, `fetch`,
  `localStorage` or a React hook, it does not belong here.
- **Deterministic.** The same input always produces the same output. No `Date.now()`, no
  `Math.random()`.
- **No mutation of inputs.** Copy before you change anything.
- **Export the types.** Callers should never have to re-declare a shape.

## Data integrity

Every literal number in `codecs.ts`, `modalities.ts` and `storage.ts` is a claim about the
real world. When you add or change one:

1. Find a primary source. Acceptable: DICOM PS3.5/PS3.6, a vendor datasheet, a peer-reviewed
   study, an official cloud price list, a national retention regulation. Not acceptable: a
   blog post summarising one of those, or your own recollection.
2. State the source in the pull request body with the retrieval date.
3. If the figure is a range rather than a point, model it as a range. Compression ratios in
   particular vary enormously by anatomy and bit depth; a single number is a lie.

Transfer syntax UIDs must exist in the DICOM standard. They all start with
`1.2.840.10008.1.2`. Verify before adding.

## Numeric safety

Guard every division. `archivePb` can be zero, a tier mix can sum to zero, and a codec can
have a ratio of exactly 1. Each of these already has a test; keep it that way.

Return `Infinity` rather than `NaN` when a result is genuinely unbounded, such as a payback
period against zero savings, and let the formatter turn it into a dash or `never`.

Never round inside the engine. Rounding is a display concern and belongs in `format.ts`.

## Testing

Every exported function needs unit tests covering:

- the normal case,
- the boundary (zero, empty collection, single element),
- the error case (unknown id throws),
- at least one **relational** assertion — "a colder tier mix costs less than an all-hot one",
  "a stronger codec saves more than a weaker one". These catch sign errors and inverted
  comparisons that fixed-value assertions sail straight past.

Coverage thresholds are enforced in CI. Do not lower them to make a change pass.
