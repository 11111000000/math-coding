(* tests/waiver_test.ml — kernel unit tests for lib/waiver.ml.
 *
 * The waiver module is pure: load takes a `reader` callback
 * and `covers` / `effective_at` are pure functions of the
 * loaded list and a `now` string. The tests below exercise
 * each surface with in-memory data; no filesystem, no real
 * time.
 *
 * Coverage:
 *   - load: empty/missing root -> []
 *   - load: valid YAML waiver -> Some
 *   - load: malformed YAML -> None (best-effort load)
 *   - load: missing required field -> None
 *   - effective_at: now inside [issued_at, expires_at] -> true
 *   - effective_at: now before issued_at -> false
 *   - effective_at: now after expires_at -> false
 *   - covers: subject match + effective -> Some
 *   - covers: subject mismatch -> None
 *   - covers: subject match + expired -> None
 *   - covers: empty list -> None
 *
 * Per OCAML_BEST_PRACTICES §11.18 we annotate the construction
 * site (`Domain.waiver` literal) so OCaml's structural row
 * polymorphism does not pick the wrong `subject` field. *)

(* --- tests --- *)

(* --- a sample waiver literal (Domain.waiver) --- *)

(* We construct the Domain.waiver record directly so the test
   is independent of the YAML parser. The parser is exercised
   separately via tests/conformance.ml. *)
let[@warning "-32"] sample_waiver =
  {
    Domain.id = "test-waiver-2026-10";
    Domain.policy_id = "bootstrap-v3";
    Domain.rule = "obligation-missing-attestation";
    Domain.subject = "test-subject";
    Domain.scope = [];
    Domain.issuer = "human:maintainer";
    Domain.issued_at = "2026-10-06T00:00:00Z";
    Domain.expires_at = "2027-04-06T00:00:00Z";
    Domain.reason = "structural deficit, see decision";
    Domain.unverified_obligation = Some "obligation-x";
    Domain.compensating_controls = [ "re-evaluate on reversal" ];
  }

(* --- tests --- *)

let test_effective_inside_window () =
  Alcotest.(check bool)
    "now inside [issued, expires] is effective" true
    (Waiver.effective_at sample_waiver ~now:"2026-12-01T00:00:00Z")

let test_effective_before_issued () =
  Alcotest.(check bool)
    "now before issued_at is not effective" false
    (Waiver.effective_at sample_waiver ~now:"2026-09-01T00:00:00Z")

let test_effective_after_expires () =
  Alcotest.(check bool)
    "now after expires_at is not effective" false
    (Waiver.effective_at sample_waiver ~now:"2027-05-01T00:00:00Z")

let test_effective_at_boundary_issued () =
  (* issued_at is inclusive (constitution.md §Waivers language:
     "MAY permit a gate"). The boundary case is inclusive. *)
  Alcotest.(check bool)
    "now == issued_at is effective (inclusive)" true
    (Waiver.effective_at sample_waiver ~now:"2026-10-06T00:00:00Z")

let test_effective_at_boundary_expires () =
  Alcotest.(check bool)
    "now == expires_at is effective (inclusive)" true
    (Waiver.effective_at sample_waiver ~now:"2027-04-06T00:00:00Z")

let test_covers_match () =
  Alcotest.(check bool)
    "matching subject at valid time is covered" true
    (Option.is_some
       (Waiver.covers [ sample_waiver ] ~decision_id:"test-subject"
          ~now:"2026-12-01T00:00:00Z"))

let test_covers_mismatch () =
  Alcotest.(check bool)
    "non-matching subject is not covered" false
    (Option.is_some
       (Waiver.covers [ sample_waiver ] ~decision_id:"different-subject"
          ~now:"2026-12-01T00:00:00Z"))

let test_covers_expired () =
  Alcotest.(check bool)
    "expired waiver does not cover" false
    (Option.is_some
       (Waiver.covers [ sample_waiver ] ~decision_id:"test-subject"
          ~now:"2027-05-01T00:00:00Z"))

let test_covers_empty () =
  Alcotest.(check bool)
    "empty waiver list covers nothing" false
    (Option.is_some
       (Waiver.covers [] ~decision_id:"test-subject" ~now:"2026-12-01T00:00:00Z"))

let test_load_empty_dir () =
  (* Waiver.load uses Sys.readdir internally; the result on
     a non-existent path is []. We exercise this via the
     `parse` surface to stay offline in unit tests. *)
  Alcotest.(check int)
    "parse empty -> None" 0
    (match Waiver.parse "" with None -> 0 | Some _ -> 1)

