open Domain

let expired ~now = function
  | None -> false
  | Some timestamp -> timestamp <= now

let current ?materials ?environment claim evidence =
  evidence.candidate_tree <> ""
  && evidence.materials_digest <> ""
  && (match materials with Some digest -> evidence.materials_digest = digest | None -> true)
  && evidence.definition_digest = definition_digest claim
  && evidence.verifier_digest = verifier_digest claim
  && (match environment with Some expected -> evidence.environment = expected | None -> evidence.environment.fingerprint <> "")
  && evidence.producer.identity <> ""
  && evidence.issued_at > 0

let rec requirement_fresh ?materials ?environment claim requirement evidence =
  current ?materials ?environment claim evidence
  && (match requirement with
      | Verifier _ ->
          evidence.control_reach = Some "subject"
          && independence_rank evidence.independence >= independence_rank Fresh_context
      | Review { minimum_independence; _ } ->
          independence_rank evidence.independence >= independence_rank minimum_independence
      | All requirements -> List.for_all (fun r -> requirement_fresh ?materials ?environment claim r evidence) requirements
      | Any requirements -> List.exists (fun r -> requirement_fresh ?materials ?environment claim r evidence) requirements)

let matches ?materials ?environment claim requirement evidence =
  evidence.claim_id = claim.id && evidence.requirement = requirement
  && requirement_fresh ?materials ?environment claim requirement evidence
