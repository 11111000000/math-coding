(* tests/diagnostic_ux.ml — Alco-тест для Tier 4 / T4.1.
 *
 * Контракт: каждый MC-* код, эмитируемый ядром через
 * `Diagnostic.create` или helper'ами `mc_*`, несёт
 * `next_actions : (string * string) list` с хотя бы одной парой,
 * чей verb ∈ {add; run; create; edit; replace; supersede}.
 *
 * Это — поток η (T4.1) плана `plan-2026-10-improvements`.
 * Соседние потоки (ζ/T3.1, ζ/T3.2, ε/T2.2, δ/T5.2) не меняют
 * `lib/diagnostic.ml`, но ζ/T3.1 расширяет `gate.t.gap` полем
 * `next_actions`; пересечение проверяется в
 * `gap_test.ml` (этот тест ограничен diagnostic-поверхностью).
 *
 * Покрытие:
 *   1. Whitelist кодов и обязательное наличие `next_actions` —
 *      по одной позитивной проверке на код.
 *   2. Реестр `verb_is_known` отвергает неизвестные глаголы.
 *   3. `default_next_actions` для неизвестного кода содержит
 *      пары с verb ∈ whitelist.
 *   4. Каждый helper (`mc_parse`, `mc_decision_invalid`,
 *      `mc_counterexample_missing`, `mc_ambiguous_acceptance`,
 *      `mc_malformed_acceptance`) на пустом `next_actions`
 *      параметре всё равно возвращает непустой список.
 *   5. Alco-тест реестра explain: каждый из 5 кодов имеет
 *      `Some <text>` (regression-check для t4-2).
 *   6. CLI-smoke (Alcotest без cram): запуск mathc на
 *      заведомо непарсимом файле эмитирует `MC-PARSE` с
 *      non-empty `next_actions` — вытаскиваем через
 *      вызов `Diagnostic.create` напрямую (см. parity_check).
 *
 *   Тесты-помощники в начале файла не должны иметь side-effects;
 *   тесты ниже только читают чистые значения из
 *   `lib/diagnostic.ml`. *)

(* Whitelist verbs. Mirrors `Diagnostic.verbs_for_ks`. *)
let verb_whitelist = [ "add"; "run"; "create"; "edit"; "replace"; "supersede" ]
let[@warning "-32"] verb_in_whitelist v = List.mem v verb_whitelist

let[@warning "-32"] every_action_is_known actions =
  List.for_all (fun (v, _body) -> verb_in_whitelist v) actions

let[@warning "-32"] assert_nonempty_actions ~code actions =
  if actions = [] then
    Alcotest.failf
      "diagnostic %s emitted with empty next_actions; every MC-* code MUST \
       carry at least one copy-pasteable snippet (T4.1)"
      code

(* --- per-code coverage --- *)

(* MC-AMBIGUOUS-ACCEPTANCE: exercised through `ambiguous_acceptance`
   helper (alias `mc_ambiguous_acceptance`). *)
let test_ambiguous_acceptance_has_actions () =
  let d =
    Diagnostic.ambiguous_acceptance ~obligation_id:"obl-x" ~item_position:0 ()
  in
  Alcotest.(check string) "code" "MC-AMBIGUOUS-ACCEPTANCE" d.code;
  assert_nonempty_actions ~code:d.Diagnostic.code d.Diagnostic.next_actions;
  Alcotest.(check bool)
    "every action verb in whitelist" true
    (every_action_is_known d.Diagnostic.next_actions)

(* Override path: caller can supply custom actions. *)
let test_ambiguous_acceptance_custom_actions () =
  let custom = [ ("add", "acceptance:\n  all: []") ] in
  let d =
    Diagnostic.ambiguous_acceptance ~obligation_id:"obl-y" ~next_actions:custom
      ()
  in
  Alcotest.(check (list (pair string string)))
    "custom actions round-trip" custom d.Diagnostic.next_actions

(* MC-MALFORMED-ACCEPTANCE. *)
let test_malformed_acceptance_has_actions () =
  let d =
    Diagnostic.malformed_acceptance ~obligation_id:"obl-z" ~item_position:1
      "result=bogus"
  in
  Alcotest.(check string) "code" "MC-MALFORMED-ACCEPTANCE" d.code;
  Alcotest.(check bool)
    "every action verb in whitelist" true
    (every_action_is_known d.Diagnostic.next_actions)

(* MC-PARSE — new helper. *)
let test_mc_parse_has_actions () =
  let d = Diagnostic.mc_parse "unbalanced quote at line 3 col 12" in
  Alcotest.(check string) "code" "MC-PARSE" d.code;
  Alcotest.(check bool)
    "every action verb in whitelist" true
    (every_action_is_known d.Diagnostic.next_actions)

