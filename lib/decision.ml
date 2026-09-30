(* Decision / Obligation decoder. *)

(* Parse a single obligation acceptance item (verifier OR review). *)
let[@warning "-32"] parse_verifier v =
  match v with
  | Jsonl.Object ps -> (
      let id =
        match Schema.take_string ps "verifier" with Some s -> s | None -> ""
      in
      let rstr =
        match Schema.take_string ps "result" with Some s -> s | None -> ""
      in
      if id = "" then None
      else
        match Codec.parse_result rstr with
        | Some result -> Some (Domain.Verifier { id; result })
        | None -> None)
  | _ -> None

let[@warning "-32"] parse_review v =
  match v with
  | Jsonl.Object ps ->
      let rps =
        match Schema.take_object ps "review" with Some o -> o | None -> []
      in
      let authority =
        match Schema.take_string rps "authority" with Some s -> s | None -> ""
      in
      if authority = "" then None
      else
        let ind = Schema.take_string rps "minimum_independence" in
        Some
          (Domain.Review
             { review_authority = authority; minimum_independence = ind })
  | _ -> None

let[@warning "-32"] parse_acceptance_item v =
  match v with
  | Jsonl.Object ps
    when Schema.take_string ps "verifier" <> None
         && Schema.take_string ps "result" <> None ->
      parse_verifier v
  | _ -> ( match parse_review v with Some a -> Some a | None -> None)

(* Shape of a single acceptance item, exposed for diagnostic
   emission. An item with both verifier and review fields is
   ambiguous (A0 separation deficit: two distinct attestation
   sources in the same object) and the conformance runner
   surfaces MC-AMBIGUOUS-ACCEPTANCE per spec/constitution.md
   "Honest status" and OCAML_BEST_PRACTICES §9.1. *)
type acceptance_shape =
  | ShapeVerifier
  | ShapeReview
  | ShapeAmbiguous
  | ShapeMalformed
  | ShapeEmpty

let[@warning "-32"] classify_acceptance_item v =
  match v with
  | Jsonl.Object ps -> (
      let has_verifier_fields =
        Schema.take_string ps "verifier" <> None
        && Schema.take_string ps "result" <> None
      in
      let has_review_field = Schema.take_object ps "review" <> None in
      match (has_verifier_fields, has_review_field) with
      | true, true -> ShapeAmbiguous
      | true, false -> (
          match parse_verifier v with
          | Some _ -> ShapeVerifier
          | None -> ShapeMalformed)
      | false, true -> (
          match parse_review v with
          | Some _ -> ShapeReview
          | None -> ShapeMalformed)
      | false, false -> ShapeEmpty)
  | _ -> ShapeEmpty

(* Per-item position-tagged shape list. Used by the conformance
   runner to emit MC-AMBIGUOUS-ACCEPTANCE per item rather than
   silently dropping the review half. *)
let[@warning "-32"] collect_shapes xs =
  let[@warning "-32"] rec loop i acc = function
    | [] -> List.rev acc
    | v :: rest -> loop (i + 1) ((i, classify_acceptance_item v) :: acc) rest
  in
  loop 0 [] xs

let parse_acceptance v =
  match v with
  | Jsonl.Object ps -> (
      match Schema.take_array ps "all" with
      | Some xs -> Domain.All (List.filter_map parse_acceptance_item xs)
      | None -> (
          match Schema.take_array ps "any" with
          | Some xs -> Domain.Any (List.filter_map parse_acceptance_item xs)
          | _ -> Domain.All []))
  | _ -> Domain.All []

(* `parse_acceptance_with_shapes` is the diagnostic-aware variant:
   it returns both the Domain.acceptance (verifier+review only,
   never ambiguous — ambiguous items are dropped) and the per-item
   shape list for diagnostic emission. Callers that want to surface
   MC-AMBIGUOUS-ACCEPTANCE should iterate the shape list and emit
   one diagnostic per ShapeAmbiguous / ShapeMalformed item. *)
let[@warning "-32"] parse_acceptance_with_shapes v =
  match v with
  | Jsonl.Object ps -> (
      match Schema.take_array ps "all" with
      | Some xs ->
          let shapes = collect_shapes xs in
          (Domain.All (List.filter_map parse_acceptance_item xs), shapes)
      | None -> (
          match Schema.take_array ps "any" with
          | Some xs ->
              let shapes = collect_shapes xs in
              (Domain.Any (List.filter_map parse_acceptance_item xs), shapes)
          | _ -> (Domain.All [], [])))
  | _ -> (Domain.All [], [])

