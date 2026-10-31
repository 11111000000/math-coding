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
  | "pre_merge" | "pre-merge" -> Some `PreMerge
  | "pre_release" | "pre-release" -> Some `PreRelease
  | "post_release" | "post-release" -> Some `PostRelease
  | _ -> None

let[@warning "-32"] parse_assumption_state s =
  match s with
  (* 3.0 legacy values *)
  | "assumed" -> Some `Assumed
  | "unknown" -> Some `Unknown
  (* 3.2 epistemic markers (kernel contract §7, axiom A5 v0.854) *)
  | "fact" -> Some `Fact
  | "hypothesis" -> Some `Hypothesis
  | "judgment" -> Some `Judgment
  | "proven" -> Some `Proven
  | _ -> None

(* Decision lifecycle state (kernel contract §7). *)
let[@warning "-32"] parse_decision_state s =
  match s with
  | "draft" -> Some `Draft
  | "active" -> Some `Active
  | "retired" -> Some `Retired
  | "superseded" -> Some `Superseded
  | _ -> None

(* Assurance mode (kernel contract §3, §7). *)
let[@warning "-32"] parse_mode s =
  match s with
  | "tiny" -> Some `Tiny
  | "light" -> Some `Light
  | "standard" -> Some `Standard
  | "strict" -> Some `Strict
  | "exhaustive" -> Some `Exhaustive
  | _ -> None

(* Environment class label (kernel contract §13). *)
let[@warning "-32"] parse_environment_class_label s =
  match s with
  | "dev" -> Some `Dev
  | "staging" -> Some `Staging
  | "staging-integration" -> Some `StagingIntegration
  | "prod-mirror" -> Some `ProdMirror
  | "prod" -> Some `Prod
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
                                                  let env_class_label =
                                                    match
                                                      Schema.take_string ps
                                                        "environment_class_label"
                                                    with
                                                    | Some s -> (
                                                        match
                                                          parse_environment_class_label
                                                            s
                                                        with
                                                        | Some l -> Some l
                                                        | None -> None)
                                                    | None -> None
                                                  in
                                                  let env_class_level =
                                                    match env_class_label with
                                                    | Some `Dev -> Some 0
                                                    | Some `Staging -> Some 1
                                                    | Some `StagingIntegration
                                                      ->
                                                        Some 2
                                                    | Some `ProdMirror -> Some 3
                                                    | Some `Prod -> Some 4
                                                    | None -> None
                                                  in
                                                  let substrate_digest =
                                                    Schema.take_string ps
                                                      "substrate_digest"
                                                  in
                                                  let substrate_fingerprint =
                                                    Schema.take_string ps
                                                      "substrate_fingerprint"
                                                  in
                                                  let ci_run_id =
                                                    Schema.take_string ps
                                                      "ci_run_id"
                                                  in
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
                                                      Domain
                                                      .environment_class_level =
                                                        env_class_level;
                                                      Domain
                                                      .environment_class_label =
                                                        env_class_label;
                                                      Domain.result;
                                                      Domain.issued_at;
                                                      Domain.valid_until = None;
                                                      Domain.evidence_digest =
                                                        None;
                                                      Domain.substrate_digest;
                                                      Domain
                                                      .substrate_fingerprint;
                                                      Domain.ci_run_id;
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

(* MC-MATERIALS-DIGEST-EMPTY validator (decisions/kernel-bugs-v3.4-
   2026-10). Returns Some diagnostic when the parsed attestation
   carries a runtime kind (`Test`, `Build`, `Observation`,
   `Analysis`) with an empty `subject.materials_digest`. Per A0
   separation, runtime attestations MUST name the materials they
   were produced against; only `Review` is exempt. The function is
   separate from `parse_attestation` so that the loader can
   grandfather legacy attestations (whose `issued_at` is before
   2026-10-16) while the validator surfaces the diagnostic for
   new attestations. `mathc validate <attestation.json>` invokes
   this validator via `bin/Mathc.ml::validate_with_counts`. *)
let[@warning "-32"] validate_attestation_materials (a : Domain.attestation) :
    Diagnostic.t option =
  let is_runtime_kind = match a.kind with `Review -> false | _ -> true in
  if is_runtime_kind && String.trim a.materials_digest = "" then
    Some
      (Diagnostic.mc_materials_digest_empty
         ~subject:(Printf.sprintf "%s/%s" a.decision a.obligation)
         ~kind:
           (match a.kind with
           | `Test -> "test"
           | `Build -> "build"
           | `Observation -> "observation"
           | `Analysis -> "analysis"
           | `Review -> "review")
         ())
  else None

(* MC-PRODUCER-CLASS-UNDECLARED / MC-PRODUCER-HUMAN-UNANCHORED validator
   (decisions/attestation-producer-vocab-2026-10). Two rules, both
   about the same question: does this file tell the reader whether a
   person or a machine produced it?

   The identity pattern is the schema's, kept in one place so the
   OCaml validator and schemas/attestation.json cannot drift by more
   than a test run. There is no JSON-Schema validator in the kernel --
   it parses by hand (see parse_attestation above) -- so the schema
   states the contract and this function enforces it. *)
let[@warning "-32"] producer_identity_pattern =
  "^(human|agent|ci):[A-Za-z0-9][A-Za-z0-9._:/-]*$"

