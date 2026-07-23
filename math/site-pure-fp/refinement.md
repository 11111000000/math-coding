# Refinement: site-pure-fp

## State

- pre: <state before implementation>
- post:   every function in pure/ is referentially transparent and tested
  by `node --test` in CI; side-effects are exactly: (a) fetch
  manifest once, (b) replaceChildren DOM operation, (c)
  localStorage.setItem for theme; zero innerHTML on dynamic
  strings.

## Operation

  pure/filter.mjs   ~15 lines — filterPackets(packets, {axiom,
                                       lifecycle, q}) => packet[]
  pure/render.mjs   ~30 lines — renderPacketCard(p) => HTML string
                                       via template literals
  pure/escape.mjs   ~10 lines — escapeHtml(s) => safe string
  theme.mjs         ~15 lines — theme toggle, listeners
  main.mjs          ~50 lines — fetch manifest, parse URL,
                                   call filter+render,
                                   replaceChildren
  tests/pure-fp.test.mjs ~30 lines — Node --test cases
  ------------------------------------------------------------------------
  Total: ~150 lines JS (pure ≈ 60 lines, effects ≈ 90 lines).

## Invariant preservation

  no innerHTML with dynamic strings; no eval; no document.write;
  no <script> injection from MD content; all output goes through
  DOMParser.parseFromString OR textContent + setAttribute.

## Test obligation

  `node --test tests/pure-fp.test.mjs` runs against
  pure/filter.mjs, pure/render.mjs, pure/escape.mjs. Three sets:
    - filterPackets returns expected arrays for sample input.
    - renderPacketCard produces HTML strings parseable without
      throw via DOMParser.
    - escapeHtml neutralizes `<script>alert(1)</script>` input.

  Coverage requirement: every exported function has at least
  3 unit tests covering normal, boundary, and adversarial input.
