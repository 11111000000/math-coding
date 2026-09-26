(* Decision / Obligation parser helpers. *)

let[@warning "-32"] parse_result s =
  match s with
  | "pass" -> Some Domain.Pass
  | "fail" -> Some Domain.Fail
  | "inconclusive" -> Some Domain.Inconclusive
  | "infrastructure-error" -> Some Domain.InfrastructureError
  | _ -> None

let[@warning "-32"] parse_kind s =
  match s with
  | "test" -> Some `Test
  | "review" -> Some `Review
  | "build" -> Some `Build
  | "analysis" -> Some `Analysis
  | "observation" -> Some `Observation
  | _ -> None

let[@warning "-32"] parse_phase s =
  match s with
  | "pre-merge" -> Some `PreMerge
  | "pre-release" -> Some `PreRelease
  | "post-release" -> Some `PostRelease
  | _ -> None

let[@warning "-32"] parse_assumption_state s =
  match s with
  | "assumed" -> Some `Assumed
  | "unknown" -> Some `Unknown
  | _ -> None

let[@warning "-32"] parse_action s =
  match s with
  | "revert" -> Some `Revert
  | "halt" -> Some `Halt
  | "review" -> Some `Review
  | "rework" -> Some `Rework
  | _ -> None

let[@warning "-32"] parse_match s =
  match s with
  | "exact" -> Some `Exact
  | "tree" -> Some `Tree
  | _ -> None

let[@warning "-32"] parse_scope_target v =
  match v with
  | Jsonl.Object ps ->
    (match List.assoc_opt "kind" ps with
     | Some (Jsonl.String "path") ->
       (match List.assoc_opt "path" ps, List.assoc_opt "match" ps with
        | Some (Jsonl.String p), Some (Jsonl.String m) ->
          (match parse_match m with
           | Some mt -> Some (Domain.PathTarget { path = p; match_ = mt })
           | None -> None)
        | _ -> None)
     | Some (Jsonl.String "capability") ->
       (match List.assoc_opt "capability" ps with
        | Some (Jsonl.String c) -> Some (Domain.CapabilityTarget c)
        | _ -> None)
     | Some (Jsonl.String "interface") ->
       (match List.assoc_opt "interface" ps with
        | Some (Jsonl.String i) -> Some (Domain.InterfaceTarget i)
        | _ -> None)
     | _ -> None)
  | _ -> None

let parse_scope arr =
  let rec loop acc = function
    | [] -> List.rev acc
    | x :: rest ->
      (match parse_scope_target x with
       | Some t -> loop (t :: acc) rest
       | None -> loop acc rest)
  in
  loop [] arr

let[@warning "-32"] parse_acceptance v =
  let[@warning "-32"] parse_one v =
    match v with
    | Jsonl.Object ps ->
      let vid = match List.assoc_opt "verifier" ps with
        | Some (Jsonl.String s) -> Some s | _ -> None in
      let result = match List.assoc_opt "result" ps with
        | Some (Jsonl.String s) -> parse_result s | _ -> None in
      let review = match List.assoc_opt "review" ps with
        | Some (Jsonl.Object rps) ->
          (match List.assoc_opt "authority" rps with
           | Some (Jsonl.String a) ->
             let ind = match List.assoc_opt "minimum_independence" rps with
               | Some (Jsonl.String s) -> Some s | _ -> None in
            Some (a, ind)
           | _ -> None)
        | _ -> None in
      let to_acceptance = function
        | `Verifier (id, r) ->
          Domain.Verifier { id = id; result = r }
        | `Review (a, b) ->
          Domain.Review { review_authority = a;
                         minimum_independence = b }
      in
      (match vid, result, review with
       | Some id, Some r, _ -> Some (to_acceptance (`Verifier (id, r)))
       | _ , _, Some (a, b) -> Some (to_acceptance (`Review (a, b)))
       | _ -> None)
    | _ -> None
  in
  match v with
  | Jsonl.Object ps ->
    (match List.assoc_opt "all" ps with
     | Some (Jsonl.Array xs) ->
       Domain.All (List.filter_map parse_one xs)
     | _ ->
       (match List.assoc_opt "any" ps with
        | Some (Jsonl.Array xs) ->
          Domain.Any (List.filter_map parse_one xs)
        | _ -> Domain.All []))
  | _ -> Domain.All []

