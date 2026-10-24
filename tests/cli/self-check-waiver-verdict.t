`mathc self-check` must never report a subject as `pass` while that
subject carries unmet obligations, and a waiver must be a NAMED
condition in the output rather than a silent green tick.

The defect: `verdict_to_pass_fail_unknown` in bin/Mathc.ml mapped
`Gate.Open_with_waiver` to the string `pass`, so a subject whose
obligations are all covered by a waiver was printed with
`"verdict":"pass"` next to a `causes[]` array enumerating those
same unmet obligations — the verdict contradicting its own
evidence. On this repository that was 7 subjects at the time of
writing. constitution.md Invariant 10 requires `waived` and
`passed` to remain distinguishable; spec/semantics.md §Merge Gate
says "A merge with a Waiver MUST report `open-with-waiver`, never
`pass`"; AGENTS.md §Friction says "A waiver is not Pass".

Scenario 1 builds a synthetic project with ONE decision, TWO
obligations, no attestations, and one decision-wide waiver. Both
gaps are waivable and both are covered, so the subject verdict is
`open-with-waiver` and the repository verdict is `open-with-waiver`
too — the aggregate of a wholly-waived corpus is not `pass`.
Exit code 0 is preserved: constitution.md Invariant 14b allows
exit 0 for `Open_with_waiver`, and 14c requires the output to
reference the waiver, which the `waivers[]` entry does (id,
issuer, issued_at, expires_at, and the obligations it covers).

Scenario 2 runs the live self-check and asserts the coherence
PROPERTY rather than a count, so it does not rot as decisions and
waivers come and go: no `pass` subject carries a cause or a
remedy; every `open-with-waiver` subject names at least one
unexpired waiver covering at least one obligation; no `pass`
subject names a waiver at all. Acceptance gate for obligations
`waived-verdict-is-not-pass` and `waiver-is-named-in-output` in
`decisions/self-check-waiver-verdict-coherence-2026-10.yaml`.

Scenario 1 stamps its synthetic decision with `mathc rehash
--write` first. `self-check` recomputes the digest of each
decision's own bytes and forces `fail` for a stale one, which would
otherwise override the verdict under test: the subject would report
`fail` with an extra cause and an extra remedy, and the coherence
properties below would pass for the wrong reason. The digest is
incidental to what this fixture tests, so the fixture makes it real
rather than weakening the verdict assertions. See
`self-check-digest-stale.t` for the digest rule itself.

  $ cd "$DUNE_SOURCEROOT"

Scenario 1 — wholly-waived subject reports open-with-waiver, names its
waiver, and exits 0:

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ echo '(lang dune 3.21)' > dune-project
  $ mkdir -p decisions/waivers attestations
  $ cat > decisions/waived.yaml <<'YAML'
  > schema: math-coding/3.0-alpha
  > id: waived
  > revision: 1
  > state: active
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent: |
  >   Self-check waiver-verdict fixture: two obligations, no
  >   attestations, one decision-wide waiver.
  > commitment: |
  >   Placeholder.
  > scope:
  >   capabilities:
  >     - waiver-verdict-coherence-test
  > obligations:
  >   - id: alpha-obligation
  >     outcome: alpha-covered
  >     statement: alpha gap must be covered by the waiver.
  >     claim: placeholder.
  >     acceptance: {}
  >   - id: beta-obligation
  >     outcome: beta-covered
  >     statement: beta gap must be covered by the waiver.
  >     claim: placeholder.
  >     acceptance: {}
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > YAML
  $ mathc rehash decisions/waived.yaml --write | tail -1
  rehash: 1 changed, 0 already current, 0 skipped (written)
  $ cat > decisions/waivers/w.yaml <<'YAML'
  > schema: math-coding/waiver-3.0-alpha
  > kind: waiver
  > id: fixture-waiver
  > policy_id: waived
  > rule: obligation-missing-attestation
  > subject: waived
  > issuer: human:maintainer
  > issued_at: 2026-10-07T00:00:00Z
  > expires_at: 2027-10-07T00:00:00Z
  > reason: |
  >   Fixture waiver covering every obligation of `waived`.
  > YAML
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" mathc self-check > /tmp/sc-waived.json; echo "exit=$?"
  exit=0
  $ jq -c '{verdict, subject: (.subjects[0] | {name, verdict, causes: (.causes | length), remedies: (.remedies | length), waivers})}' /tmp/sc-waived.json
  {"verdict":"open-with-waiver","subject":{"name":"waived","verdict":"open-with-waiver","causes":2,"remedies":4,"waivers":[{"covers":["alpha-obligation","beta-obligation"],"expires_at":"2027-10-07T00:00:00Z","id":"fixture-waiver","issued_at":"2026-10-07T00:00:00Z","issuer":"human:maintainer","scope":"decision"}]}}
  $ jq -e '[.subjects[] | select(.verdict == "pass" and ((.causes | length) > 0 or (.remedies | length) > 0))] | length == 0' /tmp/sc-waived.json > /dev/null && echo "no pass carries a cause"
  no pass carries a cause
  $ cd /
  $ rm -rf "$tmp"

Scenario 2 — live self-check: no pass subject carries a cause, and every
open-with-waiver subject names an unexpired waiver:

  $ cd "$DUNE_SOURCEROOT"
  $ cat > coherence.jq <<'JQ'
  > .now as $n
  > | {
  >   pass_with_causes: ([.subjects[] | select(.verdict == "pass") | select((.causes | length) > 0 or (.remedies | length) > 0)] | length),
  >   pass_naming_a_waiver: ([.subjects[] | select(.verdict == "pass") | select((.waivers | length) > 0)] | length),
  >   waived_without_unexpired_waiver: ([.subjects[] | select(.verdict == "open-with-waiver") | select((.waivers | length) == 0 or ([.waivers[] | select(.expires_at <= $n or (.covers | length) == 0)] | length) > 0)] | length),
  >   waived_subjects: ([.subjects[] | select(.verdict == "open-with-waiver")] | length)
  > }
  > JQ
  $ mathc self-check | jq -c -f coherence.jq
  {"pass_with_causes":0,"pass_naming_a_waiver":0,"waived_without_unexpired_waiver":0,"waived_subjects":0}
  $ rm -f coherence.jq
