(* tests/confidence_preserve.ml
 *
 * Asserts that the decision parser preserves `confidence` from
 * YAML/JSON into Domain.assumption.confidence rather than
 * dropping it to None (the pre-Fix behavior at lib/decision.ml:207).
 *
 * The fix is two-fold: lib/jsonl.ml gains a `Float` constructor
 * (so `0.85` parses as Float, not as a failed Int), and
 * lib/decision.ml:206 reads the field via `List.assoc_opt` rather
 * than discarding it. *)

let[@warning "-32"] yaml_form () =
  let raw =
    {|
---
schema: math-coding/3.0-alpha
id: conf-yaml-test
revision: 1
state: active
intent: |
  test
commitment: |
  test
counterexample: |
  none
scope:
  paths: ["lib/**"]
outcomes:
  - id: o
    statement: s
obligations:
  - id: ob1
    claim: c
    acceptance:
      all:
        - verifier: tests/conformance.exe
          result: pass
risk:
  declared_triggers: []
  owner: human:test
assumptions:
  - id: a1
    state: assumed
    statement: |
      A
    owner: human:test
    consequence_if_false: |
      B
    confidence: 0.85
|}
  in
  let v = Codec.load_yaml_string raw in
  match Decision.parse_decision_yaml v with
  | Some d -> (
      match d.Domain.assumptions with
      | [ a ] ->
          Alcotest.(check (float 0.001))
            "YAML confidence 0.85 preserved" 0.85
            (match a.Domain.confidence with Some c -> c | None -> -1.0)
      | _ -> Alcotest.fail "expected exactly one assumption")
  | None -> Alcotest.fail "YAML decision rejected unexpectedly"

let[@warning "-32"] json_form () =
  let raw =
    {|
{
  "schema": "math-coding/3.0-alpha/decision",
  "kind": "decision",
  "id": "conf-json-test",
  "revision": "1",
  "state": "active",
  "intent": {"source": "test", "text": "t"},
  "commitment": "c",
  "scope": [{"kind": "path", "path": "lib/**"}],
  "outcomes": [{"id": "o", "statement": "s"}],
  "obligations": [
    {
      "id": "ob1",
      "claim": "c",
      "acceptance": {"all": [{"verifier": "tests/conformance.exe", "result": "pass"}]}
    }
  ],
  "risk": {"declared_triggers": [], "owner": "human:test"},
  "assumptions": [
    {
      "id": "a1",
      "state": "assumed",
      "statement": "A",
      "owner": "human:test",
      "consequence_if_false": "B",
      "confidence": 0.5
    }
  ]
}
|}
  in
  let v = Jsonl.parse raw in
  match Decision.parse_decision_yaml v with
  | Some d -> (
      match d.Domain.assumptions with
      | [ a ] ->
          Alcotest.(check (float 0.001))
            "JSON confidence 0.5 preserved" 0.5
            (match a.Domain.confidence with Some c -> c | None -> -1.0)
      | _ -> Alcotest.fail "expected exactly one assumption")
  | None -> Alcotest.fail "JSON decision rejected unexpectedly"

let[@warning "-32"] missing_confidence_is_none () =
  (* No `confidence:` field at all — Domain.assumption.confidence
     should be None, not crash and not default to 0.0. *)
  let raw =
    {|
---
schema: math-coding/3.0-alpha
id: conf-missing-test
revision: 1
state: active
intent: |
  test
commitment: |
  test
counterexample: |
  none
scope:
  paths: ["lib/**"]
outcomes:
  - id: o
    statement: s
obligations:
  - id: ob1
    claim: c
    acceptance:
      all:
        - verifier: tests/conformance.exe
          result: pass
risk:
  declared_triggers: []
  owner: human:test
assumptions:
  - id: a1
    state: assumed
    statement: |
      A
    owner: human:test
    consequence_if_false: |
      B
|}
  in
  let v = Codec.load_yaml_string raw in
  match Decision.parse_decision_yaml v with
  | Some d -> (
      match d.Domain.assumptions with
      | [ a ] ->
          Alcotest.(check (option (float 0.001)))
            "missing confidence -> None" None a.Domain.confidence
      | _ -> Alcotest.fail "expected exactly one assumption")
  | None -> Alcotest.fail "decision rejected unexpectedly"

let () =
  Alcotest.run "confidence preservation"
    [
      ("yaml form", [ Alcotest.test_case "0.85 preserved" `Quick yaml_form ]);
      ("json form", [ Alcotest.test_case "0.5 preserved" `Quick json_form ]);
      ( "missing field",
        [
          Alcotest.test_case "absent -> None" `Quick missing_confidence_is_none;
        ] );
    ]
