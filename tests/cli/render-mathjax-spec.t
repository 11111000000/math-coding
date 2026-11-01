mathc render emits `dist/spec/kernel-contract.html` (and the other
normative spec pages under `spec/`) with MathJax 3 loaded in defer
mode, so the math on a spec page is typeset at runtime by the browser
rather than baked into the HTML.

WHAT IS NOT PINNED HERE, AND WHY. This fixture used to assert that two
words of the contract's prose (`friction_user` and `risk_to_mode`)
reached the rendered page. That is the mirror the contract's shrink
removes: a fixture that greps the prose breaks the moment the prose is
rewritten, and the prose is rewritten now. What this fixture holds is
the RENDERER: the MathJax wiring comes from the renderer's own source,
and the page the renderer produces carries every section the source
has. Both claims survive a rewrite of the document's words.

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

The MathJax runtime is wired into the page:

  $ grep -qF 'mathjax@3' $tmpdir/dist/spec/kernel-contract.html
  $ grep -qF 'tex-mml-chtml' $tmpdir/dist/spec/kernel-contract.html
  $ grep -qF "inlineMath" $tmpdir/dist/spec/kernel-contract.html
  $ grep -qF "displayMath" $tmpdir/dist/spec/kernel-contract.html
  $ grep -qF '<script defer' $tmpdir/dist/spec/kernel-contract.html

AND THE WIRING COMES FROM THE RENDERER, not from the page: the same
markers are in the renderer's own source, so the page and the code that
produces it cannot drift apart silently. This is the two-surfaces
comparison the corpus uses for a rule with more than one home
(`scripts/check-applicability-agreement.sh` is the same shape).

  $ grep -qF 'mathjax@3' lib/render/render_nav.ml
  $ grep -qF 'tex-mml-chtml' lib/render/render_nav.ml
  $ grep -qF 'inlineMath' lib/render/render_nav.ml
  $ grep -qF 'displayMath' lib/render/render_nav.ml
  $ grep -qF '<script defer' lib/render/render_nav.ml

The page is a spec page, and it links back to its source:

  $ grep -qF 'class="mathc-spec-page"' $tmpdir/dist/spec/kernel-contract.html
  $ grep -qF 'spec/kernel-contract.md' $tmpdir/dist/spec/kernel-contract.html

THE RENDERER DROPS NO SECTION. Every section anchor of the source
reaches the page. This is a claim about the RENDERER, not about the
words: a section the renderer swallowed would break it, and a rewrite
of the document's prose cannot.

  $ for h in $(grep -oE '^#+ §[0-9]+(\.[0-9]+)?' "$DUNE_SOURCEROOT/spec/kernel-contract.md" | sed 's/^#* //'); do grep -qF "$h" $tmpdir/dist/spec/kernel-contract.html || { echo "MISSING: $h"; exit 1; }; done; echo "every section anchor reaches the page"
  every section anchor reaches the page

  $ rm -rf dist
