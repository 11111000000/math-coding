---
proposition: "Build pipeline reuses Math_coding_lib.Parse; ./math-coding site regenerates dist/ with 45 packet pages."
antithesis: "Earlier build_site.ml had a duplicated YAML parser and a buggy html_escape that dropped non-special characters — pages rendered with empty <title> and <h1>. The duplicate parser would drift from the canonical one over time."
synthesis: "build_site.ml imports Math_coding_lib.Parse.parse_packet and Math_coding_lib.Packet. html_escape emits every char (escape & < > \"). main.ml exposes `./math-coding site` so users regenerate the static site with one command. Site artifacts: index.html (45-packet table with axiom highlighting), axioms.html (seven sections), installing.html (prerequisites + install + use), math/<name>.html per packet."
substrate: shell
status: applied
files: [tools/build_site.ml]
---

## Intent

Make the site a first-class artefact of the convention, not a
parallel tooling chain.

## What this is NOT

- Not a static site generator (Jekyll, Hugo, Astro). One OCaml
  file does the whole thing.
- Not a CMS. The site IS the math/ directory; the build tool
  just renders it.
- Not a documentation site for the OCaml runtime. It documents
  the convention, which lives in math/.

## Run

```sh
./math-coding site           # regenerates dist/
ls dist/
```

## Notes

The build tool reuses Math_coding_lib.Parse so packet format is
defined once. Adding a field to packet.yaml requires no changes
to the site renderer. Adding a substrate type requires only a
substrate check in src/lib/check.ml; the site picks it up via the
canonical parser.
