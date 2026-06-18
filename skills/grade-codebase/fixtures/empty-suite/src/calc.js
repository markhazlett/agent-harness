// Real logic with a real bug surface — but the test suite never exercises it.
export function add(a, b) {
  return a + b;
}

export function applyInterest(principal, rate) {
  // Intentionally subtle: off-by-one-style edge cases the tests would catch
  // if the tests actually called this function. They don't.
  return principal + principal * rate;
}