(* Hand-rolled prefix/subject match for the pattern above. A real
   regex engine would be the tidier tool; the kernel takes no runtime
   dependency (OCAML_BEST_PRACTICES §10.4 -- "the kernel stays offline
   and dependency-free"), and the pattern is small enough that the two
   halves are easier to read than the escaping. The conformance test
   pins this against the same strings the schema pattern accepts. *)
let[@warning "-32"] producer_class_of identity =
  let is_class = function "human" | "agent" | "ci" -> true | _ -> false in
  match String.index_opt identity ':' with
  | None -> None
  | Some i ->
      let cls = String.sub identity 0 i in
      if not (is_class cls) then None
      else
        let subject =
          String.sub identity (i + 1) (String.length identity - i - 1)
        in
        if String.length subject = 0 then None else Some (cls, subject)

(* The subject half of the pattern: first character alphanumeric,
   then any of alphanumerics and `. _ : / -`. Returns false rather
   than raising on a non-ASCII byte, which is the same answer the
   regex gives (the character class does not match it). *)
let[@warning "-32"] producer_subject_ok subject =
  let alnum c =
    (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')
  in
  let rest c = alnum c || c = '.' || c = '_' || c = ':' || c = '/' || c = '-' in
  let n = String.length subject in
  if n = 0 then false
  else
    let first = String.unsafe_get subject 0 in
    let tail_ok =
      let rec loop i =
        i >= n || (rest (String.unsafe_get subject i) && loop (i + 1))
      in
      loop 1
    in
    (* A non-ASCII lead byte is not alnum, so a non-ASCII lead is
       rejected; a non-ASCII byte anywhere later fails `rest`. The
       explicit lead check keeps that from depending on `rest`. *)
    alnum first && tail_ok

let[@warning "-32"] producer_identity_ok identity =
  match producer_class_of identity with
  | None -> false
  | Some (_, subject) -> producer_subject_ok subject

(* Returns Some diagnostic when the parsed attestation's producer
   claim is ungrounded. Order matters: an untagged identity is
   reported as undeclared even when the kind is also a runtime kind,
   because "who produced this" is the prior question -- an untagged
   runtime attestation has no human claim to anchor, so the anchoring
   rule has nothing to say about it.

   Like validate_attestation_materials above, this is deliberately
   NOT called from parse_attestation: the store loader must keep
   reading the committed corpus. This function runs on the `mathc
   validate` path, which is the issuance path. 62 committed
   attestations carry an untagged identity and 58 carry a `human:`
   identity on a runtime kind; all 765 stay loadable, and
   tests/producer_vocab.ml pins those two numbers so the backlog is
   visible rather than forgotten. *)
let[@warning "-32"] validate_attestation_producer (a : Domain.attestation) :
    Diagnostic.t option =
  let kind_str =
    match a.kind with
    | `Test -> "test"
    | `Build -> "build"
    | `Observation -> "observation"
    | `Analysis -> "analysis"
    | `Review -> "review"
  in
  let subject = Printf.sprintf "%s/%s" a.decision a.obligation in
  if not (producer_identity_ok a.producer_identity) then
    Some
      (Diagnostic.mc_producer_class_undeclared ~subject
         ~identity:a.producer_identity ())
  else
    match producer_class_of a.producer_identity with
    | Some ("human", _) ->
        let run_named =
          match a.producer_run with
          | Some r -> String.trim r <> ""
          | None -> false
        in
        (* `review` is the WEAK class: a human declaration with no
           runtime anchor. A false `human:` claim there upgrades
           nothing, so it is deliberately left unconstrained. Every
           other kind is machine-grade and must name its run. *)
        if a.kind <> `Review && not run_named then
          Some
            (Diagnostic.mc_producer_human_unanchored ~subject
               ~identity:a.producer_identity ~kind:kind_str ())
        else None
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
 * for the assumption record and OCAML_BEST_PRACTICES §11.12 for the
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
          (* Skip from '#' to but not including the next '\n' so
             the line structure is preserved. *)
          let rec skip j =
            if j >= len then ()
            else if String.unsafe_get s j = '\n' then begin
              Buffer.add_char buf '\n';
              loop (j + 1)
            end
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

(* `yline` is the 1-based line the token came from. It carries no
   parsing meaning — it exists so a diagnostic can point at the
   exact place the kernel stopped reading (`MC-UNPARSED-TAIL`)
   or where a duplicated key was declared (`MC-DUPLICATE-KEY`)
   without re-deriving positions from the raw text, which is a
   second source of truth and therefore a second chance to lie. *)
type yaml_token = { yindent : int; ycontent : string; yline : int }

let[@warning "-32"] yaml_tokens raw =
  List.mapi (fun i line -> (i + 1, line)) (yaml_lines raw)
  |> List.filter_map (fun (line_no, line) ->
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
        Some { yindent = indent; ycontent = content; yline = line_no })

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
      (* A YAML scalar like `0.85` must be parsed as Jsonl.Float,
         not as Jsonl.String. Without this, fields typed as float
         in the domain (e.g. `Domain.assumption.confidence`) are
         silently lost — see tests/confidence_preserve.ml. *)
      let is_float s =
        let len = String.length s in
        let count_dots =
          let n = ref 0 in
          for i = 0 to len - 1 do
            if String.unsafe_get s i = '.' then incr n
          done;
          !n
        in
        let all_digits_or_dot =
          let rec loop i =
            if i >= len then true
            else
              let c = String.unsafe_get s i in
              ((c >= '0' && c <= '9') || c = '.') && loop (i + 1)
          in
          loop 0
        in
        len > 0 && count_dots = 1 && all_digits_or_dot
      in
      if is_int s then
        match int_of_string_opt s with
        | Some i -> Jsonl.Int i
        | None -> Jsonl.String s
      else if is_float s then
        match float_of_string_opt s with
        | Some f -> Jsonl.Float f
        | None -> Jsonl.String s
      else if
        String.length s >= 2
        && String.unsafe_get s 0 = '"'
        && String.unsafe_get s (String.length s - 1) = '"'
      then Jsonl.String (String.sub s 1 (String.length s - 2))
      else Jsonl.String s

(* -----------------------------------------------------------------
 * YAML block scalars (| and >) — D1/D2 audit closure
 * Recognises |, |-, |+, >, >-, >+ headers at value position
 * in a mapping. Collects indented body lines and joins them
 * according to the chomping indicator. Reference: YAML 1.2 §8.1.1
 * (literal block), §8.1.3 (folded block).
 *
 * This module is pure: takes a token list and a parent indent,
 * returns the parsed value + remaining tokens. No I/O, no shell,
 * no randomness. The caller (parse_yaml_pairs) recognises the
 * header and dispatches to this function. *)

type chomp = Clip | Strip | Keep

let[@warning "-32"] parse_chomp s =
  if String.length s >= 2 then
    let c0 = String.unsafe_get s 0 in
    if c0 = '-' then Strip else if c0 = '+' then Keep else Clip
  else Clip

let[@warning "-32"] block_strip s =
  let len = String.length s in
  let buf = Buffer.create len in
  let rec skip_ws i =
    if i >= len then i
    else
      match String.unsafe_get s i with ' ' | '\t' -> skip_ws (i + 1) | _ -> i
  in
  let rec loop i =
    if i >= len then ()
    else
      let c = String.unsafe_get s i in
      (match c with '\r' -> () | _ -> Buffer.add_char buf c);
      loop (i + 1)
  in
  loop (skip_ws 0);
  Buffer.contents buf

let[@warning "-32"] strip_trailing_newlines s =
  let len = String.length s in
  let rec loop i =
    if i < 0 then 0
    else if String.unsafe_get s i = '\n' then loop (i - 1)
    else i + 1
  in
  String.sub s 0 (loop (len - 1))

let[@warning "-32"] fold_join lines chomp =
  let body =
    List.fold_left
      (fun acc line ->
        let stripped = block_strip line in
        if acc = "" then stripped
        else if stripped = "" then acc
        else acc ^ " " ^ stripped)
      "" lines
  in
  match chomp with
  | Clip -> body ^ "\n"
  | Strip -> strip_trailing_newlines body
  | Keep -> body ^ "\n"

let[@warning "-32"] literal_join lines chomp =
  let body =
    List.fold_left
      (fun acc line ->
        if acc = "" then line
        else if line = "" then acc ^ "\n"
        else acc ^ "\n" ^ line)
      "" lines
  in
  match chomp with
  | Clip -> body ^ "\n"
  | Strip -> strip_trailing_newlines body
  | Keep -> body

(* Returns true if the line at head is a block-scalar header
   (|, |-, |+, >, >-, >+). The chomping indicator (or its absence)
   is the suffix. *)
let[@warning "-32"] is_block_header s =
  if String.length s < 1 then false
  else
    let c0 = String.unsafe_get s 0 in
    if c0 = '|' || c0 = '>' then
      let s1 = if String.length s >= 2 then String.unsafe_get s 1 else ' ' in
      s1 = ' ' || s1 = '-' || s1 = '+'
    else false

let[@warning "-32"] block_header_kind s =
  if String.length s < 1 then (Clip, false)
  else
    let c0 = String.unsafe_get s 0 in
    if c0 = '|' then
      if String.length s >= 2 && String.unsafe_get s 1 = '-' then (Strip, false)
      else if String.length s >= 2 && String.unsafe_get s 1 = '+' then
        (Keep, false)
      else (Clip, false)
    else if c0 = '>' then
      if String.length s >= 2 && String.unsafe_get s 1 = '-' then (Strip, true)
      else if String.length s >= 2 && String.unsafe_get s 1 = '+' then
        (Keep, true)
      else (Clip, true)
    else (Clip, false)

(* Parse a block-scalar body. Returns the collected value and
   the remaining tokens. body_indent is the indent at which the
   body lines must appear. is_folded distinguishes '|' (literal)
   from '>' (folded). *)
let rec parse_yaml_block body_indent is_folded chomp tokens =
  let rec collect acc tokens =
    match tokens with
    | [] -> (List.rev acc, [])
    | { yindent; ycontent; _ } :: rest when yindent >= body_indent ->
        let stripped = block_strip ycontent in
        collect (stripped :: acc) rest
    | _ -> (List.rev acc, tokens)
  in
  let lines, remaining = collect [] tokens in
  let body =
    if is_folded then fold_join lines chomp else literal_join lines chomp
  in
  (body, remaining)

let[@warning "-32"] is_dash_item content =
  String.length content >= 2
  && String.unsafe_get content 0 = '-'
  && String.unsafe_get content 1 = ' '

let[@warning "-32"] head_indent = function
  | { yindent; _ } :: _ -> yindent
  | [] -> -1

(* Inline block-sequence value: YAML 1.2 §7.1 form "key: - foo"
   (the sequence starts on the same line as the key, with
   additional "- bar" items at the same indentation on
   subsequent lines).

   Triggered by `parse_yaml_pairs` when the trimmed value side
   of a key:value line starts with "- ". Without this branch,
   the value was parsed as a plain scalar string, the
   same-indent "- bar" was mistaken for the start of a new
   top-level key list (it is not — it is a continuation of
   the sequence), and every key that followed (e.g.
   `counterexample:`) was silently dropped. The audit
   report §10.5 #7 (`docs/experiments/adoption-2026-10.md`)
   named this as F-SCHEMA for sinatra and ripgrep.

   The function consumes:
   - the "- foo" item from `vstr` (already trimmed, dash prefix kept);
   - any further "- bar" tokens in `tokens` whose `yindent = cur_indent`.

   Items are parsed as scalars via `parse_yaml_scalar`; the empty
   string is mapped to `Jsonl.Null`, matching the semantics of
   `parse_yaml_seq` for empty items under the existing tests. *)
let[@warning "-32"] rec parse_yaml_inline_seq cur_indent vstr tokens =
  let first_item =
    let s = String.trim (String.sub vstr 2 (String.length vstr - 2)) in
    if s = "" then Jsonl.Null else parse_yaml_scalar s
  in
  let rec collect acc ts =
    match ts with
    | { yindent; ycontent } :: rest
      when yindent = cur_indent && is_dash_item ycontent ->
        let s =
          String.trim (String.sub ycontent 2 (String.length ycontent - 2))
        in
        let item = if s = "" then Jsonl.Null else parse_yaml_scalar s in
        collect (item :: acc) rest
    | _ -> (List.rev acc, ts)
  in
  let more, rest2 = collect [] tokens in
  (Jsonl.Array (first_item :: more), rest2)

(* Flow sequence: YAML 1.2 §7.4, the form `key: [a, b, c]`.
 *
 * WHY THIS BRANCH EXISTS. The parser had a branch for the §7.1
 * inline sequence ("key: - foo") and a branch for block scalars,
 * but none for the FLOW sequence. A value in bracket form fell
 * through to `parse_yaml_scalar`, which returned the bracket
 * text as a plain STRING. Three consequences, all of them silent:
 *
 *   - `axiom_link: [A0]` was read as the string "[A0]", so
 *     `Schema.take_array` found no array, the field read as
 *     absent, and the decision was rejected with
 *     MC-AXIOM-LINK-MISSING. The diagnostic that fired told the
 *     operator to write exactly that form.
 *   - `scope.paths: ["src/**"]` was read as a string, so the
 *     scope read as EMPTY (lib/decision.ml::parse_scope_yaml_form
 *     takes `paths` only when it is an array). An empty scope
 *     means the materials digest is computed over nothing, and
 *     an empty digest is the freshness wildcard - the attestation
 *     is fresh for every tree, for ever.
 *   - `risk.declared_triggers: ["a", "b"]` and the empty `[]`
 *     forms read as strings; the consumers that filter on an
 *     array therefore saw nothing.
 *
 * The grammar handled here is the single-line flow sequence:
 * brackets balance, items are separated by top-level commas, an
 * item may be a plain scalar, a single-quoted or a double-quoted
 * scalar, or a nested flow collection. A value that starts with
 * '[' but does not balance is NOT read as a sequence: the parser
 * falls back to the scalar reading, so a malformed file is
 * reported by the schema and not by a guess. *)

let[@warning "-32"] is_flow_seq_start s =
  String.length s >= 1 && String.unsafe_get s 0 = '['

(* Split a flow-sequence body on its top-level commas. Returns None
   when the body does not balance or ends inside a quoted scalar: a
   half-read flow sequence is worse than no flow sequence, because
   it would look like a decision that was read. *)
let[@warning "-32"] split_flow_items body =
  let len = String.length body in
  let items = ref [] in
  let buf = Buffer.create len in
  let depth = ref 0 in
  let quote = ref '\000' in
  let flush () =
    items := Buffer.contents buf :: !items;
    Buffer.clear buf
  in
  for i = 0 to len - 1 do
    let c = String.unsafe_get body i in
    if !quote <> '\000' then (
      Buffer.add_char buf c;
      if c = !quote then quote := '\000')
    else
      match c with
      | '\'' | '"' ->
          quote := c;
          Buffer.add_char buf c
      | '[' | '{' ->
          incr depth;
          Buffer.add_char buf c
      | ']' | '}' ->
          decr depth;
          Buffer.add_char buf c
      | ',' when !depth = 0 -> flush ()
      | _ -> Buffer.add_char buf c
  done;
  if !quote <> '\000' || !depth <> 0 then None
  else (
    flush ();
    Some (List.rev !items))

(* One flow item. A quoted item is a string by definition (YAML
   §7.3.3, §7.3.4); an unquoted one goes through the scalar reader,
   so `0` is a number and `src/**` is a string. *)
let[@warning "-32"] flow_item_value t =
  let n = String.length t in
  if
    n >= 2
    && ((String.unsafe_get t 0 = '"' && String.unsafe_get t (n - 1) = '"')
       || (String.unsafe_get t 0 = '\'' && String.unsafe_get t (n - 1) = '\''))
  then Jsonl.String (String.sub t 1 (n - 2))
  else if t = "" then Jsonl.Null
  else parse_yaml_scalar t

let[@warning "-32"] parse_yaml_flow_seq s =
  let n = String.length s in
  if n < 2 || String.unsafe_get s 0 <> '[' || String.unsafe_get s (n - 1) <> ']'
  then None
  else
    let body = String.sub s 1 (n - 2) in
    if String.trim body = "" then Some (Jsonl.Array [])
    else
      match split_flow_items body with
      | None -> None
      | Some items ->
          Some
            (Jsonl.Array
               (List.map (fun it -> flow_item_value (String.trim it)) items))

(* Fold YAML 1.1 plain-scalar continuation: when a non-block
   scalar value at indent `cur_indent` is followed by one or
   more lines whose indent is greater than `cur_indent`,
   those lines are appended to the scalar value with a
   single space separator. Without this, `mathc validate
   decisions/decision.yaml` rejects the bootstrap policy
   itself: the `outcomes:` array contains a 2-line plain
   scalar, the second line is at indent 6, parse_yaml_pairs
   bails out at `head_indent tokens > cur_indent`, and
   every subsequent top-level key (`assumptions:`,
   `obligations:`, `risk:`, `relations:`) is silently dropped.

   Implementation: scan forward while `head_indent tokens >
   cur_indent` AND the line is not a key:value at a deeper
   indent (i.e. the line does not start with `key:` followed
   by a value at the same line). For our use case (decisions/
   *.yaml), the simpler heuristic works: continuation lines
   have indent > cur_indent AND do not contain a colon. *)
let[@warning "-32"] rec fold_continuation tokens cur_indent =
  match tokens with
  | [] -> ("", [])
  | { yindent; ycontent } :: rest when yindent > cur_indent ->
      let stripped = String.trim ycontent in
      let is_kv = String.index_opt stripped ':' <> None in
      if
        stripped = ""
        || (String.length stripped > 0 && String.unsafe_get stripped 0 = '#')
      then
        (* blank/comment: skip and continue scanning *)
        let _, rest2 = fold_continuation rest cur_indent in
        ("", rest2)
      else if is_kv then
        (* looks like a nested key: stop *)
        ("", tokens)
      else
        let suffix, rest2 = fold_continuation rest cur_indent in
        if stripped = "" then ("", rest2)
        else if suffix = "" then (stripped, rest2)
        else (stripped ^ " " ^ suffix, rest2)
  | _ -> ("", tokens)

(* --- D4: a sequence item's scalar may span lines -----------
 *
 * `fold_continuation` above exists because a MAPPING value
 * (`key: value` then deeper lines) may continue on the
 * following lines. A SEQUENCE ITEM (`- value` then deeper
 * lines) has the identical YAML 1.2 shape -- §7.3.3 multi-line
 * plain scalar, §7.3.4 flow scalar carried across lines -- and
 * until now `parse_yaml_seq` had no counterpart: its scalar
 * branch was `(parse_yaml_scalar item_str_trim, rest)`, the
 * rest of the item's lines were handed back UNCONSUMED, and
 * every caller that stops on an unconsumed remainder
 * (`load_yaml_string`'s `let pairs, _ = ...`) dropped them.
 *
 * Six corpus decisions reached it, all VALID YAML 1.2, measured
 * by scanning `mathc validate` output over `decisions/**/*.yaml`
 * at main e019916 (18 files reported MC-UNPARSED-TAIL before this
 * change, 12 after; the 6 fixed are exactly):
 *
 *   decisions/cli-cram-tests.yaml                  `unknowns:`
 *   decisions/paren-balance-fix-2026-10.yaml       `unknowns:`
 *   archive/decisions/p8-hook-deficit-2026-10.yaml  `unknowns:`
 *   archive/decisions/render-module-split-phase1-2026-10.yaml   `unknowns:`
 *   decisions/render-module-split-phase1a-2026-10.yaml  `unknowns:`
 *   decisions/site-deploy.yaml                     `unknowns:`
 *
 * Five are plain scalars; the p8 one is a
 * double-quoted flow scalar whose closing quote sits on the
 * last line, and its continuation carries ": " -- legal inside
 * quotes (§7.3.4), illegal in a plain scalar, which is why
 * `fold_continuation`'s colon test cannot be reused as-is.
 *
 * Why the mapping-side colon test is NOT mirrored here: in a
 * mapping value position a deeper `key: value` line is
 * ambiguous, so `fold_continuation` needs a heuristic. In a
 * SEQUENCE ITEM position this branch is only reached when the
 * item's own text carries no colon at all (the `Some ci` arm
 * above handles the mapping-shaped item), so nothing at deeper
 * indent can be a sibling key: every such line belongs to the
 * scalar. Dropping the test here costs nothing in
 * disambiguation and removes a whole loss channel. The mapping
 * side keeps its heuristic -- changing it re-parses every
 * invalid file in the corpus and is its own decision; see
 * `decisions/yaml-seq-item-continuation-2026-10.yaml`.
 *)
let[@warning "-32"] quote_still_open s =
  (* True when `s` opens with '"' and that quote is still
     unclosed at the end of `s`. A closing quote preceded by an
     odd run of backslashes is escaped, so it does not close the
     flow scalar. *)
  let n = String.length s in
  if n = 0 || String.unsafe_get s 0 <> '"' then false
  else
    let rec scan i escaped closed =
      if i >= n || closed then closed
      else
        let c = String.unsafe_get s i in
        if escaped then scan (i + 1) false closed
        else if c = '\\' then scan (i + 1) true closed
        else scan (i + 1) false (c = '"')
    in
    not (scan 1 false false)

let[@warning "-32"] quoted_and_finished s =
  String.length s > 0 && String.unsafe_get s 0 = '"' && not (quote_still_open s)

let[@warning "-32"] rec fold_seq_item cur_indent acc tokens =
  match tokens with
  | [] -> (acc, [])
  | { yindent; ycontent } :: rest when yindent > cur_indent ->
      (* A deeper dash item is a sibling value at a deeper
         sequence, not a continuation of this scalar. *)
      if is_dash_item ycontent then (acc, tokens)
      else if quoted_and_finished acc then
        (* A flow scalar whose closing quote is already on the dash
           line is finished (§7.3.4): extending it would invent a
           reading for a file no strict reader would accept. The
           line is left in the tail, where MC-UNPARSED-TAIL names
           it. Checked BEFORE the append -- the append is what makes
           `acc'` finished on the closing line, so testing after it
           would always be true and the stray line would be pasted
           into the value on its way out. *)
        (acc, tokens)
      else
        let stripped = block_strip ycontent in
        let acc' = if acc = "" then stripped else acc ^ " " ^ stripped in
        (* Otherwise keep swallowing: a plain scalar runs to the
           first non-continuation line, a double-quoted one to its
           closing quote. Both fold the line break to a single space
           (§7.3.3 / §7.3.4). *)
        if quoted_and_finished acc' then (acc', rest)
        else fold_seq_item cur_indent acc' rest
  | _ -> (acc, tokens)

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
                else if is_block_header vstr then
                  let chomp, is_folded = block_header_kind vstr in
                  let body_indent =
                    match rest with
                    | { yindent; _ } :: _ when yindent > cur_indent -> yindent
                    | _ -> cur_indent + 2
                  in
                  let body, rest2 =
                    parse_yaml_block body_indent is_folded chomp rest
                  in
                  (Jsonl.String body, rest2)
                else if is_dash_item vstr then
                  (* YAML 1.2 §7.1 inline sequence: "key: - foo"
                     on a single line, with "- bar" continuations
                     on subsequent lines at the same indent. *)
                  parse_yaml_inline_seq cur_indent vstr rest
                else if is_flow_seq_start vstr then
                  (* YAML 1.2 §7.4 flow sequence: "key: [a, b]".
                     A value that starts with '[' but does not
                     balance falls through to the scalar reading. *)
                  match parse_yaml_flow_seq vstr with
                  | Some v -> (v, rest)
                  | None -> parse_yaml_scalar_value cur_indent vstr rest
                else parse_yaml_scalar_value cur_indent vstr rest
              in
              loop ((key, value) :: acc) rest2)
    | _ -> (List.rev acc, tokens)
  in
  loop [] tokens