let[@warning "-32"] parse_outcome v =
  match v with
  | Jsonl.Object ps ->
    let id = match List.assoc_opt "id" ps with
      | Some (Jsonl.String s) -> Some s | _ -> None in
    let statement = match List.assoc_opt "statement" ps with
      | Some (Jsonl.String s) -> Some s | _ -> None in
    (match id, statement with
     | Some id, Some statement -> Some { Domain.id; Domain.statement }
     | _ -> None)
  | _ -> None

let[@warning "-32"] parse_reversal v =
  match v with
  | Jsonl.Object ps ->
    let signal = match List.assoc_opt "signal" ps with
      | Some (Jsonl.String s) -> Some s | _ -> None in
    let condition = match List.assoc_opt "condition" ps with
      | Some (Jsonl.String s) -> Some s | _ -> None in
    let action = match List.assoc_opt "action" ps with
      | Some (Jsonl.String s) -> parse_action s | _ -> None in
    (match signal, action with
     | Some signal, Some action ->
       Some { Domain.signal; Domain.condition = condition;
              Domain.action }
     | _ -> None)
  | _ -> None

let rec parse_assumption v =
  match v with
  | Jsonl.Object ps ->
    let id = match List.assoc_opt "id" ps with
      | Some (Jsonl.String s) -> Some s | _ -> None in
    let state = match List.assoc_opt "state" ps with
      | Some (Jsonl.String s) -> parse_assumption_state s | _ -> None in
    let statement = match List.assoc_opt "statement" ps with
      | Some (Jsonl.String s) -> Some s | _ -> None in
    let owner = match List.assoc_opt "owner" ps with
      | Some (Jsonl.String s) -> Some s | _ -> None in
    let consequence = match List.assoc_opt "consequence_if_false" ps with
      | Some (Jsonl.String s) -> Some s | _ -> None in
    let review_on =
      match List.assoc_opt "review_on" ps with
      | Some (Jsonl.Array xs) ->
        List.filter_map
          (fun v -> match v with
            | Jsonl.Object rps ->
              let sig_ = match List.assoc_opt "signal" rps with
                | Some (Jsonl.String s) -> Some s | _ -> None in
              let date = match List.assoc_opt "date" rps with
                | Some (Jsonl.String s) -> Some s | _ -> None in
              (match sig_ with
               | Some s -> Some (s, date)
               | None -> None)
            | _ -> None)
          xs
      | _ -> [] in
    (match id, state, statement, owner with
     | Some id, Some state, Some statement, Some owner ->
       Some { Domain.id; Domain.state; Domain.statement; Domain.owner;
              Domain.consequence_if_false = consequence;
              Domain.review_on }
     | _ -> None)
  | _ -> None

and parse_obligation v =
  match v with
  | Jsonl.Object ps ->
    let id = match List.assoc_opt "id" ps with
      | Some (Jsonl.String s) -> Some s | _ -> None in
    let decision = match List.assoc_opt "decision" ps with
      | Some (Jsonl.String s) -> Some s | _ -> None in
    let outcome = match List.assoc_opt "outcome" ps with
      | Some (Jsonl.String s) -> Some s | _ -> None in
    let claim = match List.assoc_opt "claim" ps with
      | Some (Jsonl.String s) -> Some s | _ -> None in
    let subjects = match List.assoc_opt "subjects" ps with
      | Some (Jsonl.Array xs) -> parse_scope xs | _ -> [] in
    let acceptance = match List.assoc_opt "acceptance" ps with
      | Some v -> parse_acceptance v | _ -> Domain.All [] in
    let phase = match List.assoc_opt "phase" ps with
      | Some (Jsonl.String s) -> parse_phase s | _ -> None in
    let kind = match List.assoc_opt "kind" ps with
      | Some (Jsonl.String s) ->
        (match s with
         | "invariant" -> Some `Invariant
         | "acceptance" -> Some `Acceptance
         | "recovery" -> Some `Recovery
         | "operational" -> Some `Operational
         | _ -> None)
      | _ -> None in
    (match id, decision, claim, phase, kind with
     | Some id, Some decision, Some claim, Some phase, Some kind ->
       Some { Domain.id; Domain.decision; Domain.outcome;
              Domain.claim; Domain.subjects; Domain.acceptance;
              Domain.kind; Domain.phase }
     | _ -> None)
  | _ -> None

