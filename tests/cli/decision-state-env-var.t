mathc decision-state reads AND writes `<decisions_dir>/<id>.yaml`
honouring MATH_CODING_DECISIONS_DIR, per F10 fix #5 in
decisions/path-resolver-audit-2026-11.yaml. The pre-fix kernel
hard-coded `<root>/decisions/<id>.yaml`, so a user routing their
tree to `.math-coding/decisions/` would silently mutate the
wrong file.

Setup: an isolated project at `$tmpdir` with one active decision
in `.math-coding/decisions/`. Export
MATH_CODING_DECISIONS_DIR=.math-coding/decisions.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ echo '(lang dune 3.0)' > "$tmpdir/dune-project"
  $ mkdir -p "$tmpdir/.math-coding/decisions"
  $ cat > "$tmpdir/.math-coding/decisions/decision-state-env-probe-2026-11.yaml" <<'YAML'
  > schema: math-coding/3.3
  > id: decision-state-env-probe-2026-11
  > revision: 1
  > state: active
  > mode: light
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent:
  >   source: path-resolver-audit-2026-11
  >   text: |
  >     Fixture for the decision-state env-var cram test.
  > commitment: |
  >   One file, one obligation.
  > outcomes:
  >   - id: o1
  >     statement: |
  >       trivially true.
  > scope:
  >   paths:
  >     - "tests/cli/decision-state-env-var.t"
  > obligations:
  >   - id: trivial-obligation
  >     claim: |
  >       validates under $INSIDE_DUNE/bin/mathc.exe validate with active state.
  >     acceptance:
  >       all:
  >         - verifier: tests/cli/decision-state-env-var.t
  >           result: pass
  > axiom_link:
  >   - A0
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > relations:
  >   addresses:
  >     - path-resolver-audit-2026-11@1
  > counterexample: |
  >   None — synthetic fixture for the path-resolver-audit cram
  >   test; the dialectical slot does not apply.
  > YAML
  $ $INSIDE_DUNE/bin/mathc.exe rehash "$tmpdir/.math-coding/decisions/decision-state-env-probe-2026-11.yaml" --write > /dev/null
  $ export MATH_CODING_ROOT="$tmpdir"
  $ export MATH_CODING_DECISIONS_DIR=".math-coding/decisions"

`mathc decision-state <id> mark-retired` mutates
`<root>/<MATH_CODING_DECISIONS_DIR>/<id>.yaml`. The write lands
in `.math-coding/decisions/`, not the legacy `decisions/`.

  $ $INSIDE_DUNE/bin/mathc.exe rehash "$tmpdir/.math-coding/decisions/decision-state-env-probe-2026-11.yaml" --write > /dev/null
  $ $INSIDE_DUNE/bin/mathc.exe decision-state decision-state-env-probe-2026-11 mark-retired
  mathc decision-state: set state=retired
  validate: parse-ok

  $ grep '^state:' "$tmpdir/.math-coding/decisions/decision-state-env-probe-2026-11.yaml"
  state: retired
  $ test ! -f "$tmpdir/decisions/decision-state-env-probe-2026-11.yaml" \
  >   && echo "no legacy write: ok"
  no legacy write: ok

Cleanup.

  $ cd /
  $ rm -rf "$tmpdir"
