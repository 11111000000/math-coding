mathc repo-check with strict waiver-scope matching (T3.2, A3-protected):
a waiver named for `(decision, obligation) = (D, A)` lifts the
gate ONLY for that specific gap. A gap `(D, B)` of the same
decision remains Unknown even when the `(D, A)` waiver is in
effect. The fixture builds a temporary project root with one
decision `t3-2-test-decision` carrying two obligations
`alpha-obligation` and `beta-obligation`, no attestations
(every obligation surfaces as MissingEvidence, the waivable
gap kind), and waiver files under `decisions/waivers/` whose
`unverified_obligation` field is the literal obligation id
(T3.2 strict form, NOT the legacy global form).

The cram fixture exercises four scenarios on the same
decision: scenario 1 is positive (every gap has a named
waiver; verdict pass); scenario 2 is strict negative (only
the alpha waiver is present; beta remains Unknown; verdict
unknown); scenario 3 is global back-compat (a waiver whose
unverified_obligation is missing from the YAML still covers
every obligation of its decision; verdict pass); scenario 4 is
cross-decision negative (a waiver named for another decision
does NOT lift the gate; verdict unknown).

Acceptance gate for obligation `waiver-scope-narrow` in
`decisions/plan-2026-10-improvements/t3-2.yaml`.

  $ cd "$DUNE_SOURCEROOT"

Scenario 1 — positive (every gap has a named waiver):

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ echo '(lang dune 3.21)' > dune-project
  $ mkdir -p decisions/waivers attestations
  $ cat > decisions/t3-2-test-decision.yaml <<'YAML'
  > schema: math-coding/3.0-alpha
  > id: t3-2-test-decision
  > revision: 1
  > state: active
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent: |
  >   T3.2 cram fixture decision. Carries two obligations
  >   `alpha-obligation` and `beta-obligation`; each must be
  >   named by a strict waiver file for the gate to lift.
  > commitment: |
  >   Placeholder.
  > scope:
  >   capabilities:
  >     - waiver-scope-narrow-test
  > obligations:
  >   - id: alpha-obligation
  >     outcome: alpha-covered
  >     statement: alpha gap must be covered by waiver-alpha.
  >     claim: placeholder.
  >     acceptance: {}
  >   - id: beta-obligation
  >     outcome: beta-covered
  >     statement: beta gap must be covered by waiver-beta.
  >     claim: placeholder.
  >     acceptance: {}
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > YAML
  $ cat > decisions/waivers/strict-alpha.yaml <<'YAML'
  > schema: math-coding/waiver-3.0-alpha
  > kind: waiver
  > id: t3-2-strict-alpha
  > policy_id: t3-2-test-decision
  > rule: obligation-missing-attestation
  > subject: t3-2-test-decision
  > issuer: human:maintainer
  > issued_at: 2026-10-07T00:00:00Z
  > expires_at: 2027-10-07T00:00:00Z
  > reason: |
  >   T3.2 fixture: strict waiver for alpha-obligation only.
  > unverified_obligation: alpha-obligation
  > YAML
  $ cat > decisions/waivers/strict-beta.yaml <<'YAML'
  > schema: math-coding/waiver-3.0-alpha
  > kind: waiver
  > id: t3-2-strict-beta
  > policy_id: t3-2-test-decision
  > rule: obligation-missing-attestation
  > subject: t3-2-test-decision
  > issuer: human:maintainer
  > issued_at: 2026-10-07T00:00:00Z
  > expires_at: 2027-10-07T00:00:00Z
  > reason: |
  >   T3.2 fixture: strict waiver for beta-obligation only.
  > unverified_obligation: beta-obligation
  > YAML
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" mathc repo-check | jq -c '.subjects[] | select(.name == "t3-2-test-decision") | {name, verdict}'
  {"name":"t3-2-test-decision","verdict":"pass"}
  $ cd /
  $ rm -rf "$tmp"

