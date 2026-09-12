---
proposition: "  FSM diagram at /fsm.html is a hand-coded SVG showing 4   lifecycle states (draft / applied / retired / abandoned) with   arrows and per-state invariant annotations, committed as a   static asset. "
antithesis: "  A JS-rendered graph (D3, mermaid.js) would update automatically   if states change. But the FSM is *frozen by axiom A4* — adding   a 5th state would itself be a packet proposal, not a quiet   edit. The maintenance burden of hand-coding is small precisely "
synthesis: "  Hand-code the SVG once. Site-test.sh grep-checks key strings.   Mermaid-style images are forbidden (rasterization binary asset)   in favor of text-replaceable SVG that grep, git diff, and copy-   paste all see. "
axiom: 
substrate: none
---

# site-fsm-svg

## Thesis

  FSM diagram at /fsm.html is a hand-coded SVG showing 4
  lifecycle states (draft / applied / retired / abandoned) with
  arrows and per-state invariant annotations, committed as a
  static asset.

## Antithesis

  A JS-rendered graph (D3, mermaid.js) would update automatically
  if states change. But the FSM is *frozen by axiom A4* — adding
  a 5th state would itself be a packet proposal, not a quiet
  edit. The maintenance burden of hand-coding is small precisely
  because the FSM is stable.

  JS-rendered diagrams also hide from search engines and from
  copy-paste (most diagram-rendering libs serialize as canvas
  or computed paths — non-replicable). Static SVG is
  copy-pasteable, git-diffable, grep-able.

  Could we generate SVG via shell + awk? Yes, but hand-coded
  SVG with explicit coordinates is more readable and easier to
  adjust than script-generated output. This is a one-time
  artifact per FSM change, not a hot-path.

## Synthesis

  Hand-code the SVG once. Site-test.sh grep-checks key strings.
  Mermaid-style images are forbidden (rasterization binary asset)
  in favor of text-replaceable SVG that grep, git diff, and copy-
  paste all see.

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
