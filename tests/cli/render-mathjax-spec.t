mathc render emits `dist/spec/kernel-contract.html` (and the other
normative spec pages under `spec/`) with MathJax 3 loaded in
defer mode. Every `$..$` and `$$..$$` formula in
`spec/kernel-contract.md` reaches the rendered HTML as a
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
  $ tmpdir=$(mktemp -d)
  $ $INSIDE_DUNE/bin/mathc.exe render --out $tmpdir/dist --lang=both > $tmpdir/render-spec-out.txt
  $ test -f $tmpdir/dist/spec/kernel-contract.html
  $ test -f $tmpdir/dist/spec/constitution.html
  $ test -f $tmpdir/dist/spec/domain.html
  $ test -f $tmpdir/dist/spec/semantics.html
  $ grep -qF 'mathjax@3' $tmpdir/dist/spec/kernel-contract.html
  $ grep -qF 'tex-mml-chtml' $tmpdir/dist/spec/kernel-contract.html
  $ grep -qF "inlineMath" $tmpdir/dist/spec/kernel-contract.html
  $ grep -qF "displayMath" $tmpdir/dist/spec/kernel-contract.html
  $ grep -qF '<script defer' $tmpdir/dist/spec/kernel-contract.html
  $ grep -qF 'friction_user' $tmpdir/dist/spec/kernel-contract.html
  $ grep -qF 'risk_to_mode' $tmpdir/dist/spec/kernel-contract.html
  $ grep -qF 'class="mathc-spec-page"' $tmpdir/dist/spec/kernel-contract.html
  $ grep -qF 'algebra-3.2' $tmpdir/dist/spec/kernel-contract.html
  $ rm -rf dist
