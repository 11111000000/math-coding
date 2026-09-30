(* tests/test_re_evaluation.ml
 *
 * Tests for the §17 re-evaluation oracle (lib/re_evaluation.ml).
 *
 * NOTE: do not `open Stdlib` here; OCaml 5's Stdlib exports a
 * parallel-domain module named `Domain` which would shadow
 * `mathcoding_core.Domain` (the algebra entity module).
 * Use `Stdlib.X` qualified access when stdlib names are needed. *)

(* Render a status verdict as a short lowercase string so
 * Alcotest.string can compare it. *)
let[@warning "-32"] status_to_string = function
  | Re_evaluation.Compatible -> "compatible"
  | Re_evaluation.Inconclusive -> "inconclusive"
  | Re_evaluation.StaleClaim -> "stale"

(* Render a gate verdict as a string. *)
let[@warning "-32"] gate_to_string = function
  | `Pass -> "pass"
  | `Block -> "block"

(* Build a synthetic obligation with a known claim and verifier. *)
let[@warning "-32"] make_obligation ?(verifier = "tests/conformance")
    ?(claim = "no claim") () : Domain.obligation =
  let verifier_id = verifier in
  let result_str = "pass" in
  let result =
    match result_str with
    | "pass" -> Domain.Pass
    | _ -> Domain.Pass
  in
  {
    Domain.id = "ob-test-" ^ claim;
    decision = "dec-test";
    outcome = None;
    claim;
    subjects = [];
    acceptance = Domain.All [ Domain.Verifier { id = verifier_id; result } ];
    kind = `Invariant;
    phase = `PreMerge;
    obligation_domain = None;
  }

let[@warning "-32"] make_decision ?(id = "dec-test") ?(rev = "1")
    ?(commitment = "test commitment") ?(axiom_addresses = []) obligations :
    Domain.decision =
  {
    Domain.id;
    rev;
    parents = [];
    intent_source = "test";
    intent_text = "test intent";
    commitment;
    scope = [];
    outcomes = [];
    obligations;
    assumptions = [];
    reversal = [];
    Domain.risk = { Domain.declared_triggers = []; owner = "tester" };
    Domain.relations =
      {
        Domain.revises = [];
        supersedes = [];
        superseded_by = [];
        refines = [];
        depends_on = [];
        conflicts_with = [];
        addresses = axiom_addresses;
        implements = [];
        verifies = [];
      };
    counterexample = None;
    state = `Active;
    mode = `Standard;
    mode_floor_used = None;
    body_sha = None;
    yaml_sha = None;
  }

let[@warning "-32"] empty_rev axiom_id =
  {
    Re_evaluation.axiom_id;
    old_sha = "deadbeef";
    new_sha = "feedface";
    old_forbidden_patterns = [];
    new_forbidden_patterns = [];
  }

(* --- max_verdict --- *)

let[@warning "-32"] test_max_verdict () =
  Alcotest.(check string)
    "empty -> compatible"
    "compatible"
    (Re_evaluation.max_verdict [] |> status_to_string);
  Alcotest.(check string)
    "[compatible] -> compatible"
    "compatible"
    (Re_evaluation.max_verdict [ Re_evaluation.Compatible ]
     |> status_to_string);
  Alcotest.(check string)
    "[inconclusive] -> inconclusive"
    "inconclusive"
    (Re_evaluation.max_verdict [ Re_evaluation.Inconclusive ]
     |> status_to_string);
  Alcotest.(check string)
    "[stale] -> stale"
    "stale"
    (Re_evaluation.max_verdict [ Re_evaluation.StaleClaim ]
     |> status_to_string);
  Alcotest.(check string)
    "max wins"
    "stale"
    (Re_evaluation.max_verdict
       [ Re_evaluation.Compatible; Re_evaluation.Inconclusive;
         Re_evaluation.StaleClaim ]
     |> status_to_string);
  Alcotest.(check string)
    "compatible doesn't beat inconclusive"
    "inconclusive"
    (Re_evaluation.max_verdict
       [ Re_evaluation.Compatible; Re_evaluation.Inconclusive ]
     |> status_to_string)