and parse_decision v =
  match v with
  | Jsonl.Object ps ->
    let id = match List.assoc_opt "id" ps with
      | Some (Jsonl.String s) -> Some s | _ -> None in
    let revision = match List.assoc_opt "revision" ps with
      | Some (Jsonl.String s) -> Some s | _ -> None in
    let parents = match List.assoc_opt "parents" ps with
      | Some (Jsonl.Array xs) ->
        List.filter_map
          (fun x -> match x with
           | Jsonl.String s -> Some s | _ -> None)
          xs
      | _ -> [] in
    let intent = match List.assoc_opt "intent" ps with
      | Some (Jsonl.Object ips) ->
        let source = match List.assoc_opt "source" ips with
          | Some (Jsonl.String s) -> Some s | _ -> None in
        let text = match List.assoc_opt "text" ips with
          | Some (Jsonl.String s) -> Some s | _ -> None in
        (match source, text with
         | Some s, Some t -> Some (s, t) | _ -> None)
      | _ -> None in
    let commitment = match List.assoc_opt "commitment" ps with
      | Some (Jsonl.String s) -> Some s | _ -> None in
    let scope = match List.assoc_opt "scope" ps with
      | Some (Jsonl.Array xs) -> parse_scope xs | _ -> [] in
    let outcomes = match List.assoc_opt "outcomes" ps with
      | Some (Jsonl.Array xs) ->
        List.filter_map parse_outcome xs
      | _ -> [] in
    let assumptions = match List.assoc_opt "assumptions" ps with
      | Some (Jsonl.Array xs) ->
        List.filter_map parse_assumption xs
      | _ -> [] in
    let obligations = match List.assoc_opt "obligations" ps with
      | Some (Jsonl.Array xs) ->
        List.filter_map parse_obligation xs
      | _ -> [] in
    let reversal = match List.assoc_opt "reversal" ps with
      | Some (Jsonl.Array xs) ->
        List.filter_map parse_reversal xs
      | _ -> [] in
    let risk = match List.assoc_opt "risk" ps with
      | Some (Jsonl.Object rps) ->
        let triggers = match List.assoc_opt "declared_triggers" rps with
          | Some (Jsonl.Array xs) ->
            List.filter_map
              (fun v -> match v with
               | Jsonl.String s -> Some s | _ -> None)
              xs
          | _ -> [] in
        let owner = match List.assoc_opt "owner" rps with
          | Some (Jsonl.String s) -> Some s | _ -> None in
        (match owner with
         | Some o -> Some { Domain.declared_triggers = triggers; Domain.owner = o }
         | None -> None)
      | _ -> None in
    (match id, revision, intent, commitment, risk with
     | Some id, Some revision, Some (src, txt), Some commitment, Some risk ->
       Some { Domain.id; Domain.revision; Domain.parents;
              Domain.intent_source = src; Domain.intent_text = txt;
              Domain.commitment; Domain.scope; Domain.outcomes;
              Domain.obligations; Domain.assumptions; Domain.reversal;
              Domain.risk;
              Domain.relations = { Domain.supersedes = [];
                                   Domain.addresses = [];
                                   Domain.depends_on = [] } }
     | _ -> None)
  | _ -> None