(* A plain scalar value at value position, with the YAML 1.1
   plain-scalar continuation folded in. Split out of
   `parse_yaml_pairs` so the flow-sequence branch above can fall
   back to it without duplicating the fold. *)
and parse_yaml_scalar_value cur_indent vstr rest =
  let base_value = parse_yaml_scalar vstr in
  let suffix, rest2 =
    if vstr = "" then ("", rest) else fold_continuation rest cur_indent
  in
  let value =
    if suffix = "" then base_value
    else
      match base_value with
      | Jsonl.String s -> Jsonl.String (s ^ " " ^ suffix)
      | other -> other
  in
  (value, rest2)

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
            else if is_block_header item_str_trim then
              let chomp, is_folded = block_header_kind item_str_trim in
              let body_indent =
                match rest with
                | { yindent; _ } :: _ when yindent > cur_indent -> yindent
                | _ -> cur_indent + 2
              in
              let body, rest2 =
                parse_yaml_block body_indent is_folded chomp rest
              in
              (Jsonl.String body, rest2)
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
                    else if is_block_header vstr then
                      let chomp, is_folded = block_header_kind vstr in
                      let body_indent =
                        match rest with
                        | { yindent; _ } :: _ when yindent > cur_indent + 2 ->
                            yindent
                        | _ -> cur_indent + 4
                      in
                      let body, rest2 =
                        parse_yaml_block body_indent is_folded chomp rest
                      in
                      (Jsonl.String body, rest2)
                    else (parse_yaml_scalar vstr, rest)
                  in
                  let first_pair = [ (key, first_value) ] in
                  let more_pairs, rest3 =
                    parse_yaml_pairs more_rest (cur_indent + 2)
                  in
                  (Jsonl.Object (first_pair @ more_pairs), rest3)
              | None ->
                  (* D4: the item is a scalar, not a mapping, so
                     every line more indented than the dash
                     marker is a continuation of that scalar --
                     YAML 1.2 §7.3.3 (plain) / §7.3.4 (quoted).
                     Without `fold_seq_item` the continuation
                     stayed in `rest`, `parse_yaml_seq` returned
                     early on the deeper token, and the loader
                     dropped everything from there to EOF while
                     still reporting `parse-ok`. *)
                  let joined, rest2 =
                    fold_seq_item cur_indent item_str_trim rest
                  in
                  (parse_yaml_scalar joined, rest2)
          in
          loop (item :: acc) rest2
    | _ -> (Jsonl.Array (List.rev acc), tokens)
  in
  loop [] tokens

