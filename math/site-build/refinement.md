# Refinement: site-build

## State

- pre: <state before implementation>
- post:   `sh meta/site-build.sh` produces dist/ ready for GitHub Pages;
  the site renders equivalently for every packet, axiom, lifecycle,
  and epistemic marker, both with and without JS enabled; deploy is
  triggered on every push to main via .github/workflows/site.yml.

## Operation

  Build:
    sh meta/site-build.sh       # ~80 lines POSIX shell
       mkdir -p dist
       cp site/*.html dist/
       cp -r site/assets dist/assets
       for src in core/spec/*.md KNOWN_LIMITATIONS.md; do
         pandoc "$src" --from gfm --to html5 --mathml
                --standalone --no-highlight
                --output "dist/${src%.md}.html"
       done
       for d in math/*/; do
         [ -f "$d/packet.yaml" ] || continue
         id="${d%/}"; id="${id##*/}"
         yq -o=json "$d/packet.yaml" >
            "dist/packets/$id/manifest.json"
         for f in decision.md refinement.md task.md; do
           [ -f "$d/$f" ] && pandoc "$d/$f" --mathml
                          --output "dist/packets/$id/${f%.md}.html"
         done
       done
       yq collect -> dist/data/packets-manifest.json

  Deploy:
    git push -> .github/workflows/site.yml runs the same build
                then actions/deploy-pages@v4

  Verify:  sh tests/site-test.sh is in tests/run.sh
  Witness: every deploy commit SHA in math/site-build/packet.yaml:
           applications[]
  ------------------------------------------------------------------------
  Total: ~80 lines shell + 9 .html pages + 1 .yml workflow.

## Invariant preservation

  dist/ contains only .html, .css, .js, .woff2, .svg, .json, .xml,
  .txt files; no .docx, no .pdf, no binary blobs, no runtime
  eval, no <script src="https://*"> references; every A3 claim
  about site/ is checkable by tests/.

## Test obligation

  `sh tests/site-test.sh` exits 0 after build. Specifically:
    1. find site/ \( -name '*.png' -o -name '*.jpg' -o -name
       '*.pdf' -o -name '*.docx' \) is empty.
    2. grep -rE 'src="https://|cdn\.|googleapis|unpkg|jsdelivr'
       site/ finds nothing outside fonts/ (which has woff2 only).
    3. manifest packet count == find math -mindepth 1 -maxdepth 1
       -type d | wc -l (with README.md excluded).
    4. every sha in manifest.json resolves to a real commit
       (git cat-file -e $sha exits 0).
    5. every .html in dist/ has <meta name="viewport"
       content="...">.
    6. every .html in dist/ has <meta name="color-scheme"
       content="light dark">.
