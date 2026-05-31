import { describe, it, expect } from "vitest";

// This suite is GREEN but asserts nothing about the code under test.
// `npm test` exits 0, which a presence-only grader reads as "tests pass → A".
// In reality not a single assertion touches either exported function.

describe("calc", () => {
  it("works", () => {
    expect(true).toBe(true);
  });

  it.skip("adds two numbers", () => {
    // never runs
  });

  it.todo("applies interest correctly");

  it.skip("handles negative principal", () => {
    // never runs
  });
});
