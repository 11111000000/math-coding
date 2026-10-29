A waiver covers exactly what it declares.

`mathc self-check` consults the waiver store under
`decisions/waivers/`. Before this change the consultation matched a
waiver to a gap by subject and time only: the class the waiver
declares (`rule`), the scope it names, and even WHICH obligation it
accepts were not checked. A waiver that named no obligation
therefore accepted EVERY obligation of its decision -- 8 waivers,
37 gaps, one named gap each (measured on this repository).

constitution.md Invariant 11: "a waiver MUST apply only to its
named gap, scope, revisions, gate and validity interval", and
§Waivers: "A waiver ... MUST identify one gap". The four bounds a
waiver is now held to: the subject is the decision that owns the
gap; `unverified_obligation` names THIS obligation (a waiver that
names no gap covers nothing); the gap's class is the class the
waiver declares in `rule`; and the scope the waiver names stays
inside the scope of the decision that owns the gap.

The fixture builds a temporary project root with one decision
`waiver-scope-probe` carrying ONE obligation `probe-obligation`,
no attestations (the gap is therefore `MissingEvidence`, whose
class name is `obligation-missing-attestation`), and waiver files
under `decisions/waivers/`.

Acceptance gate for obligation `waiver-covers-what-it-declares` in
`decisions/exit-honesty-waivers-2026-10.yaml`.

  $ cd "$DUNE_SOURCEROOT"

Scenario 1 -- the waiver names the gap and declares its class: the
subject is open-with-waiver.

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ echo '(lang dune 3.21)' > dune-project
  $ mkdir -p decisions/waivers attestations
  $ cat > decisions/waiver-scope-probe.yaml <<'YAML'
  > schema: math-coding/3.3
  > id: waiver-scope-probe
  > revision: 1
  > state: active
  > mode: light
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent: |
  >   Fixture for the waiver scope contract.
  > commitment: |
  >   One obligation, covered or not by the waiver under test.
  > axiom_link:
  >   - A0
  > scope:
  >   paths:
  >     - "src/**"
  > outcomes:
  >   - id: probe-outcome
  >     statement: |
  >       The probe is a probe.
  > obligations:
  >   - id: probe-obligation
  >     claim: |
  >       A claim with no attestation.
  >     acceptance: {}
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
  $ $INSIDE_DUNE/bin/mathc.exe rehash decisions/waiver-scope-probe.yaml --write | tail -1
  rehash: 1 changed, 0 already current, 0 skipped (written)
  $ cat > decisions/waivers/probe.yaml <<'YAML'
  > schema: math-coding/waiver-3.3
  > kind: waiver
  > id: waiver-scope-probe-waiver
  > policy_id: bootstrap-v3
  > rule: obligation-missing-attestation
  > subject: waiver-scope-probe
  > issuer: human:maintainer
  > issued_at: 2026-10-07T00:00:00Z
  > expires_at: 2027-10-07T00:00:00Z
  > reason: |
  >   Fixture: names the gap and declares the class of that gap.
  > unverified_obligation: probe-obligation
  > YAML
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" $INSIDE_DUNE/bin/mathc.exe self-check | jq -c '.subjects[] | select(.name == "waiver-scope-probe") | {name, verdict}'
  {"name":"waiver-scope-probe","verdict":"open-with-waiver"}
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" bash -c 'mathc self-check > /dev/null; echo "exit=$?"'
  exit=0
  $ cd /
  $ rm -rf "$tmp"

Scenario 2 -- the same waiver with the WRONG declared class: the
gap is `MissingEvidence`, and a waiver that declares
`obligation-stale-attestation` did not declare that class, so it
covers nothing. The subject stays unknown (exit 3), and the
verdict is not `pass` either: an open-with-waiver verdict is the
only one a waiver can produce.

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ echo '(lang dune 3.21)' > dune-project
  $ mkdir -p decisions/waivers attestations
  $ cat > decisions/waiver-scope-probe.yaml <<'YAML'
  > schema: math-coding/3.3
  > id: waiver-scope-probe
  > revision: 1
  > state: active
  > mode: light
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent: |
  >   Fixture for the waiver scope contract.
  > commitment: |
  >   One obligation, covered or not by the waiver under test.
  > axiom_link:
  >   - A0
  > scope:
  >   paths:
  >     - "src/**"
  > outcomes:
  >   - id: probe-outcome
  >     statement: |
  >       The probe is a probe.
  > obligations:
  >   - id: probe-obligation
  >     claim: |
  >       A claim with no attestation.
  >     acceptance: {}
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
  $ $INSIDE_DUNE/bin/mathc.exe rehash decisions/waiver-scope-probe.yaml --write | tail -1
  rehash: 1 changed, 0 already current, 0 skipped (written)
  $ cat > decisions/waivers/probe.yaml <<'YAML'
  > schema: math-coding/waiver-3.3
  > kind: waiver
  > id: waiver-scope-probe-waiver
  > policy_id: bootstrap-v3
  > rule: obligation-stale-attestation
  > subject: waiver-scope-probe
  > issuer: human:maintainer
  > issued_at: 2026-10-07T00:00:00Z
  > expires_at: 2027-10-07T00:00:00Z
  > reason: |
  >   Fixture: names the gap but declares the class of a DIFFERENT gap.
  > unverified_obligation: probe-obligation
  > YAML
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" $INSIDE_DUNE/bin/mathc.exe self-check | jq -c '.subjects[] | select(.name == "waiver-scope-probe") | {name, verdict}'
  {"name":"waiver-scope-probe","verdict":"unknown"}
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" bash -c 'mathc self-check > /dev/null; echo "exit=$?"'
  exit=3
  $ cd /
  $ rm -rf "$tmp"

