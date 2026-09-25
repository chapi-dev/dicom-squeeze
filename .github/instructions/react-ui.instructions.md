---
applyTo: 'src/components/**/*.tsx,src/App.tsx,src/main.tsx'
description: Rules for React components and the UI layer.
---

# React and UI

## Component shape

- Function components only. No classes.
- Named exports for components; `App` is the single default export.
- Props interfaces are declared immediately above the component and are not exported unless
  another module genuinely needs them.
- Keep a component under roughly 120 lines. Past that, extract.

## Separation of concerns

Components **display**, they do not **calculate**. All arithmetic lives in `src/lib/`.

A component may call `estimate()`, `formatEur()` or `normaliseMix()`. It may not multiply a
price by a volume, divide a size by a ratio, or reimplement a percentage. If you need a new
derived value, add a function to `src/lib/`, test it, then call it.

State lives in `App.tsx`. Components receive values and callbacks. No context, no store, no
reducer — the app is not big enough to earn any of them.

Wrap derived values in `useMemo` only when they depend on the whole input object, as
`estimate()` does. Do not sprinkle it defensively.

## Styling

Tailwind CSS v4, configured through `@tailwindcss/vite`. There is no `tailwind.config.js`
and no PostCSS pipeline. The design tokens live in the `@theme` block in `src/index.css`.

- Use the semantic tokens: `ink-*` for surfaces and text, `signal-*` for the accent,
  `good-500` / `warn-500` / `danger-500` for status.
- Add a new token to `@theme` rather than hard-coding a hex value in a class.
- No inline `style` except for genuinely dynamic geometry, such as a bar width driven by a
  percentage.

## Accessibility

This is not optional polish; it is part of the definition of done.

- Every input has a `<label htmlFor>` pointing at its `id`. Sliders included.
- Custom controls carry the right role and state: the codec picker uses
  `role="radiogroup"` / `role="radio"` with `aria-checked`.
- Colour is never the only signal. A lossy codec is red **and** says "Lossy".
- Tables use `<th scope>` and a `<caption>`, even a visually hidden one.
- Purely decorative elements get `aria-hidden`, and anything conveying information gets a
  text equivalent.

## Testing components

Use Testing Library and query the way a user would: by role, by label, by text. Never by
class name or test id.

For range inputs use `fireEvent.change` — jsdom does not reliably simulate dragging or
arrow-key interaction on a slider, and a test that quietly does nothing is worse than no
test at all.

Assert on behaviour the user can observe: the visible figure changes, the selected codec
flips, the saving drops to zero on the uncompressed baseline.
