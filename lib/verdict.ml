open Domain

(* The reason names the cause of a state. The vocabulary is closed: the map
   reports one of these reasons and nothing else, and the reason never changes
   the state - it only says why the state is what it is. Current means fresh
   evidence and a passed check; the *-changed reasons name the freshness
   binding that does not hold; not-run means the check did not start;
   inconclusive means the observation is indeterminate; infrastructure-error
   means the run failed for infrastructural reasons; refuted means the check
   rejected the claim; waived means an accepted risk is in force; tool-changed
   means the tool that wrote the evidence is not the tool that reads it;
   copy-failed means the check could not run in the copy of the control, so the
   control proves nothing. *)
type reason =
  | Why_current | Why_never_checked | Why_source_changed | Why_materials_changed
  | Why_definition_changed | Why_verifier_changed | Why_environment_changed | Why_expired
  | Why_not_run | Why_inconclusive | Why_infrastructure_error | Why_refuted | Why_waived
  | Why_tool_changed | Why_copy_failed | Why_observed

(* The token of every reason. The table is exhaustive, so the two directions
   cannot drift apart. *)
let reason_tokens =
  [ "current", Why_current; "never-checked", Why_never_checked; "source-changed", Why_source_changed;
    "materials-changed", Why_materials_changed; "definition-changed", Why_definition_changed;
    "verifier-changed", Why_verifier_changed; "environment-changed", Why_environment_changed;
    "expired", Why_expired; "not-run", Why_not_run; "inconclusive", Why_inconclusive;
    "infrastructure-error", Why_infrastructure_error; "refuted", Why_refuted; "waived", Why_waived;
    "tool-changed", Why_tool_changed; "copy-failed", Why_copy_failed;
    "observed", Why_observed ]

let reason_to_string reason = fst (List.find (fun (_, value) -> value = reason) reason_tokens)
let reason_of_string token = Option.map snd (List.find_opt (fun (name, _) -> name = token) reason_tokens)

(* The human map prints the reason in words, the machine map prints the token.
   Both name the same cause. *)
let reason_to_words reason = String.map (fun ch -> if ch = '-' then ' ' else ch) (reason_to_string reason)

let combine a b =
  match a, b with
  | Red, _ | _, Red -> Red
  | Unknown, _ | _, Unknown -> Unknown
  | Vacant, x | x, Vacant -> x
  | Green, Green -> Green

let verdict_of_state = function
  | Holds -> Green
  | Refuted -> Red
  | Inconclusive | Outdated | NeverChecked | Waived | Observed -> Unknown

let verdict_of_states states =
  match states with
  | [] -> Vacant
  | _ -> List.fold_left (fun v s -> combine v (verdict_of_state s)) Green states

(* A reason explains the states it can be the cause of. A stale branch among
   several makes the whole claim inconclusive, so the staleness reasons explain
   an inconclusive claim as well. *)
let explains reason state =
  match reason with
  | Why_current -> state = Holds
  | Why_never_checked -> state = NeverChecked || state = Inconclusive
  | Why_source_changed | Why_materials_changed | Why_definition_changed | Why_verifier_changed
  | Why_environment_changed | Why_expired -> state = Outdated || state = Inconclusive
  | Why_not_run | Why_inconclusive | Why_infrastructure_error | Why_copy_failed -> state = Inconclusive
  | Why_refuted -> state = Refuted
  | Why_waived -> state = Waived
  | Why_tool_changed -> state = Holds
  | Why_observed -> state = Observed

(* The most specific cause wins when several branches explain one state. The
   order follows the way the method reads the map: a refutation first, a
   changed source next, then the freshness binding, then the outcome. The tool
   comes after the staleness reasons and before the current one: a stale branch
   still wins over it, and a fresh record made by another tool is not an
   ordinary current record. *)
let priority =
  [ Why_refuted; Why_source_changed; Why_materials_changed; Why_definition_changed;
    Why_verifier_changed; Why_environment_changed; Why_expired; Why_tool_changed;
    Why_copy_failed; Why_infrastructure_error; Why_not_run; Why_inconclusive;
    Why_never_checked; Why_waived; Why_current; Why_observed ]

(* The reason of a state when no branch explains it. *)
let generic state =
  match state with
  | Holds -> Why_current | Refuted -> Why_refuted | Inconclusive -> Why_inconclusive
  | Outdated -> Why_expired | NeverChecked -> Why_never_checked | Waived -> Why_waived
  | Observed -> Why_observed

let compose_reason state reasons =
  let explaining = List.filter (fun reason -> explains reason state) reasons in
  match List.find_opt (fun reason -> List.mem reason explaining) priority with
  | Some reason -> reason
  | None -> generic state

(* The freshness defect and the reason it produces. A fresh record explains
   nothing by itself: the outcome of the observation decides. *)
let reason_of_defect = function
  | Freshness.Fresh -> None
  | Freshness.Materials_changed -> Some Why_materials_changed
  | Freshness.Definition_changed -> Some Why_definition_changed
  | Freshness.Verifier_changed -> Some Why_verifier_changed
  | Freshness.Environment_changed -> Some Why_environment_changed
  | Freshness.Not_applicable -> Some Why_expired

(* The tool that produced the record is not the tool that reads it. The tool is
   an observer, not a subject: the evidence stays applicable when the tool
   changes, so the state does not change and only the reason names the
   difference. A record whose tool is unknown names nothing: we cannot say
   that the tool changed when we do not know which tool wrote the record. *)
let tool_changed ?tool evidence =
  match tool with
  | Some current ->
      evidence.tool.fingerprint <> "" && current.fingerprint <> ""
      && current <> evidence.tool
  | None -> false

(* The reason of a fresh record: current, or tool-changed when the tool that
   produced it is not the tool that reads it. *)