Scenario 2 — strict negative (only alpha waiver; beta stays Unknown):

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ echo '(lang dune 3.21)' > dune-project
  $ mkdir -p decisions/waivers attestations
  $ cat > decisions/t3-2-test-decision.yaml <<'YAML'
  > schema: math-coding/3.0-alpha
  > id: t3-2-test-decision
  > revision: 1
  > state: active
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent: |
  >   T3.2 cram fixture decision. Carries two obligations
  >   `alpha-obligation` and `beta-obligation`; each must be
  >   named by a strict waiver file for the gate to lift.
  > commitment: |
  >   Placeholder.
  > scope:
  >   capabilities:
  >     - waiver-scope-narrow-test
  > obligations:
  >   - id: alpha-obligation
  >     outcome: alpha-covered
  >     statement: alpha gap must be covered by waiver-alpha.
  >     claim: placeholder.
  >     acceptance: {}
  >   - id: beta-obligation
  >     outcome: beta-covered
  >     statement: beta gap must be covered by waiver-beta.
  >     claim: placeholder.
  >     acceptance: {}
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > YAML
  $ cat > decisions/waivers/strict-alpha.yaml <<'YAML'
  > schema: math-coding/waiver-3.0-alpha
  > kind: waiver
  > id: t3-2-strict-alpha
  > policy_id: t3-2-test-decision
  > rule: obligation-missing-attestation
  > subject: t3-2-test-decision
  > issuer: human:maintainer
  > issued_at: 2026-10-07T00:00:00Z
  > expires_at: 2027-10-07T00:00:00Z
  > reason: |
  >   T3.2 fixture: strict waiver for alpha-obligation only.
  > unverified_obligation: alpha-obligation
  > YAML
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" mathc repo-check | jq -c '.subjects[] | select(.name == "t3-2-test-decision") | {name, verdict}'
  {"name":"t3-2-test-decision","verdict":"unknown"}
  $ cd /
  $ rm -rf "$tmp"

Scenario 3 — global back-compat (legacy waiver without unverified_obligation
covers every obligation of its decision):

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ echo '(lang dune 3.21)' > dune-project
  $ mkdir -p decisions/waivers attestations
  $ cat > decisions/t3-2-test-decision.yaml <<'YAML'
  > schema: math-coding/3.0-alpha
  > id: t3-2-test-decision
  > revision: 1
  > state: active
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent: |
  >   T3.2 cram fixture decision. Carries two obligations.
  > commitment: |
  >   Placeholder.
  > scope:
  >   capabilities:
  >     - waiver-scope-narrow-test
  > obligations:
  >   - id: alpha-obligation
  >     outcome: alpha-covered
  >     statement: alpha gap must be covered.
  >     claim: placeholder.
  >     acceptance: {}
  >   - id: beta-obligation
  >     outcome: beta-covered
  >     statement: beta gap must be covered.
  >     claim: placeholder.
  >     acceptance: {}
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > YAML
  $ cat > decisions/waivers/global.yaml <<'YAML'
  > schema: math-coding/waiver-3.0-alpha
  > kind: waiver
  > id: t3-2-global-waiver
  > policy_id: t3-2-test-decision
  > rule: obligation-missing-attestation
  > subject: t3-2-test-decision
  > issuer: human:maintainer
  > issued_at: 2026-10-07T00:00:00Z
  > expires_at: 2027-10-07T00:00:00Z
  > reason: |
  >   T3.2 fixture: legacy global waiver (no unverified_obligation
  >   field). Must cover every obligation of t3-2-test-decision.
  > YAML
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" mathc repo-check | jq -c '.subjects[] | select(.name == "t3-2-test-decision") | {name, verdict}'
  {"name":"t3-2-test-decision","verdict":"pass"}
  $ cd /
  $ rm -rf "$tmp"

Scenario 4 — cross-decision negative (waiver for OTHER decision does NOT lift
the gate for t3-2-test-decision):

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ echo '(lang dune 3.21)' > dune-project
  $ mkdir -p decisions/waivers attestations
  $ cat > decisions/t3-2-test-decision.yaml <<'YAML'
  > schema: math-coding/3.0-alpha
  > id: t3-2-test-decision
  > revision: 1
  > state: active
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent: |
  >   T3.2 cram fixture decision. Carries two obligations.
  > commitment: |
  >   Placeholder.
  > scope:
  >   capabilities:
  >     - waiver-scope-narrow-test
  > obligations:
  >   - id: alpha-obligation
  >     outcome: alpha-covered
  >     statement: alpha gap.
  >     claim: placeholder.
  >     acceptance: {}
  >   - id: beta-obligation
  >     outcome: beta-covered
  >     statement: beta gap.
  >     claim: placeholder.
  >     acceptance: {}
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > YAML
  $ cat > decisions/waivers/cross-decision.yaml <<'YAML'
  > schema: math-coding/waiver-3.0-alpha
  > kind: waiver
  > id: t3-2-cross-decision
  > policy_id: other-decision
  > rule: obligation-missing-attestation
  > subject: other-decision
  > issuer: human:maintainer
  > issued_at: 2026-10-07T00:00:00Z
  > expires_at: 2027-10-07T00:00:00Z
  > reason: |
  >   T3.2 fixture: waiver for OTHER decision must not lift the
  >   gate for t3-2-test-decision even when unverified_obligation
  >   names one of our obligations (decision boundary check).
  > unverified_obligation: alpha-obligation
  > YAML
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" mathc repo-check | jq -c '.subjects[] | select(.name == "t3-2-test-decision") | {name, verdict}'
  {"name":"t3-2-test-decision","verdict":"unknown"}
  $ cd /
  $ rm -rf "$tmp"
