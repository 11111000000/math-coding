open Domain
open Helpers
open Verdict

let () =
  let values = [ Green; Red; Unknown; Vacant ] in
  List.iter
    (fun a ->
      List.iter
        (fun b -> check "combine is commutative" (Verdict.combine a b = Verdict.combine b a))
        values)
    values;
  List.iter
    (fun a ->
      List.iter
        (fun b ->
          List.iter
            (fun c ->
              check "combine is associative"
                (Verdict.combine (Verdict.combine a b) c = Verdict.combine a (Verdict.combine b c)))
            values)
        values)
    values;
  check "green is identity" (Verdict.combine Green Red = Red && Verdict.combine Green Unknown = Unknown);
  check "red absorbs" (Verdict.combine Red Unknown = Red);
  check "empty is vacant" (Verdict.verdict_of_states [] = Vacant);
  let evidence = evidence claim in
  check "fresh machine evidence holds" (Verdict.state_of_evidence ~now:10 claim (Verifier "grep -q expected subject.txt") (Some evidence) = Holds);
  check "missing control is inconclusive"
    (Verdict.state_of_evidence ~now:10 claim (Verifier "grep -q expected subject.txt")
       (Some { evidence with control_reach = None }) = Inconclusive);
  check "elsewhere control is inconclusive"
    (Verdict.state_of_evidence ~now:10 claim (Verifier "grep -q expected subject.txt")
       (Some { evidence with control_reach = Some "elsewhere" }) = Inconclusive);
  check "self attestation is not independent"
    (Verdict.state_of_evidence ~now:10 claim (Verifier "grep -q expected subject.txt")
       (Some { evidence with independence = Self_attested }) = Inconclusive);
  check "definition mismatch is outdated"
    (Verdict.state_of_evidence ~now:10 claim (Verifier "grep -q expected subject.txt")
       (Some { evidence with definition_digest = "other" }) = Outdated);
  check "verifier mismatch is outdated"
    (Verdict.state_of_evidence ~now:10 claim (Verifier "grep -q expected subject.txt")
       (Some { evidence with verifier_digest = "other" }) = Outdated);
  check "environment missing is outdated"
    (Verdict.state_of_evidence ~now:10 claim (Verifier "grep -q expected subject.txt")
       (Some { evidence with environment = { class_ = "local"; fingerprint = "" } }) = Outdated);
  check "a different nonempty environment is outdated"
    (Verdict.state_of_evidence ~now:10 ~environment:{ class_ = "local"; fingerprint = "different" }
       claim (Verifier "grep -q expected subject.txt") (Some evidence) = Outdated);
  check "expired evidence is outdated"
    (Verdict.state_of_evidence ~now:10 claim (Verifier "grep -q expected subject.txt")
       (Some { evidence with valid_until = Some 10 }) = Outdated);
  let waived = { claim with waiver = Some {
    gap = claim.id; scope = claim.scope; issuer = "owner"; issued_at = 1; expires_at = 20;
    reason = "temporary"; compensating_controls = []; recovery = "rerun"; review_on = [];
  } } in
  check "waiver is bounded" (Verdict.state_of_claim ~now:10 waived [] = Waived);
  check "expired waiver does not cover" (Verdict.state_of_claim ~now:20 waived [] = NeverChecked);
  let alternatives = { claim with requirements = [ Any [ Verifier "missing"; Verifier "grep -q expected subject.txt" ] ] } in
  let alternative_evidence = { evidence with definition_digest = definition_digest alternatives; verifier_digest = verifier_digest alternatives } in
  check "any alternative can hold" (Verdict.state_of_claim ~now:10 alternatives [ alternative_evidence ] = Holds);
  check "any alternatives without evidence do not hold" (Verdict.state_of_claim ~now:10 alternatives [] = Inconclusive);
  let failed = { evidence with outcome = Fail } in
  check "a later failure at the same timestamp wins"
    (Verdict.state_of_claim ~now:10 ~materials:"materials" claim [ evidence; failed ] = Refuted);
  check "a later pass at the same timestamp wins"
    (Verdict.state_of_claim ~now:10 ~materials:"materials" claim [ failed; evidence ] = Holds);
  let judged = { claim with register = Judgment; requirements = [ Review { authority = "owner"; minimum_independence = External } ] } in
  let review_requirement = Review { authority = "owner"; minimum_independence = External } in
  let attestation = { evidence with
    requirement = review_requirement;
    definition_digest = definition_digest judged;
    verifier_digest = verifier_digest judged;
    producer = { class_ = "human"; identity = "owner"; run = None };
    independence = External;
  } in
  check "machine-only judgment is not established"
    (Verdict.state_of_claim ~now:10 judged [ evidence ] = NeverChecked);
  check "external human review can establish judgment"
    (Verdict.state_of_claim ~now:10 judged [ attestation ] = Holds);
  print_endline "laws: PASS"

