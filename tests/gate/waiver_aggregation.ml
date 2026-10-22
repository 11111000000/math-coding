(* tests/gate/waiver_aggregation.ml — unit coverage for
   `Gate.aggregate_with_waivers` (lib/gate.ml).

   The defect this file pins is the one recorded in
   `decisions/self-check-waiver-verdict-coherence-2026-10.yaml`:
   the self-check verdict for a waiver-covered subject used to be
   reported as `pass`, so a subject carrying unmet obligations
   was indistinguishable from one whose obligations all hold.

   These cases assert the decision table at the level where the
   mistake was made — the pure aggregation, not the JSON string it
   happens to be rendered into. `tests/cli/self-check-waiver-
   verdict.t` asserts the same table end to end through the CLI,
   because a correct pure function behind a wrong string is still
   a wrong report.

   Matrix:
     1. no gaps                        -> Pass
     2. all gaps waived                -> Open_with_waiver
     3. some gaps waived               -> Unknown (partial relief is
                                         not relief)
     4. FailedEvidence gap             -> Block (never waived, even by
                                         a waiver that covers it)
     5. MissingReview gap              -> Block
     6. expired waiver                 -> Unknown
     7. not-yet-issued waiver          -> Unknown
     8. waiver for another decision    -> Unknown
     9. obligation-scoped waiver does
        not cover its sibling          -> Unknown
    10. a scoped waiver does cover its
        named obligation               -> Open_with_waiver
    11. a waived verdict carries the waiver that produced it
        (Invariant 14c: a verdict that exits 0 under a waiver
        must reference it, and that waiver must cover every gap)
    12. the expiry boundary: at now == expires_at the waiver does
        NOT lift the gap (-> Unknown, exit 3, not exit 0 under a
        waiver the constitution calls expired), at expires_at - 1s
        it DOES (-> Open_with_waiver). Invariant 14c requires
        `expires_at` to be strictly greater than the evaluation
        time; the "- 1s" case is what stops the boundary from
        being fixed by moving the error one second earlier. The
        start boundary is pinned too (now == issued_at lifts), so a
        "harmonised" strictly-open interval fails here as well. *)

open Alcotest

