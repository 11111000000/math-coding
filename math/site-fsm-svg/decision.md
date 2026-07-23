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
