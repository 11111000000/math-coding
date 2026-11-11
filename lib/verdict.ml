open Domain

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

let state_of_evidence ~now ?materials ?environment claim requirement = function
  | None -> NeverChecked
  | Some evidence ->
      if evidence.issued_at > now || not (Freshness.current ?materials ?environment claim evidence) then Outdated
      else if Freshness.expired ~now evidence.valid_until then Outdated
      else
        match evidence.outcome with
        | Fail -> Refuted
        | Inconclusive | Infrastructure_error | Not_run -> Inconclusive
        | Pass when not (Freshness.requirement_fresh ?materials ?environment claim requirement evidence) -> Inconclusive
        | Pass -> Holds

let state_of_attestation ~now ?materials ?environment claim requirement = function
  | None -> NeverChecked
  | Some evidence ->
      if evidence.issued_at > now || Freshness.expired ~now evidence.valid_until then Outdated
      else if not (Freshness.current ?materials ?environment claim evidence) then Outdated
      else if not (Freshness.requirement_fresh ?materials ?environment claim requirement evidence) then Outdated
      else
        match evidence.outcome with
        | Fail -> Refuted
        | Inconclusive | Infrastructure_error | Not_run -> Inconclusive
        | Pass -> Holds

let rec judgment_requirements = function
  | Verifier _ -> None
  | Review _ as requirement -> Some requirement
  | All requirements -> Some (All (List.filter_map judgment_requirements requirements))
  | Any requirements -> Some (Any (List.filter_map judgment_requirements requirements))

let state_of_claim ~now ?materials ?environment claim evidence =
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
    | Verifier _ -> state_of_evidence ~now ?materials ?environment claim requirement (latest requirement)
    | Review _ -> state_of_attestation ~now ?materials ?environment claim requirement (latest requirement)
    | All requirements -> fold_states (List.map evaluate requirements)
    | Any requirements -> (
        let states = List.map evaluate requirements in
        if List.exists (fun state -> state = Holds) states then Holds
        else if states <> [] && List.for_all (fun state -> state = Refuted) states then Refuted
        else Inconclusive)
  in
  let requirements = match claim.register with
    | Judgment -> List.filter_map judgment_requirements claim.requirements
    | Fact | Hypothesis | Undeclared -> claim.requirements
  in
  let computed = fold_states (List.map evaluate requirements) in
  match claim.waiver, computed with
  | Some waiver, (Inconclusive | NotCheckable | Outdated | NeverChecked)
    when waiver.issued_at <= now && now < waiver.expires_at -> Waived
  | _ -> computed

let cost_of_outcome = function Pass | Fail -> 0 | Inconclusive | Infrastructure_error | Not_run -> 1