let[@warning "-32"] load_yaml_string raw =
  (* Strip a leading YAML front-matter (`---` ... optional `---`).
     decisions/*.yaml files start with `---`; without stripping,
     the first token would be `---` and parse_yaml_pairs would
     reject it (no `:`), so the loader returns an empty object.
     This closes audit deficit D2 (see docs/AUDIT-0.0.11.md).

     Skip any leading blank lines first: an OCaml raw string
     `{|...|}` keeps any leading newline, so the first line is
     empty and the front-matter match fails. *)
  let strip_frontmatter s =
    let lines = yaml_lines s in
    let rec skip_empty acc = function
      | [] -> List.rev acc
      | "" :: rest -> skip_empty acc rest
      | l :: rest -> List.rev acc @ (l :: rest)
    in
    let lines_no_blanks = skip_empty [] lines in
    match lines_no_blanks with
    | "---" :: rest ->
        let rec skip_body acc = function
          | [] -> List.rev acc
          | "---" :: _ -> List.rev acc
          | l :: rest -> skip_body (l :: acc) rest
        in
        skip_body [] rest
    | _ -> lines_no_blanks
  in
  let tokens = yaml_tokens (String.concat "\n" (strip_frontmatter raw)) in
  let pairs, _ = parse_yaml_pairs tokens 0 in
  Jsonl.Object pairs

(* Variant of load_yaml_string that returns the parsed Jsonl.value
   directly (Object OR Array OR scalar). load_yaml_string is
   hard-coded to call parse_yaml_pairs and always returns Object,
   which silently drops top-level YAML sequences such as the
   policies.yaml file used by lib/policy.ml (spec/kernel-contract.md
   §9 multi-policy). This wrapper calls parse_yaml_value instead,
   which dispatches to parse_yaml_pairs or parse_yaml_seq based
   on whether the leading token is a dash-item.

   That wrapper was `let value, _ = parse_yaml_value tokens 0` --
   the D2 shape, on the code path that loads `policies.yaml`, and
   with NO diagnostic behind it: the MC-UNPARSED-TAIL collector in
   `bin/Mathc.ml` is wired to `load_yaml_string_full`, which this
   loader does not go through. So a policy file the loader could
   not finish was read as a shorter policy with nothing to say so.
   The remainder is therefore kept by the function below and
   asserted empty for `policies.yaml` by the
   `seq-item-continuation/policies.yaml leaves no remainder` case in
   `tests/decision_parser_yaml.ml`; emitting the diagnostic from the
   policy loader itself is the named follow-up. *)
let[@warning "-32"] load_yaml_value_remaining raw =
  let strip_frontmatter s =
    let lines = yaml_lines s in
    match lines with
    | "---" :: rest ->
        let rec skip_body acc = function
          | [] -> List.rev acc
          | "---" :: _ -> List.rev acc
          | l :: rest -> skip_body (l :: acc) rest
        in
        skip_body [] rest
    | _ -> lines
  in
  let tokens = yaml_tokens (String.concat "\n" (strip_frontmatter raw)) in
  parse_yaml_value tokens 0

let[@warning "-32"] load_yaml_value raw = fst (load_yaml_value_remaining raw)

(* === Duplicate mapping keys (MC-DUPLICATE-KEY) ===
 *
 * A YAML 1.2 §3.2.1 mapping must have unique keys, and RFC 8259
 * leaves duplicate JSON object keys undefined — but both readers
 * in this repository resolve a key with `List.assoc_opt` (see
 * `lib/schema.ml::take_string` / `take_array` / `take_object` /
 * `take_number`), which returns the FIRST binding in document
 * order. A duplicated key therefore does not overwrite: it makes
 * every later binding UNREACHABLE. The content is parsed into the
 * tree and can never be read back by anything.
 *
 * Nothing reported that. A decision file with two `obligations:`
 * blocks parsed cleanly, validated cleanly, and the second
 * block's obligations never reached `mathc gate` or
 * `mathc self-check` — the verdict was simply wrong about what
 * the author promised. See
 * `decisions/duplicate-mapping-keys-silent-drop-2026-10.yaml`.
 *
 * The walk below consumes the SAME `Jsonl.value` the readers
 * consume, so "what is duplicated" and "what is dropped" cannot
 * disagree — there is no second, independently-implemented YAML
 * scope model that could drift from `parse_yaml_pairs`. This is
 * why the detector lives here and not in a text-level scanner:
 * a text-level scanner has to re-derive block-scalar bodies and
 * sequence-item scopes, and getting that wrong is precisely the
 * defect class being fixed. Block-scalar bodies need no special
 * case at all — `parse_yaml_block` already folded them into a
 * `Jsonl.String`, so they can never appear as keys.
 *)
type duplicate_key = {
  dup_key : string;
  dup_path : string list;
  dup_count : int;
}

(* Preserve first-occurrence order while dropping later repeats. *)
let[@warning "-32"] dedup_preserve_order xs =
  let seen = Hashtbl.create 8 in
  List.filter
    (fun x ->
      if Hashtbl.mem seen x then false
      else begin
        Hashtbl.add seen x ();
        true
      end)
    xs

(* One report per duplicated key per scope. A key declared three
   times yields ONE entry with `dup_count = 3`, not two entries
   and not one per pair of occurrences. *)
let[@warning "-32"] duplicate_keys (v : Jsonl.value) : duplicate_key list =
  let rec walk_object path pairs =
    let keys = List.map fst pairs in
    let reported =
      dedup_preserve_order keys
      |> List.filter_map (fun key ->
          let n = List.length (List.filter (fun k -> k = key) keys) in
          if n < 2 then None
          else Some { dup_key = key; dup_path = path @ [ key ]; dup_count = n })
    in
    (* Recurse into EVERY occurrence: a nested duplicate that lives
       only inside the unreachable second block is still a defect
       the author wants to hear about before merging. The path gets
       an occurrence tag (`obligations#2`) so the two blocks stay
       distinguishable. *)
    let seen = Hashtbl.create 8 in
    let nested =
      List.concat_map
        (fun (key, value) ->
          let occurrence =
            match Hashtbl.find_opt seen key with Some n -> n + 1 | None -> 1
          in
          Hashtbl.replace seen key occurrence;
          let duplicated =
            List.length (List.filter (fun k -> k = key) keys) > 1
          in
          let seg =
            if (not duplicated) || occurrence = 1 then key
            else Printf.sprintf "%s#%d" key occurrence
          in
          walk_value (path @ [ seg ]) value)
        pairs
    in
    reported @ nested
  and walk_value path = function
    | Jsonl.Object ps -> walk_object path ps
    (* Array elements are indexed so the path names WHICH element:
       `obligations[1].acceptance.all[2].result` locates the nested
       duplicate precisely, which a bare dotted key cannot when the
       same key repeats under several siblings. *)
    | Jsonl.Array xs ->
        List.mapi (fun i x -> (i, x)) xs
        |> List.concat_map (fun (i, x) ->
            walk_value (path @ [ Printf.sprintf "[%d]" i ]) x)
    | Jsonl.Null | Jsonl.Bool _ | Jsonl.Int _ | Jsonl.Float _ | Jsonl.String _
      ->
        []
  in
  walk_value [] v

(* 1-based line numbers of every TOP-LEVEL `key:` declaration in
   `raw`. Deliberately restricted to indent 0: a root-level `key:`
   is unambiguous by construction (no block scalar and no sequence
   item can produce a key at column 0), so the locator cannot lie.
   For a duplicated key nested deeper than the root the caller
   passes no lines at all rather than a guess. Reading the token
   stream rather than the raw text keeps the same
   comment-stripping the parser applies, so the two agree on what
   counts as a key at all. *)
let[@warning "-32"] top_level_key_lines raw key =
  yaml_tokens raw
  |> List.filter_map (fun t ->
      if t.yindent <> 0 then None
      else
        match String.index_opt t.ycontent ':' with
        | Some ci when String.trim (String.sub t.ycontent 0 ci) = key ->
            Some t.yline
        | _ -> None)

(* === Unparsed tail (MC-UNPARSED-TAIL) ===
 *
 * `load_yaml_string` calls `parse_yaml_pairs` and throws the
 * unconsumed remainder away. That remainder is not decoration: it
 * is every line the parser could not read. When the parser meets a
 * token deeper than the mapping it is closing (see
 * `parse_yaml_pairs`'s `head_indent tokens > cur_indent` clause),
 * it returns early and the rest of the document is dropped with no
 * diagnostic and a `parse-ok` verdict.
 *
 * The corpus hit this through `fold_continuation`, whose heuristic
 * treats "this deeper line contains a colon" as "this deeper line
 * is a nested key, stop folding". English prose in a folded plain
 * scalar contains colons (`Mitigation: rename the ...`), so the
 * heuristic misfires, `fold_continuation` returns without
 * consuming, and every top-level key from there to EOF vanishes —
 * including `obligations:`, `risk:`, `relations:` and `reversal:`.
 *
 * `load_yaml_string_full` exposes the remainder so the CLI can say
 * so out loud. `load_yaml_string` keeps its old signature and
 * discards it exactly as before, so no existing caller changes. *)
let[@warning "-32"] load_yaml_string_full raw =
  let strip_frontmatter s =
    let lines = yaml_lines s in
    let rec skip_empty acc = function
      | [] -> List.rev acc
      | "" :: rest -> skip_empty acc rest
      | l :: rest -> List.rev acc @ (l :: rest)
    in
    let lines_no_blanks = skip_empty [] lines in
    match lines_no_blanks with
    | "---" :: rest ->
        let rec skip_body acc = function
          | [] -> List.rev acc
          | "---" :: _ -> List.rev acc
          | l :: rest -> skip_body (l :: acc) rest
        in
        skip_body [] rest
    | _ -> lines_no_blanks
  in
  (* A SECOND `---` line is a third silent-drop channel, and it is
     invisible to the leftover check because it fires during
     front-matter stripping, BEFORE tokenisation: `skip_body` stops
     at the next `---`, so every line after it never becomes a
     token and the leftover list comes back empty. Two corpus files
     carry a trailing `---` and the tail behind it is gone. The
     value returned is the 1-based line of that second marker, or
     None when the file has at most one. *)
  let extra_doc =
    let lines = yaml_lines raw in
    let rec go seen n = function
      | [] -> None
      | "---" :: _ when seen -> Some n
      | "---" :: rest -> go true (n + 1) rest
      | _ :: rest -> go seen (n + 1) rest
    in
    go false 1 lines
  in
  let tokens = yaml_tokens (String.concat "\n" (strip_frontmatter raw)) in
  let pairs, leftover = parse_yaml_pairs tokens 0 in
  (Jsonl.Object pairs, leftover, extra_doc)
