---
proposition: "  client-side JavaScript on math-coding site (live filter at   /packets.html, manual theme override) is implemented as pure   functions over a fetched manifest, with side-effects isolated   to one entry-point. "
antithesis: "  Server-side filtering would shift work to build step, eliminating   runtime JavaScript. For a build that runs on every commit, this   would mean re-rendering 25+ HTML pages per change to filter state   — wasteful when filter state is rarely edited. "
synthesis: "  Hybrid: pre-render 25 packet-detail HTML in CI for SEO + direct   linkability. /packets.html uses pure-FP live-filter as progressive   enhancement. Theme override is purely CSS-driven, with one   [data-theme] attribute toggle. "
axiom: 
substrate: none
---

# site-pure-fp

## Thesis

  client-side JavaScript on math-coding site (live filter at
  /packets.html, manual theme override) is implemented as pure
  functions over a fetched manifest, with side-effects isolated
  to one entry-point.

## Antithesis

  Server-side filtering would shift work to build step, eliminating
  runtime JavaScript. For a build that runs on every commit, this
  would mean re-rendering 25+ HTML pages per change to filter state
  — wasteful when filter state is rarely edited.

  Removing all JS at the cost of SSG-rendering-everything also
  costs the user: no progressive enhancement, full reloads for
  navigation, no offline cache.

  Could we use a JS framework like Preact (3 KB) for this? Even
  3 KB is 3 KB more than needed. Axiom A3 cares about substrate
  purity — a JS framework is still a JS framework, no matter how
  small. The convention forbids "Look like 90s HTML" indirectly
  via forbids-undisciplined-deps.

## Synthesis

  Hybrid: pre-render 25 packet-detail HTML in CI for SEO + direct
  linkability. /packets.html uses pure-FP live-filter as progressive
  enhancement. Theme override is purely CSS-driven, with one
  [data-theme] attribute toggle.

  Pure functions are tested by Node --test in CI (NOT in browser).
  This means runtime is just the function bodies + DOM effects.
  No test framework ships to browser.

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
