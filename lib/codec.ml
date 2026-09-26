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

(* Attestation decoder. The fixture layout nests the decision/obligation
   references and digests under a "subject" object and stores the
   attestation kind under "kind_" (because top-level "kind" carries the
   document kind string "attestation"). The producer identity lives
   under "producer.identity". Everything else is flat. See
   schemas/attestation.json for the canonical layout. *)
let[@warning "-32"] parse_attestation v =
  match v with
  | Jsonl.Object ps ->
    (match Schema.take_string ps "id" with
     | Some id ->
       (match Schema.take_object ps "subject" with
        | Some sps ->
          (match Schema.take_string sps "decision" with
           | Some decision ->
             let decision_digest = Schema.take_string sps "decision_digest" in
             (match Schema.take_string sps "obligation" with
              | Some obligation ->
                let obligation_digest =
                  Schema.take_string sps "obligation_digest" in
                let candidate_tree =
                  match Schema.take_string sps "candidate_tree" with
                  | Some s -> s | None -> "" in
                let materials_digest =
                  match Schema.take_string sps "materials_digest" with
                  | Some s -> s | None -> "" in
                (match Schema.take_string ps "kind_" with
                 | Some kind_str ->
                   (match parse_attestation_kind kind_str with
                    | Some kind ->
                      (match Schema.take_object ps "producer" with
                       | Some pps ->
                         (match Schema.take_string pps "identity" with
                          | Some producer_identity ->
                            let producer_run =
                              Schema.take_string pps "run" in
                            (match Schema.take_string ps "result" with
                             | Some result_str ->
                               (match parse_result result_str with
                                | Some result ->
                                  (match Schema.take_string ps "issued_at" with
                                   | Some issued_at ->
                                     Some { Domain.id;
                                            Domain.decision;
                                            Domain.decision_revision = None;
                                            Domain.decision_digest;
                                            Domain.obligation;
                                            Domain.obligation_digest;
                                            Domain.candidate_tree;
                                            Domain.materials_digest;
                                            Domain.kind;
                                            Domain.producer_identity;
                                            Domain.producer_run;
                                            Domain.environment_class = None;
                                            Domain.result;
                                            Domain.issued_at;
                                            Domain.valid_until = None;
                                            Domain.evidence_digest = None }
                                   | _ -> None)
                                | _ -> None)
                             | _ -> None)
                          | _ -> None)
                       | _ -> None)
                    | _ -> None)
                 | _ -> None)
              | _ -> None)
           | _ -> None)
        | _ -> None)
     | _ -> None)
  | _ -> None

(* Waiver decoder. The fixture layout mirrors schemas/waiver.json:
   required scalar fields are flat (id, policy_id, rule, subject,
   issuer, issued_at, expires_at, reason); scope is an array of
   scope_target objects under "scope" (optional — waivers may cover a
   single subject without enumerating paths); unverified_obligation is
   an optional id string; compensating_controls is an optional array
   of strings. See lib/domain.ml:127-141 for the resulting record
   type. *)
let[@warning "-32"] parse_waiver v =
  match v with
  | Jsonl.Object ps ->
    (match Schema.take_string ps "id" with
     | Some id ->
       (match Schema.take_string ps "policy_id" with
        | Some policy_id ->
          (match Schema.take_string ps "rule" with
           | Some rule ->
             (match Schema.take_string ps "subject" with
              | Some subject ->
                (match Schema.take_string ps "issuer" with
                 | Some issuer ->
                   (match Schema.take_string ps "issued_at" with
                    | Some issued_at ->
                      (match Schema.take_string ps "expires_at" with
                       | Some expires_at ->
                         (match Schema.take_string ps "reason" with
                          | Some reason ->
                            let scope =
                              match Schema.take_array ps "scope" with
                              | Some xs -> parse_scope xs
                              | None -> []
                            in
                            let unverified_obligation =
                              Schema.take_string ps "unverified_obligation"
                            in
                            let compensating_controls =
                              match Schema.take_array ps "compensating_controls" with
                              | Some xs ->
                                List.filter_map
                                  (fun x ->
                                    match x with
                                    | Jsonl.String s -> Some s
                                    | _ -> None)
                                  xs
                              | None -> []
                            in
                            Some { Domain.id;
                                   Domain.policy_id;
                                   Domain.rule;
                                   Domain.subject;
                                   Domain.scope;
                                   Domain.issuer;
                                   Domain.issued_at;
                                   Domain.expires_at;
                                   Domain.reason;
                                   Domain.unverified_obligation;
                                   Domain.compensating_controls }
                         | _ -> None)
                      | _ -> None)
                   | _ -> None)
                | _ -> None)
             | _ -> None)
          | _ -> None)
       | _ -> None)
    | _ -> None)
  | _ -> None
