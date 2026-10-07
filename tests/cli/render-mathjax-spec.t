mathc render emits `dist/spec/algebra-3.2.html` (and the other
normative spec pages under `spec/`) with MathJax 3 loaded in
defer mode. Every `$..$` and `$$..$$` formula in
`spec/algebra-3.2.md` reaches the rendered HTML as a
typescript-friendly substring — MathJax typesets the
delimiters at runtime, so the rendered HTML carries the
raw `$..$` content inside its body even when no `$..$`
delimiter is present in the source (algebra-3.2.md uses
` ``` ` fenced blocks for its math; the formulas still reach
the DOM as the live source string).

Acceptance gate for obligation `spec-mathjax-rendered` in
`decisions/plan-2026-10-improvements.yaml@1` and for the
`t5-2-spec-mathjax` sub-decision's obligation
`spec-mathjax-wired-and-rendered`.

  $ cd "$DUNE_SOURCEROOT"
  $ rm -rf dist
  $ mathc render --out dist --lang=both > /tmp/render-spec-out.txt
  $ test -f dist/spec/algebra-3.2.html
  $ test -f dist/spec/constitution.html
  $ test -f dist/spec/domain.html
  $ test -f dist/spec/semantics.html
  $ grep -qF 'mathjax@3' dist/spec/algebra-3.2.html
  $ grep -qF 'tex-mml-chtml' dist/spec/algebra-3.2.html
  $ grep -qF "inlineMath" dist/spec/algebra-3.2.html
  $ grep -qF "displayMath" dist/spec/algebra-3.2.html
  $ grep -qF '<script defer' dist/spec/algebra-3.2.html
  $ grep -qF 'friction_user' dist/spec/algebra-3.2.html
  $ grep -qF 'risk_to_mode' dist/spec/algebra-3.2.html
  $ grep -qF 'class="mathc-spec-page"' dist/spec/algebra-3.2.html
  $ grep -qF 'algebra-3.2' dist/spec/algebra-3.2.html
  $ ! grep -qF 'mathjax@3' dist/index.html
  $ ! grep -qF 'mathjax@3' dist/methodology.html
  $ ! grep -qF 'mathjax@3' dist/manifesto.html
  $ rm -rf dist
