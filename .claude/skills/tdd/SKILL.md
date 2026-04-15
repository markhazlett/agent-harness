<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Visit https://github.com/markhazlett/agent-harness to upgrade." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

# TDD Workflow

Test-driven development workflow. Use when asked to "write tests first", "TDD", or when implementing new server-side logic.

## Cycle

1. **Write a failing test** — describe the expected behavior
2. **Run the test** — confirm it fails for the right reason
3. **Implement** — write the minimum code to make it pass
4. **Run the test** — confirm it passes
5. **Refactor** — clean up while keeping tests green

## Test Conventions

Read `CLAUDE.md` for project-specific test conventions. Generic defaults:

- **Location:** Tests go in `__tests__/` adjacent to the source file, or in a top-level `tests/` directory
- **Naming:** `<module>.test.ts` or `<module>.spec.ts`
- **Framework:** Check `package.json` — commonly Vitest or Jest
- **Run tests:** Use `HARNESS_TEST_CMD` from `.claude/hooks/harness.config.sh`

## Vitest Mock Patterns (if using Vitest)

### Use static imports + vi.hoisted(), not vi.resetModules()

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

### Why vi.hoisted() is required

`vi.mock()` factories are hoisted ABOVE all other code, including `const` declarations. Without `vi.hoisted()`, mock variables hit the temporal dead zone.

### Quick checklist for new test files

1. Declare mock variables with `vi.hoisted()`
2. Define `vi.mock()` factories referencing those hoisted variables
3. Use static `import` for the module under test (after `vi.mock()` calls)
4. Use `vi.clearAllMocks()` in `beforeEach` — never `vi.resetModules()`
5. Re-configure mock implementations in `beforeEach`

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
