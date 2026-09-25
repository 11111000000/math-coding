(* tests/test_check.ml — tests for core/check.ml.

   Covers V3 (register/confidence consistency), V6 (supersession
   cycle / self-loop / broken link), V7 (dialectic sections).
   These are the predicates most likely to silently regress
   during refactoring. *)

open Test_runner

(* --- helpers --- *)

let mk_decision ?(name = "x") ?(proposition = "p") ?(register = Types.RHypothesis)
    ?(state = Types.SApplied) ?(actor = Types.AHuman) ?(confidence = 0.7)
    ?(superseded_by = None) ?(body_sections = []) () =
  {
    Types.schema_version = "2.1";
    name;
    proposition;
    code = None;
    witness = (if state = Types.SApplied then Some
      { Types.sha = "deadbeef"; date = "2026-01-01"; by = "test" }
      else None);
    register;
    state;
    actor;
    confidence;
    superseded_by;
    beneficiary = Types.System;
    substrate = Types.None;
    kind = Types.KPolicy;
    body_sections;
  }

(* --- V3 register/confidence --- *)

let test_v3_fact_low_confidence () =
  Printf.printf "V3: fact with low confidence must fail\n";
  let d = mk_decision ~register:Types.RFact ~confidence:0.5 () in
  let vs = Check.check_register d in
  assert_verdict ~label:"fact@0.5" vs Types.Fail

let test_v3_fact_high_confidence () =
  Printf.printf "V3: fact with confidence >= 0.95 must pass\n";
  let d = mk_decision ~register:Types.RFact ~confidence:0.95 () in
  let vs = Check.check_register d in
  assert_verdict ~label:"fact@0.95" vs Types.Pass

let test_v3_hypothesis_in_range () =
  Printf.printf "V3: hypothesis in (0.5, 0.95) must pass\n";
  let d = mk_decision ~register:Types.RHypothesis ~confidence:0.7 () in
  let vs = Check.check_register d in
  assert_verdict ~label:"hyp@0.7" vs Types.Pass

let test_v3_hypothesis_at_boundary () =
  Printf.printf "V3: hypothesis at boundary 0.5 must fail\n";
  let d = mk_decision ~register:Types.RHypothesis ~confidence:0.5 () in
  let vs = Check.check_register d in
  assert_verdict ~label:"hyp@0.5" vs Types.Fail

let test_v3_judgment_at_one () =
  Printf.printf "V3: judgment with confidence 1.0 must pass\n";
  let d = mk_decision ~register:Types.RJudgment ~confidence:1.0 () in
  let vs = Check.check_register d in
  assert_verdict ~label:"judgment@1.0" vs Types.Pass

let test_v3_judgment_at_zero () =
  Printf.printf "V3: judgment with confidence 0.0 must pass\n";
  let d = mk_decision ~register:Types.RJudgment ~confidence:0.0 () in
  let vs = Check.check_register d in
  assert_verdict ~label:"judgment@0.0" vs Types.Pass

let test_v3_judgment_at_half () =
  Printf.printf "V3: judgment with confidence 0.5 must fail\n";
  let d = mk_decision ~register:Types.RJudgment ~confidence:0.5 () in
  let vs = Check.check_register d in
  assert_verdict ~label:"judgment@0.5" vs Types.Fail

let test_v3_unknown_requires_zero () =
  Printf.printf "V3: unknown with confidence != 0 must fail\n";
  let d = mk_decision ~register:Types.RUnknown ~confidence:0.0 () in
  let vs = Check.check_register d in
  assert_verdict ~label:"unknown@0.0" vs Types.Pass;
  let d2 = mk_decision ~register:Types.RUnknown ~confidence:0.5 () in
  let vs2 = Check.check_register d2 in
  assert_verdict ~label:"unknown@0.5" vs2 Types.Fail

(* --- V6 supersession --- *)

