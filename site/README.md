# math-coding site

This directory contains the [Hugo](https://gohugo.io/) source for the
math-coding documentation site, deployed at
**https://11111000000.github.io/math-coding/**.

## How content is sourced

The site **never duplicates source of truth**. All content is read from
the main repository directories (`core/`, `agents/`, `adr/`, `examples/`,
`docs/`) and copied into `site/content/` only at build time, by
`.github/workflows/site.yml`.

If you edit content:

- **Edit in the main repo** (`core/core.md`, `agents/agents.md`, etc.)
- Push to `main`
- The site rebuilds automatically on every push

You should not edit files in `site/content/` directly — they are
overwritten at build time.

## What's unique to the site

Only files that **belong to the site and nowhere else** live here:

- `hugo.toml` — Hugo configuration
- `assets/css/custom.css` — custom styles (academic-monospace aesthetic)
- `layouts/partials/` — KaTeX and Mermaid loader partials
- `static/favicon.svg` — site favicon
- `static/diagrams/*.mmd` — pre-existing diagrams (live copies also in
  `content/diagrams.md`)
- `content/_index.md` — landing page (rendered from scratch)
- `content/{core,theory,agents,adr,examples,integrations}/_index.md` —
  section index pages
- `content/diagrams.md` — diagram collection (rendered as HTML)
- `content/core/_index.md` — rendered source of `core/core.md` could be
  placed here, but currently is auto-synced from `core/core.md` to
  `content/core.md`

## Local preview

Install Hugo extended ≥ 0.124 and Go ≥ 1.22, then:

```sh
cd site
hugo server --buildFuture
```

The site is served at `http://localhost:1313/`.

To run a full build (what CI does):

```sh
cd site
bash .github/sync-content.sh   # copies content from parent dirs
hugo --minify
```

(The sync step is inlined in `.github/workflows/site.yml` for build
performance; it can be extracted to a local script if you prefer.)

## Theme

[Congo](https://github.com/jpanther/congo) by jpanther, MIT licensed.
Loaded via Hugo modules. The theme is not vendored — this keeps the
repository small and tracks upstream fixes.

## Design notes

The site follows an academic-monospace aesthetic:

- Headings: monospace (JetBrains Mono)
- Body: serif (Spectral)
- Single accent color (blue `#0066cc`)
- Math: KaTeX (faster than MathJax, fully sufficient for our formulas)
- Diagrams: Mermaid (loaded client-side for inline diagrams)
- No tracking, no analytics, no cookies

See `assets/css/custom.css` for the full style layer.

## Layout philosophy

The site is a **reference**, not a product. The same words used in the
repository apply here. Every page has a "source on GitHub" link so
readers can verify what they read against the canonical document.