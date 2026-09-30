mc render --out DIR renders the static site under DIR per
spec/semantics.md §`render`. The render walks decisions/,
attestations/, axioms/, and site/; emits a fixed sequence of
files; the first stdout line announces the page count and the
last line confirms completion. Acceptance gate for obligation
render-kernel-impl in decisions/site-deploy.yaml.

  $ cd "$DUNE_SOURCEROOT"
  $ rm -rf dist
  $ mathc render --out dist > /tmp/render-out.txt
  $ head -n 1 /tmp/render-out.txt | grep -qF '[render] writing'
  $ tail -n 1 /tmp/render-out.txt | grep -qF 'render OK:'
  $ test -f dist/index.html
  $ test -f dist/axioms.html
  $ test -f dist/methodology.html
  $ test -f dist/bootstrap-gate.html
  $ test -f dist/packages.html
  $ grep -qF 'data-mc-package-count="' dist/index.html
  $ jq -e 'type == "array"' dist/index.json
  true
  $ rm -rf dist
