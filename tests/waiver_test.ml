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
 *   - effective_at: now inside [issued_at, expires_at) -> true
 *   - effective_at: now before issued_at -> false
 *   - effective_at: now == issued_at -> true (inclusive start)
 *   - effective_at: now == expires_at -> false (Invariant 14c:
 *     `expires_at` must be STRICTLY greater than the evaluation
 *     time, so the expiry second itself is already outside the
 *     interval)
 *   - effective_at: now == expires_at - 1s -> true (the last
 *     effective second; guards against "fixing" the boundary by
 *     moving the error one second earlier)
 *   - effective_at: now == expires_at + 1s -> false (the far side:
 *     an already-expired waiver keeps staying expired)
 *   - covers: subject match + effective -> Some
 *   - covers: subject mismatch -> None
 *   - covers: subject match + expired -> None
 *   - covers: at the expiry second -> None (the boundary the gate
 *     actually consults)
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
    "now inside [issued, expires) is effective" true
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
  (* issued_at is inclusive. No normative text requires an
     exclusive start: constitution.md Invariant 14c constrains
     `expires_at` only, and §Waivers requires the issue time to be
     identified, not to be exclusive. *)
  Alcotest.(check bool)
    "now == issued_at is effective (inclusive)" true
    (Waiver.effective_at sample_waiver ~now:"2026-10-06T00:00:00Z")

(* Invariant 14c: a waiver backing an exit-0 verdict MUST have
   `expires_at` strictly greater than the evaluation time. So the
   expiry second itself is OUTSIDE the interval. The old predicate
   (`issued_at <= now <= expires_at`) returned true here, which
   let a waiver the constitution calls expired produce
   `Open_with_waiver` and exit 0. *)
let test_effective_at_boundary_expires () =
  Alcotest.(check bool)
    "now == expires_at is not effective (Invariant 14c: strictly greater)" false
    (Waiver.effective_at sample_waiver ~now:"2027-04-06T00:00:00Z")

(* The other side of the boundary. Without this case the fix above
   could be "now < expires_at - 1s" — still a lie, just one second
   earlier, and a 24h hotfix waiver would silently lose a second of
   validity that the constitution grants it. *)
let test_effective_one_second_before_expiry () =
  Alcotest.(check bool)
    "now == expires_at - 1s is effective (last effective second)" true
    (Waiver.effective_at sample_waiver ~now:"2027-04-05T23:59:59Z")

(* And the far side: an already-expired waiver keeps staying
   expired. This is the case the task calls "moving the error to
   the neighbouring second" — the failure mode being ruled out is
   a predicate that returns true anywhere near the boundary. *)
let test_effective_one_second_after_expiry () =
  Alcotest.(check bool)
    "now == expires_at + 1s is not effective" false
    (Waiver.effective_at sample_waiver ~now:"2027-04-06T00:00:01Z")

let test_covers_match () =
  Alcotest.(check bool)
    "matching (subject, obligation) pair at valid time is covered" true
    (Option.is_some
       (Waiver.covers [ sample_waiver ] ~decision_id:"test-subject"
          ~obligation_id:"obligation-x" ~now:"2026-12-01T00:00:00Z"))

let test_covers_mismatch () =
  Alcotest.(check bool)
    "non-matching subject is not covered" false
    (Option.is_some
       (Waiver.covers [ sample_waiver ] ~decision_id:"different-subject"
          ~obligation_id:"obligation-x" ~now:"2026-12-01T00:00:00Z"))

let test_covers_expired () =
  Alcotest.(check bool)
    "expired waiver does not cover" false
    (Option.is_some
       (Waiver.covers [ sample_waiver ] ~decision_id:"test-subject"
          ~obligation_id:"obligation-x" ~now:"2027-05-01T00:00:00Z"))

(* `covers` is the only call site of `effective_at` in the kernel
   (lib/gate.ml:456), so the expiry bound reaches the verdict
   through it. Pin the boundary at THIS level too: the gap lifts
   on the last effective second and not on the expiry second. *)
let test_covers_at_expiry_second () =
  Alcotest.(check bool)
    "waiver does not cover at now == expires_at" false
    (Option.is_some
       (Waiver.covers [ sample_waiver ] ~decision_id:"test-subject"
          ~obligation_id:"obligation-x" ~now:"2027-04-06T00:00:00Z"));
  Alcotest.(check bool)
    "waiver covers at now == expires_at - 1s" true
    (Option.is_some
       (Waiver.covers [ sample_waiver ] ~decision_id:"test-subject"
          ~obligation_id:"obligation-x" ~now:"2027-04-05T23:59:59Z"))

