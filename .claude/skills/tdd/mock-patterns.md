# Mock Patterns — /tdd

Project-specific patterns for writing tests with mocks. Loaded on demand from `SKILL.md`.

## Test Conventions

- **Location:** Tests go in `__tests__/` adjacent to the source file, or in a top-level `tests/` directory.
- **Naming:** `<module>.test.ts` or `<module>.spec.ts`.
- **Framework:** Check `package.json` — commonly Vitest or Jest.
- **Run tests:** Use `HARNESS_TEST_CMD` from `.claude/hooks/harness.config.sh`.

## Vitest Mock Patterns (if using Vitest)

### Use static imports + `vi.hoisted()`, not `vi.resetModules()`

**NEVER do this** — causes flaky tests:

```typescript
// BAD: fragile pattern
beforeEach(() => {
  vi.resetModules(); // clears module cache — fragile
});

it("my test", async () => {
  const { myService } = await import("../my-service"); // race conditions
});
```

**Always do this** — deterministic:

```typescript
// GOOD: deterministic, no flakiness
const { mockDep } = vi.hoisted(() => ({
  mockDep: vi.fn(),
}));

vi.mock("../dependency", () => ({
  doThing: mockDep,
}));

// Static imports — vi.mock() is hoisted above these
import { myService } from "../my-service";

beforeEach(() => {
  vi.clearAllMocks(); // sufficient — resets call history
  mockDep.mockReturnValue({ result: "default" });
});
```

### Why `vi.hoisted()` is required

`vi.mock()` factories are hoisted ABOVE all other code, including `const` declarations. Without `vi.hoisted()`, mock variables hit the temporal dead zone.

### Quick checklist for new test files

1. Declare mock variables with `vi.hoisted()`.
2. Define `vi.mock()` factories referencing those hoisted variables.
3. Use static `import` for the module under test (after `vi.mock()` calls).
4. Use `vi.clearAllMocks()` in `beforeEach` — never `vi.resetModules()`.
5. Re-configure mock implementations in `beforeEach`.

## Jest Mock Patterns (if using Jest)

```typescript
jest.mock("../dependency", () => ({
  doThing: jest.fn(),
}));

import { doThing } from "../dependency";

beforeEach(() => {
  jest.clearAllMocks();
  (doThing as jest.Mock).mockReturnValue({ result: "default" });
});
```

## Example (Vitest)

```typescript
// src/services/__tests__/my-service.test.ts
import { describe, it, expect, vi, beforeEach } from "vitest";

const { mockFetch } = vi.hoisted(() => ({ mockFetch: vi.fn() }));
vi.mock("../http-client", () => ({ fetch: mockFetch }));

import { myService } from "../my-service";

describe("myService", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("should return processed result", async () => {
    mockFetch.mockResolvedValueOnce({ data: "test" });
    const result = await myService.process("input");
    expect(result).toMatchObject({ status: "success" });
  });
});
```
