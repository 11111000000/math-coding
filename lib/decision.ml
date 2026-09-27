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
                          Some
                            {
                              Domain.id;
                              Domain.state;
                              Domain.statement;
                              Domain.owner;
                              Domain.consequence_if_false = consequence;
                              Domain.review_on;
                            }
                      | _ -> None)
                  | _ -> None)
              | _ -> None)
          | _ -> None)
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
                                      Some
                                        {
                                          Domain.id;
                                          Domain.revision;
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
                                              Domain.supersedes = [];
                                              Domain.addresses = [];
                                              Domain.depends_on = [];
                                            };
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
