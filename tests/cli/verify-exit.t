`mathc verify` exits 0 only when it actually verified something.

The exit code of a verdict-producing subcommand is the last place
where the difference between "the check passed" and "the check did
not run" can still be lost, and `mathc verify` lost it: `skipped`,
`setup-fail`, `timeout` and `declared` are all "the check did not
happen", and the command exited 0 when every obligation landed on
one of them. spec/semantics.md §Kernel Output ("Verdict to exit
code") and constitution.md Invariant 14b ("exit code 0 MUST imply
verdict `Pass` or `Open_with_waiver`") both say that an
unevaluated claim is `unknown`, and `unknown` is exit 3.

Measured before the fix, on this repository: `mathc verify` on a
real decision printed seven `skipped` verdicts and exited 0.

The three exit codes, from the verdict table: `0` is `Pass` (at
least one obligation was actually fulfilled), `1` is `Block` (an
obligation failed decisively) and `3` is `Unknown` (nothing was
verified -- all obligations landed on skipped / setup-fail /
timeout / declared).

Acceptance gate for obligation `verify-exit-is-honest` in
`decisions/exit-honesty-waivers-2026-10.yaml`.

  $ cd "$DUNE_SOURCEROOT"

Scenario 1 -- every obligation skipped: exit 3 (not 0).

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ echo '(lang dune 3.21)' > dune-project
  $ cat > probe.yaml <<'YAML'
  > schema: math-coding/3.3
  > id: verify-exit-probe
  > revision: 1
  > state: active
  > mode: light
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent: |
  >   Probe for the verify exit code.
  > commitment: |
  >   One obligation whose verifier this command cannot execute.
  > axiom_link:
  >   - A0
  > scope:
  >   paths:
  >     - "probe.txt"
  > outcomes:
  >   - id: probe-outcome
  >     statement: |
  >       The probe is a probe.
  > obligations:
  >   - id: skipped-obligation
  >     claim: |
  >       A claim no verifier here can check.
  >     acceptance:
  >       all:
  >         - verifier: manual-review-of-existing-source
  >           result: pass
  > counterexample: |
  >   None; synthetic fixture.
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > relations:
  >   addresses: []
  >   supersedes: []
  >   superseded_by: []
  > YAML
  $ mathc verify probe.yaml
  verify: probe.yaml
    skipped-obligation: skipped
  [3]
  $ cd /
  $ rm -rf "$tmp"

Scenario 2 -- an obligation that fails decisively: exit 1.

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ echo '(lang dune 3.21)' > dune-project
  $ cat > probe.yaml <<'YAML'
  > schema: math-coding/3.3
  > id: verify-exit-probe
  > revision: 1
  > state: active
  > mode: light
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent: |
  >   Probe for the verify exit code.
  > commitment: |
  >   One obligation whose verifier fails.
  > axiom_link:
  >   - A0
  > scope:
  >   paths:
  >     - "probe.txt"
  > outcomes:
  >   - id: probe-outcome
  >     statement: |
  >       The probe is a probe.
  > obligations:
  >   - id: failing-obligation
  >     claim: |
  >       A claim the verifier refutes.
  >     acceptance:
  >       all:
  >         - verifier: file-exists no-such-file.txt
  >           result: pass
  > counterexample: |
  >   None; synthetic fixture.
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > relations:
  >   addresses: []
  >   supersedes: []
  >   superseded_by: []
  > YAML
  $ mathc verify probe.yaml
  verify: probe.yaml
    failing-obligation: fail
  [1]
  $ cd /
  $ rm -rf "$tmp"

Scenario 3 -- every obligation fulfilled: exit 0.

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ echo '(lang dune 3.21)' > dune-project
  $ echo present > probe.txt
  $ cat > probe.yaml <<'YAML'
  > schema: math-coding/3.3
  > id: verify-exit-probe
  > revision: 1
  > state: active
  > mode: light
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent: |
  >   Probe for the verify exit code.
  > commitment: |
  >   One obligation whose verifier passes.
  > axiom_link:
  >   - A0
  > scope:
  >   paths:
  >     - "probe.txt"
  > outcomes:
  >   - id: probe-outcome
  >     statement: |
  >       The probe is a probe.
  > obligations:
  >   - id: passing-obligation
  >     claim: |
  >       A claim the verifier confirms.
  >     acceptance:
  >       all:
  >         - verifier: file-exists probe.txt
  >           result: pass
  > counterexample: |
  >   None; synthetic fixture.
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > relations:
  >   addresses: []
  >   supersedes: []
  >   superseded_by: []
  > YAML
  $ mathc verify probe.yaml
  verify: probe.yaml
    passing-obligation: pass
  $ cd /
  $ rm -rf "$tmp"

Scenario 4 -- one obligation fulfilled and one skipped: exit 0.
The command verified SOMETHING, so it is not the "nothing was
verified" case; the skipped obligation is visible in the output, and
the per-obligation verdict stays the per-obligation verdict.

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ echo '(lang dune 3.21)' > dune-project
  $ echo present > probe.txt
  $ cat > probe.yaml <<'YAML'
  > schema: math-coding/3.3
  > id: verify-exit-probe
  > revision: 1
  > state: active
  > mode: light
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent: |
  >   Probe for the verify exit code.
  > commitment: |
  >   One fulfilled obligation and one skipped one.
  > axiom_link:
  >   - A0
  > scope:
  >   paths:
  >     - "probe.txt"
  > outcomes:
  >   - id: probe-outcome
  >     statement: |
  >       The probe is a probe.
  > obligations:
  >   - id: passing-obligation
  >     claim: |
  >       A claim the verifier confirms.
  >     acceptance:
  >       all:
  >         - verifier: file-exists probe.txt
  >           result: pass
  >   - id: skipped-obligation
  >     claim: |
  >       A claim no verifier here can check.
  >     acceptance:
  >       all:
  >         - verifier: manual-review-of-existing-source
  >           result: pass
  > counterexample: |
  >   None; synthetic fixture.
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > relations:
  >   addresses: []
  >   supersedes: []
  >   superseded_by: []
  > YAML
  $ mathc verify probe.yaml
  verify: probe.yaml
    passing-obligation: pass
    skipped-obligation: skipped
  $ cd /
  $ rm -rf "$tmp"

Scenario 5 -- the JSON shape carries the same per-obligation
verdicts, and the exit code is the same.

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ echo '(lang dune 3.21)' > dune-project
  $ cat > probe.yaml <<'YAML'
  > schema: math-coding/3.3
  > id: verify-exit-probe
  > revision: 1
  > state: active
  > mode: light
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent: |
  >   Probe for the verify exit code.
  > commitment: |
  >   One obligation whose verifier this command cannot execute.
  > axiom_link:
  >   - A0
  > scope:
  >   paths:
  >     - "probe.txt"
  > outcomes:
  >   - id: probe-outcome
  >     statement: |
  >       The probe is a probe.
  > obligations:
  >   - id: skipped-obligation
  >     claim: |
  >       A claim no verifier here can check.
  >     acceptance:
  >       all:
  >         - verifier: manual-review-of-existing-source
  >           result: pass
  > counterexample: |
  >   None; synthetic fixture.
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > relations:
  >   addresses: []
  >   supersedes: []
  >   superseded_by: []
  > YAML
  $ mathc verify probe.yaml --format=json
  {"path":"probe.yaml","verdicts":[{"obligation_id":"skipped-obligation","verdict":"skipped"}]}
  [3]
  $ cd /
  $ rm -rf "$tmp"
