---
proposition: "The v1.0 documentation site is plain HTML + CSS rendered from math/<name>/packet.md at build time, with no JavaScript framework and no client-side dependencies."
antithesis: "v0.993 had a Pandoc-based site build that required pandoc installed on the host. Pandoc is heavyweight and added a third-party dependency to the convention's A3 (Material Basis) property."
synthesis: "Each packet's packet.md is read by an OCaml script that produces a static HTML page. CSS lives in site/assets/tokens.css (no CDN, no JS). Build is one `dune build` invocation. A single HTML index.html lists all packets with axiom + proposition + status."
substrate: shell
status: applied
files: [tools/build_site.ml, site/assets/tokens.css]
---

## Intent

Documentation follows the same discipline as code: plain text,
git history, one binary. No third-party templating, no JS framework.

## What this is NOT

- Not a static site generator (Jekyll, Hugo). Just a 200-line OCaml script.
- Not a CMS. The site IS the math/ directory.
- Not a single-page app. Every page is a real HTML file with real content.

## Run

```sh
dune build
./math-coding site           # regenerates dist/
```

## Notes

Total build artifact: ~150 KiB HTML+CSS. CSS variables for paper+ink
palette. One accent per epistemic/lifecycle instrument: axiom (blue),
antithesis (crimson), synthesis (green), proof (sepia).

Pages emitted per packet:
- index.html — axiom index with status
- math/<name>.html — full packet page with proposition/notes
- axioms.html — seven axioms overview
- installing.html — how to install math-coding v1.0
