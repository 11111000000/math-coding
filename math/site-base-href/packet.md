---
schema_version: "2.0"
name: site-base-href
proposition: "Site deployed under /math-coding/ subpath uses <base href='/math-coding/'> with MATH_CODING_BASE env override, and rewrites .md links to lowercase .html so GitHub Pages case-sensitive routing works."
register: judgment
state: draft
actor: agent
confidence: 0.9
superseded_by:
beneficiary: Developer
---

## Why

GitHub Pages serves the repo at `/math-coding/` (not root), and is case-sensitive.
Absolute hrefs like `/manifesto.html` resolved to `user.github.io/manifesto.html`
(404) instead of `user.github.io/math-coding/manifesto.html`.
Pandoc also leaves `.md` in cross-document links and does not lowercase.
A `<base href>` tag with env override plus a post-processing rewrite pass
fixes both, without forcing the source docs into a different relative scheme.

## Care

Proposition is non-empty.

## Thesis

Emit `<base href="/math-coding/">` in `render_page`; rewrite `.md`→`.html`,
lowercase href paths, and fold `math/modeling/` and `LICENSE` links to the
right targets in `rewrite_md_links`.

## Antithesis

- Keep absolute hrefs and ask each contributor to write `./manifesto.html` everywhere.
- Switch the Pages config to a custom domain (`kosov.online/math-coding`) — same problem.
- Drop the page model entirely and serve a single SPA.

Both variants either leak the deploy path into the source tree or remove a
page model that is already load-bearing for `packets.html`.

## Synthesis

Decision: keep absolute-feeling paths in source, hide the deploy path behind
`<base>` and a single OCaml pass. Override via `MATH_CODING_BASE` env so
local dev (`http://localhost:8000/`) and the `/math-coding/` subpath both work.

## Notes

- `core/render.ml:23` now uses `Str.global_replace` and friends; `str` added to `core/dune`.
- `Str` is not opened (qualified references only), so `open Str` was removed to silence warning 33.
