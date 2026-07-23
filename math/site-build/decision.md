# site-build

## Thesis

  math-coding ships a static documentation site built by a POSIX
  shell script (meta/site-build.sh) that compiles plain HTML,
  CSS, JS, self-hosted woff2, and SVG into dist/, with no JS
  framework and no external CDN, deployable to GitHub Pages.

## Antithesis

  A framework like Astro + Tailwind would be faster to develop,
  provides hot-reload during development, and offers easier MDX
  components. Build complexity is invisible to end-users.

  However:
  - A site depending on Node requires two toolchains on
    contributor machines (POSIX + Node), violating A3's "older
    than the convention" requirement.
  - When Node version drifts on CI, builds fail in subtle ways
    (lockfile disputes, peer-dep churn). The convention's CI is
    gated on `sh math-coding probe` exiting 0; site build must
    integrate without making A6 mean "Node + POSIX both pass".
  - CDN for fonts means uptime dependency on a third party.
    A3 explicitly rejects this.
  - Framework-rendered output tends to be markup-heavy and
    harder to verify by simple grep+find than hand-authored HTML.

## Synthesis

  Use pandoc --mathml + yq + POSIX shell for the entire pipeline.
  Pure FP JavaScript for the 2 places where client-side
  interactivity adds value (live-filter at /packets.html, manual
  theme override). Self-hosted Source Serif 4 + JetBrains Mono
  (~138 KB). Hand-coded SVG for FSM.

  This gives:
  - A3 satisfied (no JS framework, no external CDN).
  - A4 satisfied (build steps are explicit finite ordered
    operations).
  - A5 satisfied (every deploy commit has SHA in applications[]).
  - A6 satisfied (tests/site-test.sh is part of verify-pipeline).

  Up-front cost is ~1500 lines of explicit code; long-term cost
  is zero — no lockfile disputes, no version drift, no peer-
  dependency security alerts.