(* --- gate_verdict --- *)

let[@warning "-32"] test_gate_verdict () =
  Alcotest.(check string) "compatible -> pass" "pass"
    (Re_evaluation.gate_verdict Re_evaluation.Compatible
     |> gate_to_string);
  Alcotest.(check string) "inconclusive -> pass" "pass"
    (Re_evaluation.gate_verdict Re_evaluation.Inconclusive
     |> gate_to_string);
  Alcotest.(check string) "stale -> block" "block"
    (Re_evaluation.gate_verdict Re_evaluation.StaleClaim
     |> gate_to_string)

(* --- re_evaluate: per-obligation rules --- *)

let[@warning "-32"] test_re_evaluate_test_verifier_compatible () =
  let ob = make_obligation ~verifier:"tests/x" ~claim:"hello world" () in
  let d = make_decision [ ob ] in
  let rev = empty_rev "A0" in
  Alcotest.(check string)
    "test verifier + no forbidden pattern -> compatible"
    "compatible"
    (Re_evaluation.re_evaluate d rev |> status_to_string)

let[@warning "-32"] test_re_evaluate_manual_verifier_inconclusive () =
  let ob = make_obligation ~verifier:"manual-review" ~claim:"hello world" () in
  let d = make_decision [ ob ] in
  let rev = empty_rev "A0" in
  Alcotest.(check string) "manual verifier -> inconclusive" "inconclusive"
    (Re_evaluation.re_evaluate d rev |> status_to_string)

let[@warning "-32"] test_re_evaluate_builtin_verifier_compatible () =
  let ob =
    make_obligation ~verifier:"mc-validate-self-check" ~claim:"hello world" ()
  in
  let d = make_decision [ ob ] in
  let rev = empty_rev "A0" in
  Alcotest.(check string) "mc- builtin verifier -> compatible" "compatible"
    (Re_evaluation.re_evaluate d rev |> status_to_string)

let[@warning "-32"] test_re_evaluate_stale_claim () =
  let ob =
    make_obligation
      ~verifier:"tests/x"
      ~claim:"the old axiom says 'forbidden phrase' must hold"
      ()
  in
  let d = make_decision [ ob ] in
  let rev =
    {
      Re_evaluation.axiom_id = "A0";
      old_sha = "deadbeef";
      new_sha = "feedface";
      old_forbidden_patterns = [ "forbidden phrase" ];
      new_forbidden_patterns = [];
    }
  in
  Alcotest.(check string) "claim mentions forbidden pattern -> stale"
    "stale"
    (Re_evaluation.re_evaluate d rev |> status_to_string)

let[@warning "-32"] test_re_evaluate_worst_across_obligations () =
  let ok_ob = make_obligation ~verifier:"tests/x" ~claim:"hello world" () in
  let stale_ob =
    make_obligation
      ~verifier:"tests/x"
      ~claim:"contains the keyword forbidden-pattern-here today"
      ()
  in
  let d = make_decision [ ok_ob; stale_ob ] in
  let rev =
    {
      Re_evaluation.axiom_id = "A0";
      old_sha = "deadbeef";
      new_sha = "feedface";
      old_forbidden_patterns = [ "forbidden-pattern-here" ];
      new_forbidden_patterns = [];
    }
  in
  Alcotest.(check string) "max over [compatible; stale] -> stale"
    "stale"
    (Re_evaluation.re_evaluate d rev |> status_to_string)

(* --- impact_list / transitive_impact_list --- *)

let[@warning "-32"] test_impact_list_filters_by_addresses () =
  let d_a0 = make_decision ~id:"alpha" ~axiom_addresses:[ "A0"; "A1" ] [] in
  let d_a2 = make_decision ~id:"beta" ~axiom_addresses:[ "A2" ] [] in
  let d_none = make_decision ~id:"gamma" ~axiom_addresses:[] [] in
  let ds = [ d_a0; d_a2; d_none ] in
  let result = Re_evaluation.impact_list ds "A0" in
  Alcotest.(check int) "A0 -> 1 decision"
    (Stdlib.List.length result) 1;
  Alcotest.(check string) "A0 -> alpha"
    "alpha"
    (Stdlib.List.hd result).Domain.id

