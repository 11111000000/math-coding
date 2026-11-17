open Domain

let expired ~now = function
  | None -> false
  | Some timestamp -> timestamp <= now

(* Which part of the freshness binding does not hold. The binding is the
   subject and its materials, the definition of the claim, the verifier and the
   environment. The defect names the first binding that fails, so the map can
   say which part of the evidence became stale. *)
type defect =
  | Fresh
  | Materials_changed
  | Definition_changed
  | Verifier_changed
  | Environment_changed
  | Not_applicable

(* The environment binds the execution of a check, not the decision of a human.
   A review requirement is bound to the subject and its materials, to the
   definition of the claim and to the independence of the reviewer; a change of
   the machine does not make that decision stale. A claim that asks for a
   machine check is bound to the environment as well. *)
let rec binds_environment = function
  | Verifier _ -> true
  | Review _ -> false
  | All requirements | Any requirements -> List.exists binds_environment requirements

let defect ?materials ?environment ?(binds_environment = true) claim evidence =
  if evidence.issued_at <= 0 || evidence.producer.identity = "" then Not_applicable
  else if evidence.candidate_tree = "" || evidence.materials_digest = "" then Materials_changed
  else if (match materials with Some digest -> evidence.materials_digest <> digest | None -> false) then
    Materials_changed
  else if evidence.definition_digest <> definition_digest claim then Definition_changed
  else if evidence.verifier_digest <> verifier_digest claim then Verifier_changed
  else if
    binds_environment
    && (match environment with
        | Some expected -> evidence.environment <> expected
        | None -> evidence.environment.fingerprint = "")
  then Environment_changed
  else Fresh

let rec requirement_fresh ?materials ?environment claim requirement evidence =
  defect ?materials ?environment ~binds_environment:(binds_environment requirement) claim evidence = Fresh
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