let[@warning "-32"] gap ?(kind = `MissingEvidence) obligation_id =
  {
    Gate.obligation_id;
    kind;
    causes = [ "c" ];
    remedies = [ "r" ];
    next_actions = [];
  }

let[@warning "-32"] waiver ?(obligation = None)
    ?(issued = "2026-10-01T00:00:00Z") ?(expires = "2027-10-01T00:00:00Z") id
    subject =
  {
    Domain.id;
    policy_id = "bootstrap-v3";
    rule = "obligation-missing-attestation";
    subject;
    scope = [];
    issuer = "human:maintainer";
    issued_at = issued;
    expires_at = expires;
    reason = "unit-test fixture";
    unverified_obligation = obligation;
    compensating_controls = [];
  }

let[@warning "-32"] now_default = "2026-11-01T00:00:00Z"
let[@warning "-32"] d = "d1"

let () =
  (* `case_at` evaluates at an explicit instant; `case` uses the
     matrix default. The boundary cases need `case_at` because the
     expiry second is the whole subject of those cases. Two
     helpers rather than an optional argument: an optional
     argument cannot be erased when every call site is a labelled
     application (OCaml warning 16, fatal under this profile). *)
  let case_at at name ~gaps ~waivers ~expected =
    ( name,
      `Quick,
      fun () ->
        let verdict, _covered =
          Gate.aggregate_with_waivers waivers ~decision_id:d ~now:at gaps
        in
        check string "verdict"
          (Gate.verdict_to_string expected)
          (Gate.verdict_to_string verdict) )
  in
  let case name ~gaps ~waivers ~expected =
    case_at now_default name ~gaps ~waivers ~expected
  in
  let cases =
    [
      case "no gaps is Pass" ~gaps:[] ~waivers:[] ~expected:Gate.Pass;
      case "every gap waived is Open_with_waiver"
        ~gaps:[ gap "a"; gap "b" ]
        ~waivers:[ waiver "w1" d ]
        ~expected:Gate.Open_with_waiver;
      case "partial coverage stays Unknown"
        ~gaps:[ gap "a"; gap "b" ]
        ~waivers:[ waiver ~obligation:(Some "a") "w1" d ]
        ~expected:Gate.Unknown;
      case "a decisive fail is never waived"
        ~gaps:[ gap ~kind:`FailedEvidence "a" ]
        ~waivers:[ waiver "w1" d ]
        ~expected:Gate.Block;
      case "a missing required review is never waived"
        ~gaps:[ gap ~kind:`MissingReview "a" ]
        ~waivers:[ waiver "w1" d ]
        ~expected:Gate.Block;
      case "a fail among waived gaps is still Block"
        ~gaps:[ gap "a"; gap ~kind:`FailedEvidence "b" ]
        ~waivers:[ waiver "w1" d ]
        ~expected:Gate.Block;
      case "an expired waiver does not lift a gap"
        ~gaps:[ gap "a" ]
        ~waivers:[ waiver ~expires:"2026-10-02T00:00:00Z" "w1" d ]
        ~expected:Gate.Unknown;
      (* --- the expiry boundary (Invariant 14c) --- *)
      case_at "2026-10-01T00:00:00Z"
        "a waiver lifts a gap at now == issued_at (inclusive start)"
        ~gaps:[ gap "a" ]
        ~waivers:[ waiver "w1" d ]
        ~expected:Gate.Open_with_waiver;
      case_at "2026-11-01T00:00:00Z"
        "a waiver does not lift a gap at now == expires_at"
        ~gaps:[ gap "a" ]
        ~waivers:[ waiver ~expires:"2026-11-01T00:00:00Z" "w1" d ]
        ~expected:Gate.Unknown;
      case_at "2026-10-31T23:59:59Z"
        "a waiver does lift a gap at now == expires_at - 1s"
        ~gaps:[ gap "a" ]
        ~waivers:[ waiver ~expires:"2026-11-01T00:00:00Z" "w1" d ]
        ~expected:Gate.Open_with_waiver;
      case_at "2026-11-01T00:00:01Z"
        "a waiver does not lift a gap at now == expires_at + 1s"
        ~gaps:[ gap "a" ]
        ~waivers:[ waiver ~expires:"2026-11-01T00:00:00Z" "w1" d ]
        ~expected:Gate.Unknown;
      case "a waiver not yet issued does not lift a gap"
        ~gaps:[ gap "a" ]
        ~waivers:[ waiver ~issued:"2026-12-01T00:00:00Z" "w1" d ]
        ~expected:Gate.Unknown;
      case "another decision's waiver does not lift the gap"
        ~gaps:[ gap "a" ]
        ~waivers:[ waiver "w1" "d2" ]
        ~expected:Gate.Unknown;
      case "an obligation-scoped waiver does not cover its sibling"
        ~gaps:[ gap "a" ]
        ~waivers:[ waiver ~obligation:(Some "other") "w1" d ]
        ~expected:Gate.Unknown;
      case "an obligation-scoped waiver covers its named obligation"
        ~gaps:[ gap "a" ]
        ~waivers:[ waiver ~obligation:(Some "a") "w1" d ]
        ~expected:Gate.Open_with_waiver;
      ( "a waived verdict names the waiver that produced it",
        `Quick,
        fun () ->
          let w = waiver "w1" d in
          let verdict, covered =
            Gate.aggregate_with_waivers [ w ] ~decision_id:d ~now:now_default
              [ gap "a"; gap "b" ]
          in
          check string "verdict" "open-with-waiver"
            (Gate.verdict_to_string verdict);
          (* Invariant 14c: the verdict that exits 0 under a
               waiver must reference the waiver, and that waiver
               must cover EVERY gap in the verdict — not just the
               first. *)
          check (list string) "covered waiver ids" [ "w1"; "w1" ]
            (List.map (fun (_, (w' : Waiver.t)) -> w'.Domain.id) covered);
          check (list string) "covered obligation ids" [ "a"; "b" ]
            (List.map (fun (g, _) -> g.Gate.obligation_id) covered);
          check bool "the returned waiver is the one passed in" true
            (List.for_all
               (fun (_, (w' : Waiver.t)) ->
                 String.equal w'.Domain.id w.Domain.id)
               covered) );
    ]
  in
  run
    ~log_dir:(Filename.concat (Filename.get_temp_dir_name ()) "mathc-alcotest")
    "gate waiver aggregation"
    [ ("aggregate_with_waivers", cases) ]