let[@warning "-32"] test_transitive_impact_includes_dependents () =
  let d_a0 = make_decision ~id:"alpha" ~axiom_addresses:[ "A0" ] [] in
  let d_depends_on_alpha =
    {
      (make_decision ~id:"delta" ~axiom_addresses:[] []) with
      Domain.relations =
        {
          (make_decision ~id:"delta" ~axiom_addresses:[] []).Domain.relations
          with
          Domain.depends_on = [ "alpha" ];
        };
    }
  in
  let ds = [ d_a0; d_depends_on_alpha ] in
  let result : Domain.decision list =
    Re_evaluation.transitive_impact_list ds "A0"
  in
  let ids = Stdlib.List.map (fun (d : Domain.decision) -> d.Domain.id) result in
  Alcotest.(check (list string))
    "A0 -> [alpha; delta] (alpha direct, delta depends on alpha)"
    [ "alpha"; "delta" ] ids

let[@warning "-32"] test_transitive_impact_no_self_reference () =
  let d_a0 = make_decision ~id:"alpha" ~axiom_addresses:[ "A0" ] [] in
  let ds = [ d_a0 ] in
  let result : Domain.decision list =
    Re_evaluation.transitive_impact_list ds "A0"
  in
  let ids = Stdlib.List.map (fun (d : Domain.decision) -> d.Domain.id) result in
  Alcotest.(check (list string))
    "single direct match, no transitive self-reference"
    [ "alpha" ] ids

(* --- remediation --- *)

let[@warning "-32"] test_remediation_mentions_decision_and_axiom () =
  let d = make_decision ~id:"kernel-change" [] in
  let text = Re_evaluation.remediation d "A1" in
  Alcotest.(check bool) "names decision id"
    true
    (Str.string_match (Str.regexp "kernel-change") text 0);
  Alcotest.(check bool) "names axiom id"
    true
    (Str.string_match (Str.regexp "A1") text 0);
  Alcotest.(check bool) "mentions axioms path"
    true
    (Str.string_match (Str.regexp "axioms/A1.md") text 0)

(* --- enumerate --- *)

let () =
  Alcotest.run "re-evaluation oracle"
    [
      ( "max_verdict",
        [ Alcotest.test_case "ordering" `Quick test_max_verdict ] );
      ( "gate_verdict",
        [ Alcotest.test_case "pass/block split" `Quick test_gate_verdict ] );
      ( "re_evaluate",
        [
          Alcotest.test_case "test verifier -> compatible" `Quick
            test_re_evaluate_test_verifier_compatible;
          Alcotest.test_case "manual verifier -> inconclusive" `Quick
            test_re_evaluate_manual_verifier_inconclusive;
          Alcotest.test_case "builtin verifier -> compatible" `Quick
            test_re_evaluate_builtin_verifier_compatible;
          Alcotest.test_case "stale claim -> stale" `Quick
            test_re_evaluate_stale_claim;
          Alcotest.test_case "worst across obligations" `Quick
            test_re_evaluate_worst_across_obligations;
        ] );
      ( "impact_list",
        [
          Alcotest.test_case "filters by axiom_id" `Quick
            test_impact_list_filters_by_addresses;
        ] );
      ( "transitive_impact_list",
        [
          Alcotest.test_case "includes dependents" `Quick
            test_transitive_impact_includes_dependents;
          Alcotest.test_case "no self-reference" `Quick
            test_transitive_impact_no_self_reference;
        ] );
      ( "remediation",
        [
          Alcotest.test_case "names decision and axiom" `Quick
            test_remediation_mentions_decision_and_axiom;
        ] );
    ]