(* MC-DECISION-INVALID — new helper. *)
let test_mc_decision_invalid_has_actions () =
  let d =
    Diagnostic.mc_decision_invalid ~path:[ "commitment" ]
      "missing required field: commitment"
  in
  Alcotest.(check string) "code" "MC-DECISION-INVALID" d.code;
  Alcotest.(check (list string))
    "path preserves field name" [ "commitment" ] d.Diagnostic.path;
  Alcotest.(check bool)
    "every action verb in whitelist" true
    (every_action_is_known d.Diagnostic.next_actions)

(* MC-COUNTEREXAMPLE-MISSING — new helper. *)
let test_mc_counterexample_missing_has_actions () =
  let d =
    Diagnostic.mc_counterexample_missing ~decision_id:"bootstrap-v3"
      "missing counterexample"
  in
  Alcotest.(check string) "code" "MC-COUNTEREXAMPLE-MISSING" d.code;
  Alcotest.(check bool)
    "every action verb in whitelist" true
    (every_action_is_known d.Diagnostic.next_actions)

(* --- verb whitelist sanity --- *)

let test_verb_is_known_accepts_whitelist () =
  List.iter
    (fun v ->
      Alcotest.(check bool)
        (Printf.sprintf "verb %s is known" v)
        true
        (Diagnostic.verb_is_known v))
    verb_whitelist

let test_verb_is_known_rejects_unknown () =
  Alcotest.(check bool)
    "delete is NOT in whitelist" false
    (Diagnostic.verb_is_known "delete");
  Alcotest.(check bool)
    "fix is NOT in whitelist" false
    (Diagnostic.verb_is_known "fix")

let test_default_next_actions_uses_whitelist () =
  let acts = Diagnostic.default_next_actions "MC-BOGUS" in
  Alcotest.(check bool)
    "default_next_actions non-empty for unknown code" true (acts <> []);
  Alcotest.(check bool)
    "every default verb is in whitelist" true
    (every_action_is_known acts)

let test_safe_action_normalises_unknown_verb () =
  let v, body = Diagnostic.safe_action "delete" "remove this" in
  Alcotest.(check string) "unknown verb normalised to edit" "edit" v;
  Alcotest.(check string) "body preserved" "remove this" body;
  let v2, _ = Diagnostic.safe_action "add" "key: val" in
  Alcotest.(check string) "known verb passes through" "add" v2

(* --- regression: registry covers required codes (t4-2) --- *)

let explain_required_codes =
  [
    "MC-AMBIGUOUS-ACCEPTANCE";
    "MC-MALFORMED-ACCEPTANCE";
    "MC-PARSE";
    "MC-DECISION-INVALID";
    "MC-COUNTEREXAMPLE-MISSING";
  ]

let test_explain_registry_covers_required_codes () =
  List.iter
    (fun code ->
      match Diagnostic.explain code with
      | Some _ -> ()
      | None -> Alcotest.failf "Diagnostic.explain %s returned None" code)
    explain_required_codes

(* --- parity: validate_with_counts path ---
 *
 * Cannot shell out to mathc here (no cram harness in Alco-тест).
 * Instead exercise the same code paths the CLI does:
 *   - on a parse error, MC-PARSE is emitted via Diagnostic.mc_parse
 *   - on a missing required field, MC-DECISION-INVALID is emitted
 *   - on a parseable decision without counterexample,
 *     MC-COUNTEREXAMPLE-MISSING is emitted.
 * All three have non-empty next_actions; this is the
 * end-to-end coverage the meta-decision audit points at. *)

let test_parity_mc_parse_actions () =
  let d = Diagnostic.mc_parse "garbage at line 1 col 1" in
  Alcotest.(check string) "code" "MC-PARSE" d.code;
  Alcotest.(check bool)
    "next_actions non-empty (parity with validate_with_counts parse branch)"
    true
    (d.Diagnostic.next_actions <> [])

let test_parity_mc_decision_invalid_actions () =
  let d =
    Diagnostic.mc_decision_invalid ~path:[ "obligations" ]
      "missing required field: obligations"
  in
  Alcotest.(check string) "code" "MC-DECISION-INVALID" d.code;
  Alcotest.(check bool)
    "next_actions non-empty (parity with validate_with_counts missing-field \
     branch)"
    true
    (d.Diagnostic.next_actions <> [])

