`mathc self-check` must stop honouring a waiver the moment its term
is over, and must not report the subject it was covering as
`open-with-waiver` after that.

constitution.md §Waivers: a waiver "MUST NOT outlive its expiry".
Invariant 14c: an `Open_with_waiver` verdict that exits 0 "MUST
reference a waiver whose `expires_at` is strictly greater than the
evaluation time".

These two fixtures pin the CLI end of that rule for the case the
pure unit tests cannot reach: a waiver evaluated by the real
binary, through `Waiver.load` and `aggregate_with_waivers`, at the
real wall clock.

Scenario 1 is the lapse: a waiver whose `expires_at` is in the
past covers nothing. The subject reports `unknown` (exit 3), its
`waivers[]` array is EMPTY — the verdict names no relief — and its
`causes[]` still lists the unmet obligation. `open-with-waiver`
here would be a green verdict held by an expired waiver, which is
exactly what 14c forbids.

Scenario 2 is the control: byte-identical project, live waiver. It
must still report `open-with-waiver` with a named waiver and exit
0. Without it, scenario 1 would also pass on a binary that never
consults a waiver at all.

Both scenarios stamp the synthetic decision with `mathc rehash
--write` before running `self-check`. `self-check` recomputes
each decision's own bytes and forces `fail` for a stale one, and
that `fail` would override the verdict under test: both scenarios
would report `fail` with an extra cause, scenario 2 would stop
being a control, and the lapse assertions would hold for the wrong
reason. The digest is incidental to waiver expiry, so the fixture
makes it real rather than weakening the verdict assertions. See
`self-check-digest-stale.t` for the digest rule itself.

The exact-second boundary (`now == expires_at`, and `now ==
expires_at + 1s`) is NOT exercised here: `bin/Mathc.ml:now_iso`
reads the wall clock and does not honour `MATH_CODING_FIXED_TIME`,
so a cram fixture cannot place the evaluation time on a chosen
instant. That second is pinned by `tests/waiver_test.ml` and
`tests/gate/waiver_aggregation.ml`, which own the pure predicate.

  $ cd "$DUNE_SOURCEROOT"

Scenario 1 — a waiver past its `expires_at` covers nothing:

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ echo '(lang dune 3.21)' > dune-project
  $ mkdir -p decisions/waivers attestations
  $ cat > decisions/lapsed.yaml <<'YAML'
  > schema: math-coding/3.0-alpha
  > id: lapsed
  > revision: 1
  > state: active
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent: |
  >   Self-check waiver-expiry fixture: one obligation, no
  >   attestations, one waiver whose term is over.
  > commitment: |
  >   Placeholder.
  > scope:
  >   capabilities:
  >     - waiver-expiry-boundary-test
  > obligations:
  >   - id: alpha-obligation
  >     outcome: alpha-covered
  >     statement: alpha gap must be covered by a live waiver.
  >     claim: placeholder.
  >     acceptance: {}
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > YAML
  $ mathc rehash decisions/lapsed.yaml --write | tail -1
  rehash: 1 changed, 0 already current, 0 skipped (written)
  $ cat > decisions/waivers/lapsed.yaml <<'YAML'
  > schema: math-coding/waiver-3.0-alpha
  > kind: waiver
  > id: lapsed-waiver
  > policy_id: lapsed
  > rule: obligation-missing-attestation
  > subject: lapsed
  > issuer: human:maintainer
  > issued_at: 2026-10-07T00:00:00Z
  > expires_at: 2026-10-08T00:00:00Z
  > reason: |
  >   Fixture waiver whose 24h term is over.
  > YAML
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" mathc self-check > /tmp/sc-lapsed.json; echo "exit=$?"
  exit=3
  $ jq -c '{verdict, subject: (.subjects[0] | {name, verdict, causes, waivers})}' /tmp/sc-lapsed.json
  {"verdict":"unknown","subject":{"name":"lapsed","verdict":"unknown","causes":["obligation alpha-obligation of decision lapsed has no attestations in the store"],"waivers":[]}}
  $ jq -e '.now > "2026-10-08T00:00:00Z"' /tmp/sc-lapsed.json > /dev/null && echo "the evaluation time is past the waiver's expiry"
  the evaluation time is past the waiver's expiry
  $ jq -e '[.subjects[] | select(.verdict == "open-with-waiver")] | length == 0' /tmp/sc-lapsed.json > /dev/null && echo "no subject claims relief from a lapsed waiver"
  no subject claims relief from a lapsed waiver
  $ jq -e '[.subjects[] | select(.verdict != "pass" and (.waivers | length) > 0)] | length == 0' /tmp/sc-lapsed.json > /dev/null && echo "no verdict names a lapsed waiver"
  no verdict names a lapsed waiver
  $ cd /

Scenario 2 — control: the same project with a live waiver is
`open-with-waiver` and exits 0:

  $ cd "$tmp"
  $ cat > decisions/waivers/lapsed.yaml <<'YAML'
  > schema: math-coding/waiver-3.0-alpha
  > kind: waiver
  > id: live-waiver
  > policy_id: lapsed
  > rule: obligation-missing-attestation
  > subject: lapsed
  > issuer: human:maintainer
  > issued_at: 2026-10-07T00:00:00Z
  > expires_at: 2027-10-07T00:00:00Z
  > reason: |
  >   Fixture waiver still inside its term.
  > YAML
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" mathc self-check > /tmp/sc-live.json; echo "exit=$?"
  exit=0
  $ jq -c '{verdict, subject: (.subjects[0] | {name, verdict, waivers: [.waivers[] | {id, expires_at, covers}]})}' /tmp/sc-live.json
  {"verdict":"open-with-waiver","subject":{"name":"lapsed","verdict":"open-with-waiver","waivers":[{"id":"live-waiver","expires_at":"2027-10-07T00:00:00Z","covers":["alpha-obligation"]}]}}
  $ jq -e '[.subjects[] | select(.verdict == "open-with-waiver" and (.waivers | length) == 0)] | length == 0' /tmp/sc-live.json > /dev/null && echo "every open-with-waiver names its waiver (Invariant 14c)"
  every open-with-waiver names its waiver (Invariant 14c)
  $ cd /
  $ rm -rf "$tmp"