Scenario 3 -- a waiver that names NO gap (the legacy decision-wide
form) covers nothing: constitution.md §Waivers says a waiver MUST
identify one gap.

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ echo '(lang dune 3.21)' > dune-project
  $ mkdir -p decisions/waivers attestations
  $ cat > decisions/waiver-scope-probe.yaml <<'YAML'
  > schema: math-coding/3.3
  > id: waiver-scope-probe
  > revision: 1
  > state: active
  > mode: light
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent: |
  >   Fixture for the waiver scope contract.
  > commitment: |
  >   One obligation, covered or not by the waiver under test.
  > axiom_link:
  >   - A0
  > scope:
  >   paths:
  >     - "src/**"
  > outcomes:
  >   - id: probe-outcome
  >     statement: |
  >       The probe is a probe.
  > obligations:
  >   - id: probe-obligation
  >     claim: |
  >       A claim with no attestation.
  >     acceptance: {}
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
  $ $INSIDE_DUNE/bin/mathc.exe rehash decisions/waiver-scope-probe.yaml --write | tail -1
  rehash: 1 changed, 0 already current, 0 skipped (written)
  $ cat > decisions/waivers/probe.yaml <<'YAML'
  > schema: math-coding/waiver-3.3
  > kind: waiver
  > id: waiver-scope-probe-waiver
  > policy_id: bootstrap-v3
  > rule: obligation-missing-attestation
  > subject: waiver-scope-probe
  > issuer: human:maintainer
  > issued_at: 2026-10-07T00:00:00Z
  > expires_at: 2027-10-07T00:00:00Z
  > reason: |
  >   Fixture: the legacy decision-wide form, which names no gap.
  > YAML
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" $INSIDE_DUNE/bin/mathc.exe self-check | jq -c '.subjects[] | select(.name == "waiver-scope-probe") | {name, verdict}'
  {"name":"waiver-scope-probe","verdict":"unknown"}
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" bash -c 'mathc self-check > /dev/null; echo "exit=$?"'
  exit=3
  $ cd /
  $ rm -rf "$tmp"

Scenario 4 -- a waiver whose scope names a path OUTSIDE the scope of
the decision that owns the gap covers nothing.

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ echo '(lang dune 3.21)' > dune-project
  $ mkdir -p decisions/waivers attestations
  $ cat > decisions/waiver-scope-probe.yaml <<'YAML'
  > schema: math-coding/3.3
  > id: waiver-scope-probe
  > revision: 1
  > state: active
  > mode: light
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent: |
  >   Fixture for the waiver scope contract.
  > commitment: |
  >   One obligation, covered or not by the waiver under test.
  > axiom_link:
  >   - A0
  > scope:
  >   paths:
  >     - "src/**"
  > outcomes:
  >   - id: probe-outcome
  >     statement: |
  >       The probe is a probe.
  > obligations:
  >   - id: probe-obligation
  >     claim: |
  >       A claim with no attestation.
  >     acceptance: {}
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
  $ $INSIDE_DUNE/bin/mathc.exe rehash decisions/waiver-scope-probe.yaml --write | tail -1
  rehash: 1 changed, 0 already current, 0 skipped (written)
  $ cat > decisions/waivers/probe.yaml <<'YAML'
  > schema: math-coding/waiver-3.3
  > kind: waiver
  > id: waiver-scope-probe-waiver
  > policy_id: bootstrap-v3
  > rule: obligation-missing-attestation
  > subject: waiver-scope-probe
  > issuer: human:maintainer
  > issued_at: 2026-10-07T00:00:00Z
  > expires_at: 2027-10-07T00:00:00Z
  > reason: |
  >   Fixture: names the gap, but claims a path the decision does not
  >   govern.
  > unverified_obligation: probe-obligation
  > scope:
  >   - kind: path
  >     path: "other/file.txt"
  >     match: exact
  > YAML
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" $INSIDE_DUNE/bin/mathc.exe self-check | jq -c '.subjects[] | select(.name == "waiver-scope-probe") | {name, verdict}'
  {"name":"waiver-scope-probe","verdict":"unknown"}
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" bash -c 'mathc self-check > /dev/null; echo "exit=$?"'
  exit=3
  $ cd /
  $ rm -rf "$tmp"

