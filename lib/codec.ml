(* Codec helpers — JSON-string <-> domain variant conversions.
   These live next to the canonicalization layer rather than in
   decision.ml so they can be reused by future parsers for
   Attestation and Waiver without duplication. *)

let[@warning "-32"] parse_result s =
  match s with
  | "pass" -> Some Domain.Pass
  | "fail" -> Some Domain.Fail
  | "inconclusive" -> Some Domain.Inconclusive
  | "infrastructure-error" -> Some Domain.InfrastructureError
  | _ -> None

let[@warning "-32"] parse_attestation_kind s =
  match s with
  | "test" -> Some `Test
  | "review" -> Some `Review
  | "build" -> Some `Build
  | "analysis" -> Some `Analysis
  | "observation" -> Some `Observation
  | _ -> None

let[@warning "-32"] parse_obligation_kind s =
  match s with
  | "invariant" -> Some `Invariant
  | "acceptance" -> Some `Acceptance
  | "recovery" -> Some `Recovery
  | "operational" -> Some `Operational
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

(* Scope target parsing — one entry; combined with scope below. *)
let[@warning "-32"] parse_scope_target v =
  match v with
  | Jsonl.Object ps ->
    (match Schema.take_string ps "kind" with
     | Some "path" ->
       (match Schema.take_string ps "path" with
        | Some path ->
          (match Schema.take_string ps "match" with
           | Some m ->
             (match parse_match m with
              | Some mt -> Some (Domain.PathTarget { path; match_ = mt })
              | None -> None)
           | _ -> Some (Domain.PathTarget { path; match_ = `Tree }))
        | _ -> None)
     | Some "capability" ->
       (match Schema.take_string ps "capability" with
        | Some c -> Some (Domain.CapabilityTarget c)
        | _ -> None)
     | Some "interface" ->
       (match Schema.take_string ps "interface" with
        | Some i -> Some (Domain.InterfaceTarget i)
        | _ -> None)
     | _ -> None)
  | _ -> None

let[@warning "-32"] parse_scope arr =
  let rec loop acc = function
    | [] -> List.rev acc
    | x :: rest ->
      (match parse_scope_target x with
       | Some t -> loop (t :: acc) rest
       | None -> loop acc rest)
  in
  loop [] arr
