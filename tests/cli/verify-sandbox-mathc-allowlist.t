mathc verify --sandbox=strict enforces the read-only mathc-scheme
allowlist (a1-strict-mathc-scheme-deny). A verifier string
`mathc <subcmd>` is only executed when <subcmd> is in the
allowlist (validate/assess/find/self-check/explain/
explain-diagnostic/context/packages/version). Write-capable
subcommands (`init`, `new-decision`, `import-adr`, `attest-batch`)
are reported `skipped`. In the default `none` mode the same
verifier is executed (and may `fail` or `pass` on its own merit).

Setup: a scratch decision whose obligations carry one
allowlisted verifier (`mathc version`) and one denied verifier
(`mathc init`). MATH_CODING_ROOT pins find_project_root to the
scratch dir so the denied `mathc init` never mutates the live
tree.

  $ tmp=$(mktemp -d)
  $ cat > "$tmp/scratch-verify.yaml" <<'YAML'
  > schema: math-coding/3.3
  > id: scratch-verify-sandbox-2026-11
  > revision: 1
  > state: active
  > mode: light
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent:
  >   source: verify-sandbox-hardening-2026-11
  >   text: |
  >     scratch decision for mathc-scheme allowlist coverage.
  > commitment: |
  >   One allowlisted verifier, one denied verifier.
  > outcomes:
  >   - id: o1
  >     statement: trivially true.
  > scope:
  >   paths:
  >     - "tests/cli/verify-sandbox-mathc-allowlist.t"
  > obligations:
  >   - id: allowlisted-version
  >     claim: $INSIDE_DUNE/bin/mathc.exe version runs in strict mode.
  >     acceptance:
  >       all:
  >         - verifier: $INSIDE_DUNE/bin/mathc.exe version
  >           result: pass
  >   - id: denied-init
  >     claim: $INSIDE_DUNE/bin/mathc.exe init is denied in strict mode.
  >     acceptance:
  >       all:
  >         - verifier: $INSIDE_DUNE/bin/mathc.exe init
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

strict mode: `mathc version` passes, `mathc init` is skipped.

  $ $INSIDE_DUNE/bin/mathc.exe verify --sandbox=strict scratch-verify.yaml 2>/dev/null | grep -E 'allowlisted-version|denied-init'
    allowlisted-version: pass
    denied-init: skipped

default (none) mode: `mathc init` is executed (and fails on its
own merit because it refuses to overwrite a live tree), not
skipped by the allowlist.

  $ $INSIDE_DUNE/bin/mathc.exe verify scratch-verify.yaml 2>/dev/null | grep 'denied-init'
    denied-init: fail

Cleanup.

  $ cd /
  $ rm -rf "$tmp"