let why_current ?tool evidence =
  if tool_changed ?tool evidence then Why_tool_changed else Why_current

(* The state of a requirement together with the reason of that state. The state
   is the one the method computes; the reason only names its cause. The unmet
   condition tells what a record means when the declared condition of the
   requirement is not met. A human attestation checks that condition before
   the outcome of the record, a machine check only after a pass. *)
let explain_record ~requirement_first ~unmet ~now ?materials ?environment ?tool claim requirement = function
  | None -> (NeverChecked, Why_never_checked)
  | Some evidence ->
      if evidence.issued_at > now then (Outdated, Why_expired)
      else
        match reason_of_defect
                (Freshness.defect ?materials ?environment
                   ~binds_machine:(Freshness.binds_machine requirement) claim evidence) with
        | Some reason -> (Outdated, reason)
        | None ->
            if Freshness.expired ~now evidence.valid_until then (Outdated, Why_expired)
            else if
              requirement_first
              && not (Freshness.requirement_fresh ?materials ?environment claim requirement evidence)
            then unmet
            else
              match evidence.outcome with
              | Fail -> (Refuted, Why_refuted)
              | Not_run -> (Inconclusive, Why_not_run)
              | Infrastructure_error -> (Inconclusive, Why_infrastructure_error)
              | Inconclusive ->
                  (* A copy that fails on its own names itself. *)
                  (Inconclusive,
                   (match evidence.control_reach with
                    | Some "copy-failed" -> Why_copy_failed
                    | _ -> Why_inconclusive))
              | Pass ->
                  if Freshness.requirement_fresh ?materials ?environment claim requirement evidence
                  then (Holds, why_current ?tool evidence)
                  else if
                    (match requirement with Verifier _ -> evidence.control_reach = None | _ -> false)
                    && independence_rank evidence.independence >= independence_rank Fresh_context
                  then (Observed, Why_observed)
                  else unmet

let explain_evidence ~now ?materials ?environment ?tool claim requirement evidence =
  explain_record ~requirement_first:false ~unmet:(Inconclusive, Why_inconclusive) ~now ?materials ?environment ?tool claim requirement evidence

let explain_attestation ~now ?materials ?environment ?tool claim requirement evidence =
  explain_record ~requirement_first:true ~unmet:(Outdated, Why_verifier_changed) ~now ?materials ?environment ?tool claim requirement evidence

let rec judgment_requirements = function
  | Verifier _ -> None
  | Review _ as requirement -> Some requirement
  | All requirements -> Some (All (List.filter_map judgment_requirements requirements))
  | Any requirements -> Some (Any (List.filter_map judgment_requirements requirements))

(* The last record for a requirement: by time of issue, and then by position. *)
let latest (claim : claim) requirement records =
  List.filter (fun e -> e.claim_id = claim.id && e.requirement = requirement) records
  |> List.fold_left (fun found record ->
       match found with
       | Some current when current.issued_at > record.issued_at -> found
       | _ -> Some record) None

(* The state and the reason of a claim. The requirements that are evaluated
   are the ones of the claim, unless a subset is named: a branch is judged
   against the definition of the whole claim. *)
let explain_claim ~now ?materials ?environment ?tool ?requirements claim evidence =
  let last requirement = latest claim requirement evidence in
  let rec fold_states states =
    if states = [] then NeverChecked
    else if List.exists (fun s -> s = Refuted) states then Refuted
    else if List.for_all (fun s -> s = Holds) states then Holds
    else if List.for_all (fun s -> s = NeverChecked) states then NeverChecked
    else if List.for_all (fun s -> s = Outdated) states then Outdated
    else if List.for_all (fun s -> s = Observed) states then Observed
    else Inconclusive
  in
  let rec evaluate requirement =
    match requirement with
    | Verifier _ -> explain_evidence ~now ?materials ?environment ?tool claim requirement (last requirement)
    | Review _ -> explain_attestation ~now ?materials ?environment ?tool claim requirement (last requirement)
    | All requirements ->
        let explained = List.map evaluate requirements in
        let state = fold_states (List.map fst explained) in
        (state, compose_reason state (List.map snd explained))
    | Any requirements ->
        let explained = List.map evaluate requirements in
        let states = List.map fst explained in
        let state =
          if List.exists (fun state -> state = Holds) states then Holds
          else if states <> [] && List.for_all (fun state -> state = Refuted) states then Refuted
          else Inconclusive
        in
        (state, compose_reason state (List.map snd explained))
  in
  let requirements = match requirements with
    | Some requirements -> requirements
    | None -> (
        match claim.register with
        | Judgment -> List.filter_map judgment_requirements claim.requirements
        | Fact | Hypothesis | Undeclared -> claim.requirements)
  in
  let explained = List.map evaluate requirements in
  let computed = fold_states (List.map fst explained) in
  let reason = compose_reason computed (List.map snd explained) in
  match claim.waiver, computed with
  | Some waiver, (Inconclusive | Outdated | NeverChecked)
    when waiver.issued_at <= now && now < waiver.expires_at -> (Waived, Why_waived)
  | _ -> (computed, reason)

let state_of_evidence ~now ?materials ?environment ?tool claim requirement evidence =
  fst (explain_evidence ~now ?materials ?environment ?tool claim requirement evidence)

let state_of_attestation ~now ?materials ?environment ?tool claim requirement evidence =
  fst (explain_attestation ~now ?materials ?environment ?tool claim requirement evidence)

let state_of_claim ~now ?materials ?environment ?tool claim evidence =
  fst (explain_claim ~now ?materials ?environment ?tool claim evidence)

let cost_of_outcome = function Pass | Fail -> 0 | Inconclusive | Infrastructure_error | Not_run -> 1
