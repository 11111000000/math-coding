---
schema: math-coding/3.0-alpha
id: parse-acceptance-diagnostics
revision: 1

intent: |
  Close OCAML_BEST_PRACTICES §9.1: when an obligation's acceptance
  item carries both `verifier` and `review` fields on the same
  object, the kernel MUST classify the ambiguity rather than
  silently dropping the review half. This decision introduces
  shape classification and the matching diagnostic codes so the
  author can disambiguate instead of wondering why their review
  is ignored.

commitment: |
  Decision.classify_acceptance_item : Jsonl.value -> acceptance_shape
  returns one of ShapeVerifier | ShapeReview | ShapeAmbiguous |
  ShapeMalformed | ShapeEmpty. Decision.parse_acceptance_with_shapes
  returns both the typed Domain.acceptance and the per-item shape
  list. Diagnostic.ambiguous_acceptance and Diagnostic.malformed_acceptance
  emit MC-AMBIGUOUS-ACCEPTANCE and MC-MALFORMED-ACCEPTANCE on the
  bin/Mathc.ml side. mc validate prints the diagnostics to stderr
  AND embeds them in JSON output under 'diagnostics':[…]. The
  verdict remains 'accept' on the verifier half; the diagnostic is
  a side-channel that does NOT lie about pass-attestation.

scope:
  paths:
    - "lib/decision.ml"
    - "lib/diagnostic.ml"
    - "bin/Mathc.ml"
    - "OCAML_BEST_PRACTICES.md"
    - "fixtures/conformance/decision/positive-ambiguous-acceptance.json"
    - "fixtures/conformance/decision/positive-malformed-acceptance.json"
    - "tests/fixtures/ambiguous-acceptance.sh"
    - "tests/fixtures/malformed-acceptance.sh"
    - "bootstrap/parse-acceptance-diagnostics.md"
  exclusions:
    - "lib/capsule.ml"
    - "lib/codec.ml"
    - "spec/**"
    - "schemas/**"

outcomes:
  - id: kernel-shape-classifier
    statement: |
      Decision.classify_acceptance_item is exported from lib/decision.ml
      and returns one of five acceptance_shape variants. Tests in
      tests/conformance.ml can call it directly; tests/fixtures/
      *.sh exercise it via mc validate.
  - id: diagnostic-emission
    statement: |
      mc validate FILE prints MC-AMBIGUOUS-ACCEPTANCE per obligation
      with ShapeAmbiguous items, and MC-MALFORMED-ACCEPTANCE per
      obligation with ShapeMalformed items. Diagnostics appear on
      stderr AND in the JSON output under 'diagnostics':[…].

countercase: |
  "WARN diagnostics on accept-verdict erode the gap between
  Pass and Open-with-waiver (A2 invariant 10)." Counterargument:
  the verdict remains 'accept' on the verifier half; the diagnostic
  is a side-channel that surfaces silent-drop without claiming
  attestation-pass. A future revision under a stricter policy may
  upgrade WARN to BLOCK at merge time; today's WARN matches the
  bootstrap reality where the attestation store does not yet exist.

assumptions:
  - id: shape-classifier-pure
    state: assumed
    statement: |
      classify_acceptance_item is a pure function over the JSON
      object — no I/O, no Schema string lookup beyond what the
      parser already does. The kernel stays offline.
    owner: human:maintainer
    consequence_if_false: |
      Tests would need fixture-side JSON-loading; for now they
      rely on Decision.parse_decision to populate Domain.decision
      and Decision.parse_acceptance_with_shapes to return shapes.
    review_on:
      - signal: kernel-touches-disk

obligations:
  - id: parse-acceptance-shape-classification
    outcome: kernel-shape-classifier
    claim: |
      Decision.classify_acceptance_item distinguishes five shapes:
      ShapeVerifier (only verifier+result), ShapeReview (only
      review), ShapeAmbiguous (both), ShapeMalformed (one shape
      present but unparseable), ShapeEmpty (neither).
    acceptance:
      all:
        - verifier: tests/conformance.ml positive-ambiguous-acceptance
          result: pass
        - verifier: tests/conformance.ml positive-malformed-acceptance
          result: pass
  - id: diagnostic-emission-cli
    outcome: diagnostic-emission
    claim: |
      mc validate emits MC-AMBIGUOUS-ACCEPTANCE and
      MC-MALFORMED-ACCEPTANCE on stderr; JSON output includes
      'diagnostics':[…] array.
    acceptance:
      all:
        - verifier: tests/fixtures/ambiguous-acceptance.sh
          result: pass
        - verifier: tests/fixtures/malformed-acceptance.sh
          result: pass

reversal:
  - signal: kernel-strict-attestation-store
    condition: |
      A future revision under obligation gate-attestation-store-fill
      makes accept on a verified attestation the canonical gate.
      At that point MC-AMBIGUOUS-ACCEPTANCE may upgrade from WARN
      to BLOCK under a stricter policy; the diagnostic stays.
    action: supersede-with-stricter-policy

risk:
  declared_triggers:
    - warn-flood-on-noisy-input
    - cli-output-schema-drift
  owner: human:maintainer

relations:
  addresses:
    - bootstrap-v3
  supersedes: []
  superseded_by: []