Scenario 5 -- a waiver whose scope names a path INSIDE the scope of
the decision still covers the gap: the scope check bounds the
waiver, it does not void it.

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ echo '(lang dune 3.21)' > dune-project
  $ mkdir -p decisions/waivers attestations
  $ cat > decisions/waiver-scope-probe.yaml <<'YAML'
  > schema: math-coding/3.3
  > id: waiver-scope-probe
  > revision: 1
  > state: active
  > mode: light
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent: |
  >   Fixture for the waiver scope contract.
  > commitment: |
  >   One obligation, covered or not by the waiver under test.
  > axiom_link:
  >   - A0
  > scope:
  >   paths:
  >     - "src/**"
  > outcomes:
  >   - id: probe-outcome
  >     statement: |
  >       The probe is a probe.
  > obligations:
  >   - id: probe-obligation
  >     claim: |
  >       A claim with no attestation.
  >     acceptance: {}
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
  $ $INSIDE_DUNE/bin/mathc.exe rehash decisions/waiver-scope-probe.yaml --write | tail -1
  rehash: 1 changed, 0 already current, 0 skipped (written)
  $ cat > decisions/waivers/probe.yaml <<'YAML'
  > schema: math-coding/waiver-3.3
  > kind: waiver
  > id: waiver-scope-probe-waiver
  > policy_id: bootstrap-v3
  > rule: obligation-missing-attestation
  > subject: waiver-scope-probe
  > issuer: human:maintainer
  > issued_at: 2026-10-07T00:00:00Z
  > expires_at: 2027-10-07T00:00:00Z
  > reason: |
  >   Fixture: names the gap and a path the decision governs.
  > unverified_obligation: probe-obligation
  > scope:
  >   - kind: path
  >     path: "src/probe.txt"
  >     match: exact
  > YAML
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" $INSIDE_DUNE/bin/mathc.exe self-check | jq -c '.subjects[] | select(.name == "waiver-scope-probe") | {name, verdict}'
  {"name":"waiver-scope-probe","verdict":"open-with-waiver"}
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" bash -c 'mathc self-check > /dev/null; echo "exit=$?"'
  exit=0
  $ cd /
  $ rm -rf "$tmp"

Scenario 6 -- a waiver that names ANOTHER obligation of the same
decision does not cover this one. One gap per waiver: the waiver
names `other-obligation`, the gap is `probe-obligation`.

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ echo '(lang dune 3.21)' > dune-project
  $ mkdir -p decisions/waivers attestations
  $ cat > decisions/waiver-scope-probe.yaml <<'YAML'
  > schema: math-coding/3.3
  > id: waiver-scope-probe
  > revision: 1
  > state: active
  > mode: light
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent: |
  >   Fixture for the waiver scope contract.
  > commitment: |
  >   Two obligations; the waiver names the second one.
  > axiom_link:
  >   - A0
  > scope:
  >   paths:
  >     - "src/**"
  > outcomes:
  >   - id: probe-outcome
  >     statement: |
  >       The probe is a probe.
  > obligations:
  >   - id: probe-obligation
  >     claim: |
  >       A claim with no attestation.
  >     acceptance: {}
  >   - id: other-obligation
  >     claim: |
  >       Another claim with no attestation.
  >     acceptance: {}
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
  $ $INSIDE_DUNE/bin/mathc.exe rehash decisions/waiver-scope-probe.yaml --write | tail -1
  rehash: 1 changed, 0 already current, 0 skipped (written)
  $ cat > decisions/waivers/probe.yaml <<'YAML'
  > schema: math-coding/waiver-3.3
  > kind: waiver
  > id: waiver-scope-probe-waiver
  > policy_id: bootstrap-v3
  > rule: obligation-missing-attestation
  > subject: waiver-scope-probe
  > issuer: human:maintainer
  > issued_at: 2026-10-07T00:00:00Z
  > expires_at: 2027-10-07T00:00:00Z
  > reason: |
  >   Fixture: names the SECOND obligation of the decision, so the
  >   first one stays uncovered and the verdict stays unknown.
  > unverified_obligation: other-obligation
  > YAML
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" $INSIDE_DUNE/bin/mathc.exe self-check | jq -c '.subjects[] | select(.name == "waiver-scope-probe") | {name, verdict}'
  {"name":"waiver-scope-probe","verdict":"unknown"}
  $ cd /
  $ rm -rf "$tmp"
