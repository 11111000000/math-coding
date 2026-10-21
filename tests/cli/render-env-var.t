mathc render resolves decisions_root and attestations_root
through `Path_config.resolve_*` at call time (not via
top-level `let <name> = "decisions"` / `let <name> =
"attestations"` bindings), per F10 fix #4 in
decisions/path-resolver-audit-2026-11.yaml.

Setup: an isolated project at `$tmpdir` with one decision in
`.math-coding/decisions/`, an empty attestation store, and a
shrunken `site/` directory. The render relies on the resolver's
relative path opening correctly relative to the cwd; this matches
the existing `tests/cli/env-var-resolver.t` convention where
`mathc packages` and `mathc self-check` walk the same
MATH_CODING_DECISIONS_DIR-relative tree.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ export MATH_CODING_ROOT="$tmpdir"
  $ cp dune-project "$tmpdir/"
  $ mkdir -p "$tmpdir/site" "$tmpdir/.math-coding/decisions" "$tmpdir/.math-coding/attestations"
  $ for f in site/manifesto.md site/foundations.md site/workflow.md site/faq.md site/contributing.md site/readme.md site/install.md site/methodology.md site/bootstrap-gate.md site/packages.md site/differences.md site/axioms.md site/index.md; do
  >   cp "$f" "$tmpdir/$f" 2>/dev/null || true
  > done
  $ cat > "$tmpdir/.math-coding/decisions/render-env-probe-2026-11.yaml" <<'EOF'
  > ---
  > schema: math-coding/3.3
  > id: render-env-probe-2026-11
  > revision: 1
  > state: active
  > mode: standard
  > change_kind: implementation
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > axiom_link:
  >   - A0
  > intent: |
  >   Probe decision for tests/cli/render-env-var.t (F10 fix #4).
  > commitment: |
  >   mathc render emits a package page that includes the probe.
  > counterexample: |
  >   Pre-fix mathc render walked decisions/ at the cwd, ignoring
  >   the resolver; the probe would be invisible.
  > scope:
  >   paths:
  >     - "tests/cli/render-env-var.t"
  > outcomes:
  >   - id: o1
  >     statement: A first outcome.
  > obligations:
  >   - id: ob1
  >     claim: |
  >       The probe decision appears in the rendered packages page.
  >     acceptance:
  >       all:
  >         - verifier: mathc self-check
  >           result: pass
  > risk:
  >   declared_triggers: []
  >   owner: human:tester
  > relations:
  >   addresses: []
  > EOF
  $ cd "$tmpdir"
  $ export MATH_CODING_DECISIONS_DIR=".math-coding/decisions"
  $ export MATH_CODING_ATTESTATIONS_DIR=".math-coding/attestations"

`mathc render` walks `<cwd>/<MATH_CODING_DECISIONS_DIR>/` and the
attestation store at `<cwd>/<MATH_CODING_ATTESTATIONS_DIR>/`. The
probe decision appears in `out/packages.html` (emitted only when
the cwd has `site/packages.md`; the F10 fix only changes the
path lookup, not the page set). Pre-fix render walked
`<cwd>/decisions/` and emitted an empty package list because the
cwd (tmpdir) has no legacy `decisions/` at its root.

  $ rm -rf out
  $ mathc render --out $tmpdir/out > $tmpdir/render-env-out.txt 2>&1
  $ grep -qF 'render OK' $tmpdir/render-env-out.txt \
  >   && echo "render OK" \
  >   || cat $tmpdir/render-env-out.txt
  render OK
  $ grep -oE 'data-mathc-package-count="[0-9]+"' $tmpdir/out/packages.html
  data-mathc-package-count="1"
  $ grep -q 'decisions/render-env-probe-2026-11.html' $tmpdir/out/packages.html \
  >   && echo "probe decision link in rendered packages.html: ok"
  probe decision link in rendered packages.html: ok

Cleanup.

  $ cd /
  $ rm -rf "$tmpdir"
