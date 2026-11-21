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
    reason = "temporary"; compensating_controls = []; recovery = "rerun";
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
  (* A decision of a human is bound to the subject and its materials, to the
     definition of the claim and to the independence of the reviewer. It is not
     bound to the machine that carried it: a change of the tool does not make
     that decision stale. A machine check is bound to the environment it ran in,
     and a review that is not independent does not hold. *)
  check "a human decision survives a change of the tool"
    (Verdict.state_of_claim ~now:10 ~environment:{ class_ = "local"; fingerprint = "other" }
       judged [ attestation ] = Holds);
  check "a human decision that is not independent does not hold"
    (Verdict.state_of_claim ~now:10 judged [ { attestation with independence = Self_attested } ] <> Holds);
  check "a machine check does not survive a change of the environment"
    (Verdict.state_of_claim ~now:10 ~environment:{ class_ = "local"; fingerprint = "other" }
       claim [ evidence ] = Outdated);
  print_endline "laws: PASS"

(* The reason is a closed vocabulary: it names the cause of a state and never
   changes the state. *)
let () =
  let reasons =
    [ Why_current; Why_never_checked; Why_source_changed; Why_materials_changed;
      Why_definition_changed; Why_verifier_changed; Why_environment_changed; Why_expired;
      Why_not_run; Why_inconclusive; Why_infrastructure_error; Why_refuted; Why_waived;
      Why_tool_changed ]
  in
  (* The vocabulary is closed: every reason has a token, every token names one
     reason, and no two reasons share a token. *)
  check "the vocabulary of the reasons is exhaustive"
    (List.length Verdict.reason_tokens = List.length reasons);
  check "every reason has a token of the closed vocabulary"
    (List.for_all
       (fun reason -> List.exists (fun (_, value) -> value = reason) Verdict.reason_tokens)
       reasons);
  check "no two reasons share a token"
    (List.length (List.sort_uniq String.compare (List.map fst Verdict.reason_tokens))
     = List.length Verdict.reason_tokens);
  check "every token names the reason it came from"
    (List.for_all
       (fun (token, reason) -> Verdict.reason_of_string token = Some reason)
       Verdict.reason_tokens);
  check "the order of the reasons names every reason once"
    (List.sort_uniq compare Verdict.priority = List.sort_uniq compare reasons);
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
  check "the changed tool explains a claim that holds" (Verdict.explains Why_tool_changed Holds);
  check "the changed tool does not explain a stale claim" (not (Verdict.explains Why_tool_changed Outdated));
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
    reason = "temporary"; compensating_controls = []; recovery = "rerun";
  } } in
  let state, reason = Verdict.explain_claim ~now:10 waived [] in
  check "an accepted risk is waived for the reason waived"
    (state = Waived && reason = Why_waived);
  (* The tool that produced the record is not the tool that reads it. The
     evidence stays applicable: a change of the binary names the difference
     and changes nothing else. *)
  let same_environment : Domain.environment = { class_ = "local"; fingerprint = "environment" } in
  let same_tool : Domain.tool = { class_ = "mathc"; fingerprint = "tool" } in
  let other_tool : Domain.tool = { class_ = "mathc"; fingerprint = "another-build" } in
  let state, reason =
    Verdict.explain_claim ~now:10 ~environment:same_environment ~tool:same_tool claim [ evidence ]
  in
  check "the same tool keeps the claim current"
    (state = Holds && reason = Why_current);
  let state, reason =
    Verdict.explain_claim ~now:10 ~environment:same_environment ~tool:other_tool claim [ evidence ]
  in
  check "a changed tool does not make the claim stale"
    (state = Holds && reason = Why_tool_changed);
  let state, reason =
    Verdict.explain_claim ~now:10 ~environment:same_environment ~tool:other_tool claim
      [ { evidence with tool = { class_ = "mathc"; fingerprint = "" } } ]
  in
  check "an unknown tool names no cause"
    (state = Holds && reason = Why_current);
  let state, reason =
    Verdict.explain_claim ~now:10 ~environment:{ class_ = "local"; fingerprint = "other" } ~tool:same_tool
      claim [ evidence ]
  in
  check "a changed environment is outdated for the reason environment-changed, tool or not"
    (state = Outdated && reason = Why_environment_changed);
  let state, reason =
    Verdict.explain_claim ~now:10 ~environment:same_environment ~tool:other_tool claim
      [ { evidence with definition_digest = "other" } ]
  in
  check "a stale reason wins over the changed tool"
    (state = Outdated && reason = Why_definition_changed);
  print_endline "reason-laws: PASS"