let test_v6_self_loop () =
  Printf.printf "V6: self-loop must fail\n";
  let d = mk_decision ~name:"a" ~superseded_by:(Some "a") () in
  let vs = Check.check_supersession d [d] in
  assert_verdict ~label:"self-loop" vs Types.Fail

let test_v6_broken_link () =
  Printf.printf "V6: missing target must fail\n";
  let d = mk_decision ~name:"a" ~superseded_by:(Some "ghost") () in
  let vs = Check.check_supersession d [d] in
  assert_verdict ~label:"broken-link" vs Types.Fail

let test_v6_three_cycle () =
  Printf.printf "V6: 3-cycle a->b->c->a must fail\n";
  let a = mk_decision ~name:"a" ~superseded_by:(Some "b") () in
  let b = mk_decision ~name:"b" ~superseded_by:(Some "c") () in
  let c = mk_decision ~name:"c" ~superseded_by:(Some "a") () in
  let vs = Check.check_supersession a [a; b; c] in
  assert_verdict ~label:"3-cycle" vs Types.Fail

let test_v6_clean_chain () =
  Printf.printf "V6: clean chain a->b->c must pass\n";
  let a = mk_decision ~name:"a" ~superseded_by:(Some "b") () in
  let b = mk_decision ~name:"b" ~superseded_by:(Some "c") () in
  let c = mk_decision ~name:"c" () in
  let vs = Check.check_supersession a [a; b; c] in
  assert_verdict ~label:"clean-chain" vs Types.Pass

let test_v6_empty_target () =
  Printf.printf "V6: empty superseded_by treated as None must pass\n";
  let d = mk_decision ~name:"a" ~superseded_by:(Some "") () in
  let vs = Check.check_supersession d [d] in
  assert_verdict ~label:"empty-target" vs Types.Pass

(* --- V7 dialectic --- *)

let test_v7_judgment_all_present () =
  Printf.printf "V7: judgment with all sections present must pass\n";
  let body = [
    "Why", "because";
    "Antithesis", "but";
    "Synthesis", "therefore";
  ] in
  let d = mk_decision ~register:Types.RJudgment ~body_sections:body () in
  let vs = Check.check_dialectic d in
  assert_verdict ~label:"judgment-complete" vs Types.Pass

let test_v7_judgment_missing_section () =
  Printf.printf "V7: judgment missing a section must fail\n";
  let body = [ "Why", "because"; "Antithesis", "but" ] in
  let d = mk_decision ~register:Types.RJudgment ~body_sections:body () in
  let vs = Check.check_dialectic d in
  assert_verdict ~label:"judgment-missing-synthesis" vs Types.Fail

let test_v7_judgment_empty_section () =
  Printf.printf "V7: judgment with empty Synthesis section must fail\n";
  let body = [ "Why", "because"; "Antithesis", "but"; "Synthesis", "   " ] in
  let d = mk_decision ~register:Types.RJudgment ~body_sections:body () in
  let vs = Check.check_dialectic d in
  assert_verdict ~label:"judgment-empty-synthesis" vs Types.Fail

let test_v7_non_judgment_no_dialectic () =
  Printf.printf "V7: non-judgment register does not require dialectic\n";
  let d = mk_decision ~register:Types.RFact ~body_sections:[] () in
  let vs = Check.check_dialectic d in
  assert_verdict ~label:"fact-no-sections" vs Types.Pass

(* --- V4 FSM --- *)

let test_v4_draft_with_witness () =
  Printf.printf "V4: draft with witness must fail\n";
  let base = mk_decision ~state:Types.SDraft () in
  let d = { base with witness = Some
    { Types.sha = "deadbeef"; date = "2026-01-01"; by = "test" } } in
  let vs = Check.check_fsm d in
  assert_verdict ~label:"draft+witness" vs Types.Fail