(* The reason is a closed vocabulary: it names the cause of a state and never
   changes the state. *)
let () =
  let reasons =
    [ Why_current; Why_never_checked; Why_source_changed; Why_materials_changed;
      Why_definition_changed; Why_verifier_changed; Why_environment_changed; Why_expired;
      Why_not_run; Why_inconclusive; Why_infrastructure_error; Why_refuted; Why_waived;
      Why_not_checkable ]
  in
  List.iter
    (fun reason ->
      let token = Verdict.reason_to_string reason in
      check "a reason has a token of the closed vocabulary"
        (Verdict.reason_of_string token = Some reason);
      check "a token names the reason it came from"
        (Verdict.reason_to_words reason <> ""))
    reasons;
  check "an unknown reason is not a reason" (Verdict.reason_of_string "invented" = None);
  check "a reason explains the state it causes" (Verdict.explains Why_current Holds);
  check "a reason does not explain another state" (not (Verdict.explains Why_current Refuted));
  check "a stale reason explains an outdated state" (Verdict.explains Why_materials_changed Outdated);
  check "a stale reason explains an inconclusive state" (Verdict.explains Why_expired Inconclusive);
  let evidence = evidence claim in
  let state, reason =
    Verdict.explain_claim ~now:10 claim [ evidence ]
  in
  check "a fresh claim holds for the reason current"
    (state = Holds && reason = Why_current);
  let state, reason =
    Verdict.explain_claim ~now:10 ~materials:"materials" claim [ { evidence with materials_digest = "other" } ]
  in
  check "changed materials are outdated for the reason materials-changed"
    (state = Outdated && reason = Why_materials_changed);
  let state, reason =
    Verdict.explain_claim ~now:10 claim [ { evidence with definition_digest = "other" } ]
  in
  check "a changed definition is outdated for the reason definition-changed"
    (state = Outdated && reason = Why_definition_changed);
  let state, reason =
    Verdict.explain_claim ~now:10 claim [ { evidence with verifier_digest = "other" } ]
  in
  check "a changed verifier is outdated for the reason verifier-changed"
    (state = Outdated && reason = Why_verifier_changed);
  let state, reason =
    Verdict.explain_claim ~now:10 ~environment:{ class_ = "local"; fingerprint = "other" } claim [ evidence ]
  in
  check "a changed environment is outdated for the reason environment-changed"
    (state = Outdated && reason = Why_environment_changed);
  let state, reason = Verdict.explain_claim ~now:10 claim [ { evidence with valid_until = Some 10 } ] in
  check "an expired record is outdated for the reason expired"
    (state = Outdated && reason = Why_expired);
  let state, reason = Verdict.explain_claim ~now:10 claim [ { evidence with outcome = Fail } ] in
  check "a rejected claim is refuted for the reason refuted"
    (state = Refuted && reason = Why_refuted);
  let state, reason = Verdict.explain_claim ~now:10 claim [ { evidence with outcome = Not_run } ] in
  check "a check that did not start is inconclusive for the reason not-run"
    (state = Inconclusive && reason = Why_not_run);
  let state, reason =
    Verdict.explain_claim ~now:10 claim [ { evidence with outcome = Infrastructure_error } ]
  in
  check "an infrastructure error is inconclusive for the reason infrastructure-error"
    (state = Inconclusive && reason = Why_infrastructure_error);
  let state, reason = Verdict.explain_claim ~now:10 claim [] in
  check "a claim without evidence is never-checked"
    (state = NeverChecked && reason = Why_never_checked);
  let waived = { claim with waiver = Some {
    gap = claim.id; scope = claim.scope; issuer = "owner"; issued_at = 1; expires_at = 20;
    reason = "temporary"; compensating_controls = []; recovery = "rerun"; review_on = [];
  } } in
  let state, reason = Verdict.explain_claim ~now:10 waived [] in
  check "an accepted risk is waived for the reason waived"
    (state = Waived && reason = Why_waived);
  print_endline "reason-laws: PASS"