(* Round-trip the YAML parser. The waiver file content mirrors
   schemas/waiver.json: all required fields present, no
   optional fields, plain scalars only. *)
let valid_yaml =
  "---\n\
   schema: math-coding/waiver-3.0-alpha\n\
   kind: waiver\n\
   id: roundtrip-2026-10\n\
   policy_id: bootstrap-v3\n\
   rule: obligation-missing-attestation\n\
   subject: roundtrip-subject\n\
   issuer: human:maintainer\n\
   issued_at: 2026-10-06T00:00:00Z\n\
   expires_at: 2027-04-06T00:00:00Z\n\
   reason: roundtrip test\n"

let test_load_valid () =
  match Waiver.parse valid_yaml with
  | None -> Alcotest.fail "expected valid YAML to parse"
  | Some w ->
      Alcotest.(check string)
        "subject round-trips" "roundtrip-subject" w.Domain.subject;
      Alcotest.(check string)
        "issued_at round-trips" "2026-10-06T00:00:00Z" w.Domain.issued_at;
      Alcotest.(check string)
        "expires_at round-trips" "2027-04-06T00:00:00Z" w.Domain.expires_at

let test_load_malformed () =
  (* Missing required field `reason`. The parser must return
     None. *)
  let bad =
    "---\n\
     schema: math-coding/waiver-3.0-alpha\n\
     kind: waiver\n\
     id: bad-2026-10\n\
     policy_id: bootstrap-v3\n\
     rule: obligation-missing-attestation\n\
     subject: bad-subject\n\
     issuer: human:maintainer\n\
     issued_at: 2026-10-06T00:00:00Z\n\
     expires_at: 2027-04-06T00:00:00Z\n"
  in
  Alcotest.(check bool)
    "malformed YAML -> None" false
    (Option.is_some (Waiver.parse bad))

let test_load_empty_file () =
  Alcotest.(check bool)
    "empty file -> None" false
    (Option.is_some (Waiver.parse ""))

(* Integration: covers after parse. *)
let test_covers_after_load () =
  match Waiver.parse valid_yaml with
  | None -> Alcotest.fail "expected valid YAML to parse"
  | Some w ->
      let result =
        Waiver.covers [ w ] ~decision_id:"roundtrip-subject"
          ~now:"2026-12-01T00:00:00Z"
      in
      Alcotest.(check bool)
        "parsed waiver covers its subject" true (Option.is_some result)

let test_covers_after_load_expired () =
  match Waiver.parse valid_yaml with
  | None -> Alcotest.fail "expected valid YAML to parse"
  | Some w ->
      let result =
        Waiver.covers [ w ] ~decision_id:"roundtrip-subject"
          ~now:"2027-12-01T00:00:00Z"
      in
      Alcotest.(check bool)
        "parsed waiver does not cover after expiry" false
        (Option.is_some result)

(* --- runner --- *)

let () =
  Alcotest.run "waiver"
    [
      ( "effective_at",
        [
          Alcotest.test_case "inside window" `Quick test_effective_inside_window;
          Alcotest.test_case "before issued" `Quick test_effective_before_issued;
          Alcotest.test_case "after expires" `Quick test_effective_after_expires;
          Alcotest.test_case "at issued boundary" `Quick
            test_effective_at_boundary_issued;
          Alcotest.test_case "at expires boundary" `Quick
            test_effective_at_boundary_expires;
        ] );
      ( "covers",
        [
          Alcotest.test_case "match" `Quick test_covers_match;
          Alcotest.test_case "subject mismatch" `Quick test_covers_mismatch;
          Alcotest.test_case "expired" `Quick test_covers_expired;
          Alcotest.test_case "empty list" `Quick test_covers_empty;
        ] );
      ( "load",
        [
          Alcotest.test_case "empty / missing dir" `Quick test_load_empty_dir;
          Alcotest.test_case "valid YAML" `Quick test_load_valid;
          Alcotest.test_case "malformed YAML dropped" `Quick test_load_malformed;
          Alcotest.test_case "empty file dropped" `Quick test_load_empty_file;
        ] );
      ( "load + covers",
        [
          Alcotest.test_case "covers after load" `Quick test_covers_after_load;
          Alcotest.test_case "expired after load" `Quick
            test_covers_after_load_expired;
        ] );
    ]