let test_v4_reviewed_without_witness () =
  Printf.printf "V4: reviewed without witness must fail\n";
  let d = mk_decision ~state:Types.SReviewed () in
  let vs = Check.check_fsm d in
  assert_verdict ~label:"reviewed-no-witness" vs Types.Fail

let test_v4_applied_without_witness () =
  Printf.printf "V4: applied without witness must warn\n";
  let d = mk_decision ~state:Types.SApplied () in
  let d = { d with witness = None } in
  let vs = Check.check_fsm d in
  assert_verdict ~label:"applied-no-witness" vs Types.Warn

(* --- V1 structure --- *)

let test_v1_empty_proposition () =
  Printf.printf "V1: empty proposition must fail\n";
  let d = mk_decision ~proposition:"" () in
  let vs = Check.check_structure d in
  assert_verdict ~label:"empty-prop" vs Types.Fail

(* --- V5 actor/signing -- *)

let test_v5_strict_unsigned () =
  Printf.printf "V5: strict + unsigned witness must fail\n";
  let d = mk_decision () in
  let is_signed _ = false in
  let vs = Check.check_actor_with ~is_signed Signing.Strict d in
  assert_verdict ~label:"strict-unsigned" vs Types.Fail

let test_v5_strict_signed () =
  Printf.printf "V5: strict + signed witness must pass\n";
  let d = mk_decision () in
  let is_signed _ = true in
  let vs = Check.check_actor_with ~is_signed Signing.Strict d in
  assert_verdict ~label:"strict-signed" vs Types.Pass

let test_v5_lenient_unsigned () =
  Printf.printf "V5: lenient + unsigned witness must warn\n";
  let d = mk_decision () in
  let is_signed _ = false in
  let vs = Check.check_actor_with ~is_signed Signing.Lenient d in
  assert_verdict ~label:"lenient-unsigned" vs Types.Warn

let test_v5_off_unsigned () =
  Printf.printf "V5: off + unsigned witness must pass\n";
  let d = mk_decision () in
  let is_signed _ = false in
  let vs = Check.check_actor_with ~is_signed Signing.Off d in
  assert_verdict ~label:"off-unsigned" vs Types.Pass

let test_v5_no_witness () =
  Printf.printf "V5: no witness; signing verdict is Pass in any mode\n";
  let base = mk_decision ~state:Types.SDraft () in
  let d = { base with witness = None } in
  let is_signed _ = false in
  let vs_s = Check.check_actor_with ~is_signed Signing.Strict d in
  let vs_l = Check.check_actor_with ~is_signed Signing.Lenient d in
  let vs_o = Check.check_actor_with ~is_signed Signing.Off d in
  assert_verdict ~label:"no-witness-strict" vs_s Types.Pass;
  assert_verdict ~label:"no-witness-lenient" vs_l Types.Pass;
  assert_verdict ~label:"no-witness-off" vs_o Types.Pass

(* --- runner --- *)

let () =
  test_v3_fact_low_confidence ();
  test_v3_fact_high_confidence ();
  test_v3_hypothesis_in_range ();
  test_v3_hypothesis_at_boundary ();
  test_v3_judgment_at_one ();
  test_v3_judgment_at_zero ();
  test_v3_judgment_at_half ();
  test_v3_unknown_requires_zero ();
  test_v6_self_loop ();
  test_v6_broken_link ();
  test_v6_three_cycle ();
  test_v6_clean_chain ();
  test_v6_empty_target ();
  test_v7_judgment_all_present ();
  test_v7_judgment_missing_section ();
  test_v7_judgment_empty_section ();
  test_v7_non_judgment_no_dialectic ();
  test_v4_draft_with_witness ();
  test_v4_reviewed_without_witness ();
  test_v4_applied_without_witness ();
  test_v1_empty_proposition ();
  test_v5_strict_unsigned ();
  test_v5_strict_signed ();
  test_v5_lenient_unsigned ();
  test_v5_off_unsigned ();
  test_v5_no_witness ();
  summary ()