let[@warning "-32"] parse_outcome v =
  match v with
  | Jsonl.Object ps -> (
      match Schema.take_string ps "id" with
      | Some id -> (
          match Schema.take_string ps "statement" with
          | Some statement -> Some { Domain.id; Domain.statement }
          | _ -> None)
      | _ -> None)
  | _ -> None

let[@warning "-32"] parse_reversal v =
  match v with
  | Jsonl.Object ps ->
      let signal =
        match Schema.take_string ps "signal" with Some s -> s | None -> ""
      in
      if signal = "" then None
      else
        let condition = Schema.take_string ps "condition" in
        let action_str =
          match Schema.take_string ps "action" with Some s -> s | None -> ""
        in
        let action =
          match Codec.parse_action action_str with
          | Some a -> a
          | None -> `Review
        in
        Some { Domain.signal; condition; Domain.action }
  | _ -> None

let rec parse_assumption v =
  match v with
  | Jsonl.Object ps -> (
      match Schema.take_string ps "id" with
      | Some id -> (
          match Schema.take_string ps "state" with
          | Some state_str -> (
              match Codec.parse_assumption_state state_str with
              | Some state -> (
                  match Schema.take_string ps "statement" with
                  | Some statement -> (
                      match Schema.take_string ps "owner" with
                      | Some owner ->
                          let consequence =
                            Schema.take_string ps "consequence_if_false"
                          in
                          let review_on =
                            match Schema.take_array ps "review_on" with
                            | Some xs ->
                                List.filter_map
                                  (fun v ->
                                    match v with
                                    | Jsonl.Object rps -> (
                                        match
                                          Schema.take_string rps "signal"
                                        with
                                        | Some s ->
                                            let date =
                                              Schema.take_string rps "date"
                                            in
                                            Some (s, date)
                                        | _ -> None)
                                    | _ -> None)
                                  xs
                            | _ -> []
                          in
                          let evidence = Schema.take_string ps "evidence" in
                          (* confidence is typed as float option;
                             the JSON parser only exposes Int,
                             so leave None for now. A future parser
                             update (Phase 2D) can wire up Float
                             reading when the Jsonl module gains it. *)
                          let confidence = None in
                          Some
                            {
                              Domain.id;
                              Domain.state;
                              Domain.statement;
                              Domain.owner;
                              Domain.consequence_if_false = consequence;
                              Domain.review_on;
                              Domain.evidence;
                              Domain.confidence;
                            }
                      | _ -> None)
                  | _ -> None)
              | _ -> None)
          | _ -> None)
      | _ -> None)
  | _ -> None

and parse_obligation_domain v =
  match v with
  | Jsonl.Object ps -> (
      match Schema.take_string ps "obligation_kind" with
      | Some obligation_kind ->
          let path_namespace =
            match Schema.take_string ps "path_namespace" with
            | Some s -> s
            | None -> ""
          in
          Some { Domain.obligation_kind; Domain.path_namespace }
      | _ -> None)
  | _ -> None

and parse_obligation v =
  match v with
  | Jsonl.Object ps ->
      let id =
        match Schema.take_string ps "id" with Some s -> s | None -> ""
      in
      let decision =
        match Schema.take_string ps "decision" with Some s -> s | None -> ""
      in
      let claim =
        match Schema.take_string ps "claim" with Some s -> s | None -> ""
      in
      if id = "" || decision = "" || claim = "" then None
      else
        let outcome = Schema.take_string ps "outcome" in
        let subjects =
          match Schema.take_array ps "subjects" with
          | Some xs -> Codec.parse_scope xs
          | _ -> []
        in
        let acceptance =
          match Schema.take_object ps "acceptance" with
          | Some a -> parse_acceptance (Jsonl.Object a)
          | _ -> parse_acceptance v
        in
        let phase_str =
          match Schema.take_string ps "phase" with
          | Some s -> s
          | None -> "pre-merge"
        in
        let phase =
          match Codec.parse_phase phase_str with
          | Some p -> p
          | None -> `PreMerge
        in
        let kind_str =
          match Schema.take_string ps "kind" with
          | Some s -> s
          | None -> "invariant"
        in
        let kind =
          match Codec.parse_obligation_kind kind_str with
          | Some k -> k
          | None -> `Invariant
        in
        let obligation_domain =
          match Schema.take_object ps "obligation_domain" with
          | Some ops -> parse_obligation_domain (Jsonl.Object ops)
          | _ -> None
        in
        Some
          {
            Domain.id;
            decision;
            Domain.outcome;
            Domain.claim;
            subjects;
            Domain.acceptance;
            Domain.kind;
            Domain.phase;
            Domain.obligation_domain;
          }
  | _ -> None

and parse_decision v =
  match v with
  | Jsonl.Object ps -> (
      match Schema.take_string ps "id" with
      | Some id -> (
          match Schema.take_string ps "revision" with
          | Some revision -> (
              let parents =
                match Schema.take_array ps "parents" with
                | Some xs ->
                    List.filter_map
                      (fun x ->
                        match x with Jsonl.String s -> Some s | _ -> None)
                      xs
                | _ -> []
              in
              match Schema.take_object ps "intent" with
              | Some ips -> (
                  match Schema.take_string ips "source" with
                  | Some source -> (
                      match Schema.take_string ips "text" with
                      | Some text -> (
                          match Schema.take_string ps "commitment" with
                          | Some commitment -> (
                              let scope =
                                match Schema.take_array ps "scope" with
                                | Some xs -> Codec.parse_scope xs
                                | _ -> []
                              in
                              let outcomes =
                                match Schema.take_array ps "outcomes" with
                                | Some xs -> List.filter_map parse_outcome xs
                                | _ -> []
                              in
                              let assumptions =
                                match Schema.take_array ps "assumptions" with
                                | Some xs -> List.filter_map parse_assumption xs
                                | _ -> []
                              in
                              let obligations =
                                match Schema.take_array ps "obligations" with
                                | Some xs -> List.filter_map parse_obligation xs
                                | _ -> []
                              in
                              let reversal =
                                match Schema.take_array ps "reversal" with
                                | Some xs -> List.filter_map parse_reversal xs
                                | _ -> []
                              in
                              match Schema.take_object ps "risk" with
                              | Some rps -> (
                                  let triggers =
                                    match
                                      Schema.take_array rps "declared_triggers"
                                    with
                                    | Some xs ->
                                        List.filter_map
                                          (fun v ->
                                            match v with
                                            | Jsonl.String s -> Some s
                                            | _ -> None)
                                          xs
                                    | _ -> []
                                  in
                                  match Schema.take_string rps "owner" with
                                  | Some owner ->
                                      let counterexample =
                                        match
                                          Schema.take_array ps "counterexample"
                                        with
                                        | Some xs ->
                                            List.filter_map
                                              (fun x ->
                                                match x with
                                                | Jsonl.String s -> Some s
                                                | _ -> None)
                                              xs
                                            |> String.concat "\n"
                                            |> fun s -> Some s
                                        | _ -> None
                                      in
                                      let state_str =
                                        match Schema.take_string ps "state" with
                                        | Some s -> s
                                        | None -> "active"
                                      in
                                      let state =
                                        match
                                          Codec.parse_decision_state state_str
                                        with
                                        | Some s -> s
                                        | None -> `Active
                                      in
                                      let mode_str =
                                        match Schema.take_string ps "mode" with
                                        | Some s -> s
                                        | None -> "standard"
                                      in
                                      let mode =
                                        match Codec.parse_mode mode_str with
                                        | Some m -> m
                                        | None -> `Standard
                                      in
                                      let mode_floor_used =
                                        match
                                          Schema.take_string ps
                                            "mode_floor_used"
                                        with
                                        | Some s -> (
                                            match Codec.parse_mode s with
                                            | Some m -> Some m
                                            | None -> None)
                                        | None -> None
                                      in
                                      let body_sha =
                                        Schema.take_string ps "body_sha"
                                      in
                                      let yaml_sha =
                                        Schema.take_string ps "yaml_sha"
                                      in
                                      Some
                                        {
                                          Domain.id;
                                          Domain.rev = revision;
                                          Domain.parents;
                                          Domain.intent_source = source;
                                          Domain.intent_text = text;
                                          Domain.commitment;
                                          Domain.scope;
                                          Domain.outcomes;
                                          Domain.obligations;
                                          Domain.assumptions;
                                          Domain.reversal;
                                          Domain.risk =
                                            {
                                              Domain.declared_triggers =
                                                triggers;
                                              Domain.owner;
                                            };
                                          Domain.relations =
                                            {
                                              Domain.revises = [];
                                              Domain.supersedes = [];
                                              Domain.superseded_by = [];
                                              Domain.refines = [];
                                              Domain.depends_on = [];
                                              Domain.conflicts_with = [];
                                              Domain.addresses = [];
                                              Domain.implements = [];
                                              Domain.verifies = [];
                                            };
                                          Domain.counterexample;
                                          Domain.state;
                                          Domain.mode;
                                          Domain.mode_floor_used;
                                          Domain.body_sha;
                                          Domain.yaml_sha;
                                        }
                                  | _ -> None)
                              | _ -> None)
                          | _ -> None)
                      | _ -> None)
                  | _ -> None)
              | _ -> None)
          | _ -> None)
      | _ -> None)
  | _ -> None
