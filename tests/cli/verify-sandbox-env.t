MATH_CODING_VERIFY_SANDBOX controls the default sandbox mode for
`mathc verify` (a1-env-var-resolver). `resolve_sandbox_mode ()`
in lib/path_config.ml returns one of none|minimal|strict, and
unknown env values are coerced to `none` with a one-line stderr
warning. The `--sandbox` flag overrides the env var.

Setup: a scratch decision with one mathc-scheme verifier
(`mathc version`) and one write-capable verifier (`mathc init`),
so the allowlist effect is observable. MATH_CODING_ROOT pins
find_project_root.

  $ tmp=$(mktemp -d)
  $ cat > "$tmp/scratch-verify.yaml" <<'YAML'
  > schema: math-coding/3.3
  > id: scratch-verify-env-2026-11
  > revision: 1
  > state: active
  > mode: light
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent:
  >   source: verify-sandbox-hardening-2026-11
  >   text: |
  >     scratch decision for sandbox env-var coverage.
  > commitment: |
  >   One allowlisted, one denied verifier.
  > outcomes:
  >   - id: o1
  >     statement: trivially true.
  > scope:
  >   paths:
  >     - "tests/cli/verify-sandbox-env.t"
  > obligations:
  >   - id: version-runs
  >     claim: mathc version runs.
  >     acceptance:
  >       all:
  >         - verifier: mathc version
  >   - id: init-denied
  >     claim: mathc init is denied under strict.
  >     acceptance:
  >       all:
  >         - verifier: mathc init
  > axiom_link:
  >   - A0
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > relations:
  >   addresses:
  >     - bootstrap-v3@3
  > counterexample: |
  >   None — synthetic.
  > YAML
  $ export MATH_CODING_ROOT="$tmp"
  $ cd "$tmp"

env var strict drives the same allowlist behaviour as the flag.

  $ MATH_CODING_VERIFY_SANDBOX=strict $INSIDE_DUNE/bin/mathc.exe verify scratch-verify.yaml 2>/dev/null | grep 'init-denied'
    init-denied: skipped

unknown env value coerces to none with a stderr warning; the
denied verifier is then executed (fail), not skipped.

  $ MATH_CODING_VERIFY_SANDBOX=bogus $INSIDE_DUNE/bin/mathc.exe verify scratch-verify.yaml 2>/dev/null | grep 'init-denied'
    init-denied: fail

explicit --sandbox flag overrides the env var.

  $ MATH_CODING_VERIFY_SANDBOX=none $INSIDE_DUNE/bin/mathc.exe verify --sandbox=strict scratch-verify.yaml 2>/dev/null | grep 'init-denied'
    init-denied: skipped

Cleanup.

  $ cd /
  $ rm -rf "$tmp"
