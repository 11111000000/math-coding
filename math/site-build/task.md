# site-build

## Problem

math-coding needs a static documentation site that satisfies
axiom A3 (Material Basis: plain text, git, POSIX) while still
being readable, fast, and discoverable. A framework-based
solution (Astro, Hugo, Docusaurus) would either require Node
on contributor machines (violates A3) or be heavy enough to
create a maintenance burden.

## Desired outcome

`sh meta/site-build.sh` produces dist/ ready for GitHub Pages.
Every MD file in core/ and every packet under math/ is
pre-rendered to a static HTML page via pandoc --mathml.
A manifest.json enumerates all packets with their lifecycle,
axiom, and last commit SHA. The site works without JS for
reading; with JS for live-filter at /packets.html.

## Constraints

- Build script is POSIX shell, no bashism, no node at runtime.
- dist/ contains only .html/.css/.js/.woff2/.svg/.json/.xml/.txt.
- No CDN, no Google Fonts, no scripts from https://.
- Every deploy commit SHA is recorded in
  math/site-build/packet.yaml:applications[] (axiom A5).
- The site self-verifies via tests/site-test.sh, included in
  tests/run.sh. Breaking self-test blocks deploy (axiom A6).
