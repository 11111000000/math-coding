open Domain

(* The reason names the cause of a state. The vocabulary is closed: the map
   reports one of these reasons for every claim and nothing else. The reason
   never changes the state, it only says why the state is what it is. Current
   means fresh evidence and a passed check; never-checked means the requirement
   was never executed; source-changed means the bound source changed; the four
   *-changed reasons name the freshness binding that does not hold; expired
   means the record does not apply now; not-run means the check did not start;
   inconclusive means the observation is indeterminate; infrastructure-error
   means the run failed for infrastructural reasons; refuted means the check
   rejected the claim; waived means an accepted risk is in force; not-checkable
   means the requirement cannot be performed. *)
type reason =
  | Why_current | Why_never_checked | Why_source_changed | Why_materials_changed
  | Why_definition_changed | Why_verifier_changed | Why_environment_changed | Why_expired
  | Why_not_run | Why_inconclusive | Why_infrastructure_error | Why_refuted | Why_waived
  | Why_not_checkable

(* The token of every reason. The table is exhaustive, so the two directions
   cannot drift apart. *)
let reason_tokens =
  [ "current", Why_current; "never-checked", Why_never_checked; "source-changed", Why_source_changed;
    "materials-changed", Why_materials_changed; "definition-changed", Why_definition_changed;
    "verifier-changed", Why_verifier_changed; "environment-changed", Why_environment_changed;
    "expired", Why_expired; "not-run", Why_not_run; "inconclusive", Why_inconclusive;
    "infrastructure-error", Why_infrastructure_error; "refuted", Why_refuted; "waived", Why_waived;
    "not-checkable", Why_not_checkable ]

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
  | Inconclusive | NotCheckable | Outdated | NeverChecked | Waived -> Unknown

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
  | Why_not_run | Why_inconclusive | Why_infrastructure_error -> state = Inconclusive
  | Why_refuted -> state = Refuted
  | Why_waived -> state = Waived
  | Why_not_checkable -> state = NotCheckable

(* The most specific cause wins when several branches explain one state. The
   order follows the way the method reads the map: a refutation first, a
   changed source next, then the freshness binding, then the outcome. *)
let priority =
  [ Why_refuted; Why_source_changed; Why_materials_changed; Why_definition_changed;
    Why_verifier_changed; Why_environment_changed; Why_expired; Why_infrastructure_error;
    Why_not_run; Why_inconclusive; Why_never_checked; Why_not_checkable; Why_waived; Why_current ]

(* The reason of a state when no branch explains it. *)
let generic state =
  match state with
  | Holds -> Why_current | Refuted -> Why_refuted | Inconclusive -> Why_inconclusive
  | NotCheckable -> Why_not_checkable | Outdated -> Why_expired | NeverChecked -> Why_never_checked
  | Waived -> Why_waived

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

(* The state of a requirement together with the reason of that state. The state
   is the one the method computes; the reason only names its cause. The unmet
   condition tells what a record means when the declared condition of the
   requirement is not met. A human attestation checks that condition before
   the outcome of the record, a machine check only after a pass. *)
let explain_record ~requirement_first ~unmet ~now ?materials ?environment claim requirement = function
  | None -> (NeverChecked, Why_never_checked)
  | Some evidence ->
      if evidence.issued_at > now then (Outdated, Why_expired)
      else
        match reason_of_defect
                (Freshness.defect ?materials ?environment
                   ~binds_environment:(Freshness.binds_environment requirement) claim evidence) with
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
              | Inconclusive -> (Inconclusive, Why_inconclusive)
              | Pass ->
                  if Freshness.requirement_fresh ?materials ?environment claim requirement evidence
                  then (Holds, Why_current) else unmet

let explain_evidence ~now ?materials ?environment claim requirement evidence =
  explain_record ~requirement_first:false ~unmet:(Inconclusive, Why_inconclusive) ~now ?materials ?environment claim requirement evidence

let explain_attestation ~now ?materials ?environment claim requirement evidence =
  explain_record ~requirement_first:true ~unmet:(Outdated, Why_verifier_changed) ~now ?materials ?environment claim requirement evidence

let rec judgment_requirements = function
  | Verifier _ -> None
  | Review _ as requirement -> Some requirement
  | All requirements -> Some (All (List.filter_map judgment_requirements requirements))
  | Any requirements -> Some (Any (List.filter_map judgment_requirements requirements))

let explain_claim ~now ?materials ?environment claim evidence =
  let latest requirement =
    List.filter (fun e -> e.claim_id = claim.id && e.requirement = requirement) evidence
    |> List.fold_left (fun latest evidence ->
      match latest with
      | Some current when current.issued_at > evidence.issued_at -> latest
      | _ -> Some evidence) None
  in
  let rec fold_states states =
    if states = [] then NeverChecked
    else if List.exists (fun s -> s = Refuted) states then Refuted
    else if List.exists (fun s -> s = NotCheckable) states then NotCheckable
    else if List.for_all (fun s -> s = Holds) states then Holds
    else if List.for_all (fun s -> s = NeverChecked) states then NeverChecked
    else if List.for_all (fun s -> s = Outdated) states then Outdated
    else Inconclusive
  in
  let rec evaluate requirement =
    match requirement with
    | Verifier _ -> explain_evidence ~now ?materials ?environment claim requirement (latest requirement)
    | Review _ -> explain_attestation ~now ?materials ?environment claim requirement (latest requirement)
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
  let requirements = match claim.register with
    | Judgment -> List.filter_map judgment_requirements claim.requirements
    | Fact | Hypothesis | Undeclared -> claim.requirements
  in
  let explained = List.map evaluate requirements in
  let computed = fold_states (List.map fst explained) in
  let reason = compose_reason computed (List.map snd explained) in
  match claim.waiver, computed with
  | Some waiver, (Inconclusive | NotCheckable | Outdated | NeverChecked)
    when waiver.issued_at <= now && now < waiver.expires_at -> (Waived, Why_waived)
  | _ -> (computed, reason)

let state_of_evidence ~now ?materials ?environment claim requirement evidence =
  fst (explain_evidence ~now ?materials ?environment claim requirement evidence)

let state_of_attestation ~now ?materials ?environment claim requirement evidence =
  fst (explain_attestation ~now ?materials ?environment claim requirement evidence)

let state_of_claim ~now ?materials ?environment claim evidence =
  fst (explain_claim ~now ?materials ?environment claim evidence)

let cost_of_outcome = function Pass | Fail -> 0 | Inconclusive | Infrastructure_error | Not_run -> 1
