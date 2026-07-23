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
