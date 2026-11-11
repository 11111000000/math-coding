open Domain
open Helpers

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
  print_endline "laws: PASS"
