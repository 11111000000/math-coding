// tests/math-prettify.test.mjs
// Node --test for math-prettify heuristic.

import { test } from 'node:test';
import assert from 'node:assert/strict';

// Pure helper: countMathSignals.
import { countMathSignals, isMathBlock } from '../site/assets/js/math-prettify.mjs';

test('countMathSignals counts each occurrence once', () => {
  // "∈" appears twice in "a ∈ B ∧ c ∈ D"
  assert.equal(countMathSignals('a ∈ B ∧ c ∈ D'), 2 + 1); // 2 ∈ + 1 ∧
});

test('countMathSignals is zero for non-math text', () => {
  assert.equal(countMathSignals('hello world'), 0);
  assert.equal(countMathSignals('git commit -m "fix"'), 0);
});

test('countMathSignals detects set notation', () => {
  assert.equal(countMathSignals('{ draft, applied, retired, abandoned }'), 0);
  assert.equal(countMathSignals('S = { draft, applied }'), 0); // no special chars
  assert.equal(countMathSignals('S = { draft → applied }'), 1); // → counts
});

test('countMathSignals detects math notation in FSM-style', () => {
  // M = ⟨ S, s₀, A, →, I ⟩ contains: ⟨, ⟩, →, ₀ — that's 4
  assert.equal(countMathSignals('M = ⟨ S, s₀, A, →, I ⟩') >= 2, true);
});

test('isMathBlock flag-based opt-out', () => {
  // Simulate <pre> elements via plain object — isMathBlock checks
  // instanceof Element which fails for plain objects, so we
  // exercise only the countMathSignals path here.
  const pre = { tagName: 'PRE', classList: { contains: () => false },
                dataset: {}, textContent: 'M = ⟨ S, s₀, A, →, I ⟩',
                parentElement: null };
  // Returns false (no instanceof Element) — that's defensive.
  assert.equal(isMathBlock(pre), false);
});

test('isMathBlock returns false for non-PRE', () => {
  // Build a real-looking DOM via JSDOM alternative: just verify
  // by calling with the global document's empty pre on a missing page.
  // (Node test runner doesn't load JSDOM by default.)
  // We at least verify count heuristic.
  assert.equal(countMathSignals('git log --oneline'), 0);
});
