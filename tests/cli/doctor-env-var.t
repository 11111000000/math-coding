mathc doctor config and decisions sections resolve through
`Path_config.resolve_policy_path ()` and
`Path_config.resolve_decisions_dir ()`, per F10 fix #6 in
decisions/path-resolver-audit-2026-11.yaml. The pre-fix kernel
hard-coded `decisions/decision.yaml` (config section) and
`decisions` (decisions section), so an env-var override was
silently ignored for half of the doctor.

Setup: an isolated project at `$tmpdir` with
`.math-coding/decisions/` holding one probe decision. Export
MATH_CODING_ROOT, MATH_CODING_POLICY,
MATH_CODING_DECISIONS_DIR, MATH_CODING_ATTESTATIONS_DIR and
`cd` into `$tmpdir` so the resolver's cwd-relative disk checks
(the same convention `tests/cli/env-var-resolver.t` uses) see
the probe tree.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ echo '(lang dune 3.0)' > "$tmpdir/dune-project"
  $ mkdir -p "$tmpdir/.math-coding/decisions" "$tmpdir/.math-coding/attestations"
  $ cat > "$tmpdir/.math-coding/decisions/doctor-env-probe-2026-11.yaml" <<'YAML'
  > schema: math-coding/3.3
  > id: doctor-env-probe-2026-11
  > revision: 1
  > state: active
  > mode: light
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent:
  >   source: path-resolver-audit-2026-11
  >   text: |
  >     Fixture for the doctor env-var cram test.
  > commitment: |
  >   One file, one obligation.
  > outcomes:
  >   - id: o1
  >     statement: |
  >       trivially true.
  > scope:
  >   paths:
  >     - "tests/cli/doctor-env-var.t"
  > obligations:
  >   - id: trivial-obligation
  >     claim: |
  >       validates under $INSIDE_DUNE/bin/mathc.exe validate with active state.
  >     acceptance:
  >       all:
  >         - verifier: tests/cli/doctor-env-var.t
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
  $ cd "$tmpdir"
  $ export MATH_CODING_ROOT="$tmpdir"
  $ export MATH_CODING_POLICY=".math-coding/policy.yaml"
  $ export MATH_CODING_DECISIONS_DIR=".math-coding/decisions"
  $ export MATH_CODING_ATTESTATIONS_DIR=".math-coding/attestations"

`mathc doctor --json` routes the config section's `path`
through the resolver: with MATH_CODING_POLICY set, the path is
`<root>/.math-coding/policy.yaml` (not the legacy
`decisions/decision.yaml`). The decisions section counts the
env-routed probe decision (total=1).

  $ $INSIDE_DUNE/bin/mathc.exe doctor --json | jq -c '[.sections[] | select(.id == "config") | (.details.path | endswith(".math-coding/policy.yaml"))], [.sections[] | select(.id == "decisions") | .details.total]'
  [true]
  [1]

Cleanup.

  $ cd /
  $ rm -rf "$tmpdir"