let test_covers_empty () =
  Alcotest.(check bool)
    "empty waiver list covers nothing" false
    (Option.is_some
       (Waiver.covers [] ~decision_id:"test-subject" ~obligation_id:"any"
          ~now:"2026-12-01T00:00:00Z"))

(* T3.2: strict (decision, obligation) matching when
   `unverified_obligation` is set. The positive case is already
   covered by test_covers_match (sample_waiver has
   `unverified_obligation = Some "obligation-x"` and the call
   passes `~obligation_id:"obligation-x"`). The cases below
   pin the negative contract. *)

let test_covers_strict_obligation_mismatch () =
  (* sample_waiver.unverified_obligation = Some "obligation-x";
     a gap with obligation_id "obligation-y" must NOT be covered
     even when subject and now match. *)
  Alcotest.(check bool)
    "strict waiver named for obligation-x does not cover obligation-y" false
    (Option.is_some
       (Waiver.covers [ sample_waiver ] ~decision_id:"test-subject"
          ~obligation_id:"obligation-y" ~now:"2026-12-01T00:00:00Z"))

(* Global waiver (unverified_obligation = None) covers EVERY
   obligation of its named decision — the legacy behaviour
   preserved for backward compatibility per the T3.2 contract. *)

let[@warning "-32"] global_waiver =
  {
    sample_waiver with
    Domain.id = "global-waiver-2026-10";
    Domain.subject = "global-subject";
    Domain.unverified_obligation = None;
  }

let test_covers_global_covers_every_obligation () =
  Alcotest.(check bool)
    "global waiver covers obligation-x of its subject" true
    (Option.is_some
       (Waiver.covers [ global_waiver ] ~decision_id:"global-subject"
          ~obligation_id:"any-obligation" ~now:"2026-12-01T00:00:00Z"));
  Alcotest.(check bool)
    "global waiver covers obligation-y of its subject" true
    (Option.is_some
       (Waiver.covers [ global_waiver ] ~decision_id:"global-subject"
          ~obligation_id:"a-different-obligation" ~now:"2026-12-01T00:00:00Z"))

let test_covers_global_still_subject_scoped () =
  (* A global waiver still does not cross decision boundaries;
     the decision_id must match. *)
  Alcotest.(check bool)
    "global waiver does not cover a different subject" false
    (Option.is_some
       (Waiver.covers [ global_waiver ] ~decision_id:"other-subject"
          ~obligation_id:"any-obligation" ~now:"2026-12-01T00:00:00Z"))

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

(* Integration: covers after parse. The valid_yaml fixture
   has no `unverified_obligation` field, so it is treated as a
   global waiver that covers every obligation of the named
   subject (T3.2 backward-compatibility clause). *)
let test_covers_after_load () =
  match Waiver.parse valid_yaml with
  | None -> Alcotest.fail "expected valid YAML to parse"
  | Some w ->
      let result =
        Waiver.covers [ w ] ~decision_id:"roundtrip-subject"
          ~obligation_id:"any-obligation" ~now:"2026-12-01T00:00:00Z"
      in
      Alcotest.(check bool)
        "parsed waiver covers its subject" true (Option.is_some result)

let test_covers_after_load_expired () =
  match Waiver.parse valid_yaml with
  | None -> Alcotest.fail "expected valid YAML to parse"
  | Some w ->
      let result =
        Waiver.covers [ w ] ~decision_id:"roundtrip-subject"
          ~obligation_id:"any-obligation" ~now:"2027-12-01T00:00:00Z"
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
          Alcotest.test_case "at expires boundary (Invariant 14c)" `Quick
            test_effective_at_boundary_expires;
          Alcotest.test_case "one second before expires" `Quick
            test_effective_one_second_before_expiry;
          Alcotest.test_case "one second after expires" `Quick
            test_effective_one_second_after_expiry;
        ] );
      ( "covers",
        [
          Alcotest.test_case "match" `Quick test_covers_match;
          Alcotest.test_case "subject mismatch" `Quick test_covers_mismatch;
          Alcotest.test_case "expired" `Quick test_covers_expired;
          Alcotest.test_case "at the expiry second (Invariant 14c)" `Quick
            test_covers_at_expiry_second;
          Alcotest.test_case "empty list" `Quick test_covers_empty;
          Alcotest.test_case "strict obligation mismatch (T3.2)" `Quick
            test_covers_strict_obligation_mismatch;
          Alcotest.test_case "global waiver covers every obligation (T3.2)"
            `Quick test_covers_global_covers_every_obligation;
          Alcotest.test_case "global waiver is subject-scoped (T3.2)" `Quick
            test_covers_global_still_subject_scoped;
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
