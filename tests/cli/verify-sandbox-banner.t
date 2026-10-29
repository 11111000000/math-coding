mathc verify --sandbox=strict emits a stderr notice naming the
deferred OS primitives (a1-strict-os-primitives-deferred). The
notice makes the deferral observable (axiom A1) rather than a
silent no-op: prctl/capset/RLIMIT application requires a C
foreign stub not present in this build (OCaml 5.5 removed
`Unix.setrlimit`; ctypes-foreign is absent from flake.nix).

The strict-mode child path is reached through a `mathc` scheme
verifier (the only scheme that forks a subprocess). On Linux the
notice names RLIMIT_NPROC=1; on non-Linux the same run emits the
Linux-only fallback warning instead. The test accepts either.

Setup: a scratch decision with a `mathc version` verifier so the
verify run forks the sandboxed child.

  $ tmp=$(mktemp -d)
  $ cat > "$tmp/scratch-verify.yaml" <<'YAML'
  > schema: math-coding/3.3
  > id: scratch-verify-banner-2026-11
  > revision: 1
  > state: active
  > mode: light
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent:
  >   source: verify-sandbox-hardening-2026-11
  >   text: |
  >     scratch decision for strict-mode notice coverage.
  > commitment: |
  >   One obligation; the verifier exercises the child path.
  > outcomes:
  >   - id: o1
  >     statement: trivially true.
  > scope:
  >   paths:
  >     - "tests/cli/verify-sandbox-banner.t"
  > obligations:
  >   - id: version-runs
  >     claim: $INSIDE_DUNE/bin/mathc.exe version runs in strict mode.
  >     acceptance:
  >       all:
  >         - verifier: $INSIDE_DUNE/bin/mathc.exe version
  >           result: pass
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

strict mode emits the RLIMIT banner (Linux) or the Linux-only
fallback warning (non-Linux); either is acceptable.

  $ if $INSIDE_DUNE/bin/mathc.exe verify --sandbox=strict scratch-verify.yaml 2>&1 | grep -qE 'RLIMIT_NPROC=1|Linux-only'; then
  >   echo "strict-mode-primitive-notice: ok"
  > else
  >   echo "strict-mode-primitive-notice: MISSING"
  > fi
  strict-mode-primitive-notice: ok

Cleanup.

  $ cd /
  $ rm -rf "$tmp"