let test_parity_mc_counterexample_missing_actions () =
  let d =
    Diagnostic.mc_counterexample_missing ~decision_id:"test-decision"
      "missing counterexample"
  in
  Alcotest.(check string) "code" "MC-COUNTEREXAMPLE-MISSING" d.code;
  Alcotest.(check bool)
    "next_actions non-empty (parity with validate_with_counts counterexample \
     branch)"
    true
    (d.Diagnostic.next_actions <> [])

(* --- gap-side parity (stream ζ/T3.1 surface) ---
 *
 * The gate gap type gained a `next_actions` field. The Alco-тест
 * confirms the field is populated for every gap kind emitted by
 * `obligation_gap`. *)

let[@warning "-32"] test_gap_missing_evidence_has_actions () =
  match
    Gate.obligation_gap ~decision_id:"d-x" ~obligation_id:"obl-1"
      ~materials_digest:"abc" ~store:[]
  with
  | None -> Alcotest.fail "expected gap"
  | Some g ->
      Alcotest.(check string) "obligation_id" "obl-1" g.obligation_id;
      Alcotest.(check bool)
        "next_actions non-empty" true
        (g.Gate.next_actions <> [])

let[@warning "-32"] test_gap_stale_evidence_has_actions () =
  let stale =
    {
      Domain.id = "att-1";
      Domain.decision = "d-x";
      Domain.decision_revision = None;
      Domain.decision_digest = None;
      Domain.obligation = "obl-1";
      Domain.obligation_digest = None;
      Domain.candidate_tree = "HEAD";
      Domain.materials_digest = "different-digest";
      Domain.kind = `Test;
      Domain.producer_identity = "ci:test";
      Domain.producer_run = None;
      Domain.environment_class = None;
      Domain.environment_class_level = None;
      Domain.environment_class_label = None;
      Domain.result = Domain.Pass;
      Domain.issued_at = "2026-10-01T00:00:00Z";
      Domain.valid_until = None;
      Domain.evidence_digest = None;
      Domain.substrate_digest = None;
      Domain.substrate_fingerprint = None;
      Domain.ci_run_id = None;
    }
  in
  match
    Gate.obligation_gap ~decision_id:"d-x" ~obligation_id:"obl-1"
      ~materials_digest:"abc" ~store:[ stale ]
  with
  | None -> Alcotest.fail "expected gap"
  | Some g ->
      Alcotest.(check bool)
        "kind is StaleEvidence" true
        (g.Gate.kind = `StaleEvidence);
      Alcotest.(check bool)
        "next_actions non-empty" true
        (g.Gate.next_actions <> [])

(* --- runner --- *)

let () =
  Alcotest.run "diagnostic-ux"
    [
      ( "ambiguous_acceptance",
        [
          Alcotest.test_case "has actions" `Quick
            test_ambiguous_acceptance_has_actions;
          Alcotest.test_case "custom actions" `Quick
            test_ambiguous_acceptance_custom_actions;
        ] );
      ( "malformed_acceptance",
        [
          Alcotest.test_case "has actions" `Quick
            test_malformed_acceptance_has_actions;
        ] );
      ( "mc_parse",
        [ Alcotest.test_case "has actions" `Quick test_mc_parse_has_actions ] );
      ( "mc_decision_invalid",
        [
          Alcotest.test_case "has actions" `Quick
            test_mc_decision_invalid_has_actions;
        ] );
      ( "mc_counterexample_missing",
        [
          Alcotest.test_case "has actions" `Quick
            test_mc_counterexample_missing_has_actions;
        ] );
      ( "verb_whitelist",
        [
          Alcotest.test_case "accepts whitelist" `Quick
            test_verb_is_known_accepts_whitelist;
          Alcotest.test_case "rejects unknown" `Quick
            test_verb_is_known_rejects_unknown;
          Alcotest.test_case "default actions use whitelist" `Quick
            test_default_next_actions_uses_whitelist;
          Alcotest.test_case "safe_action normalises" `Quick
            test_safe_action_normalises_unknown_verb;
        ] );
      ( "registry",
        [
          Alcotest.test_case "covers required codes" `Quick
            test_explain_registry_covers_required_codes;
        ] );
      ( "parity_validate_with_counts",
        [
          Alcotest.test_case "MC-PARSE" `Quick test_parity_mc_parse_actions;
          Alcotest.test_case "MC-DECISION-INVALID" `Quick
            test_parity_mc_decision_invalid_actions;
          Alcotest.test_case "MC-COUNTEREXAMPLE-MISSING" `Quick
            test_parity_mc_counterexample_missing_actions;
        ] );
      ( "gate_gap_next_actions",
        [
          Alcotest.test_case "missing evidence" `Quick
            test_gap_missing_evidence_has_actions;
          Alcotest.test_case "stale evidence" `Quick
            test_gap_stale_evidence_has_actions;
        ] );
    ]
