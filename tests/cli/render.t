mathc render --out DIR renders the static site under DIR per
spec/semantics.md §`render`. The render walks decisions/,
attestations/, axioms/, and site/; emits a fixed sequence of
files; the first stdout line announces the page count and the
last line confirms completion. Acceptance gate for obligation
render-kernel-impl in decisions/site-deploy.yaml.

The rev 2 accept test additionally asserts: Tufte stylesheet,
sidenote rendering, MathJax in <head>, <base href> for the
subpath deployment, and the bilingual EN+RU page set
(MANIFESTO, FOUNDATIONS, WORKFLOW, FAQ, CONTRIBUTING, README).

  $ cd "$DUNE_SOURCEROOT"
  $ rm -rf dist
  $ mathc render --out dist --lang=both > /tmp/render-out.txt
  $ head -n 1 /tmp/render-out.txt | grep -qF '[render] writing'
  $ tail -n 1 /tmp/render-out.txt | grep -qF 'render OK:'
  $ test -f dist/index.html
  $ test -f dist/index.ru.html
  $ test -f dist/axioms.html
  $ test -f dist/methodology.html
  $ test -f dist/bootstrap-gate.html
  $ test -f dist/packages.html
  $ test -f dist/manifesto.html
  $ test -f dist/manifesto.ru.html
  $ test -f dist/foundations.html
  $ test -f dist/foundations.ru.html
  $ test -f dist/workflow.html
  $ test -f dist/faq.html
  $ test -f dist/readme.html
  $ test -f dist/readme.ru.html
  $ test -f dist/contributing.html
  $ grep -qF 'data-mathc-package-count="' dist/index.html
  $ jq -e 'type == "array"' dist/index.json
  true
  $ grep -qF '<base href="/math-coding/">' dist/index.html
  $ grep -qF 'lang="en"' dist/index.html
  $ grep -qF 'lang="ru"' dist/index.ru.html
  $ grep -qF 'mathjax@3' dist/methodology.html
  [1]
  $ grep -qF 'class="sidenote"' dist/manifesto.html
  $ grep -qF '<table class="mathc-table"' dist/manifesto.html
  $ grep -qF '<strong>' dist/manifesto.html
  $ grep -qF '<a href="axioms.html"' dist/workflow.html
  $ rm -rf dist

