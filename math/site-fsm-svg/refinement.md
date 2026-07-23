# Refinement: site-fsm-svg

## State

- pre: <state before implementation>
- post:   /fsm.html renders the FSM diagram with monospace labels,
  invariant annotations, and no JavaScript; the diagram
  precisely mirrors `core/spec/fsm.md` notation M = ⟨S, s₀, A,
  →, I⟩.

## Operation

  fsm.svg: ~80 lines hand-coded SVG with:
    - 4 rect nodes (draft, applied, retired, abandoned),
    - 5 path arrows (apply, retire, abandon, archive x2),
    - 4 invariant text blocks (I(s) per state),
    - 1 legend block,
    - mono font labels via inline font-family.
  Inline in /fsm.html OR referenced as
  /assets/fsm/fsm.svg via <img> with descriptive alt.
  Standalone file recommended for clarity.
  ------------------------------------------------------------------------
  Total: 1 SVG file + 1 line in HTML linking to it.

## Invariant preservation

  exactly one SVG file for /fsm.html (either inline or
  /assets/fsm/fsm.svg); node positions are explicit pixel
  coordinates; edge labels match `core/spec/fsm.md` strings
  verbatim; all 4 invariant texts (I(draft), I(applied),
  I(retired), I(abandoned)) appear in the SVG.

## Test obligation

  grep checks in tests/site-test.sh:
    1. SVG file or inline SVG contains all 4 state names:
       draft, applied, retired, abandoned.
    2. SVG contains all 4 invariant marker names:
       I(draft), I(applied), I(retired), I(abandoned).
    3. SVG contains all 5 transition labels:
       apply, retire, abandon, archive (some apply in both
       directions).
