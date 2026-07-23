// math-prettify.mjs
//
// Detects <pre> blocks that contain mathematical notation and
// adds `.pre-math` class. CSS uses serif-italic + centered layout
// to give the block a "displayed equation" feel, separating it
// from regular shell/yaml code blocks.
//
// Heuristic signals (any 2+ of these in a <pre> → flagged as math):
//   - Set/logic operators: ∈ ∋ ⊆ ⊂ ∪ ∩ ∅ × Γ → ↔ ⇒ ∀ ∃ ¬ ∨ ∧ ⊥
//   - Tuple brackets: ⟨ ⟩
//   - Subscript chars: ₀ ₁ ₂ ₃ ₄ ₅ ₆ ₇ ₈ ₉
//   - Definition pattern: leading "X = ..." or "X : ..."
//
// Pure DOM mutation: one classList.add per match. No fetching,
// no innerHTML. Safe to call any time after DOM is parsed.

const MATH_SIGNALS = [
  '∈', '∋', '⊆', '⊂', '∪', '∩', '∅', '×', 'Γ', 'Π', 'Σ',
  '→', '↔', '⇒', '∀', '∃', '¬', '∨', '∧', '⊥', '⊤', '≡',
  '⟨', '⟩', '⟦', '⟧',
  '₀', '₁', '₂', '₃', '₄', '₅', '₆', '₇', '₈', '₉',
];

// Math-leading patterns: "X = ..." or "X : ..." at start of line.
const MATH_LEAD_RE = /^\s*[A-ZΑ-Ω][A-Za-zΑ-Ω0-9₀-₉]*\s*[:=]/;

/**
 * Count math signals in a string.
 * Pure function.
 */
export const countMathSignals = (s) => {
  let n = 0;
  for (const sig of MATH_SIGNALS) {
    let idx = s.indexOf(sig);
    while (idx !== -1) { n++; idx = s.indexOf(sig, idx + 1); }
  }
  return n;
};

/**
 * Detect whether a <pre> element's textContent suggests math.
 * Returns true if:
 *   - 2+ math-symbol signals present, OR
 *   - first non-empty line matches X = ... / X : ... pattern, OR
 *   - element is inside .theorem-box or .fsm-svg-wrap (math context).
 *
 * Pure function. Pure: same text → same boolean.
 */
export const isMathBlock = (el) => {
  // Defensive DOM check: Node test runner has no `Element`.
  if (typeof Element === 'undefined') return false;
  if (!(el instanceof Element)) return false;
  if (el.tagName !== 'PRE' && el.tagName !== 'CODE') return false;
  if (el.classList.contains('pre-math')) return false;
  if (el.classList.contains('code-math')) return false;
  if (el.classList.contains('pre-no-math')) return false;
  if (el.dataset.heuristic === 'off') return false;

  // If <code> is inside an already-math <pre>, skip — let the
  // <pre> own the styling.
  if (el.tagName === 'CODE') {
    let ancestor = el.parentElement;
    while (ancestor && ancestor !== document.body) {
      if (ancestor.classList && ancestor.classList.contains('pre-math')) {
        return false;
      }
      ancestor = ancestor.parentElement;
    }
  }

  // Context wins: theorem-box/proof-box/etc always treated as math.
  let p = el.parentElement;
  let inMathContext = false;
  while (p) {
    if (p.classList && (
      p.classList.contains('theorem-box') ||
      p.classList.contains('fsm-svg-wrap')  ||
      p.classList.contains('proof-box')    ||
      p.classList.contains('synthesis-box') ||
      p.classList.contains('antithesis-box')
    )) {
      inMathContext = true;
      break;
    }
    p = p.parentElement;
    if (p === document.body) break;
  }

  const text = el.textContent || '';
  if (inMathContext && text.length >= 1 && countMathSignals(text) >= 1) {
    // Inside math context, any math char is enough.
    return true;
  }

  // For inline <code>, even outside math context, if the text
  // matches a definition pattern (X = ..., X : ..., G = P × I \ {...}),
  // it's a math expression.
  if (el.tagName === 'CODE') {
    const trimmed = text.trim();
    if (trimmed.length >= 2 && /^[A-ZΑ-Ω][A-Za-zΑ-Ω0-9₀-₉]*\s*[:=]/.test(trimmed)) {
      return true;
    }
    // Two or more math signals even in inline code (e.g., "G = P × I \ {(p, p)}")
    if (countMathSignals(text) >= 2) return true;
    return false;
  }

  if (el.tagName !== 'PRE') return false;

  if (countMathSignals(text) >= 2) return true;

  // Leading-line pattern (e.g., "M = ⟨ S, s₀, ...⟩")
  const firstNonEmpty = text.split('\n').find(l => l.trim().length > 0) || '';
  if (MATH_LEAD_RE.test(firstNonEmpty)) return true;

  return false;
};

/**
 * Walk the document and add `.pre-math` / `.code-math` class to
 * every <pre> / <code> that contains math notation. Idempotent.
 *
 * Side effect: classList mutation on matched elements only.
 */
export const prettifyMathBlocks = (root = document) => {
  const els = root.querySelectorAll('pre, code');
  let changed = 0;
  els.forEach((el) => {
    if (!isMathBlock(el)) return;
    if (el.tagName === 'PRE') el.classList.add('pre-math');
    if (el.tagName === 'CODE') el.classList.add('code-math');
    changed++;
  });
  return changed;
};
