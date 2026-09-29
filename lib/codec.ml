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
  match s with "exact" -> Some `Exact | "tree" -> Some `Tree | _ -> None

(* Scope target parsing — one entry; combined with scope below. *)
let[@warning "-32"] parse_scope_target v =
  match v with
  | Jsonl.Object ps -> (
      match Schema.take_string ps "kind" with
      | Some "path" -> (
          match Schema.take_string ps "path" with
          | Some path -> (
              match Schema.take_string ps "match" with
              | Some m -> (
                  match parse_match m with
                  | Some mt -> Some (Domain.PathTarget { path; match_ = mt })
                  | None -> None)
              | _ -> Some (Domain.PathTarget { path; match_ = `Tree }))
          | _ -> None)
      | Some "capability" -> (
          match Schema.take_string ps "capability" with
          | Some c -> Some (Domain.CapabilityTarget c)
          | _ -> None)
      | Some "interface" -> (
          match Schema.take_string ps "interface" with
          | Some i -> Some (Domain.InterfaceTarget i)
          | _ -> None)
      | _ -> None)
  | _ -> None

let[@warning "-32"] parse_scope arr =
  let rec loop acc = function
    | [] -> List.rev acc
    | x :: rest -> (
        match parse_scope_target x with
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
  | Jsonl.Object ps -> (
      match Schema.take_string ps "id" with
      | Some id -> (
          match Schema.take_object ps "subject" with
          | Some sps -> (
              match Schema.take_string sps "decision" with
              | Some decision -> (
                  let decision_digest =
                    Schema.take_string sps "decision_digest"
                  in
                  match Schema.take_string sps "obligation" with
                  | Some obligation -> (
                      let obligation_digest =
                        Schema.take_string sps "obligation_digest"
                      in
                      let candidate_tree =
                        match Schema.take_string sps "candidate_tree" with
                        | Some s -> s
                        | None -> ""
                      in
                      let materials_digest =
                        match Schema.take_string sps "materials_digest" with
                        | Some s -> s
                        | None -> ""
                      in
                      match Schema.take_string ps "kind_" with
                      | Some kind_str -> (
                          match parse_attestation_kind kind_str with
                          | Some kind -> (
                              match Schema.take_object ps "producer" with
                              | Some pps -> (
                                  match Schema.take_string pps "identity" with
                                  | Some producer_identity -> (
                                      let producer_run =
                                        Schema.take_string pps "run"
                                      in
                                      match Schema.take_string ps "result" with
                                      | Some result_str -> (
                                          match parse_result result_str with
                                          | Some result -> (
                                              match
                                                Schema.take_string ps
                                                  "issued_at"
                                              with
                                              | Some issued_at ->
                                                  Some
                                                    {
                                                      Domain.id;
                                                      Domain.decision;
                                                      Domain.decision_revision =
                                                        None;
                                                      Domain.decision_digest;
                                                      Domain.obligation;
                                                      Domain.obligation_digest;
                                                      Domain.candidate_tree;
                                                      Domain.materials_digest;
                                                      Domain.kind;
                                                      Domain.producer_identity;
                                                      Domain.producer_run;
                                                      Domain.environment_class =
                                                        None;
                                                      Domain.result;
                                                      Domain.issued_at;
                                                      Domain.valid_until = None;
                                                      Domain.evidence_digest =
                                                        None;
                                                    }
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
  | Jsonl.Object ps -> (
      match Schema.take_string ps "id" with
      | Some id -> (
          match Schema.take_string ps "policy_id" with
          | Some policy_id -> (
              match Schema.take_string ps "rule" with
              | Some rule -> (
                  match Schema.take_string ps "subject" with
                  | Some subject -> (
                      match Schema.take_string ps "issuer" with
                      | Some issuer -> (
                          match Schema.take_string ps "issued_at" with
                          | Some issued_at -> (
                              match Schema.take_string ps "expires_at" with
                              | Some expires_at -> (
                                  match Schema.take_string ps "reason" with
                                  | Some reason ->
                                      let scope =
                                        match Schema.take_array ps "scope" with
                                        | Some xs -> parse_scope xs
                                        | None -> []
                                      in
                                      let unverified_obligation =
                                        Schema.take_string ps
                                          "unverified_obligation"
                                      in
                                      let compensating_controls =
                                        match
                                          Schema.take_array ps
                                            "compensating_controls"
                                        with
                                        | Some xs ->
                                            List.filter_map
                                              (fun x ->
                                                match x with
                                                | Jsonl.String s -> Some s
                                                | _ -> None)
                                              xs
                                        | None -> []
                                      in
                                      Some
                                        {
                                          Domain.id;
                                          Domain.policy_id;
                                          Domain.rule;
                                          Domain.subject;
                                          Domain.scope;
                                          Domain.issuer;
                                          Domain.issued_at;
                                          Domain.expires_at;
                                          Domain.reason;
                                          Domain.unverified_obligation;
                                          Domain.compensating_controls;
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

(* --- YAML subset loader ---
 *
 * Mirrors the loader in tests/conformance.ml: block-style mappings
 * with scalar or list values, nested objects via indentation,
 * quoted or bare scalars, and block-style sequences via "- ".
 * This is NOT a general YAML parser. See decisions/validate-and-context.yaml
 * for the assumption record and OCAML_BEST_PRACTICES §11.13 for the
 * trap-log entry that fixes the whitespace-stripping bug.
 *
 * Pure function: takes a string, returns a Jsonl.value. No file I/O.
 * The bin/ wrapper in bin/Mathc.ml reads the file and passes the
 * contents here. *)

let[@warning "-32"] yaml_strip s =
  let len = String.length s in
  let buf = Buffer.create len in
  let rec loop i =
    if i >= len then ()
    else
      let c = String.unsafe_get s i in
      match c with
      | '#' ->
          let rec skip j =
            if j >= len then ()
            else if String.unsafe_get s j = '\n' then loop (j + 1)
            else skip (j + 1)
          in
          skip i
      | '\r' -> loop (i + 1)
      | _ ->
          Buffer.add_char buf c;
          loop (i + 1)
  in
  loop 0;
  Buffer.contents buf

let[@warning "-32"] yaml_lines s =
  let stripped = yaml_strip s in
  let len = String.length stripped in
  let rec loop i acc =
    if i >= len then List.rev acc
    else
      let rec find_eol j =
        if j >= len || String.unsafe_get stripped j = '\n' then j
        else find_eol (j + 1)
      in
      let j = find_eol i in
      loop (j + 1) (String.sub stripped i (j - i) :: acc)
  in
  loop 0 []

type yaml_token = { yindent : int; ycontent : string }

let[@warning "-32"] yaml_tokens raw =
  List.filter_map
    (fun line ->
      let len = String.length line in
      let rec count_spaces i =
        if i >= len then i
        else if String.unsafe_get line i = ' ' then count_spaces (i + 1)
        else i
      in
      let indent = count_spaces 0 in
      if indent = len then None
      else
        let content = String.sub line indent (len - indent) in
        Some { yindent = indent; ycontent = content })
    (yaml_lines raw)

let[@warning "-32"] parse_yaml_scalar s =
  let s = String.trim s in
  match s with
  | "" -> Jsonl.Null
  | "true" -> Jsonl.Bool true
  | "false" -> Jsonl.Bool false
  | "null" -> Jsonl.Null
  | _ ->
      let is_int s =
        let len = String.length s in
        len > 0
        &&
        let rec loop i =
          if i >= len then true
          else
            let c = String.unsafe_get s i in
            (c >= '0' && c <= '9') && loop (i + 1)
        in
        loop 0
      in
      if is_int s then
        match int_of_string_opt s with
        | Some i -> Jsonl.Int i
        | None -> Jsonl.String s
      else if
        String.length s >= 2
        && String.unsafe_get s 0 = '"'
        && String.unsafe_get s (String.length s - 1) = '"'
      then Jsonl.String (String.sub s 1 (String.length s - 2))
      else Jsonl.String s

let[@warning "-32"] is_dash_item content =
  String.length content >= 2
  && String.unsafe_get content 0 = '-'
  && String.unsafe_get content 1 = ' '

let[@warning "-32"] head_indent = function
  | { yindent; _ } :: _ -> yindent
  | [] -> -1

let[@warning "-32"] rec parse_yaml_pairs tokens cur_indent =
  let rec loop acc tokens =
    match tokens with
    | [] -> (List.rev acc, [])
    | _ :: _ when head_indent tokens < cur_indent -> (List.rev acc, tokens)
    | _ :: _ when head_indent tokens > cur_indent -> (List.rev acc, tokens)
    | { ycontent; _ } :: rest when head_indent tokens = cur_indent -> (
        if is_dash_item ycontent then (List.rev acc, tokens)
        else
          match String.index_opt ycontent ':' with
          | None -> (List.rev acc, tokens)
          | Some ci ->
              let key = String.sub ycontent 0 ci in
              let vraw =
                String.sub ycontent (ci + 1) (String.length ycontent - ci - 1)
              in
              let vstr = String.trim vraw in
              let value, rest2 =
                if vstr = "" then
                  match rest with
                  | [] -> (Jsonl.Null, [])
                  | first :: _ -> parse_yaml_value rest first.yindent
                else (parse_yaml_scalar vstr, rest)
              in
              loop ((key, value) :: acc) rest2)
    | _ -> (List.rev acc, tokens)
  in
  loop [] tokens

and parse_yaml_value tokens cur_indent =
  match tokens with
  | [] -> (Jsonl.Null, [])
  | _ :: _ when head_indent tokens < cur_indent -> (Jsonl.Null, tokens)
  | { ycontent; _ } :: _ when head_indent tokens = cur_indent ->
      if is_dash_item ycontent then parse_yaml_seq tokens cur_indent
      else
        let pairs, rest2 = parse_yaml_pairs tokens cur_indent in
        (Jsonl.Object pairs, rest2)
  | _ -> (Jsonl.Null, [])

and parse_yaml_seq tokens cur_indent =
  let rec loop acc tokens =
    match tokens with
    | [] -> (Jsonl.Array (List.rev acc), [])
    | _ :: _ when head_indent tokens < cur_indent ->
        (Jsonl.Array (List.rev acc), tokens)
    | _ :: _ when head_indent tokens > cur_indent ->
        (Jsonl.Array (List.rev acc), tokens)
    | { ycontent; _ } :: rest when head_indent tokens = cur_indent ->
        if not (is_dash_item ycontent) then (Jsonl.Array (List.rev acc), tokens)
        else
          let item_str = String.sub ycontent 2 (String.length ycontent - 2) in
          let item_str_trim = String.trim item_str in
          let item, rest2 =
            if item_str_trim = "" then parse_yaml_value rest (cur_indent + 2)
            else
              match String.index_opt item_str ':' with
              | Some ci ->
                  let key = String.sub item_str 0 ci in
                  let vraw =
                    String.sub item_str (ci + 1)
                      (String.length item_str - ci - 1)
                  in
                  let vstr = String.trim vraw in
                  let first_value, more_rest =
                    if vstr = "" then
                      match rest with
                      | [] -> (Jsonl.Null, [])
                      | first :: _ -> parse_yaml_value rest first.yindent
                    else (parse_yaml_scalar vstr, rest)
                  in
                  let first_pair = [ (key, first_value) ] in
                  let more_pairs, rest3 =
                    parse_yaml_pairs more_rest (cur_indent + 2)
                  in
                  (Jsonl.Object (first_pair @ more_pairs), rest3)
              | None -> (parse_yaml_scalar item_str_trim, rest)
          in
          loop (item :: acc) rest2
    | _ -> (Jsonl.Array (List.rev acc), tokens)
  in
  loop [] tokens

let[@warning "-32"] load_yaml_string raw =
  let tokens = yaml_tokens raw in
  let pairs, _ = parse_yaml_pairs tokens 0 in
  Jsonl.Object pairs
