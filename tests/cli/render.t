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

The rev 3 accept test additionally asserts: the trilingual
EN+RU+ZH page set (all 10 canonical articles + 3 indices)
under `--lang=all`.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ mathc render --out $tmpdir/dist --lang=all > $tmpdir/render-out.txt
  $ head -n 1 $tmpdir/render-out.txt | grep -qF '[render] writing'
  $ tail -n 1 $tmpdir/render-out.txt | grep -qF 'render OK:'
  $ test -f $tmpdir/dist/index.html
  $ test -f $tmpdir/dist/index.ru.html
  $ test -f $tmpdir/dist/index.zh.html
  $ test -f $tmpdir/dist/axioms.html
  $ test -f $tmpdir/dist/methodology.html
  $ test -f $tmpdir/dist/bootstrap-gate.html
  $ test -f $tmpdir/dist/packages.html
  $ test -f $tmpdir/dist/manifesto.html
  $ test -f $tmpdir/dist/manifesto.ru.html
  $ test -f $tmpdir/dist/manifesto.zh.html
  $ test -f $tmpdir/dist/foundations.html
  $ test -f $tmpdir/dist/foundations.ru.html
  $ test -f $tmpdir/dist/foundations.zh.html
  $ test -f $tmpdir/dist/workflow.html
  $ test -f $tmpdir/dist/workflow.ru.html
  $ test -f $tmpdir/dist/workflow.zh.html
  $ test -f $tmpdir/dist/faq.html
  $ test -f $tmpdir/dist/faq.ru.html
  $ test -f $tmpdir/dist/faq.zh.html
  $ test -f $tmpdir/dist/readme.html
  $ test -f $tmpdir/dist/readme.ru.html
  $ test -f $tmpdir/dist/readme.zh.html
  $ test -f $tmpdir/dist/contributing.html
  $ test -f $tmpdir/dist/contributing.ru.html
  $ test -f $tmpdir/dist/contributing.zh.html
  $ test -f $tmpdir/dist/install.html
  $ test -f $tmpdir/dist/install.ru.html
  $ test -f $tmpdir/dist/install.zh.html
  $ grep -qF 'data-mathc-package-count="' $tmpdir/dist/packages.html
  $ jq -e 'type == "array"' $tmpdir/dist/index.json
  true
  $ grep -qF '<base href="/math-coding/">' $tmpdir/dist/index.html
  $ grep -qF 'lang="en"' $tmpdir/dist/index.html
  $ grep -qF 'lang="ru"' $tmpdir/dist/index.ru.html
  $ grep -qF 'lang="zh"' $tmpdir/dist/index.zh.html
  $ grep -qF 'mathjax@3' $tmpdir/dist/methodology.html
  $ grep -qF 'class="sidenote"' $tmpdir/dist/manifesto.html
  $ grep -qF 'decisions/decision.yaml' $tmpdir/dist/manifesto.html
  $ grep -qF '<strong>' $tmpdir/dist/manifesto.html
  $ grep -qF '<a href="axioms.html"' $tmpdir/dist/workflow.html
  $ grep -qF 'class="github-link"' $tmpdir/dist/index.html
  $ grep -qF 'href="https://github.com/11111000000/math-coding"' $tmpdir/dist/index.html
  $ grep -qF 'github.com/11111000000/math-coding/blob/main/AGENTS.md' $tmpdir/dist/index.html
  $ grep -qF 'github.com/11111000000/math-coding/blob/main/ROADMAP.md' $tmpdir/dist/index.html
  $ grep -qF 'github.com/11111000000/math-coding/blob/main/PACKAGES.md' $tmpdir/dist/index.html
  $ grep -qF 'github.com/11111000000/math-coding/blob/main/spec/algebra-3.2.md' $tmpdir/dist/index.html
  $ grep -qF 'href="manifesto.zh.html"' $tmpdir/dist/axioms.zh.html
  $ grep -qF 'href="foundations.zh.html"' $tmpdir/dist/axioms.zh.html
  $ grep -qF 'href="manifesto.html"' $tmpdir/dist/manifesto.ru.html
  $ grep -qF 'href="axioms.html"' $tmpdir/dist/axioms.zh.html
  $ grep -qF 'href="index.html"' $tmpdir/dist/manifesto.html
  $ if grep -qF 'href="manifesto.en.html"' $tmpdir/dist/manifesto.ru.html; then echo 'FAIL: $tmpdir/dist/manifesto.ru.html still references manifesto.en.html (regression)'; exit 1; fi
  $ if grep -qF 'href="axioms.en.html"' $tmpdir/dist/axioms.zh.html; then echo 'FAIL: $tmpdir/dist/axioms.zh.html still references axioms.en.html (regression)'; exit 1; fi
  $ rm -rf dist

