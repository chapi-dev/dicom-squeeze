---
applyTo: '**/*.test.ts,**/*.test.tsx,src/test/**'
description: Testing conventions for Vitest and Testing Library.
---

# Tests

## Layout

- Unit tests for `src/lib/` live in `src/lib/__tests__/<module>.test.ts`.
- Component and integration tests live in `src/test/`.
- Shared setup is `src/test/setup.ts`, registered through `setupFiles` in `vite.config.ts`.

## Writing a test

Name the test after the behaviour, not the function: "applies volume bands progressively,
not retroactively" beats "monthlyCost works".

Each test asserts one idea. If the name needs an "and", split it.

Prefer relational assertions over magic numbers wherever the relationship is the real
requirement:

```ts
// Brittle, and passes even if the sign is inverted elsewhere.
expect(cost).toBe(1234.56);

// States the actual requirement.
expect(coldMix).toBeLessThan(hotMix);
```

Use fixed values when the number itself is the contract — a banded price calculation, a
unit conversion, a locale format.

Use `toBeCloseTo` for anything involving division or accumulated floating point.

## Testing Library

Query by role, label or text. Never by class name, never by test id. If an element is hard
to query, that is usually an accessibility defect in the component, not a reason to reach
for `container.querySelector`.

Use `fireEvent.change` for range inputs. `userEvent` keyboard interaction on a slider does
not work reliably in jsdom and produces a test that silently asserts nothing.

Scope assertions with `within()` when the same text could appear more than once on screen.

## What must be tested

- Every exported function in `src/lib/`.
- Every boundary: zero, empty, single element, the maximum.
- Every thrown error.
- Every user-visible state change in the UI.

Coverage thresholds are enforced by `npm run test:coverage` in CI. If a change drops
coverage, add tests. Do not lower the threshold.
