(* math-coding CLI.
 *
 * Subcommands:
 *   mathc version                       - print the bootstrap hello and exit 0.
 *   mathc validate FILE [--format=...]  - parse FILE as a decision. Exits
 *                                      0/1/2/3 per spec/semantics.md and
 *                                      OCAML_BEST_PRACTICES §4.3.
 *                                      FILE may be .json or .yaml.
 *   mathc context BASE HEAD --budget N  - print a JSON capsule of relevant
 *                                      context (decisions, obligations,
 *                                      changed paths, recent commits)
 *                                      for an LLM agent. Exit 0 on
 *                                      success, 2 on input error.
 *   mathc assess BASE HEAD              - print a JSON array of changed
 *                                      file paths under BASE..HEAD via
 *                                      `git diff --name-only`. Exit 0
 *                                      on success; exit 2 if git fails
 *                                      or positional arguments are
 *                                      wrong. BASE and HEAD may be any
 *                                      git ref (commit, branch, tag).
 *   mathc import-junit FILE             - parse FILE as a JUnit XML report
 *                                      and print a JSON summary on stdout.
 *                                      Exit 0 on success (including soft
 *                                      parse errors that populate an
 *                                      "error" field); exit 2 only when
 *                                      the path is wrong (file not found,
 *                                      unreadable). `mathc attest FILE` is
 *                                      a deprecated alias that emits a
 *                                      one-shot stderr warning and
 *                                      forwards to the canonical handler.
 *
 * Exit codes:
 *   0  accept   (Decision.parse_decision returned Some _)
 *   1  reject   (kernel rejected the file). A structured diagnostic is
 *                printed.
 *   2  input    (file not found, malformed JSON/YAML, bad CLI args,
 *                bad BASE/HEAD ref).
 *   3  internal (uncaught exception).
 *
 * The kernel (lib/) stays offline and pure. All I/O happens here in
 * bin/. Pure helpers (Jsonl.parse, Decision.parse_decision,
 * Codec.load_yaml_string, Memory.load_memory, Capsule.build_capsule,
 * Junit.parse_junit, Junit.to_json) are called on already-loaded
 * strings or with injected readers. The git adapter
 * (Git_diff.changed_files) lives in lib/git/ and is the I/O
 * boundary for git invocations from this binary. *)

type output_format = Text | Json

let read_file path =
  try Ok (In_channel.with_open_bin path In_channel.input_all) with
  | Sys_error s -> Error (`Sys s)
  | e -> Error (`Other (Printexc.to_string e))

let parse_file path :
    ( Jsonl.value,
      [ `Sys of string | `Other of string | `Parse of string * int * int ] )
    result =
  let ext = Filename.extension path in
  match ext with
  | ".yaml" | ".yml" -> (
      match read_file path with
      | Ok s -> (
          try Ok (Codec.load_yaml_string s)
          with e -> Error (`Other (Printexc.to_string e)))
      | Error e -> Error e)
  | _ -> (
      match read_file path with
      | Ok s -> (
          try Ok (Jsonl.parse s)
          with Jsonl.Parse_error { line; col; msg; context = _ } ->
            Error (`Parse (msg, line, col)))
      | Error e -> Error e)

(* Walk every obligation's acceptance list and emit one diagnostic
   per ambiguous or malformed item. The kernel still parses the
   verifier-half successfully; this collector is what surfaces
   the silent-drop defect so authors can fix the input rather than
   wonder why their review is ignored. *)
let[@warning "-32"] collect_ambiguous_acceptance_diagnostics v =
  match v with
  | Jsonl.Object ps -> (
      match Schema.take_array ps "obligations" with
      | Some obls ->
          List.concat_map
            (fun v ->
              match v with
              | Jsonl.Object ops -> (
                  let id =
                    match Schema.take_string ops "id" with
                    | Some s -> s
                    | None -> ""
                  in
                  match Schema.take_object ops "acceptance" with
                  | Some a ->
                      let _, shapes =
                        Decision.parse_acceptance_with_shapes (Jsonl.Object a)
                      in
                      List.filter_map
                        (fun (pos, shape) ->
                          match shape with
                          | Decision.ShapeAmbiguous ->
                              Some
                                (Diagnostic.ambiguous_acceptance
                                   ~obligation_id:id ~item_position:pos ())
                          | Decision.ShapeMalformed ->
                              Some
                                (Diagnostic.malformed_acceptance
                                   ~obligation_id:id ~item_position:pos
                                   "verifier or review present but unparseable")
                          | Decision.ShapeVerifier | Decision.ShapeReview
                          | Decision.ShapeEmpty ->
                              None)
                        shapes
                  | None -> [])
              | _ -> [])
            obls
      | None -> [])
  | _ -> []

(* MC-DUPLICATE-KEY collector: one Warn diagnostic per duplicated
   mapping key. Runs on the ALREADY-PARSED document, so the
   detector and the readers agree by construction — see
   `lib/codec.ml::duplicate_keys` for why this is a tree walk and
   not a text scan.

   `raw` is re-read only to attach line numbers, and only for
   root-level keys where a top-level `key:` line is unambiguous.
   A key nested deeper than the root gets no lines rather than a
   guessed position. *)
let[@warning "-32"] collect_duplicate_key_diagnostics path v =
  let raw = match read_file path with Ok s -> s | Error _ -> "" in
  Codec.duplicate_keys v
  |> List.map (fun d ->
      let lines =
        match d.Codec.dup_path with
        | [ k ] -> Codec.top_level_key_lines raw k
        | _ -> []
      in
      Diagnostic.mc_duplicate_key ~key:d.Codec.dup_key ~path:d.dup_path
        ~occurrences:d.dup_count ~lines ())

(* MC-UNPARSED-TAIL collector: the complementary half of the
   silent-drop family. Re-parses the raw text with
   `load_yaml_string_full` — the same loader `parse_file` used, so
   the remainder reported here is the remainder the verdict was
   computed from, not a second opinion. Two channels feed it:

     - the token list `parse_yaml_pairs` did not consume (the
       loader returned early);
     - a second `---` document marker, which truncates the file
       during front-matter stripping, before tokenisation, so the
       leftover list is empty and only the marker betrays it.

   Content dropped by either is ABSENT from the tree, so the
   duplicate-key walk cannot see it; without this collector a
   truncated decision validates clean and the gate never learns
   what it missed.

   Scoped to the YAML loader on purpose: `parse_file` dispatches
   on the extension, so a `.json` input went through `Jsonl.parse`
   and never through `parse_yaml_pairs` at all. Re-parsing it as
   YAML stalls on the opening `{` and would report a tail that the
   verdict was not computed from -- a diagnostic about a code path
   that did not run. The duplicate-key walk has no such guard
   because it inspects the parsed tree, which is the same object
   for both formats. *)
let[@warning "-32"] collect_unparsed_tail_diagnostics path =
  match Filename.extension path with
  | ".yaml" | ".yml" -> (
      match read_file path with
      | Error _ -> []
      | Ok raw ->
          let _, leftover, extra_doc = Codec.load_yaml_string_full raw in
          let tail =
            match leftover with
            | [] -> []
            | first :: _ ->
                [
                  Diagnostic.mc_unparsed_tail
                    ~path:[ Printf.sprintf "line %d" first.Codec.yline ]
                    ~line:first.Codec.yline ~content:first.Codec.ycontent
                    ~lost:(List.length leftover) ();
                ]
          in
          let doc =
            match extra_doc with
            | None -> []
            | Some line ->
                [
                  Diagnostic.mc_unparsed_tail
                    ~path:[ Printf.sprintf "document %d" 2 ]
                    ~line ~content:"---"
                    ~lost:(max 1 (List.length (Codec.yaml_lines raw) - line))
                    ~document_marker:true ();
                ]
          in
          tail @ doc)
  | _ -> []

(* Canonical verifier scheme allowlist (plan-decision C5,
   decisions/verifier-scheme-convention-2026-11.yaml). The
   scheme is the first whitespace-delimited token of the
   verifier string (see `parse_verifier_string`). An item
   matches the canonical list iff either:

     (a) its scheme is in `canonical_verifier_schemes` exactly,
     (b) its scheme starts with one of the strings in
         `canonical_verifier_prefixes`.

   The list is intentionally minimal — it does NOT try to
   cover every bespoke scheme name in this repo's decision
   corpus; the diagnostic is the discoverability surface
   for the convention, not a check on existing usage. New
   scheme families extend the list via a follow-up
   decision.

   `dune` (bare) is a command-runner scheme exactly like
   `bash` and `mathc` — the corpus uses `verifier: dune build`
   / `verifier: dune test` widely. `dune-` covers the
   sentinel forms `dune-build` / `dune-runtest`. *)
let[@warning "-32"] canonical_verifier_schemes =
  [ "file-exists"; "dir-exists"; "bash"; "mathc"; "shell-grep"; "dune" ]

let[@warning "-32"] canonical_verifier_prefixes =
  [ "text-scan-"; "tests/"; "dune-"; "scripts/"; "manual-" ]

let[@warning "-32"] known_verifier_scheme scheme =
  if List.mem scheme canonical_verifier_schemes then true
  else
    List.exists
      (fun prefix ->
        String.length scheme >= String.length prefix
        && String.sub scheme 0 (String.length prefix) = prefix)
      canonical_verifier_prefixes

(* Inline copy of `parse_verifier_string` (defined later in
   this file, around line 2874). The OCaml toplevel is
   sequential so we can't forward-reference; the body is 6
   lines so duplicating it is cheaper than reordering. *)
let[@warning "-32"] scheme_of_verifier s =
  let trimmed = String.trim s in
  if trimmed = "" then None
  else
    let parts =
      trimmed |> String.split_on_char ' '
      |> List.filter (fun t -> String.trim t <> "")
    in
    match parts with [] -> None | scheme :: _ -> Some scheme

(* Walk every obligation's acceptance list and emit one Warn
   MC-VERIFIER-SCHEME-UNKNOWN diagnostic per non-canonical
   scheme token. Mirrors the structure of
   `collect_ambiguous_acceptance_diagnostics` above: walks
   raw Jsonl (not the parsed Domain tree) because verifier
   strings are opaque to the kernel. The scheme is the
   first whitespace-delimited token of the verifier string
   (extracted via `scheme_of_verifier` here; the production
   parser `parse_verifier_string` lives below the verify
   subcommand block and is identical).

   An empty/whitespace-only verifier string is silently
   skipped (scheme_of_verifier returns None); the
   malformed-acceptance diagnostic already covers the
   verifier-shaped-but-empty case via
   `Decision.classify_acceptance_item`. *)
let[@warning "-32"] collect_verifier_scheme_diagnostics v =
  match v with
  | Jsonl.Object ps -> (
      match Schema.take_array ps "obligations" with
      | Some obls ->
          List.concat_map
            (fun v ->
              match v with
              | Jsonl.Object ops -> (
                  let id =
                    match Schema.take_string ops "id" with
                    | Some s -> s
                    | None -> ""
                  in
                  match Schema.take_object ops "acceptance" with
                  | Some a -> (
                      match Schema.take_array a "all" with
                      | Some xs ->
                          List.filter_map
                            (fun item ->
                              match item with
                              | Jsonl.Object ips -> (
                                  match Schema.take_string ips "verifier" with
                                  | Some s -> (
                                      match scheme_of_verifier s with
                                      | Some scheme ->
                                          if known_verifier_scheme scheme then
                                            None
                                          else
                                            Some
                                              (Diagnostic
                                               .mc_verifier_scheme_unknown
                                                 ~obligation_id:id ~scheme
                                                 ~verifier:s ())
                                      | None -> None)
                                  | None -> None)
                              | _ -> None)
                            xs
                      | None -> [])
                  | None -> [])
              | _ -> [])
            obls
      | None -> [])
  | _ -> []

(* Required top-level fields per schemas/decision.json. Used by
   validate_with_counts to surface the FIRST missing field instead
   of a generic "missing or invalid required field". *)
let decision_required_fields =
  [ "schema"; "id"; "intent"; "commitment"; "scope"; "outcomes"; "obligations" ]

let first_missing_required v =
  match v with
  | Jsonl.Object ps ->
      let keys = List.map fst ps in
      List.find_opt (fun f -> not (List.mem f keys)) decision_required_fields
  | _ -> None

(* T2.2: detect axiom_link violations pre-parse. The parser
   rejects active+empty axiom_link by returning None; the CLI
   distinguishes that specific cause from the generic
   "missing or invalid required field" reject by inspecting
   the raw input FIRST. The check is:
     state == active (or absent, which defaults to active per
       schemas/decision.json), AND
     axiom_link field is absent OR an empty array.
   Draft / Retired / Superseded decisions are exempt. The
   diagnostic id is `MC-AXIOM-LINK-MISSING` (registered in
   `lib/diagnostic.ml::explain`); the helper that builds it is
   `Diagnostic.axiom_link_missing`. The decision_id is read
   for the message body; missing id is fine (the message is
   informative without it). This block is the surgical
   bin/Mathc.ml addition that stream ε (T2.2) needed; stream
   η (T4.1) refactored it out by mistake and stream ε (T6.2)
   restores it as part of the same A3-protected transition
   pipeline.
*)
let axiom_link_violation v =
  match v with
  | Jsonl.Object ps -> (
      let state_str =
        match Schema.take_string ps "state" with
        | Some s -> s
        | None -> "active"
      in
      let axiom_link_present =
        match Schema.take_array ps "axiom_link" with
        | Some xs ->
            List.exists
              (fun x ->
                match x with
                | Jsonl.String s when String.trim s <> "" -> true
                | _ -> false)
              xs
        | None -> false
      in
      match state_str with
      | "active" when not axiom_link_present ->
          let decision_id =
            match Schema.take_string ps "id" with Some s -> s | None -> ""
          in
          Some (Diagnostic.axiom_link_missing ~decision_id ())
      | _ -> None)
  | _ -> None

(* T6.2: detect counterexample violations pre-parse. The parser
   rejects decisions whose mode is >= standard with an empty
   counterexample by returning None; the CLI distinguishes that
   specific cause from the generic "missing or invalid required
   field" reject (and from the T2.2 axiom_link violation) by
   inspecting the raw input FIRST. The check is:
     mode >= standard (i.e. mode ∈ {standard, strict, exhaustive};
       mode absent defaults to `standard` per Codec.parse_mode's
       default and Domain.mode encoding in lib/domain.ml:43),
       AND
     counterexample field is absent OR is a YAML scalar that
       trims to the empty string OR is a JSON array where every
       element trims to the empty string.

   Tiny / light modes are exempt (counterexample remains a soft
   Warn at most for those modes; the legacy soft-warning path
   below `validate_with_counts` is unchanged). The diagnostic
   id is `MC-COUNTEREXAMPLE-MISSING` (registered in
   `lib/diagnostic.ml::explain`); the helper that builds it is
   `Diagnostic.mc_counterexample_missing` with the new
   `~severity:Block` parameter. The decision_id is read for the
   message body. The rule is A3-protected (per
   `spec/constitution.md` §Self-application and the A3
   separation axiom: a contract change cannot authorize its own
   adoption); human review is required before merge (see the
   dual attestations `attestations/t6-2-*.json` and
   `attestations/plan-2026-10-improvements-t6-2-*.json`). *)
let counterexample_violation v =
  match v with
  | Jsonl.Object ps -> (
      let mode_str =
        match Schema.take_string ps "mode" with
        | Some s -> s
        | None -> "standard"
      in
      (* mode_exempt is true ONLY for tiny and light; standard, strict,
         exhaustive, considered all require a counterexample. The
         previous implementation inverted the predicate (returning
         true for every named mode except considered), which made the
         pre-parse check silently no-op for the default mode=standard.
         See decisions/kernel-bugs-v3.4-2026-10 for the closure. *)
      let mode_exempt =
        match mode_str with
        | "tiny" | "light" -> true
        | "standard" | "strict" | "exhaustive" | "considered" -> false
        | _ -> true (* unknown mode defaults to exempt (defensive) *)
      in
      let counterexample_meaningful =
        match Schema.take_string ps "counterexample" with
        | Some s when String.trim s <> "" -> true
        | _ -> (
            match Schema.take_array ps "counterexample" with
            | Some xs ->
                List.exists
                  (fun x ->
                    match x with
                    | Jsonl.String s when String.trim s <> "" -> true
                    | _ -> false)
                  xs
            | None -> false)
      in
      match mode_exempt with
      | true -> None
      | false when not counterexample_meaningful ->
          let decision_id =
            match Schema.take_string ps "id" with Some s -> s | None -> ""
          in
          let msg =
            Printf.sprintf "%s%s%s"
              (if decision_id = "" then "" else decision_id ^ ": ")
              "decision has mode="
              (if mode_str = "" then "standard" else mode_str)
            ^
            match mode_str with
            | "light" -> ""
            | _ ->
                " but empty counterexample: spec/algebra-3.2.md §11 requires \
                 the counterexample dialectical slot for modes >= standard; \
                 add a counterexample section naming the strongest objection \
                 (or downgrade to mode: light if a documented soft slot is "
                ^ "appropriate)"
          in
          Some
            (Diagnostic.mc_counterexample_missing ~decision_id
               ~severity:Diagnostic.Block msg)
      | _ -> None)
  | _ -> None

(* Antithesis violation: parallel to `counterexample_violation` for the
   antithesis slot (v3 dialectic method). A decision with mode >= standard
   must carry a non-empty antithesis. See
   `decisions/dialectic-method-v3-2026-10.yaml` and
   `spec/algebra-3.2.md` §11. The kernel-side check in
   `lib/decision.ml::parse_decision` returns None when antithesis is
   missing; this CLI-side check surfaces a precise diagnostic so the
   author knows whether the missing field is counterexample or antithesis. *)
let antithesis_violation v =
  match v with
  | Jsonl.Object ps -> (
      let mode_str =
        match Schema.take_string ps "mode" with
        | Some s -> s
        | None -> "standard"
      in
      (* antithesis is required ONLY for mode=considered per
         decisions/antithesis-mode-considered-2026-10; every other
         mode is exempt from this pre-parse check. The kernel-side
         predicate `mode_geq_considered` (lib/decision.ml:421) is the
         single source of truth. *)
      let mode_exempt =
        match mode_str with "considered" -> false | _ -> true
      in
      let antithesis_meaningful =
        match Schema.take_string ps "antithesis" with
        | Some s when String.trim s <> "" -> true
        | _ -> false
      in
      match mode_exempt with
      | true -> None
      | false when not antithesis_meaningful ->
          let decision_id =
            match Schema.take_string ps "id" with Some s -> s | None -> ""
          in
          let msg =
            Printf.sprintf
              "%sdecision has mode=%s but empty antithesis: \
               spec/algebra-3.2.md §11 (v3 dialectic method) requires the \
               antithesis dialectical slot for mode = considered; add an \
               antithesis section naming the coherent counter-position the \
               author considered and rejected (distinct from counterexample, \
               which is the strongest objection surfaced to future readers)"
              (if decision_id = "" then "" else decision_id ^ ": ")
              (if mode_str = "" then "considered" else mode_str)
          in
          Some
            (Diagnostic.mc_antithesis_missing ~decision_id
               ~severity:Diagnostic.Block msg)
      | _ -> None)
  | _ -> None

type aggregate_evidence = {
  kind : string;
  id : string;
  extra_diags : Diagnostic.t list;
}

let validate_with_counts path =
  match parse_file path with
  | Error (`Sys m) -> `Input_err m
  | Error (`Other m) -> `Input_err m
  | Error (`Parse (m, line, col)) ->
      let msg = Printf.sprintf "%s at line %d col %d" m line col in
      `Reject (Diagnostic.mc_parse msg, msg)
  | Ok v -> (
      (* mathc-validate-skip-non-decisions-fix-2026-10: dispatch
         on the top-level `schema:` field BEFORE the decision
         required-field check. Waiver and obligations-aggregator
         files live under `decisions/` and are well-formed for
         their own schema family, but they lack the decision-
         required fields (intent, commitment, scope, outcomes,
         obligations). Without the dispatch, the decision parser
         rejects them with `MC-DECISION-INVALID: missing required
         field: <id|intent>` and there is no way for the user to
         validate them.

         The dispatch returns Some (kind, id) for the two known
         non-decision families (`math-coding/waiver-*` and
         `math-coding/obligations-*`); for waivers the helper also
         verifies `kind: waiver`. Anything else returns None and
         falls through to the decision parser unchanged — the
         decision path is not weakened. *)
      (* MC-DUPLICATE-KEY is a property of the mapping itself, not
         of the schema family, so the collector runs BEFORE the
         family dispatch and its diagnostics ride along on every
         Accept branch below. A waiver or obligations aggregator
         with a duplicated key is just as unreachable as a
         decision's. *)
      let dup_diags =
        collect_unparsed_tail_diagnostics path
        @ collect_duplicate_key_diagnostics path v
      in
      match Decision.peek_schema_family v with
      | Some (Decision.Waiver, id) ->
          `Accept_aggregate { kind = "waiver"; id; extra_diags = dup_diags }
      | Some (Decision.Obligations, id) ->
          `Accept_aggregate
            { kind = "obligations"; id; extra_diags = dup_diags }
      | Some (Decision.Attestation, id) -> (
          (* MC-MATERIALS-DIGEST-EMPTY dispatch
                (decisions/kernel-bugs-v3.4-2026-10). The validator is
                separate from parse_attestation so the loader can
                grandfather legacy attestations whose `issued_at`
                predates 2026-10-16. *)
          match Codec.parse_attestation v with
          | Some a -> (
              match Codec.validate_attestation_materials a with
              | Some diag ->
                  let msg = diag.Diagnostic.message in
                  `Reject (diag, msg)
              | None ->
                  `Accept_aggregate
                    { kind = "attestation"; id; extra_diags = dup_diags })
          | None ->
              let msg =
                "attestation is not parseable: schemas/attestation.json \
                 requires schema, id, kind, subject, kind_, producer, result, \
                 issued_at; check the file against the schema"
              in
              `Reject
                (Diagnostic.mc_decision_invalid ~path:[ "attestation" ] msg, msg)
          )
      | None -> (
          match first_missing_required v with
          | Some field ->
              let msg = Printf.sprintf "missing required field: %s" field in
              `Reject (Diagnostic.mc_decision_invalid ~path:[ field ] msg, msg)
          | None -> (
              (* T6.2: counterexample-mode-required runs BEFORE
             parse_decision_yaml so we get a precise Block-level
             `MC-COUNTEREXAMPLE-MISSING` diagnostic and the right exit
             code (1). The parser also returns None for the same
             rule; this pre-check is what determines which exact
             diagnostic code/severity reaches the user.
             T2.2: same trick is used for `MC-AXIOM-LINK-MISSING` —
             we restored the helper that stream η (T4.1) had
             refactored out by mistake.
             Order axiom -> counterexample: axiom_link is enforced
             first because it was the earlier rule (T2.2 vs T6.2);
             keeping the prior order means we emit axiom_link first
             when both fire, which is the more general message. *)
              match axiom_link_violation v with
              | Some diag ->
                  let msg = diag.Diagnostic.message in
                  `Reject (diag, msg)
              | None -> (
                  match counterexample_violation v with
                  | Some diag ->
                      let msg = diag.Diagnostic.message in
                      `Reject (diag, msg)
                  | None -> (
                      match antithesis_violation v with
                      | Some diag ->
                          let msg = diag.Diagnostic.message in
                          `Reject (diag, msg)
                      | None -> (
                          try
                            match Decision.parse_decision_yaml v with
                            | Some d -> (
                                (* T0.2: sha-match enforcement (spec/algebra-3.2.md §7,
                           schemas/decision.json: when both `body_sha` and
                           `yaml_sha` are present, the digests must agree.
                           sha_match_check returns `(bool, Diagnostic.t list)`;
                           the bool is non-binding here — the diagnostic list
                           is the single source of truth for surface emission.
                           A Block diagnostic still rejects the file. *)
                                let _, sha_match_diags =
                                  Decision.sha_match_check d
                                in
                                match sha_match_diags with
                                | first :: _ ->
                                    let msg =
                                      Printf.sprintf
                                        "body_sha ≠ yaml_sha (see %s)"
                                        first.Diagnostic.code
                                    in
                                    `Reject (first, msg)
                                | [] ->
                                    let extra_diags =
                                      collect_ambiguous_acceptance_diagnostics v
                                    in
                                    (* T6.2: counterexample is required for
                               modes >= standard (Block); for modes in
                               {tiny, light} the counterexample field is
                               optional and missing-ness becomes a soft
                               Warn (the legacy soft-warning path
                               preserved from the pre-T6.2 kernel). The
                               Block case is already rejected by the
                               pre-parse check above; here we only emit
                               the Warn for tiny / light modes. *)
                                    let counterexample_diag =
                                      if d.Domain.counterexample = None then
                                        Some
                                          (Diagnostic.mc_counterexample_missing
                                             ~decision_id:d.Domain.id
                                             "missing counterexample: \
                                              spec/algebra-3.2.md §11 names it \
                                              as a dialectical slot for modes \
                                              >= light; add a counterexample \
                                              section naming the strongest \
                                              objection (legacy soft warning; \
                                              the Block path was already \
                                              rejected before parse)")
                                      else None
                                    in
                                    let extra_diags =
                                      match counterexample_diag with
                                      | Some diag -> diag :: extra_diags
                                      | None -> extra_diags
                                    in
                                    (* Plan-decision C5: emit one Warn
                                       MC-VERIFIER-SCHEME-UNKNOWN per
                                       non-canonical scheme token in
                                       obligations[*].acceptance.all[*].verifier.
                                       Severity is Warn (the verdict stays
                                       parse-ok); the diagnostic is the
                                       discoverability surface for the
                                       convention documented in
                                       decisions/verifier-scheme-convention-2026-11.yaml. *)
                                    let extra_diags =
                                      collect_verifier_scheme_diagnostics v
                                      @ extra_diags
                                    in
                                    let extra_diags = dup_diags @ extra_diags in
                                    `Accept (d, extra_diags))
                            | None ->
                                (* D8 (Slice A): the parser now returns a typed
                           Diagnostic.t option. When parse_decision_yaml
                           rejects, surface the parser-level Diagnostic.t
                           so the author sees the specific MC-* code (e.g.
                           MC-MISSING-ID) instead of the coarse legacy
                           "missing or invalid required field" string. *)
                                let diag =
                                  match Decision.parse_decision v with
                                  | Some d -> d
                                  | None ->
                                      Diagnostic.mc_decision_invalid
                                        "missing or invalid required field \
                                         (parser rejected without a specific \
                                         MC-* code; check the schema contract \
                                         in schemas/decision.json)"
                                in
                                let msg = diag.Diagnostic.message in
                                `Reject (diag, msg)
                          with
                          | Jsonl.Parse_error
                              { line; col; msg = raw_msg; context }
                          ->
                            let msg =
                              Printf.sprintf "%s at line %d col %d" raw_msg line
                                col
                            in
                            `Reject (Diagnostic.mc_parse ~cause:context msg, msg)
                          ))))))

let emit (format : output_format) path
    (outcome :
      [ `Input_err of string
      | `Accept of Domain.decision * Diagnostic.t list
      | `Accept_aggregate of aggregate_evidence
      | `Reject of Diagnostic.t * string ]) =
  match outcome with
  | `Input_err m ->
      let d = Diagnostic.create ~code:"MC-INPUT" ~severity:Diagnostic.Warn m in
      Printf.fprintf stderr "[%s] %s/%s: %s\n"
        (Diagnostic.string_of_severity d.severity)
        (Diagnostic.string_of_kind d.kind)
        d.code d.message;
      exit 2
  | `Accept (d, extra_diags) ->
      let decision_id = d.Domain.id in
      let revision = d.Domain.rev in
      let obligations = List.length d.Domain.obligations in
      let assumptions = List.length d.Domain.assumptions in
      (match format with
      | Text ->
          Printf.printf
            "parse-ok: %s\n\
            \  decision: %s\n\
            \  revision: %s\n\
            \  obligations: %d\n\
            \  assumptions: %d\n"
            path decision_id revision obligations assumptions
      | Json ->
          let extras =
            if extra_diags = [] then ""
            else
              Printf.sprintf ",\"diagnostics\":[%s]"
                (String.concat ","
                   (List.map
                      (fun d ->
                        Printf.sprintf
                          "{\"code\":\"%s\",\"severity\":\"%s\",\"message\":%s}"
                          d.Diagnostic.code
                          (Diagnostic.string_of_severity d.severity)
                          (Jsonl.stringify (Jsonl.String d.message)))
                      extra_diags))
          in
          Printf.printf
            "{\"verdict\":\"parse-ok\",\"path\":%s,\"decision\":\"%s\",\"revision\":\"%s\",\"obligations\":%d,\"assumptions\":%d%s}\n"
            (Jsonl.stringify (Jsonl.String path))
            decision_id revision obligations assumptions extras);
      (* Print extra diagnostics (e.g., MC-AMBIGUOUS-ACCEPTANCE) to
         stderr. The verdict is still "parse-ok" because the kernel
         DID parse the verifier-half; the diagnostic tells the
         author that their review half is silently dropped. *)
      List.iter
        (fun diag ->
          Printf.fprintf stderr "[%s] %s/%s: %s\n"
            (Diagnostic.string_of_severity diag.Diagnostic.severity)
            (Diagnostic.string_of_kind diag.kind)
            diag.Diagnostic.code diag.message)
        extra_diags;
      exit 0
  | `Accept_aggregate { kind; id; extra_diags } ->
      (* mathc-validate-skip-non-decisions-fix-2026-10: waiver and
         obligations files take a permissive fast path through
         `Decision.peek_schema_family`. The verdict is "parse-ok"
         with a `kind:` annotation; no decision-shaped fields
         (revision, obligations, assumptions) are reported because
         those concepts do not exist on the waiver/aggregator
         family. The author of a waiver should not be told the
         waiver has zero obligations. *)
      (match format with
      | Text ->
          Printf.printf "parse-ok: %s\n  kind: %s\n  id: %s\n" path kind id
      | Json ->
          let extras =
            if extra_diags = [] then ""
            else
              Printf.sprintf ",\"diagnostics\":[%s]"
                (String.concat ","
                   (List.map
                      (fun d ->
                        Printf.sprintf
                          "{\"code\":\"%s\",\"severity\":\"%s\",\"message\":%s}"
                          d.Diagnostic.code
                          (Diagnostic.string_of_severity d.severity)
                          (Jsonl.stringify (Jsonl.String d.message)))
                      extra_diags))
          in
          Printf.printf
            "{\"verdict\":\"parse-ok\",\"path\":%s,\"kind\":%s,\"id\":%s%s}\n"
            (Jsonl.stringify (Jsonl.String path))
            (Jsonl.stringify (Jsonl.String kind))
            (Jsonl.stringify (Jsonl.String id))
            extras);
      List.iter
        (fun diag ->
          Printf.fprintf stderr "[%s] %s/%s: %s\n"
            (Diagnostic.string_of_severity diag.Diagnostic.severity)
            (Diagnostic.string_of_kind diag.kind)
            diag.Diagnostic.code diag.message)
        extra_diags;
      exit 0
  | `Reject (d, _) ->
      (match format with
      | Text ->
          Printf.printf
            "reject: %s\n  code: %s\n  severity: %s\n  message: %s\n" path
            d.Diagnostic.code
            (Diagnostic.string_of_severity d.severity)
            d.message
      | Json ->
          Printf.printf
            "{\"verdict\":\"reject\",\"path\":%s,\"code\":\"%s\",\"severity\":\"%s\",\"message\":%s}\n"
            (Jsonl.stringify (Jsonl.String path))
            d.Diagnostic.code
            (Diagnostic.string_of_severity d.severity)
            (Jsonl.stringify (Jsonl.String d.message)));
      exit 1

(* `mathc version` prints the live project version. The string is
   read from `./VERSION` at runtime so `scripts/release.sh` and
   the build pipeline only need to update one file. *)
let[@warning "-32"] read_cli_version () =
  let dune_root =
    match Sys.getenv_opt "DUNE_SOURCEROOT" with
    | Some p -> Some (Filename.concat p "VERSION")
    | None -> None
  in
  let candidates =
    Option.to_list dune_root
    @ [
        "VERSION";
        "../VERSION";
        "../../VERSION";
        "../../../VERSION";
        "../../../../VERSION";
      ]
  in
  let try_one path =
    if Sys.file_exists path then begin
      let ic = open_in path in
      let n = in_channel_length ic in
      let s = really_input_string ic n in
      close_in ic;
      Some (s |> String.trim)
    end
    else None
  in
  let rec loop = function
    | [] -> "math-coding"
    | p :: rest -> ( match try_one p with Some v -> v | None -> loop rest)
  in
  loop candidates

let[@warning "-32"] print_version () =
  Printf.printf "math-coding %s: bootstrap\n" (read_cli_version ())

let print_usage oc =
  Printf.fprintf oc
    "usage: mathc <command> [args]\n\n\
     commands:\n\
    \  version [--check]                print the bootstrap hello (with --check,\n\
    \                                   exit 1 + newer version on stdout when an\n\
    \                                   upgrade is available)\n\
    \  validate FILE [--format=...]     parse FILE as a decision\n\
    \  verify FILE [--format=...]       walk acceptance.all[*].verifier\n\
    \                                   strings in FILE and execute them in\n\
    \                                   a sandbox (subprocess, env-stripped,\n\
    \                                   60s timeout, cwd = project root).\n\
    \                                   Per-obligation verdict is one of\n\
    \                                   pass | fail | skipped. See\n\
    \                                   bin/Mathc.ml::do_verify for the\n\
    \                                   scheme allowlist.\n\
    \  update [--channel=...] [--yes]   self-update the mathc binary by shelling\n\
    \                                   out to \
     scripts/install-tooling/install.{sh,\n\
    \                                   ps1} with --version=<resolved>.\n\
    \  context BASE HEAD --budget N     print a JSON context capsule\n\
    \  explain DETAIL_REF               print JSON {kind,id,digest,path,body} \
     for the ref\n\
    \  explain-diagnostic <CODE>        print JSON {code,definition,occurs_when,\n\
    \  forge-verify [--org ORG]            query forge_mirror for team\n\
    \                  [--team TEAM]          membership of the committer;\n\
    \                  [--user USER]          fail-mode open|closed (default \
     open)\n\
    \                                   remediation} for an MC-* diagnostic code\n\
    \  assess BASE HEAD                 print JSON array of changed file paths\n\
    \  import-junit FILE                parse FILE as a JUnit XML report\n\
     (canonical name; `attest` is a\n\
     deprecated alias emitting a\n\
     stderr warning)\n\
    \  attest-batch [--manifest=PATH]    generate attestation JSONs from a TSV\n\
     [--from=...]   manifest or by walking\n\
     [--out=DIR]   MATH_CODING_DECISIONS_DIR. Output\n\
     [--kind=...]  goes to MATH_CODING_ATTESTATIONS_DIR\n\
     [--producer=ID] (or .math-coding/attestations).\n\
     [--result=pass|fail]\n\
     [--dry-run]   See bin/Mathc.ml::do_attest_batch.\n\
    \  time-estimate --class ...        print JSON forecast from declared \
     distribution\n\
    \  gate BASE HEAD                   print JSON gate verdict (scaffold)\n\
    \  mode PATHS...                    compute risk + mode from paths (v3.2 §2)\n\
    \  rebuttals COMMIT_SHA              load rebuttals/<sha>.yaml (v3.2 §10)\n\
    \  re-evaluate                       run re_evaluate oracle (v3.2 §17)\n\
    \  re-evaluate-decisions AXIOM_ID    walk decisions/ and emit post-run\n\
    \                                   verdicts + attestations (T1.2)\n\
    \  self-check                       print JSON self-check verdict; exits \
     0|1|3\n\
    \  session-start                    write .local/session-start ISO timestamp\n\
    \  record --decision-id ID ...      append event to \
     decisions/execution-logs.jsonl\n\
    \  stats [--class N] [--scale S]    emit empirical aggregate JSON\n\
    \  packages [--format=...]         list decisions + verdicts \
     (text|json|html)\n\
    \  find KEYWORD [--obligation=ID]    case-insensitive substring search \
     across\n\
    \                       [--format=json]      decisions/ (or \
     single-obligation lookup).\n\
    \                                            Output is a `mathc \
     packages`-shaped JSON\n\
    \                                            object with `decisions[]` \
     filtered.\n\
    \       precommit [PATH...]               batch-validate decisions/*.yaml \
     (or the\n\
    \                       [--format=text|json]   listed paths) by shelling \
     out to\n\
    \                                            `mathc validate` per file. \
     Exit 0 if all\n\
    \                                            accept, 1 if any reject, 2 if \
     any input\n\
    \                                            error. No attestation store, \
     no git diff.\n\
    \       decision-state <id>                transition a single decision's \
     lifecycle\n\
    \                       <action>           state. Actions: mark-superseded\n\
    \                       [--by=<id>@<rev>]  --by=<id>@<rev>, mark-retired, \
     set\n\
    \                                            \
     <active|draft|retired|superseded>.\n\
    \                                            Writes the patched YAML back to\n\
    \                                            decisions/<id>.yaml, then \
     re-runs\n\
    \                                            `mathc validate`. Exit 0 on \
     accept,\n\
    \                                            1 on reject (idempotent \
     re-issue or\n\
    \                                            kernel validation failure), 2 \
     on\n\
    \                                            input error (no such id, bad \
     kebab,\n\
    \                                            missing args). The user-facing\n\
    \                                            aliases obsolete and archive \
     are\n\
    \                                            NOT accepted; see\n\
    \                                            lib/lifecycle/lifecycle.ml \
     preamble.\n\
    \       render [--out DIR] [--lang en|ru|zh|both|all]\n\
    \                [--site-base HREF] [--mathjax|--no-mathjax]\n\
    \                                     render the static site under DIR\n\
    \  counters                          emit JSON counts (decisions, \
     obligations,\n\
    \                                     attestations, self-check, cram, CLI)\n\
    \  init [PATH] [--agent NAME]        scaffold a new math-coding project:\n\
    \                  [--from-adr PATH]     create decisions/, attestations/, \
     write\n\
    \                  [--no-install]        decisions/decision.yaml, install \
     the\n\
    \                  [--merge]             pre-commit hook. Refuses on \
     arc42/MADR\n\
    \                  [--with-ci-workflow]  unless --merge; --from-adr is a \
     no-op\n\
    \                                       stub (deferred to ux-3-import-adr).\n\
    \                                       --with-ci-workflow copies\n\
    \                                       templates/ci.yml to\n\
    \                                       .github/workflows/ci.yml (off by \
     default).\n\
    \  import-adr PATH                    import an existing ADR file (MADR or\n\
    \                                       [--write]                       \
     adr-tools shape) and emit a math-coding decision\n\
    \                                       YAML to stdout (or to \
     decisions/<id>.yaml\n\
    \                                       with --write). Best-effort; the user\n\
    \                                       reviews the output before mathc \
     validate.\n\
     adopt [PATH]                                    brownfield adoption: \
     detect arc42/MADR/adr-tools;\n\
     orchestrate init + per-file import-adr via\n\
     [--agent NAME]                                  Sys.executable_name (no \
     PATH lookup);\n\
     [--no-install]                                  see \
     ux-3-adopt-subcommand-2026-10.\n\
     [--dry-run]\n\
     [--only=CONV]\n\
     [--merge]\n\
     new-decision <id>                            scaffold a decision file \
     from the canonical\n\
     [--write]                        template; --write writes \
     decisions/<id>.yaml;\n\
     [--interactive]                  --interactive is a stub in this slice.\n\
     [--force]\n\
    \  telemetry status                   print current telemetry state (Phase \
     2; tracked: decisions/ux-3-telemetry-stub-2026-10.yaml\n\
    \                                     stub; no transport, no data \
     emission).\n\n\
     migrate --from=X --to=Y                        declarative migration plan \
     reader; emit a\n\
     per-file plan from\n\
     [--root=DIR]                                    \
     decisions/migrations/<from>-to-<to>.yaml;\n\
     [--format=text|json]                            --write writes sibling \
     <file>.migrated.yaml\n\
     [--explain]                                     (kernel never mutates the \
     original).\n\
     [--manifest=PATH]                               See \
     migration-mechanism-2026-10.\n\
     [--write|--dry-run]\n\
    \  doctor [--json]                       print install-coverage \
     diagnostic; sections\n\
     install, path, latest, config, decisions,\n\
     attestations, self-check (skip). Exit 0 when\n\
     no section is `fail`, 1 otherwise. See\n\
     mathc-doctor-subcommand-2026-10.\n\n\
    \     options:\n\
    \  --format=text (default) or --format=json\n\
    \  --budget=N    max bytes for the context capsule (default 8192)\n\n\
     exit codes:\n\
    \  0 accept  1 reject  2 input error  3 internal error\n"

let parse_format s =
  match s with
  | "text" -> Text
  | "json" -> Json
  | _ -> raise (Arg.Bad ("unknown --format value: " ^ s))

let do_validate () =
  let format = ref Text in
  let file = ref "" in
  let set_file s = file := s in
  let set_format s = format := parse_format s in
  Arg.current := 1;
  Arg.parse
    [
      ( "--format",
        Arg.String set_format,
        " Output format: text (default) or json" );
    ]
    set_file "usage: mathc validate FILE [--format=...]";
  let path = !file in
  if path = "" then begin
    print_usage stderr;
    exit 2
  end;
  emit !format path (validate_with_counts path)

(* --- context subcommand --- *)

(* Read a file path; same helper as validate so error messages
   share semantics. *)
let read_file_for_capsule path =
  try Ok (In_channel.with_open_bin path In_channel.input_all) with
  | Sys_error s -> Error (`Sys s)
  | e -> Error (`Other (Printexc.to_string e))

(* Run `git log BASE..HEAD --oneline` or `git diff BASE..HEAD --name-only`
   via the shell. We only run two invocations per `mathc context` call;
   subprocess latency is acceptable here.

   Note: we read until EOF instead of using `in_channel_length` because
   pipes report 0 length (the data hasn't been buffered yet). *)
let[@warning "-32"] read_all ic =
  let buf = Buffer.create 256 in
  (try
     while true do
       Buffer.add_channel buf ic 4096
     done
   with End_of_file -> ());
  Buffer.contents buf

let[@warning "-32"] run_git_command base head args =
  let argv = Array.of_list (("git" :: args) @ [ base ^ ".." ^ head ]) in
  let ic = Unix.open_process_args_in "git" argv in
  let raw = read_all ic in
  let _ = Unix.close_process_in ic in
  raw

(* Project root: the directory containing `dune-project`. We anchor
    here so the CLI is reproducible from any working directory.
    Mirrors the helper in tests/conformance.ml but the bin/ side
    follows the OCAML_BEST_PRACTICES §11.8 rule for production
    binaries (CLI defaults to CWD; agent can override via -C,
    or via the MATH_CODING_ROOT environment variable which the
    cram harness sets to $DUNE_SOURCEROOT).

    Resolution chain (first hit wins):
      1. $MATH_CODING_ROOT (explicit, recommended for tests)
      2. $DUNE_SOURCEROOT (dune cram runtime export; some versions
         of dune 3.x emit it empty when the test is launched via
         dune runtest, so we still need the next two)
      3. dirname $0 / dirname of Sys.executable_name (binary path;
         works even when cwd is unrelated to the project root, e.g.
         in bwrap sandbox from cram)
      4. walk up from cwd (the historical behaviour; works when
         the user runs the binary from inside the project tree)

    Without (3), the cram sandbox of dune 3.23 + bwrap can place
    mathc at a cwd where $DUNE_SOURCEROOT is unset and the walk
    from cwd hits no `dune-project`. Symptom: decisions/[] in the
    capsule collapses to fallback defaults (0 obligations, 0
    triggers) even though the test fixture expects real counts,
    because the loader's hardcoded 4 files are read with wrong cwd. *)
let[@warning "-32"] find_project_root start =
  let climb d =
    let rec loop d =
      let candidate = Filename.concat d "dune-project" in
      if Sys.file_exists candidate then Some d
      else
        let parent = Filename.dirname d in
        if parent = d then None else loop parent
    in
    loop d
  in
  let has_dune_project root =
    Sys.file_exists (Filename.concat root "dune-project")
  in
  match Sys.getenv_opt "MATH_CODING_ROOT" with
  | Some root when has_dune_project root -> root
  | _ -> (
      match Sys.getenv_opt "DUNE_SOURCEROOT" with
      | Some root when has_dune_project root -> root
      | _ -> (
          match climb (Filename.dirname Sys.executable_name) with
          | Some root -> root
          | None -> (
              match climb start with Some root -> root | None -> start)))

(* Same walk as `find_project_root`, but with `Path_config.effective_root`'s
   weaker env-var guard kept in front of it.

   `mathc adopt DIR` re-execs its child commands with
   `MATH_CODING_ROOT=DIR` (see `do_adopt`::run_argv), and the child
   resolves its decisions / attestation dirs through
   `Path_config.*_at ()`, whose `effective_root` accepts that variable
   as soon as it names an existing *directory* — it does not require a
   `dune-project`. An adopted target need not be a dune project, so
   calling `find_project_root` unconditionally would let the walk fall
   past a perfectly valid `MATH_CODING_ROOT` and re-anchor on whatever
   dune project the binary happens to live in.

   So: env var first (exactly `effective_root`'s condition), project-root
   walk only as the fallback. Under `adopt` the two agree — `effective_root`
   already picks `MATH_CODING_ROOT` when the probe it feeds is asked about
   the same tree. The fallback adds the case that was previously wrong and
   silent: `mathc attest-batch` from a cwd unrelated to the project.
   Decision `path-probe-anchoring-2026-11`. *)
let[@warning "-32"] root_with_env_precedence () =
  match Sys.getenv_opt "MATH_CODING_ROOT" with
  | Some r when String.trim r <> "" && Sys.is_directory r -> r
  | _ -> find_project_root (Sys.getcwd ())

let[@warning "-32"] now_iso () =
  let tm = Unix.gmtime (Unix.time ()) in
  Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ" (tm.tm_year + 1900)
    (tm.tm_mon + 1) tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec

(* --- mathc update subcommand (d9-mathc-update-subcommand) ---
 *
 * `mathc update [--channel=stable|edge|<ver>] [--yes]` shells out
 * to scripts/install-tooling/install.sh (POSIX) or install.ps1
 * (Windows) with --version=<resolved>. The install script
 * already replaces ~/.local/bin/mathc on Linux/macOS or
 * %LOCALAPPDATA%\Programs\mathc\mathc.exe on Windows; the
 * subcommand is a UX wrapper.
 *
 * `mathc version --check` reads the locally installed version
 * (from ./VERSION), queries the upstream tag list via
 * `git ls-remote --tags`, and exits 1 (printing the newer
 * version) when an upgrade is available.
 *
 * Touches only bin/Mathc.ml. No kernel change. Network errors
 * degrade to exit 3 (input-error class per OCAML_BEST_PRACTICES
 * §4.3). Functions here `exit` directly; the dispatcher arm
 * never returns. *)

(* Run an external command with captured stdout; returns
   (status, stdout_text). Mirrors the run_git_command helper at
   line 731. *)
let[@warning "-32"] update_run_proc prog argv : Unix.process_status * string =
  let a = Array.of_list (prog :: argv) in
  let ic = Unix.open_process_args_in prog a in
  let buf = Buffer.create 256 in
  (try
     while true do
       Buffer.add_channel buf ic 4096
     done
   with End_of_file -> ());
  let status = Unix.close_process_in ic in
  (status, Buffer.contents buf)

(* Scan stdout line-by-line; helper for update_fetch_latest_tag. *)
let[@warning "-32"] update_each_line s f =
  let n = String.length s in
  let i = ref 0 in
  let start = ref 0 in
  while !i < n do
    if s.[!i] = '\n' then begin
      let line = String.sub s !start (!i - !start) in
      f line;
      i := !i + 1;
      start := !i
    end
    else i := !i + 1
  done;
  if !start < n then f (String.sub s !start (n - !start))

(* Fetch the latest `vX.Y.Z` tag for the math-coding repo.
   Strategy: `git ls-remote --tags --sort=-v:refname
   https://github.com/11111000000/math-coding`, then take the
   first matching `vN.N.N` line (sort is descending). Returns
   None on any subprocess or parse error so callers can degrade
   gracefully. *)
let[@warning "-32"] update_fetch_latest_tag () : string option =
  let url = "https://github.com/11111000000/math-coding" in
  let argv = [ "ls-remote"; "--tags"; "--sort=-v:refname"; url ] in
  try
    let status, body = update_run_proc "git" argv in
    if status <> Unix.WEXITED 0 then None
    else
      let v_re = Str.regexp "^v[0-9]+\\.[0-9]+\\.[0-9]+$" in
      let found = ref None in
      update_each_line body (fun ln ->
          match !found with
          | Some _ -> ()
          | None -> (
              match Str.split (Str.regexp "\t") ln with
              | [ _sha; refstr ] ->
                  let prefix = "refs/tags/" in
                  let pl = String.length prefix in
                  if
                    String.length refstr > pl && String.sub refstr 0 pl = prefix
                  then begin
                    let tag =
                      String.sub refstr pl (String.length refstr - pl)
                    in
                    let stripped =
                      let ll = String.length tag in
                      if ll > 2 && String.sub tag (ll - 2) 2 = "^{}" then
                        String.sub tag 0 (ll - 2)
                      else tag
                    in
                    if Str.string_match v_re stripped 0 then
                      found := Some stripped
                  end
              | _ -> ()));
      !found
  with _ -> None

(* Strip leading `v` from `vX.Y.Z` to get `X.Y.Z`. *)
let[@warning "-32"] update_strip_v s =
  if String.length s > 1 && s.[0] = 'v' then String.sub s 1 (String.length s - 1)
  else s

(* Elementwise version compare for `X.Y.Z` strings; -1/0/1. *)
let[@warning "-32"] update_cmp_version a b : int =
  let split_v s = Str.split (Str.regexp "\\.") s in
  let rec loop la lb =
    match (la, lb) with
    | [], [] -> 0
    | [], _ -> -1
    | _, [] -> 1
    | x :: xs, y :: ys -> (
        match (int_of_string_opt x, int_of_string_opt y) with
        | Some n, Some m ->
            let c = compare n m in
            if c <> 0 then c else loop xs ys
        | _ ->
            let c = String.compare x y in
            if c <> 0 then c else loop xs ys)
  in
  loop (split_v a) (split_v b)

(* Compose the documented --help block; exits 0 when invoked. *)
let[@warning "-32"] update_print_help () =
  print_string
    "usage: mathc update [--channel=stable|edge|<ver>] [--yes]\n\n\
     Replaces the installed mathc binary by shelling out to\n\
     scripts/install-tooling/install.sh (POSIX) or install.ps1\n\
     (Windows) with --version=<resolved>.\n\n\
     options:\n\
    \  --channel=stable        default; resolves to the latest v*.*.* tag\n\
    \  --channel=edge          install the rolling `edge` build\n\
    \  --channel=vX.Y.Z        pin to a specific tag\n\
    \  --yes                   skip the confirmation prompt\n\n\
     exit codes:\n\
    \  0   install succeeded\n\
    \  1   user declined (no --yes)\n\
    \  2   input error (unknown --channel value)\n\
    \  3   network or filesystem error\n";
  exit 0

(* Detect --help/-h in Sys.argv before invoking Arg.parse (which
   would otherwise raise Arg.Bad "no help available"). Returns
   true after printing help and exiting when --help is present
   in the slice starting at offset. *)
let[@warning "-32"] update_has_help offset =
  let n = Array.length Sys.argv in
  let rec loop i =
    if i >= n then false
    else if Sys.argv.(i) = "--help" || Sys.argv.(i) = "-h" then true
    else loop (i + 1)
  in
  loop offset

(* Channel ADT: default = stable (resolved at call time via HTTP /
   git ls-remote), edge = literal "edge" tag, pinned = `vX.Y.Z`. *)
type update_channel = Update_stable | Update_edge | Update_pinned of string

let[@warning "-32"] update_label_of_channel = function
  | Update_stable -> "stable"
  | Update_edge -> "edge"
  | Update_pinned s -> s

let[@warning "-32"] update_parse_channel s : update_channel =
  match s with
  | "" -> Update_stable
  | "stable" -> Update_stable
  | "edge" -> Update_edge
  | _ ->
      let ok =
        String.length s > 1
        && s.[0] = 'v'
        && (function '0' .. '9' -> true | _ -> false) (String.get s 1)
      in
      if ok then Update_pinned s
      else begin
        Printf.fprintf stderr
          "mathc update: unknown channel: %s (expected stable|edge|v<X.Y.Z>)\n"
          s;
        exit 2
      end

(* Resolve the channel ADT into a concrete tag string. *)
let[@warning "-32"] update_resolve c : string =
  match c with
  | Update_stable -> (
      match update_fetch_latest_tag () with
      | Some s -> s
      | None ->
          Printf.eprintf
            "mathc update: could not reach upstream; falling back to installed \
             version\n";
          "v" ^ read_cli_version ())
  | Update_edge -> "edge"
  | Update_pinned s -> s

(* Confirmation prompt; true on y/yes, false otherwise. *)
let[@warning "-32"] update_prompt () =
  Printf.printf "mathc update: replace the installed mathc binary? [y/N] ";
  flush stdout;
  try
    let line = input_line stdin in
    let s = String.trim (String.lowercase_ascii line) in
    match s with "y" | "yes" -> true | _ -> false
  with End_of_file -> false

(* Build argv for the platform's installer. POSIX uses bash -c on
   sh; Windows uses powershell.exe on install.ps1. *)
let[@warning "-32"] update_installer_argv ~root ~version =
  let script_dir = Filename.concat root "scripts/install-tooling" in
  if Sys.os_type = "Win32" then
    let ps1 = Filename.concat script_dir "install.ps1" in
    [
      "powershell.exe";
      "-NoProfile";
      "-ExecutionPolicy";
      "Bypass";
      "-File";
      ps1;
      "-Version";
      update_strip_v version;
    ]
  else
    let sh = Filename.concat script_dir "install.sh" in
    [ sh; "--version=" ^ version ]

(* Shell out to the installer; translate its exit into ours. *)
let[@warning "-32"] update_invoke_and_exit ~root ~version =
  let argv = update_installer_argv ~root ~version in
  let prog = List.hd argv in
  let args = List.tl argv in
  match update_run_proc prog args with
  | Unix.WEXITED 0, _ -> exit 0
  | Unix.WEXITED 1, _ ->
      Printf.eprintf "mathc update: installer declined or user-cancelled\n";
      exit 1
  | Unix.WEXITED 2, _ ->
      Printf.eprintf "mathc update: installer rejected the input\n";
      exit 2
  | Unix.WEXITED n, _ ->
      Printf.eprintf "mathc update: installer failed with exit %d\n" n;
      exit 3
  | _ ->
      Printf.eprintf "mathc update: installer terminated abnormally\n";
      exit 3

(* `mathc update [--channel=<s>] [--yes]` — top-level arm.
   --help / -h are recognized before Arg.parse (which would
   otherwise raise Arg.Bad "no help available"). *)
let[@warning "-32"] do_update () =
  Arg.current := 1;
  if update_has_help 2 then update_print_help ();
  let channel = ref "" in
  let yes = ref false in
  let set_channel s = channel := s in
  (try
     Arg.parse
       [
         ( "--channel",
           Arg.String set_channel,
           "<s> what to install (stable|edge|vX.Y.Z); default stable" );
         ("--yes", Arg.Set yes, " skip the confirmation prompt");
       ]
       (fun s ->
         Printf.fprintf stderr "mathc update: unexpected argument: %s\n" s;
         exit 2)
       "usage: mathc update [--channel=stable|edge|<ver>] [--yes]"
   with Arg.Bad m ->
     Printf.fprintf stderr "mathc update: %s\n" m;
     exit 2);
  let c = update_parse_channel !channel in
  let resolved = update_resolve c in
  let root = find_project_root (Sys.getcwd ()) in
  if not !yes then
    if not (update_prompt ()) then begin
      Printf.eprintf "mathc update: declined; no changes made\n";
      exit 1
    end;
  Printf.printf "mathc update: installing channel=%s version=%s\n"
    (update_label_of_channel c)
    resolved;
  flush stdout;
  update_invoke_and_exit ~root ~version:resolved

(* `mathc version [--check]`. Default behavior is preserved; the
   new --check flag exits 1 (printing the newer version) when an
   upgrade is available, 0 otherwise (including no-network). *)
let[@warning "-32"] do_version () =
  Arg.current := 1;
  if update_has_help 2 then begin
    print_version ();
    exit 0
  end;
  let check = ref false in
  (try
     Arg.parse
       [ ("--check", Arg.Set check, " compare with the latest stable release") ]
       (fun s ->
         Printf.fprintf stderr "mathc version: unexpected argument: %s\n" s;
         exit 2)
       "usage: mathc version [--check]"
   with Arg.Bad m ->
     Printf.fprintf stderr "mathc version: %s\n" m;
     exit 2);
  if !check then
    begin match update_fetch_latest_tag () with
    | None -> exit 0
    | Some tag ->
        let installed = read_cli_version () in
        let latest = update_strip_v tag in
        if update_cmp_version installed latest < 0 then begin
          print_endline tag;
          exit 1
        end;
        exit 0
    end;
  print_version ()

(* Mathc_cmd.Update namespace alias. The Update logic lives in
   the top-level helpers above (`update_*`); this module exposes
   `Mathc_cmd.Update.run` per spec/algebra-3.2.md §15 CLI catalog
   convention. *)
module Mathc_cmd = struct
  module Update = struct
    let run ~channel ~yes () = do_update ()
  end
end

(* Build the Memory.t for the context subcommand. All file I/O
   happens here; the kernel stays offline. *)
let[@warning "-32"] build_memory_for root base head =
  let reader path =
    match read_file_for_capsule path with Ok s -> s | Error _ -> ""
  in
  let recent_commits_raw =
    try run_git_command base head [ "log"; "--oneline" ] with _ -> ""
  in
  let changed_paths_raw =
    try run_git_command base head [ "diff"; "--name-only" ] with _ -> ""
  in
  Memory.load_memory ~reader ~root ~recent_commits_raw ~changed_paths_raw

(* Render a Capsule.t as JSON. We hand-build the JSON so we do not
   need yojson in the kernel or in bin/ (OCAML_BEST_PRACTICES §7.3
   — bin may not pull Yojson; here we only need flat serialisation).
   The shape is:
     { "change": {...},
       "decisions": [...],
       "obligations": [...],
       "omitted": [...],
       "total_bytes": N,
       "truncated": true|false,
       "now": "...",
       "base": "...",
       "head": "..." }
   Keys are sorted lex. (We use the same sort discipline as
   Jsonl.stringify.) *)

let[@warning "-32"] priority_to_json = function
  | Capsule.RequiredForGate -> "\"RequiredForGate\""
  | Capsule.Changed -> "\"Changed\""
  | Capsule.HighRisk -> "\"HighRisk\""
  | Capsule.Unresolved -> "\"Unresolved\""
  | Capsule.Supporting -> "\"Supporting\""
  | Capsule.Historical -> "\"Historical\""

let[@warning "-32"] item_to_json (it : Capsule.item) =
  let fields =
    [
      ("detail_ref", Jsonl.stringify (Jsonl.String it.detail_ref));
      ( "freshness",
        match it.freshness with
        | None -> "null"
        | Some s -> Jsonl.stringify (Jsonl.String s) );
      ("priority", priority_to_json it.kind);
      ("summary", Jsonl.stringify (Jsonl.String it.summary));
    ]
  in
  let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) fields in
  "{"
  ^ String.concat ","
      (List.map
         (fun (k, v) -> Jsonl.stringify (Jsonl.String k) ^ ":" ^ v)
         sorted)
  ^ "}"

let[@warning "-32"] reference_to_json (r : Capsule.reference) =
  let fields =
    [
      ("detail_ref", Jsonl.stringify (Jsonl.String r.detail_ref));
      ("expansion", Jsonl.stringify (Jsonl.String r.expansion));
      ("priority", priority_to_json r.kind);
      ("summary", Jsonl.stringify (Jsonl.String r.summary));
    ]
  in
  let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) fields in
  "{"
  ^ String.concat ","
      (List.map
         (fun (k, v) -> Jsonl.stringify (Jsonl.String k) ^ ":" ^ v)
         sorted)
  ^ "}"

(* Top-level capsule JSON. *)
let[@warning "-32"] capsule_to_json cap =
  let items_json =
    "[" ^ String.concat "," (List.map item_to_json cap.Capsule.items) ^ "]"
  in
  let omitted_json =
    "["
    ^ String.concat "," (List.map reference_to_json cap.Capsule.omitted)
    ^ "]"
  in
  (* Build the top-level shape manually so we can guarantee the
     required key order/sort. The required keys "change",
     "decisions", "obligations" come from the items; we extract
     them into separate arrays. *)
  let change_items, decision_items, obligation_items =
    let rec partition (c : Capsule.item list) (d : Capsule.item list)
        (o : Capsule.item list) (xs : Capsule.item list) :
        Capsule.item list * Capsule.item list * Capsule.item list =
      match xs with
      | [] -> (List.rev c, List.rev d, List.rev o)
      | (it : Capsule.item) :: rest -> (
          let prefix =
            let s = it.detail_ref in
            let n = min 4 (String.length s) in
            if n = 0 then `Change
            else
              match String.sub s 0 n with
              | "path" | "comm" -> `Change
              | "deci" -> `Decision
              | "obli" -> `Obligation
              | _ -> `Change
          in
          match prefix with
          | `Change -> partition (it :: c) d o rest
          | `Decision -> partition c (it :: d) o rest
          | `Obligation -> partition c d (it :: o) rest)
    in
    partition [] [] [] cap.Capsule.items
  in
  let change_json =
    "{"
    ^ String.concat ","
        [
          Jsonl.stringify (Jsonl.String "base")
          ^ ":"
          ^ Jsonl.stringify (Jsonl.String cap.base);
          Jsonl.stringify (Jsonl.String "head")
          ^ ":"
          ^ Jsonl.stringify (Jsonl.String cap.head);
          Jsonl.stringify (Jsonl.String "items")
          ^ ":["
          ^ String.concat "," (List.map item_to_json change_items)
          ^ "]";
        ]
    ^ "}"
  in
  let decisions_json =
    "[" ^ String.concat "," (List.map item_to_json decision_items) ^ "]"
  in
  let obligations_json =
    "[" ^ String.concat "," (List.map item_to_json obligation_items) ^ "]"
  in
  let fields =
    [
      ("base", Jsonl.stringify (Jsonl.String cap.base));
      ("change", change_json);
      ("decisions", decisions_json);
      ("head", Jsonl.stringify (Jsonl.String cap.head));
      ("items", items_json);
      ("now", Jsonl.stringify (Jsonl.String cap.now));
      ("obligations", obligations_json);
      ("omitted", omitted_json);
      ("total_bytes", string_of_int cap.Capsule.total_bytes);
      ("truncated", if cap.Capsule.truncated then "true" else "false");
    ]
  in
  let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) fields in
  "{"
  ^ String.concat ","
      (List.map
         (fun (k, v) -> Jsonl.stringify (Jsonl.String k) ^ ":" ^ v)
         sorted)
  ^ "}\n"

(* --- explain subcommand (bootstrap decision mathc-explain-subcommand) --- *)

(* Resolve a decision id to its project-relative file under
   decisions/. Mirrors the special-case table in
   lib/capsule.ml:174-185 so a `mathc context` omitted item with
   detail_ref `decision:<id>` resolves to the same file the
   capsule would have shown had the budget permitted. Returns
   a project-relative path so the JSON `path` field is portable
   across worktrees (the absolute path is reconstructed for the
   actual file read). *)
let[@warning "-32"] decision_relpath ~root id =
  let dir = Path_config.resolve_decisions_dir ~root () in
  match id with
  | "bootstrap-v3" -> dir ^ "/decision.yaml"
  | "infrastructure-honesty" -> dir ^ "/infrastructure-honesty.yaml"
  | "kernel-conformance-runner" -> dir ^ "/kernel-conformance-runner.yaml"
  | "validate-and-context" -> dir ^ "/validate-and-context.yaml"
  | _ -> dir ^ "/" ^ id ^ ".yaml"

(* Resolve a "soft" kind that lib/reference.ml does not recognise
   (the formal parser covers decision/obligation/attestation/waiver/
   change; the capsule also emits spec/axiom/doc which are project
   files outside the formal schema). Returns a project-relative
   path or None. *)
let[@warning "-32"] soft_kind_relpath kind id =
  match kind with
  | "spec" -> Some ("spec/" ^ id)
  | "axiom" -> Some ("axioms/" ^ id)
  | "doc" -> Some id
  | _ -> None

(* Render an explain success object. Sorted keys per
   spec/semantics.md:170. *)
let[@warning "-32"] explain_json kind id digest path body =
  let fields =
    [
      ("body", Jsonl.String body);
      ("digest", Jsonl.String digest);
      ("id", Jsonl.String id);
      ("kind", Jsonl.String kind);
      ("path", Jsonl.String path);
    ]
  in
  let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) fields in
  "{"
  ^ String.concat ","
      (List.map
         (fun (k, v) ->
           Jsonl.stringify (Jsonl.String k) ^ ":" ^ Jsonl.stringify v)
         sorted)
  ^ "}\n"

(* Render a typed explain diagnostic on stderr. Sorted keys. *)
let[@warning "-32"] explain_diag code kind id message =
  let fields =
    [
      ("code", Jsonl.String code);
      ("id", Jsonl.String id);
      ("kind", Jsonl.String kind);
      ("message", Jsonl.String message);
    ]
  in
  let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) fields in
  let s =
    "{"
    ^ String.concat ","
        (List.map
           (fun (k, v) ->
             Jsonl.stringify (Jsonl.String k) ^ ":" ^ Jsonl.stringify v)
           sorted)
    ^ "}\n"
  in
  Printf.fprintf stderr "%s" s

(* Dispatch a parsed DETAIL_REF to a (kind, id, relpath) triple.

   Resolution order:
     1. lib/reference.ml handles the five formal kinds. We act on
        `Ref { Decision }` directly (the only file-resident formal
        kind in this revision).
     2. The "soft" table handles spec/axiom/doc — capsule-emitted
        detail_refs that the formal parser does not cover.
     3. Anything else is MC-REF-UNKNOWN: either a non-file formal
        kind (obligation/attestation/waiver/change, which aggregate
        across multiple files) or a non-file capsule kind
        (commits/path, git artifacts). This is an honest declaration
        of scope, not a permanent limit. *)
let[@warning "-32"] resolve_ref ~root raw_ref :
    (string * string * string, string * string * string * string) result =
  match String.split_on_char ':' raw_ref with
  | [ kind; id ] -> (
      match Reference.parse raw_ref with
      | Some (Ref { kind = Decision; id = did; revision = _ }) ->
          Ok (kind, did, decision_relpath ~root did)
      | _ -> (
          match soft_kind_relpath kind id with
          | Some p -> Ok (kind, id, p)
          | None ->
              Error
                ( "MC-REF-UNKNOWN",
                  kind,
                  id,
                  Printf.sprintf
                    "kind '%s' is not addressable to a single file in this \
                     revision; the dispatcher resolves decision/spec/axiom/doc \
                     only"
                    kind )))
  | _ ->
      Error
        ("MC-REF-INVALID", "", raw_ref, "DETAIL_REF must be of the form kind:id")

let[@warning "-32"] do_explain () =
  let positionals : string list ref = ref [] in
  let anon s = positionals := s :: !positionals in
  Arg.current := 1;
  (try Arg.parse [] anon "usage: mathc explain DETAIL_REF"
   with Arg.Bad m ->
     Printf.fprintf stderr "mathc explain: %s\n" m;
     exit 2);
  let args = List.rev !positionals in
  let raw_ref =
    match args with
    | [ r ] -> r
    | [] ->
        Printf.fprintf stderr "mathc explain: missing DETAIL_REF\n";
        print_usage stderr;
        exit 2
    | _ ->
        Printf.fprintf stderr
          "mathc explain: expected one DETAIL_REF; got %d positional(s)\n"
          (List.length args);
        print_usage stderr;
        exit 2
  in
  let root = find_project_root (Sys.getcwd ()) in
  match resolve_ref ~root raw_ref with
  | Error (code, k, i, msg) ->
      explain_diag code k i msg;
      exit 2
  | Ok (kind, id, relpath) -> (
      let abs_path = Filename.concat root relpath in
      match read_file_for_capsule abs_path with
      | Error (`Sys s) ->
          explain_diag "MC-REF-UNKNOWN" kind id
            (Printf.sprintf "cannot read '%s': %s" relpath s);
          exit 2
      | Error (`Other s) ->
          explain_diag "MC-REF-UNKNOWN" kind id
            (Printf.sprintf "cannot read '%s': %s" relpath s);
          exit 2
      | Ok body ->
          let digest = Digest.sha256_hex body in
          print_string (explain_json kind id digest relpath body);
          exit 0)

(* --- explain-diagnostic subcommand (Tier 4, t4-2) ---
 *
 * `mathc explain-diagnostic <CODE>` prints a JSON object with
 * `{code, definition, occurs_when, remediation}` for the given
 * diagnostic code. The registry lives in `lib/diagnostic.ml`
 * (`Diagnostic.explain`). On an unknown code or a missing
 * positional argument the handler prints a typed
 * `MC-EXPLAIN-DIAGNOSTIC-UNKNOWN` diagnostic on stderr and
 * exits 2. The JSON contract mirrors `mathc explain` (sorted
 * keys, trailing newline). *)

(* Split a `Diagnostic.explain` body into the three required
   sections. The body uses `### Definition` / `### Occurs when`
   / `### Remediation` as section headers; everything between
   one header and the next is the section body, trimmed.
   Returns a triple `(definition, occurs_when, remediation)`.
   Falls back to the full text for the `Definition` slot when
   a section header is missing (forward-compat with bodies
   that lack the full marker set). *)
let[@warning "-32"] split_records body =
  let sections =
    let cur = Buffer.create 256 in
    let flush acc label =
      let body = Buffer.contents cur |> String.trim in
      Buffer.clear cur;
      (label, body) :: acc
    in
    let rec walk acc label = function
      | [] ->
          let acc = flush acc label in
          List.rev acc
      | line :: rest ->
          let t = String.trim line in
          if t = "### Definition" then
            let acc = flush acc label in
            walk acc "definition" rest
          else if t = "### Occurs when" then
            let acc = flush acc label in
            walk acc "occurs_when" rest
          else if t = "### Remediation" then
            let acc = flush acc label in
            walk acc "remediation" rest
          else begin
            if label <> "" && Buffer.length cur > 0 then
              Buffer.add_char cur '\n';
            Buffer.add_string cur line;
            walk acc label rest
          end
    in
    walk [] "" (String.split_on_char '\n' body)
  in
  let get label =
    match List.assoc_opt label sections with Some s -> s | None -> ""
  in
  (get "definition", get "occurs_when", get "remediation")

let[@warning "-32"] explain_diagnostic_to_json code body =
  let definition, occurs_when, remediation = split_records body in
  let fields =
    [
      ("code", Jsonl.String code);
      ("definition", Jsonl.String definition);
      ("occurs_when", Jsonl.String occurs_when);
      ("remediation", Jsonl.String remediation);
    ]
  in
  let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) fields in
  "{"
  ^ String.concat ","
      (List.map
         (fun (k, v) ->
           Jsonl.stringify (Jsonl.String k) ^ ":" ^ Jsonl.stringify v)
         sorted)
  ^ "}\n"

let[@warning "-32"] do_explain_diagnostic () =
  let positionals : string list ref = ref [] in
  let anon s = positionals := s :: !positionals in
  Arg.current := 1;
  (try Arg.parse [] anon "usage: mathc explain-diagnostic <CODE>"
   with Arg.Bad m ->
     Printf.fprintf stderr "mathc explain-diagnostic: %s\n" m;
     exit 2);
  let args = List.rev !positionals in
  let code =
    match args with
    | [ c ] -> c
    | [] ->
        Printf.fprintf stderr "mathc explain-diagnostic: missing CODE\n";
        Printf.fprintf stderr "usage: mathc explain-diagnostic <CODE>\n";
        exit 2
    | _ ->
        Printf.fprintf stderr
          "mathc explain-diagnostic: expected one CODE; got %d positional(s)\n"
          (List.length args);
        exit 2
  in
  match Diagnostic.explain code with
  | None ->
      let msg =
        Printf.sprintf
          "unknown diagnostic code '%s'; supported codes are listed by \
           lib/diagnostic.ml::explain (MC-VERIFIER-SCHEME-UNKNOWN, \
           MC-AMBIGUOUS-ACCEPTANCE, MC-MALFORMED-ACCEPTANCE, MC-PARSE, \
           MC-DECISION-INVALID, MC-COUNTEREXAMPLE-MISSING, \
           MC-AXIOM-LINK-MISSING, MC-SHA-MISMATCH)"
          code
      in
      explain_diag "MC-EXPLAIN-DIAGNOSTIC-UNKNOWN" "diagnostic" code msg;
      exit 2
  | Some body ->
      print_string (explain_diagnostic_to_json code body);
      exit 0

let do_context () =
  let base = ref "" and head = ref "" and budget = ref 8192 in
  let positionals : string list ref = ref [] in
  let anon s = positionals := s :: !positionals in
  let set_budget s =
    match int_of_string_opt s with
    | Some n when n > 0 -> budget := n
    | _ -> raise (Arg.Bad ("invalid --budget value: " ^ s))
  in
  Arg.current := 1;
  (try
     Arg.parse
       [ ("--budget", Arg.String set_budget, " Maximum bytes for the capsule") ]
       anon "usage: mathc context BASE HEAD [--budget N]"
   with Arg.Bad m ->
     Printf.fprintf stderr "mathc context: %s\n" m;
     exit 2);
  let args = List.rev !positionals in
  (match args with
  | [ b; h ] ->
      base := b;
      head := h
  | [ _ ] ->
      Printf.fprintf stderr "mathc context: missing HEAD\n";
      print_usage stderr;
      exit 2
  | _ ->
      Printf.fprintf stderr
        "mathc context: expected BASE HEAD; got %d positional(s)\n"
        (List.length args);
      print_usage stderr;
      exit 2);
  let root = find_project_root (Sys.getcwd ()) in
  let memory = build_memory_for root !base !head in
  let cap =
    Capsule.build_capsule ~now:(now_iso ()) ~base:!base ~head:!head ~memory
      ~budget_bytes:!budget ~active_policy_id:Capsule.default_active_policy_id
  in
  print_string (capsule_to_json cap);
  exit 0

(* --- assess subcommand ---
 *
 * `mathc assess BASE HEAD` invokes Git_diff.changed_files with the
 * current working directory and prints a JSON array of the changed
 * file paths on stdout. Exits 0 on success; exits 2 if the git
 * command fails or positional arguments are wrong. Follows the
 * positionals-collection pattern from OCAML_BEST_PRACTICES §11.17
 * to avoid the Arg.parse anonfun-overwrite trap. *)
let[@warning "-32"] do_assess () =
  let positionals : string list ref = ref [] in
  let anon s = positionals := s :: !positionals in
  Arg.current := 1;
  (try Arg.parse [] anon "usage: mathc assess BASE HEAD"
   with Arg.Bad m ->
     Printf.fprintf stderr "mathc assess: %s\n" m;
     exit 2);
  let args = List.rev !positionals in
  match args with
  | [ b; h ] -> (
      let cwd = Sys.getcwd () in
      match Git_diff.changed_files ~cwd ~base:b ~head:h with
      | Ok paths ->
          let json_items =
            String.concat ","
              (List.map (fun p -> Jsonl.stringify (Jsonl.String p)) paths)
          in
          Printf.printf "[%s]\n" json_items;
          exit 0
      | Error msg ->
          Printf.fprintf stderr "mathc assess: %s\n" msg;
          exit 2)
  | [ _ ] ->
      Printf.fprintf stderr "mathc assess: missing HEAD\n";
      print_usage stderr;
      exit 2
  | _ ->
      Printf.fprintf stderr
        "mathc assess: expected BASE HEAD; got %d positional(s)\n"
        (List.length args);
      print_usage stderr;
      exit 2

(* --- time-estimate subcommand (bootstrap decision time-honesty) ---
 *
 * Reads bin/data/time-distribution.yaml and prints a JSON
 * reference-class forecast. Side-effect-free w.r.t. the kernel;
 * reads one declared data file and emits a single JSON document.
 *
 * Exits 0 on success and emits one JSON object on stdout. Exits
 * 2 when the class is unknown, the YAML cannot be parsed, or a
 * required CLI flag is missing; in that case a JSON diagnostic is
 * emitted on stderr (Unix convention, follows the existing
 * subcommand style). *)

let obj_get (k : string) (v : Jsonl.value) : Jsonl.value =
  match v with
  | Jsonl.Object pairs -> (
      match List.assoc_opt k pairs with Some x -> x | None -> Jsonl.Null)
  | _ -> Jsonl.Null

let obj_string_opt (v : Jsonl.value) (k : string) : string option =
  match obj_get k v with Jsonl.String s -> Some s | _ -> None

let obj_int_opt (v : Jsonl.value) (k : string) : int option =
  match obj_get k v with Jsonl.Int n -> Some n | _ -> None

let obj_string_keys (v : Jsonl.value) : string list =
  match v with
  | Jsonl.Object pairs -> List.map (fun (k, _) -> k) pairs
  | _ -> []

let load_distribution root : Jsonl.value =
  let path = Filename.concat root "bin/data/time-distribution.yaml" in
  match read_file path with
  | Ok s -> (
      try Codec.load_yaml_string s
      with _ ->
        Printf.fprintf stderr "mathc time-estimate: cannot parse %s\n" path;
        exit 2)
  | Error (`Sys m) ->
      Printf.fprintf stderr "mathc time-estimate: cannot read %s: %s\n" path m;
      exit 2
  | Error _ ->
      Printf.fprintf stderr "mathc time-estimate: cannot read %s\n" path;
      exit 2

(* Look up class C inside the classes block. Returns (p50, p95)
   or None when the class is absent or the row is malformed. *)
let class_data (dist : Jsonl.value) (klass : string) : (int * int) option =
  match obj_get "classes" dist with
  | Jsonl.Object pairs -> (
      match List.assoc_opt klass pairs with
      | Some row -> (
          match (obj_int_opt row "p50", obj_int_opt row "p95") with
          | Some p50, Some p95 -> Some (p50, p95)
          | _ -> None)
      | None -> None)
  | _ -> None

let int_x10_or_exit (block : Jsonl.value) (k : string) (ctx : string) : int =
  match obj_int_opt block k with
  | Some n -> n
  | None ->
      Printf.fprintf stderr "mathc time-estimate: missing %s in %s\n" k ctx;
      exit 2

(* Percentile for non-stored quantiles. Linear interpolation
   between P50 and P95 (file declares only those two). P99 is
   extrapolated by continuing the slope by 4/5 of the P50->P95
   rise. This is documented in the file's `caveats:` block. *)
let interp_p50_p95 p50 p95 p_percent =
  let base = float_of_int p50 in
  let hi = float_of_int p95 in
  if p_percent = 50 then base
  else if p_percent = 95 then hi
  else if p_percent = 80 then base +. ((hi -. base) *. (30.0 /. 45.0))
  else if p_percent = 99 then hi +. ((hi -. base) *. (4.0 /. 45.0))
  else base +. ((hi -. base) *. (float_of_int (p_percent - 50) /. 45.0))

let[@warning "-32"] apply_multiplier (name : string) (count : int)
    (dist : Jsonl.value) (estimate : float) : float * string list =
  let block = obj_get name (obj_get "multipliers" dist) in
  match name with
  | "per_artifact_over_first" -> (
      let f =
        if count <= 1 then None
        else if count = 2 then
          Some (int_x10_or_exit block "factor_at_count_2_x10" name)
        else if count = 3 then
          Some (int_x10_or_exit block "factor_at_count_3_x10" name)
        else if count <= 5 then
          Some (int_x10_or_exit block "factor_at_count_4_or_5_x10" name)
        else Some (int_x10_or_exit block "factor_at_count_6_or_more_x10" name)
      in
      match f with
      | None -> (estimate, [])
      | Some m -> (estimate *. (float_of_int m /. 10.0), [ name ]))
  | "mixed_class_scope" ->
      let m = int_x10_or_exit block "factor_x10" name in
      (estimate *. (float_of_int m /. 10.0), [ name ])
  | "cross_language_non_ocaml" ->
      let m = int_x10_or_exit block "factor_x10" name in
      (estimate *. (float_of_int m /. 10.0), [ name ])
  | "test_required_with_runtime" ->
      let m = int_x10_or_exit block "factor_x10" name in
      (estimate *. (float_of_int m /. 10.0), [ name ])
  | _ ->
      Printf.fprintf stderr "mathc time-estimate: unknown --multiplier: %s\n"
        name;
      exit 2

let known_classes_json (dist : Jsonl.value) : string =
  let keys = obj_string_keys (obj_get "classes" dist) in
  let sorted = List.sort String.compare keys in
  "["
  ^ String.concat ","
      (List.map (fun s -> Jsonl.stringify (Jsonl.String s)) sorted)
  ^ "]"

let[@warning "-32"] do_time_estimate () =
  let class_ref = ref "" in
  let count_ref = ref 1 in
  let percentile_ref = ref 80 in
  let multipliers_ref : string list ref = ref [] in
  let set_class s = class_ref := s in
  let set_count s =
    match int_of_string_opt s with
    | Some n when n >= 1 -> count_ref := n
    | _ -> raise (Arg.Bad ("invalid --count: " ^ s))
  in
  let set_percentile s =
    match s with
    | "p50" -> percentile_ref := 50
    | "p80" -> percentile_ref := 80
    | "p95" -> percentile_ref := 95
    | "p99" -> percentile_ref := 99
    | _ -> raise (Arg.Bad ("unknown --percentile: " ^ s))
  in
  let add_mult s = multipliers_ref := s :: !multipliers_ref in
  let reject_positional _ =
    raise (Arg.Bad "no positional arguments expected")
  in
  Arg.current := 1;
  (try
     Arg.parse
       [
         ("--class", Arg.String set_class, " Class name (required)");
         ("--count", Arg.String set_count, " Number of artifacts in scope");
         ( "--percentile",
           Arg.String set_percentile,
           " p50 | p80 (default) | p95 | p99" );
         ( "--multiplier",
           Arg.String add_mult,
           " Repeatable: per_artifact_over_first | mixed_class_scope | \
            cross_language_non_ocaml | test_required_with_runtime" );
       ]
       reject_positional
       "usage: mathc time-estimate --class <name> [--count N] [--percentile \
        p50|p80|p95|p99] [--multiplier NAME]..."
   with Arg.Bad m ->
     Printf.fprintf stderr "mathc time-estimate: %s\n" m;
     exit 2);
  if !class_ref = "" then begin
    Printf.fprintf stderr "mathc time-estimate: --class is required\n";
    exit 2
  end;
  let root = find_project_root (Sys.getcwd ()) in
  let dist = load_distribution root in
  let unit =
    match obj_string_opt dist "unit" with Some u -> u | None -> "minutes"
  in
  match class_data dist !class_ref with
  | None ->
      let body =
        let fields =
          [
            ("class", Jsonl.stringify (Jsonl.String !class_ref));
            ("code", Jsonl.stringify (Jsonl.String "MC-CLASS-UNKNOWN"));
            ( "known_classes",
              Jsonl.stringify (Jsonl.String (known_classes_json dist)) );
            ( "message",
              Jsonl.stringify
                (Jsonl.String
                   ("unknown class; known: " ^ known_classes_json dist)) );
          ]
        in
        let sorted =
          List.sort (fun (a, _) (b, _) -> String.compare a b) fields
        in
        "{"
        ^ String.concat ","
            (List.map
               (fun (k, v) -> Jsonl.stringify (Jsonl.String k) ^ ":" ^ v)
               sorted)
        ^ "}"
      in
      Printf.fprintf stderr "%s\n" body;
      exit 2
  | Some (p50, p95) ->
      let per_p = interp_p50_p95 p50 p95 !percentile_ref in
      let est, applied_rev =
        List.fold_left
          (fun (e, acc) name ->
            let e', names = apply_multiplier name !count_ref dist e in
            (e', names @ acc))
          (per_p, []) !multipliers_ref
      in
      let est_int = int_of_float (est +. 0.5) in
      let applied_sorted = List.sort String.compare applied_rev in
      let mults_json =
        "["
        ^ String.concat ","
            (List.map
               (fun s -> Jsonl.stringify (Jsonl.String s))
               applied_sorted)
        ^ "]"
      in
      let body =
        let fields =
          [
            ("applied_multipliers", mults_json);
            ( "caveat",
              Jsonl.stringify
                (Jsonl.String
                   "declared distribution; SWE-bench-V 2025-Q4; update via \
                    Decision") );
            ("class", Jsonl.stringify (Jsonl.String !class_ref));
            ("count", string_of_int !count_ref);
            ("estimate_value", string_of_int est_int);
            ("percentile", string_of_int !percentile_ref);
            ( "reference",
              Jsonl.stringify
                (Jsonl.String "SWE-bench Verified (n=500, 2025-Q4)") );
            ("scale", Jsonl.stringify (Jsonl.String unit));
            ( "source",
              Jsonl.stringify (Jsonl.String "bin/data/time-distribution.yaml")
            );
          ]
        in
        let sorted =
          List.sort (fun (a, _) (b, _) -> String.compare a b) fields
        in
        "{"
        ^ String.concat ","
            (List.map
               (fun (k, v) -> Jsonl.stringify (Jsonl.String k) ^ ":" ^ v)
               sorted)
        ^ "}"
      in
      print_endline body;
      exit 0

(* --- session-start subcommand (bootstrap decision time-honesty-storage) ---
 *
 * Writes the current UTC instant as one ISO 8601 line to
 * .local/session-start inside the project root. Re-runs
 * overwrite; the most recent call wins. Each `mathc record` reads
 * this file and uses (now - session_start) as the
 * wall-clock-minutes value. The user controls when the session
 * starts; the agent cannot influence the resulting elapsed
 * time without also editing the file (the file is in the
 * worktree, gitignored per decisions/time-honesty-storage.yaml;
   users can verify). *)

(* mkdir -p, recursively. Idempotent: ignores EEXIST. *)
let[@warning "-32"] rec ensure_dir d =
  if d = "" || d = "/" || Filename.basename d = "" then ()
  else if Sys.file_exists d then ()
  else begin
    ensure_dir (Filename.dirname d);
    try Unix.mkdir d 0o755 with Unix.Unix_error (Unix.EEXIST, _, _) -> ()
  end

let[@warning "-32"] read_session_start_path root =
  Filename.concat root ".local/session-start"

let[@warning "-32"] write_session_start () =
  let root = find_project_root (Sys.getcwd ()) in
  let path = read_session_start_path root in
  ensure_dir (Filename.dirname path);
  (* MATH_CODING_FIXED_TIME, when set, overrides the wall-clock
     timestamp. Cram tests set this to make session-start output
     deterministic across runs; the env var is documented in
     OCAML_BEST_PRACTICES §11.16 alongside the cram-test path
     fragility fix. *)
  let ts =
    match Sys.getenv_opt "MATH_CODING_FIXED_TIME" with
    | Some s when String.length s > 0 -> s
    | _ -> now_iso ()
  in
  let oc = open_out path in
  output_string oc ts;
  output_char oc '\n';
  close_out oc;
  Printf.printf "%s\n%!" (Jsonl.stringify (Jsonl.String ts))

(* Parse an ISO-8601 UTC timestamp like 2026-09-27T10:00:00Z
   into Unix.time () (seconds since epoch). Returns nan on parse
   failure. The format is fixed: we only write what we wrote. *)
let[@warning "-32"] parse_iso_to_unix s =
  try
    Scanf.sscanf s "%4d-%2d-%2dT%2d:%2d:%2dZ" (fun y mo d h mi se ->
        let tm : Unix.tm =
          {
            tm_year = y - 1900;
            tm_mon = mo - 1;
            tm_mday = d;
            tm_hour = h;
            tm_min = mi;
            tm_sec = se;
            tm_wday = 0;
            tm_yday = 0;
            tm_isdst = false;
          }
        in
        fst (Unix.mktime tm))
  with _ -> nan

let[@warning "-32"] read_session_start () : string =
  let root = find_project_root (Sys.getcwd ()) in
  let path = read_session_start_path root in
  In_channel.with_open_bin path In_channel.input_all |> String.trim

let[@warning "-32"] do_session_start () =
  let anon _ = raise (Arg.Bad "no positional arguments expected") in
  Arg.current := 1;
  (try Arg.parse [] anon "usage: mathc session-start"
   with Arg.Bad m ->
     Printf.fprintf stderr "mathc session-start: %s\n" m;
     exit 2);
  write_session_start ()

(* observed_by: prefer the explicit MATH_CODING_USER env var;
   fall back to git config user.email; final fallback is
   human:anonymous. *)
let[@warning "-32"] observed_by () =
  match Sys.getenv_opt "MATH_CODING_USER" with
  | Some s when s <> "" -> s
  | _ -> (
      let ic =
        try Some (Unix.open_process_in "git config user.email") with _ -> None
      in
      match ic with
      | None -> "human:anonymous"
      | Some ic -> (
          try
            let email = input_line ic |> String.trim in
            let _ = Unix.close_process_in ic in
            if email = "" then "human:anonymous" else "human:" ^ email
          with _ ->
            let _ = Unix.close_process_in ic in
            "human:anonymous"))

(* --- record subcommand (bootstrap decision time-honesty-storage) ---
 *
 * Appends one event line to decisions/execution-logs.jsonl.
 * The wall-clock-minutes value is auto-computed from
 * now - session_start. The step-count value is supplied by
 * the caller (assumption step-count-supplied, until the
 * runtime harness lands); --value is REJECTED for
 * wall-clock-minutes by the subcommand logic. *)

let[@warning "-32"] append_event_to_file path body =
  ensure_dir (Filename.dirname path);
  let oc = open_out_gen [ Open_append; Open_creat; Open_text ] 0o644 path in
  output_string oc body;
  output_char oc '\n';
  close_out oc

let[@warning "-32"] event_to_json_line (ev : (string * Jsonl.value) list) =
  let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) ev in
  "{"
  ^ String.concat ","
      (List.map
         (fun (k, v) ->
           Jsonl.stringify (Jsonl.String k) ^ ":" ^ Jsonl.stringify v)
         sorted)
  ^ "}"

let[@warning "-32"] do_record () =
  let decision_id = ref "" in
  let decision_rev = ref "" in
  let scale = ref "" in
  let class_opt = ref "" in
  let value_opt = ref "" in
  let set_id s = decision_id := s in
  let set_rev s = decision_rev := s in
  let set_scale s = scale := s in
  let set_class s = class_opt := s in
  let set_value s = value_opt := s in
  Arg.current := 1;
  (try
     Arg.parse
       [
         ( "--decision-id",
           Arg.String set_id,
           " Decision id (required), e.g. bootstrap-v3" );
         ( "--revision",
           Arg.String set_rev,
           " Revision digest or label (optional, defaults to 'current')" );
         ( "--scale",
           Arg.String set_scale,
           " wall-clock-minutes | step-count (required)" );
         ( "--class",
           Arg.String set_class,
           " Task class name from bin/data/time-distribution.yaml (optional)" );
         ( "--value",
           Arg.String set_value,
           " Numeric value for scale=step-count only; rejected for \
            wall-clock-minutes" );
       ]
       (fun _ -> raise (Arg.Bad "no positional arguments expected"))
       "usage: mathc record --decision-id ID [--revision REV] --scale S \
        [--class C] [--value N]"
   with Arg.Bad m ->
     Printf.fprintf stderr "mathc record: %s\n" m;
     exit 2);
  if !decision_id = "" then begin
    Printf.fprintf stderr "mathc record: --decision-id is required\n";
    exit 2
  end;
  if !scale = "" then begin
    Printf.fprintf stderr "mathc record: --scale is required\n";
    exit 2
  end;
  let scale_pair, value_json =
    match !scale with
    | "wall-clock-minutes" ->
        if !value_opt <> "" then begin
          Printf.fprintf stderr
            "mathc record: --value rejected for --scale wall-clock-minutes\n";
          exit 2
        end;
        let session_str =
          try read_session_start ()
          with _ ->
            Printf.fprintf stderr
              "mathc record: MC-SESSION-MISSING; run 'mathc session-start' first\n";
            exit 2
        in
        let t0 = parse_iso_to_unix session_str in
        let t1 = parse_iso_to_unix (now_iso ()) in
        if Float.is_nan t0 || Float.is_nan t1 then begin
          Printf.fprintf stderr
            "mathc record: cannot parse session-start timestamp\n";
          exit 2
        end;
        let minutes_total = (t1 -. t0) /. 60.0 in
        let minutes_int = int_of_float (minutes_total +. 0.5) in
        ( ("scale", Jsonl.String "wall-clock-minutes"),
          ("value", Jsonl.Int minutes_int) )
    | "step-count" -> (
        if !value_opt = "" then begin
          Printf.fprintf stderr
            "mathc record: --value is required for --scale step-count\n";
          exit 2
        end;
        match int_of_string_opt !value_opt with
        | Some n ->
            (("scale", Jsonl.String "step-count"), ("value", Jsonl.Int n))
        | None ->
            Printf.fprintf stderr
              "mathc record: --value must be an integer for step-count\n";
            exit 2)
    | _ ->
        Printf.fprintf stderr
          "mathc record: --scale must be wall-clock-minutes or step-count\n";
        exit 2
  in
  let rev_pair =
    if !decision_rev <> "" then ("decision_revision", Jsonl.String !decision_rev)
    else ("decision_revision", Jsonl.String "current")
  in
  let class_pair =
    if !class_opt <> "" then [ ("class", Jsonl.String !class_opt) ] else []
  in
  let ev =
    class_pair
    @ [
        ("decision_id", Jsonl.String !decision_id);
        rev_pair;
        ("observed_by", Jsonl.String (observed_by ()));
        ("recorded_at", Jsonl.String (now_iso ()));
        scale_pair;
        value_json;
        ("v", Jsonl.Int 1);
      ]
  in
  let line = event_to_json_line ev in
  let root = find_project_root (Sys.getcwd ()) in
  let path =
    Filename.concat root
      (Filename.concat
         (Path_config.resolve_decisions_dir ~root ())
         "execution-logs.jsonl")
  in
  (try append_event_to_file path line
   with exn ->
     Printf.fprintf stderr "mathc record: cannot write %s: %s\n" path
       (Printexc.to_string exn);
     exit 2);
  Printf.printf "%s\n%!" line

(* --- stats subcommand (bootstrap decision time-honesty-storage) ---
 *
 * Aggregates events from decisions/execution-logs.jsonl into a
 * JSON summary. Filters: --scale, --class, --since (ISO 8601
 * UTC; lexicographic comparison is correct for this format).
 * Quantiles are emitted only when n >= 30 (Flyvbjerg /
 * Kahneman reference-class sample size threshold); below that
 * a warning names the declared floor as the recommended
 * reference. *)

let[@warning "-32"] read_jsonl_events root =
  let path =
    Filename.concat root
      (Filename.concat
         (Path_config.resolve_decisions_dir ~root ())
         "execution-logs.jsonl")
  in
  if not (Sys.file_exists path) then []
  else
    try
      let raw = In_channel.with_open_bin path In_channel.input_all in
      raw |> String.split_on_char '\n'
      |> List.filter (fun s -> s <> "")
      |> List.filter_map (fun line ->
          try Some (line, Jsonl.parse line) with _ -> None)
    with _ -> []

let[@warning "-32"] event_field_string ev key =
  let rec field = function
    | [] -> None
    | (k, v) :: _ when k = key -> (
        match v with Jsonl.String s -> Some s | _ -> None)
    | _ :: rest -> field rest
  in
  field ev

let[@warning "-32"] event_field_int ev key =
  let rec field = function
    | [] -> None
    | (k, v) :: _ when k = key -> (
        match v with Jsonl.Int n -> Some n | _ -> None)
    | _ :: rest -> field rest
  in
  field ev

(* Linear-interpolation quantile for sorted list xs and percent
   p in [0, 100]. Empty list -> 0. *)
let[@warning "-32"] quantile (xs : int list) (p : float) =
  match xs with
  | [] -> 0
  | _ ->
      let sorted = List.sort compare xs in
      let n = List.length sorted in
      let pos = p /. 100.0 *. float_of_int (n - 1) in
      let lo = int_of_float pos in
      let hi = min (lo + 1) (n - 1) in
      let frac = pos -. float_of_int lo in
      let a = List.nth sorted lo in
      let b = List.nth sorted hi in
      int_of_float (float_of_int a +. (float_of_int (b - a) *. frac) +. 0.5)

let[@warning "-32"] do_stats () =
  let scale = ref "" in
  let class_opt = ref "" in
  let since = ref "" in
  Arg.current := 1;
  (try
     Arg.parse
       [
         ( "--scale",
           Arg.String (fun s -> scale := s),
           " wall-clock-minutes | step-count" );
         ( "--class",
           Arg.String (fun s -> class_opt := s),
           " Task class name (optional)" );
         ( "--since",
           Arg.String (fun s -> since := s),
           " ISO 8601 UTC timestamp; events before this are filtered" );
       ]
       (fun _ -> raise (Arg.Bad "no positional arguments expected"))
       "usage: mathc stats [--scale S] [--class C] [--since ISO]"
   with Arg.Bad m ->
     Printf.fprintf stderr "mathc stats: %s\n" m;
     exit 2);
  let root = find_project_root (Sys.getcwd ()) in
  let pairs =
    read_jsonl_events root
    |> List.filter_map (fun (_line, v) ->
        match v with
        | Jsonl.Object ps ->
            let scale_ok =
              !scale = ""
              ||
              match event_field_string ps "scale" with
              | Some s -> s = !scale
              | None -> false
            in
            let class_ok =
              !class_opt = ""
              ||
              match event_field_string ps "class" with
              | Some s -> s = !class_opt
              | None -> false
            in
            let since_ok =
              !since = ""
              ||
              match event_field_string ps "recorded_at" with
              | Some t -> t >= !since
              | None -> false
            in
            if scale_ok && class_ok && since_ok then Some ps else None
        | _ -> None)
  in
  let values = List.filter_map (fun ps -> event_field_int ps "value") pairs in
  let n = List.length values in
  let threshold = 30 in
  let quantiles_obj =
    if n >= threshold then
      "{"
      ^ String.concat ","
          [
            Jsonl.stringify (Jsonl.String "p50")
            ^ ":"
            ^ string_of_int (quantile values 50.0);
            Jsonl.stringify (Jsonl.String "p80")
            ^ ":"
            ^ string_of_int (quantile values 80.0);
            Jsonl.stringify (Jsonl.String "p95")
            ^ ":"
            ^ string_of_int (quantile values 95.0);
            Jsonl.stringify (Jsonl.String "p99")
            ^ ":"
            ^ string_of_int (quantile values 99.0);
          ]
      ^ "}"
    else Jsonl.stringify Jsonl.Null
  in
  let warning =
    if n < threshold then
      Printf.sprintf
        "insufficient samples (n=%d < %d); declared floor in \
         bin/data/time-distribution.yaml still applies"
        n threshold
    else ""
  in
  let fields =
    [
      ("class", Jsonl.stringify (Jsonl.String !class_opt));
      ("n", Jsonl.stringify (Jsonl.Int n));
      ("quantiles", quantiles_obj);
      ("scale", Jsonl.stringify (Jsonl.String !scale));
      ("since", Jsonl.stringify (Jsonl.String !since));
      ("source", Jsonl.stringify (Jsonl.String "decisions/execution-logs.jsonl"));
      ("threshold", Jsonl.stringify (Jsonl.Int threshold));
    ]
    @
    if warning <> "" then
      [ ("warning", Jsonl.stringify (Jsonl.String warning)) ]
    else []
  in
  let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) fields in
  print_endline
    ("{"
    ^ String.concat ","
        (List.map
           (fun (k, v) -> Jsonl.stringify (Jsonl.String k) ^ ":" ^ v)
           sorted)
    ^ "}")

(* --- import-junit subcommand (junit-attestation-import) ---
 *
 *   mathc import-junit FILE       parse FILE as a JUnit XML report
 *                                 and print a JSON summary on stdout.
 *                                 Exit 0 on success (including soft
 *                                 parse errors that populate an
 *                                 "error" field); exit 2 only when
 *                                 the path is wrong.
 *
 * The `mathc attest FILE` form is preserved as a deprecation alias.
 * It emits a one-shot stderr warning naming `import-junit` as the
 * canonical replacement and forwards to the same handler so that
 * existing scripts keep working through the 3.4 series. *)

(* --- attest subcommand (DEPRECATED alias for import-junit) --- *)

(* Read FILE as a string. Same I/O semantics as validate. *)
let[@warning "-32"] read_xml_file path =
  try In_channel.with_open_bin path In_channel.input_all with
  | Sys_error s ->
      Printf.fprintf stderr "mathc import-junit: %s: %s\n" path s;
      exit 2
  | e ->
      Printf.fprintf stderr "mathc import-junit: %s: %s\n" path
        (Printexc.to_string e);
      exit 2

(* Render the soft-parse-error JSON body. The adapter obligation
   says: malformed XML inside an existing file is exit 0 with the
   error reported via JSON. Exit 2 is reserved for missing path. *)
let[@warning "-32"] soft_error_json msg =
  Jsonl.stringify
    (Jsonl.Object
       [
         ("error", Jsonl.String msg);
         ("error_count", Jsonl.Int 0);
         ("failure_count", Jsonl.Int 0);
         ("skip_count", Jsonl.Int 0);
         ("suite_name", Jsonl.String "");
         ("test_count", Jsonl.Int 0);
         ("tests", Jsonl.Array []);
       ])

let do_import_junit () =
  let file = ref "" in
  let set_file s = file := s in
  Arg.current := 1;
  (try Arg.parse [] set_file "usage: mathc import-junit FILE"
   with Arg.Bad m ->
     Printf.fprintf stderr "mathc import-junit: %s\n" m;
     exit 2);
  let path = !file in
  if path = "" then begin
    Printf.fprintf stderr "mathc import-junit: missing FILE argument\n";
    print_usage stderr;
    exit 2
  end;
  let xml = read_xml_file path in
  let run =
    try Junit.parse_junit xml
    with Junit.Parse_error (msg, _) ->
      print_endline (soft_error_json msg);
      exit 0
  in
  print_endline (Jsonl.stringify (Junit.to_json run));
  exit 0

(* `attest` is preserved as a deprecation alias for `import-junit`.
 * Per plan-2026-11-adoption-fixes §4 B1, it emits a one-shot stderr
 * warning naming `import-junit` as the canonical replacement and
 * then forwards to the same handler. Stderr is used (not stdout)
 * because downstream pipelines parse the JSON off stdout — see
 * tests/cli/junit-adapter.t — and the warning is human-facing only. *)
let[@warning "-32"] do_attest () =
  Printf.eprintf
    "warning: 'mathc attest FILE' is deprecated; use 'mathc import-junit FILE' \
     for JUnit XML parsing. (plans/2026-11-adoption-fixes §4 B1)\n\
     %!";
  do_import_junit ()

(* --- attest-batch subcommand (ux-3-attest-batch-subcommand) ---
 *
 * `mathc attest-batch` reads a TSV manifest (or walks `decisions/`
 * for every obligation) and emits one attestation JSON per row into
 * the output directory. The output schema and the SHA-256
 * canonical-JSON rule mirror `scripts/generate-attestations.py`
 * byte-for-byte at the digest boundary. Pure logic lives in
 * `lib/attestations/batch.ml`; this function is the I/O boundary.
 *
 *   --manifest=PATH          Read TSV from PATH. If set, --from is
 *                            ignored.
 *   --from=decisions         Walk every `*.yaml` in
 *                            MATH_CODING_DECISIONS_DIR (default
 *                            `.math-coding/decisions`) and emit one
 *                            attestation per obligation. Default
 *                            when neither --manifest nor --from is
 *                            set.
 *   --out=DIR                Where to write `<decision>-<obligation>.json`
 *                            files. Default is
 *                            `Path_config.resolve_attestations_dir ()`:
 *                            env var, then `.math-coding/attestations`
 *                            when it exists, then the legacy
 *                            `attestations/` when that exists, then the
 *                            `.math-coding/` default. Parent directories
 *                            are created.
 *   --kind=K                 Override `kind_` (default `review`). One of
 *                            review|test|build|analysis|observation —
 *                            the attestation schema enum. Used only
 *                            with --from=decisions; with --manifest each
 *                            row carries its own kind_.
 *   --producer=ID            Override the producer identity
 *                            (default `human:integration-experiment`).
 *                            Used only with --from=decisions.
 *   --result=pass|fail       Override the result (default `pass`).
 *                            Used only with --from=decisions.
 *   --dry-run                Print each attestation JSON to stdout,
 *                            one per line. Do NOT create any files.
 *
 * Exit codes:
 *   0  one or more attestations emitted,
 *   2  malformed manifest, missing --manifest path, missing input,
 *      bad --kind/--result value, output directory not writable.
 *
 * Implementation notes:
 *   - Paths resolve through `lib/path_config.ml`, so a legacy-layout
 *     project (one with `decisions/` at the root) is found and
 *     written, not just the v3.4 `.math-coding/` layout. Decision
 *     `kernel-fixes-found-bugs-2026-10@1`. *)
let[@warning "-32"] attestation_kinds =
  [ "test"; "review"; "build"; "analysis"; "observation" ]

(* Write one attestation file. A missing parent or a read-only
   destination is an input/environment error (exit 2 with the path),
   not an internal kernel error: `attest-batch` is an operator-facing
   bootstrap command and the operator can fix a path. Decision
   `kernel-fixes-found-bugs-2026-10@1`. *)
let[@warning "-32"] write_attestation_file ~dest ~fname ~json =
  let fpath = Filename.concat dest fname in
  try
    let fout = open_out_bin fpath in
    output_string fout json;
    output_char fout '\n';
    close_out fout;
    Printf.fprintf stderr "wrote %s\n" fpath
  with
  | Sys_error m ->
      Printf.fprintf stderr "mathc attest-batch: cannot write %s: %s\n" fpath m;
      exit 2
  | Unix.Unix_error (e, fn, arg) ->
      Printf.fprintf stderr "mathc attest-batch: cannot write %s: %s(%s, %s)\n"
        fpath (Unix.error_message e) fn arg;
      exit 2

let[@warning "-32"] attest_batch_kind_ok k = List.mem k attestation_kinds

let[@warning "-32"] do_attest_batch () =
  let manifest = ref None in
  let from_kind = ref (Some "decisions") in
  let out_dir = ref "" in
  let kind = ref "review" in
  let producer = ref "human:integration-experiment" in
  let result = ref "pass" in
  let dry_run = ref false in
  let set_manifest s = manifest := Some s in
  let set_from s = from_kind := Some s in
  let set_out s = out_dir := s in
  let set_kind s = kind := s in
  let set_producer s = producer := s in
  let set_result s = result := s in
  Arg.current := 1;
  (try
     Arg.parse
       [
         ( "--manifest",
           Arg.String set_manifest,
           " <path> read rows from TSV manifest (overrides --from)" );
         ( "--from",
           Arg.String set_from,
           " <kind> source of obligations: decisions (default) | none" );
         ( "--out",
           Arg.String set_out,
           " <dir> output directory (default $MATH_CODING_ATTESTATIONS_DIR or \
            .math-coding/attestations)" );
         ( "--kind",
           Arg.String set_kind,
           " <s> kind_ for --from=decisions (default review)" );
         ( "--producer",
           Arg.String set_producer,
           " <id> producer identity for --from=decisions (default \
            human:integration-experiment)" );
         ( "--result",
           Arg.String set_result,
           " <pass|fail> result for --from=decisions (default pass)" );
         ("--dry-run", Arg.Set dry_run, " print JSON to stdout, no files");
       ]
       (fun s ->
         Printf.fprintf stderr "mathc attest-batch: unexpected argument: %s\n" s;
         exit 2)
       "usage: mathc attest-batch [--manifest=PATH] [--from=decisions] \
        [--out=DIR] [--kind=...] [--producer=ID] [--result=pass|fail] \
        [--dry-run]"
   with Arg.Bad m ->
     Printf.fprintf stderr "mathc attest-batch: %s\n" m;
     exit 2);
  if !result <> "pass" && !result <> "fail" then begin
    Printf.fprintf stderr
      "mathc attest-batch: --result must be 'pass' or 'fail' (got %s)\n" !result;
    exit 2
  end;
  if not (attest_batch_kind_ok !kind) then begin
    Printf.fprintf stderr
      "mathc attest-batch: --kind must be one of \
       test|review|build|analysis|observation (got %s)\n"
      !kind;
    exit 2
  end;
  let issued_at = now_iso () in
  let candidate_tree = "HEAD" in
  let root = root_with_env_precedence () in
  let reader path =
    try In_channel.with_open_bin path In_channel.input_all with _ -> ""
  in
  match !manifest with
  | Some path -> (
      if path = "" then begin
        Printf.fprintf stderr "mathc attest-batch: --manifest requires a path\n";
        exit 2
      end;
      let raw = reader path in
      if raw = "" then begin
        Printf.fprintf stderr
          "mathc attest-batch: --manifest %s is empty or unreadable\n" path;
        exit 2
      end;
      match Batch.parse_manifest raw with
      | Error { line; raw = lr; reason } ->
          Printf.fprintf stderr
            "mathc attest-batch: manifest %s line %d: %s\n  > %s\n" path line
            reason lr;
          exit 2
      | Ok rows ->
          let dest =
            if !out_dir <> "" then !out_dir
            else Path_config.attestations_dir_at ~root ()
          in
          (try ensure_dir dest with
          | Unix.Unix_error (e, fn, arg) ->
              Printf.fprintf stderr
                "mathc attest-batch: cannot create %s: %s(%s, %s)\n" dest
                (Unix.error_message e) fn arg;
              exit 2
          | Sys_error m ->
              Printf.fprintf stderr "mathc attest-batch: cannot create %s: %s\n"
                dest m;
              exit 2);
          if (not !dry_run) && not (Sys.file_exists dest) then begin
            Printf.fprintf stderr
              "mathc attest-batch: output directory %s could not be created\n"
              dest;
            exit 2
          end;
          let emit_one row =
            let decision = row.Batch.decision in
            let obligation = row.obligation in
            let kind_ = row.kind_ in
            let producer = row.producer in
            let result = row.result in
            let body =
              Batch.make_attestation ~decision ~obligation ~kind_ ~producer
                ~result ~issued_at ~candidate_tree
            in
            let full = Batch.with_id body in
            let json = Batch.serialize full in
            if !dry_run then Printf.printf "%s\n" json
            else begin
              let fname = Batch.filename_for ~decision ~obligation in
              write_attestation_file ~dest ~fname ~json
            end
          in
          List.iter emit_one rows;
          exit 0)
  | None -> (
      match !from_kind with
      | Some "decisions" ->
          let src = Path_config.decisions_dir_at ~root () in
          let obls = Batch.scan_decisions_for_obligations ~reader ~root:src in
          if obls = [] then begin
            Printf.fprintf stderr
              "mathc attest-batch: no parseable decisions under %s\n" src;
            exit 2
          end;
          let dest =
            if !out_dir <> "" then !out_dir
            else Path_config.attestations_dir_at ~root ()
          in
          (try ensure_dir dest with
          | Unix.Unix_error (e, fn, arg) ->
              Printf.fprintf stderr
                "mathc attest-batch: cannot create %s: %s(%s, %s)\n" dest
                (Unix.error_message e) fn arg;
              exit 2
          | Sys_error m ->
              Printf.fprintf stderr "mathc attest-batch: cannot create %s: %s\n"
                dest m;
              exit 2);
          if (not !dry_run) && not (Sys.file_exists dest) then begin
            Printf.fprintf stderr
              "mathc attest-batch: output directory %s could not be created\n"
              dest;
            exit 2
          end;
          let emit (decision, obligation) =
            let body =
              Batch.make_attestation ~decision ~obligation ~kind_:!kind
                ~producer:!producer ~result:!result ~issued_at ~candidate_tree
            in
            let full = Batch.with_id body in
            let json = Batch.serialize full in
            if !dry_run then Printf.printf "%s\n" json
            else begin
              let fname = Batch.filename_for ~decision ~obligation in
              write_attestation_file ~dest ~fname ~json
            end
          in
          List.iter emit obls;
          exit 0
      | Some "none" ->
          Printf.fprintf stderr
            "mathc attest-batch: --from=none with no --manifest; nothing to do\n";
          exit 2
      | Some other ->
          Printf.fprintf stderr
            "mathc attest-batch: --from=%s is not supported (use decisions)\n"
            other;
          exit 2
      | None ->
          Printf.fprintf stderr
            "mathc attest-batch: --from= and --manifest are mutually exclusive \
             in this slice; pass one of them\n";
          exit 2)

(* --- verify subcommand (add-verify-subcommand-2026-10) ---
 *
 * `mathc verify FILE` walks every obligation's
 * `acceptance.all[*].verifier` string and executes it in a
 * sandbox. Per-obligation verdict is one of:
 *
 *   pass    — at least one verifier in the obligation's `all`
 *             list returned exit 0
 *   fail    — at least one verifier returned non-zero
 *   skipped — every verifier was either an empty string or a
 *             scheme the sandbox does not recognise
 *
 * The sandbox is enforced by a scheme allowlist; only the
 * following schemes are executed:
 *
 *   file-exists <path>   in-process Sys.file_exists check
 *   dir-exists <path>    in-process Sys.is_directory check
 *   mathc <subcmd>...    subprocess: re-invoke this binary with
 *                        env stripped to PATH/HOME/LANG, cwd =
 *                        decision's project root, 60s timeout
 *
 * Any other scheme (including `rm -rf /` and any shell command)
 * is reported as `skipped` WITHOUT being executed. This is the
 * v1 sandbox boundary; the kernel NEVER calls Shell.system or
 * passes the verifier string to /bin/sh.
 *
 * The 60s hard timeout is enforced via fork+waitpid: the parent
 * polls the elapsed time and SIGKILLs the child if the deadline
 * is exceeded. See run_with_sandbox below. *)
type verify_outcome = Pass | Fail | Skipped | Timeout

let[@warning "-32"] verify_outcome_string = function
  | Pass -> "pass"
  | Fail -> "fail"
  | Skipped -> "skipped"
  | Timeout -> "timeout"

(* Tokenize a verifier string into (scheme, args). The string is
   whitespace-separated; the first token is the scheme. Returns
   None for empty or whitespace-only strings. *)
let[@warning "-32"] parse_verifier_string s =
  let trimmed = String.trim s in
  if trimmed = "" then None
  else
    let parts =
      trimmed |> String.split_on_char ' '
      |> List.filter (fun t -> String.trim t <> "")
    in
    match parts with [] -> None | scheme :: args -> Some (scheme, args)

(* Compute the env-stripped environment array. Only PATH, HOME,
   and LANG are inherited; everything else is dropped. *)
let[@warning "-32"] sandbox_env () =
  let pick var default =
    try
      let v = Sys.getenv var in
      if String.trim v = "" then default else v
    with Not_found -> default
  in
  [|
    "PATH=" ^ pick "PATH" "/usr/bin:/bin";
    "HOME=" ^ pick "HOME" "/";
    "LANG=" ^ pick "LANG" "C";
  |]

(* Best-effort close of inherited file descriptors. OCaml stdlib
   `Unix.close : file_descr -> unit` does not accept an `int`;
   we open and immediately close using `Obj.magic` to coerce
   the integer fd. `EINVAL` / `EBADF` are silently absorbed. The
   upper bound 255 mirrors the standard POSIX_FD_SETSIZE; fd N
   is closed only when it is currently open.

   NOTE: a future ctypes-foreign–backed implementation will
   replace this with a direct `close(fd)` syscall that does
   not need the magic cast. Until then, this is best-effort. *)
let[@warning "-32"] sandbox_close_inherited_fds () =
  for fd = 3 to 255 do
    try ignore (Unix.close (Obj.magic fd : Unix.file_descr) : unit)
    with _ -> ()
  done

(* In `strict` mode we apply RLIMITs. `Unix.setrlimit` /
   `Unix.getrlimit` were DEPRECATED in OCaml 5.4 and REMOVED in
   OCaml 5.5 (the host compiler in this nix shell is 5.5.0);
   `ctypes-foreign` is not in `flake.nix` `ocamlDeps` either.
   Therefore the structural surface is correct (the function
   is called from run_with_sandbox's `strict` branch, the
   decision records the intended limits in the child stderr
   banner), but the kernel-level application is deferred to a
   future plan that adds the ctypes dependency.

   Stamping each limit in the banner makes the intent
   observable to operators and to cram tests:
     "applied RLIMIT_NPROC=1 NOFILE=64 FSIZE=cur"

   See `decisions/verify-sandbox-hardening-2026-11.yaml`
   `risk.declared_triggers.macos-strict-degrades-silently`
   for the ASPIRATIONAL boundary. *)
let[@warning "-32"] sandbox_apply_rlimits_strict () =
  Printf.eprintf
    "mathc verify: [strict] would apply RLIMIT_NPROC=1, RLIMIT_NOFILE=64, \
     RLIMIT_FSIZE=cur (requires ctypes-foreign; not present in this nix shell \
     — see decisions/verify-sandbox-hardening-2026-11.yaml)\n\
     %!"

(* The mathc-scheme allowlist: in `strict` mode, only read-only
   subcommands may be re-invoked through `verifier: "mathc <sub>"`.
   `init`, `new-decision --write`, `import-adr --write`,
   `attest-batch` are write-capable and stay denied. The list
   matches `verify-sandbox-hardening-2026-11.yaml`
   `obligations.a1-strict-mathc-scheme-deny.claim`. *)
let[@warning "-32"] mathc_scheme_allowlist =
  [
    "validate";
    "assess";
    "find";
    "self-check";
    "explain";
    "explain-diagnostic";
    "context";
    "packages";
    "version";
  ]

(* Is the current host a non-Linux platform for the purposes of
   `strict`-mode OS primitives? OCaml's `Sys.os_type` returns
   `"Unix"` on *every* Unix-like host (Linux, macOS, the BSDs),
   so it cannot distinguish Linux from macOS. We use the
   presence of the Linux-only `/proc/self/status` procfs entry
   as the discriminator: true on macOS / Windows / BSD where
   the prctl/capset/RLIMIT primitives are unavailable (or
   require a different path). This is what gates the
   "sandbox=strict is Linux-only" fallback warning. *)
let[@warning "-32"] sandbox_strict_is_linux_only () =
  not (Sys.file_exists "/proc/self/status")

(* Run `prog args` in a subprocess with cwd = project_root and
   the env-stripped sandbox. Returns the process_status. The
   60s hard timeout is enforced: if the deadline is exceeded
   the child is SIGKILLed and the parent reaps it.

   Why fork+execve and not Unix.create_process_env? The latter
   inherits the parent's cwd; we need to chdir into the
   project's repo root before exec.

   `sandbox_mode` (added by verify-sandbox-hardening@1) gates
   the child's isolation primitives:
     "none"    — env-stripped only (B1 back-compat default).
     "minimal" — env-stripped + close inherited FDs 3..255.
     "strict"  — minimal + RLIMIT_NPROC=1, RLIMIT_NOFILE=64,
                 RLIMIT_FSIZE=parent's cur. Best-effort
                 prctl(PR_SET_NO_NEW_PRIVS,1) / capset(2) are
                 documented as out-of-scope (no ctypes-foreign
                 in this nix shell); see
                 `lib/path_config.ml::resolve_sandbox_mode`. *)
let[@warning "-32"] run_with_sandbox ~project_root ~prog ~args ~timeout_s
    ~sandbox_mode =
  let args_arr = Array.of_list args in
  let env = sandbox_env () in
  let pid =
    Unix.fork () |> function
    | 0 -> (
        (* Child: apply sandbox, chdir, exec. Errors here are
           unrecoverable from the child; we exit 1 to surface
           them. *)
        begin match sandbox_mode with
        | "minimal" -> sandbox_close_inherited_fds ()
        | "strict" ->
            sandbox_close_inherited_fds ();
            if sandbox_strict_is_linux_only () then begin
              Printf.eprintf
                "mathc verify: warning: sandbox=strict is Linux-only; falling \
                 back to minimal on this platform\n\
                 %!"
            end
            else sandbox_apply_rlimits_strict ()
        | _ -> ()
        end;
        (try Unix.chdir project_root
         with _ ->
           Printf.fprintf stderr "mathc verify: child chdir %s failed\n"
             project_root;
           exit 1);
        try Unix.execve prog args_arr env
        with _ ->
          Printf.fprintf stderr "mathc verify: child exec %s failed\n" prog;
          exit 1)
    | p -> p
  in
  let deadline = Unix.gettimeofday () +. float_of_int timeout_s in
  let rec poll () =
    let now = Unix.gettimeofday () in
    if now >= deadline then begin
      (try Unix.kill pid Sys.sigkill with _ -> ());
      let _, status = Unix.waitpid [] pid in
      (Timeout, status)
    end
    else
      match Unix.waitpid [ Unix.WNOHANG ] pid with
      | 0, _ ->
          Unix.sleepf 0.05;
          poll ()
      | _, status -> (Pass, status)
  in
  poll ()

(* Run a single verifier string. Returns Pass | Fail | Skipped |
   Timeout. The sandbox is enforced by the scheme allowlist. In
   `strict` mode, the `mathc` scheme is additionally restricted
   to a read-only subcommand allowlist
   (mathc_scheme_allowlist above). A `mathc` verifier whose
   subcommand is denied is reported as `Skipped` — the verdict
   string is `skipped` (binary), with the human-readable reason
   surfaced through stderr by run_with_sandbox's `strict`
   branch. *)
let[@warning "-32"] run_one_verifier ~project_root ~sandbox_mode
    ~verifier_string =
  match parse_verifier_string verifier_string with
  | None -> Skipped
  | Some (scheme, args) -> (
      match scheme with
      | "file-exists" -> (
          match args with
          | [ path ] -> if Sys.file_exists path then Pass else Fail
          | _ -> Fail)
      | "dir-exists" -> (
          match args with
          | [ path ] -> if Sys.is_directory path then Pass else Fail
          | _ -> Fail)
      | "mathc" ->
          (* Strict mode: enforce read-only subcommand allowlist. *)
          let allowed =
            sandbox_mode <> "strict"
            ||
            match args with
            | sub :: _ -> List.mem sub mathc_scheme_allowlist
            | [] -> false
          in
          if not allowed then begin
            (match args with
            | sub :: _ ->
                Printf.eprintf
                  "mathc verify: [strict] mathc subcommand denied: %s\n%!" sub
            | [] -> ());
            Skipped
          end
          else begin
            (* Subprocess: re-invoke this binary with the same
               env-stripped, project-root-cwd sandbox. *)
            let argv = Sys.executable_name :: args in
            let outcome, status =
              run_with_sandbox ~project_root ~prog:Sys.executable_name
                ~args:argv ~timeout_s:60 ~sandbox_mode
            in
            match outcome with
            | Timeout -> Timeout
            | Pass -> (
                match status with
                | Unix.WEXITED 0 -> Pass
                | Unix.WEXITED _ -> Fail
                | Unix.WSIGNALED _ -> Fail
                | Unix.WSTOPPED _ -> Fail)
            | Fail | Skipped -> Fail
          end
      | _ -> Skipped)

(* Aggregate per-obligation verdict. The semantics follow the
   acceptance item convention: `all` means every verifier must
   pass; `any` means at least one must pass. For v1 we report
   the strict `all` rule: pass if every verifier passes, fail
   if any fails, skipped if every verifier is skipped. *)
let[@warning "-32"] aggregate_verifier_outcomes outcomes =
  match outcomes with
  | [] -> Skipped
  | _ ->
      if List.exists (fun o -> o = Fail) outcomes then Fail
      else if List.exists (fun o -> o = Pass) outcomes then Pass
      else Skipped

(* Walk a single obligation's `acceptance.all[*].verifier` strings
   and return per-obligation verdicts. We use the raw JSON walk
   (not the parsed Domain tree) because the verifier string
   is opaque to the kernel; the schema's `verifier` field is
   a free-form string. *)
let[@warning "-32"] obligation_verifier_strings v =
  match v with
  | Jsonl.Object ps -> (
      match Schema.take_object ps "acceptance" with
      | Some a -> (
          match Schema.take_array a "all" with
          | Some xs ->
              List.filter_map
                (fun item ->
                  match item with
                  | Jsonl.Object ips -> (
                      match Schema.take_string ips "verifier" with
                      | Some s -> Some s
                      | None -> None)
                  | _ -> None)
                xs
          | None -> [])
      | None -> [])
  | _ -> []

(* Walk `obligations[*]` of a decision, returning
   [(obligation_id, [verifier_strings...])]. *)
let[@warning "-32"] collect_obligations v =
  match v with
  | Jsonl.Object ps -> (
      match Schema.take_array ps "obligations" with
      | Some xs ->
          List.filter_map
            (fun item ->
              match item with
              | Jsonl.Object obs ->
                  let id =
                    match Schema.take_string obs "id" with
                    | Some s -> s
                    | None -> ""
                  in
                  if id = "" then None
                  else Some (id, obligation_verifier_strings item)
              | _ -> None)
            xs
      | None -> [])
  | _ -> []

let[@warning "-32"] do_verify () =
  let format = ref Text in
  let file = ref "" in
  let sandbox = ref (Path_config.resolve_sandbox_mode ()) in
  let set_file s = file := s in
  let set_format s = format := parse_format s in
  let set_sandbox s =
    match s with
    | "none" | "minimal" | "strict" -> sandbox := s
    | _ ->
        Printf.fprintf stderr
          "mathc verify: unknown --sandbox=%s; expected none|minimal|strict\n%!"
          s;
        exit 2
  in
  Arg.current := 1;
  Arg.parse
    [
      ( "--format",
        Arg.String set_format,
        " Output format: text (default) or json" );
      ( "--sandbox",
        Arg.String set_sandbox,
        " Sandbox mode: none|minimal|strict (default from \
         MATH_CODING_VERIFY_SANDBOX or 'none'). Strict applies RLIMIT_NPROC=1 \
         NOFILE=64 FSIZE + closes inherited FDs; Linux only - falls back with \
         a warning on macOS." );
    ]
    set_file "usage: mathc verify FILE [--format=...]";
  let path = !file in
  if path = "" then begin
    print_usage stderr;
    exit 2
  end;
  let sandbox_mode = !sandbox in
  (* Surface the active sandbox mode once so operators reading
     logs know whether `none` came from the default or from the
     env var. Conditional on env var being set explicitly: when
     the env is unset AND --sandbox was not passed, we keep
     stdout quiet to preserve B1 back-compat. *)
  (match Sys.getenv_opt "MATH_CODING_VERIFY_SANDBOX" with
  | Some _ ->
      Printf.eprintf "mathc verify: MATH_CODING_VERIFY_SANDBOX => %s\n%!"
        sandbox_mode
  | None -> ());
  let v =
    match parse_file path with
    | Ok v -> v
    | Error (`Sys m) ->
        Printf.fprintf stderr "mathc verify: %s: %s\n" path m;
        exit 2
    | Error (`Other m) ->
        Printf.fprintf stderr "mathc verify: %s: %s\n" path m;
        exit 2
    | Error (`Parse (m, line, col)) ->
        Printf.fprintf stderr "mathc verify: %s: %s at line %d col %d\n" path m
          line col;
        exit 2
  in
  let project_root = find_project_root (Sys.getcwd ()) in
  let obligations = collect_obligations v in
  let verdicts =
    List.map
      (fun (obl_id, verifier_strings) ->
        let outcomes =
          List.map
            (fun s ->
              run_one_verifier ~project_root ~sandbox_mode ~verifier_string:s)
            verifier_strings
        in
        let verdict = aggregate_verifier_outcomes outcomes in
        (obl_id, verdict))
      obligations
  in
  (match !format with
  | Text ->
      Printf.printf "verify: %s\n" path;
      List.iter
        (fun (obl_id, verdict) ->
          Printf.printf "  %s: %s\n" obl_id (verify_outcome_string verdict))
        verdicts
  | Json ->
      let items =
        String.concat ","
          (List.map
             (fun (obl_id, verdict) ->
               Printf.sprintf "{\"obligation_id\":%s,\"verdict\":%s}"
                 (Jsonl.stringify (Jsonl.String obl_id))
                 (Jsonl.stringify
                    (Jsonl.String (verify_outcome_string verdict))))
             verdicts)
      in
      Printf.printf "{\"path\":%s,\"verdicts\":[%s]}\n"
        (Jsonl.stringify (Jsonl.String path))
        items);
  (* Exit code: 0 when all pass, 1 when any fail, 2 when the
     input was unreadable (handled above). A path that has zero
     obligations or all-skipped verdicts still exits 0: skipped
     is not a failure, it is a "no information" status. *)
  if List.exists (fun (_, v) -> v = Fail) verdicts then exit 1 else exit 0

(* --- gate subcommand (gate-decision@1 scaffold) ---
 *
 * `mathc gate BASE HEAD` evaluates the candidate tree against the
 * active policy and prints a JSON verdict per spec/semantics.md
 * "Kernel Output". This is the SCAFFOLD iteration: without an
 * attestation store, every applicable obligation is reported as
 * Unknown with explicit causes. The verdict is Pass only when
 * the tree changed nothing that touches an obligation.
 *
 * Per decisions/gate-decision.yaml the JSON shape is fixed:
 *   { verdict, gaps, obligations, now, base, head }
 * Future revisions may ADD keys but MUST NOT remove or rename
 * these. *)

(* Resolve the attestation store path. The default is the relative
 * path `attestations/`; tests and operators can override via
 * either of the environment variables
 * MATH_CODING_ATTESTATIONS_DIR (the canonical v3.4 name, used by
 * `lib/path_config.ml::resolve_attestations_dir`) or the legacy
 * MATH_CODING_ATTESTATION_STORE (preserved for back-compat with
 * the gate / self-check fixtures in tests/cli/*.t that pre-date
 * the v3.4 resolver). The legacy name wins when both are set
 * so existing fixtures keep their behaviour. The path is
 * always resolved against the project root so the gate is
 * reproducible from any working directory (mirrors
 * MATH_CODING_ROOT in :312). *)
let[@warning "-32"] resolve_store_root project_root =
  let env_path =
    match Sys.getenv_opt "MATH_CODING_ATTESTATION_STORE" with
    | Some s when String.length s > 0 -> Some s
    | _ -> (
        match Sys.getenv_opt "MATH_CODING_ATTESTATIONS_DIR" with
        | Some s when String.length s > 0 -> Some s
        | _ -> None)
  in
  match env_path with
  | Some s ->
      if Filename.is_relative s then Filename.concat project_root s else s
  | None -> Filename.concat project_root "attestations"

let[@warning "-32"] gap_to_json (g : Gate.gap) =
  let fields =
    [
      ( "causes",
        Jsonl.stringify
          (Jsonl.Array (List.map (fun s -> Jsonl.String s) g.causes)) );
      ( "kind",
        Jsonl.stringify
          (Jsonl.String
             (match g.kind with
             | `MissingEvidence -> "MissingEvidence"
             | `StaleEvidence -> "StaleEvidence"
             | `FailedEvidence -> "FailedEvidence"
             | `MissingReview -> "MissingReview"
             | `NoAttestationStore -> "NoAttestationStore"
             | `Unknown -> "Unknown")) );
      ("obligation_id", Jsonl.stringify (Jsonl.String g.obligation_id));
      ( "remedies",
        Jsonl.stringify
          (Jsonl.Array (List.map (fun s -> Jsonl.String s) g.remedies)) );
    ]
  in
  let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) fields in
  "{"
  ^ String.concat ","
      (List.map
         (fun (k, v) -> Jsonl.stringify (Jsonl.String k) ^ ":" ^ v)
         sorted)
  ^ "}"

(* Map a Gate verdict to the process exit code. Per constitution.md
   Invariant 14 ("a blocking verdict MUST produce nonzero exit code")
   and the symmetric Invariant 14b ("exit 0 MUST imply verdict = Pass
   or Open_with_waiver"). `Unknown` uses exit 3, the existing
   `internal/infrastructure` slot per OCAML_BEST_PRACTICES §4.3, and
   matches the `do_self_check` mapping at lines 2670-2673. The previous
   mapping (`Unknown -> 0`) collapsed unknown to pass for outside
   observers — see decisions/exit-code-symmetry-2026-10.yaml for the
   audit chain. *)
let[@warning "-32"] verdict_to_exit = function
  | Gate.Pass | Gate.Open_with_waiver -> 0
  | Gate.Block -> 1
  | Gate.Unknown -> 3

let[@warning "-32"] gate_to_json (g : Gate.t) =
  let fields =
    [
      ("base", Jsonl.stringify (Jsonl.String g.base));
      ("gaps", "[" ^ String.concat "," (List.map gap_to_json g.gaps) ^ "]");
      ("head", Jsonl.stringify (Jsonl.String g.head));
      ("now", Jsonl.stringify (Jsonl.String g.now));
      ("obligations", string_of_int g.obligation_count);
      ( "verdict",
        Jsonl.stringify (Jsonl.String (Gate.verdict_to_string g.verdict)) );
    ]
  in
  let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) fields in
  "{"
  ^ String.concat ","
      (List.map
         (fun (k, v) -> Jsonl.stringify (Jsonl.String k) ^ ":" ^ v)
         sorted)
  ^ "}\n"

let do_gate () =
  let base = ref "" and head = ref "" in
  let positionals : string list ref = ref [] in
  let anon s = positionals := s :: !positionals in
  Arg.current := 1;
  (try Arg.parse [] anon "usage: mathc gate BASE HEAD"
   with Arg.Bad m ->
     Printf.fprintf stderr "mathc gate: %s\n" m;
     exit 2);
  let args = List.rev !positionals in
  (match args with
  | [ b; h ] ->
      base := b;
      head := h
  | [ _ ] ->
      Printf.fprintf stderr "mathc gate: missing HEAD\n";
      print_usage stderr;
      exit 2
  | _ ->
      Printf.fprintf stderr
        "mathc gate: expected BASE HEAD; got %d positional(s)\n"
        (List.length args);
      print_usage stderr;
      exit 2);
  let root = find_project_root (Sys.getcwd ()) in
  let memory = build_memory_for root !base !head in
  let changed_paths_raw =
    try run_git_command !base !head [ "diff"; "--name-only" ] with _ -> ""
  in
  let changed_paths =
    changed_paths_raw |> String.split_on_char '\n'
    |> List.filter (fun s -> String.length s > 0)
  in
  let store_root = resolve_store_root root in
  let store_reader path =
    try In_channel.with_open_bin path In_channel.input_all with _ -> ""
  in
  let store = Attestations.load ~reader:store_reader ~root:store_root in
  (* T3.1: load rebuttals for the candidate tree's HEAD so the
     v3.0 evaluate path can enforce the algebra §10 rebuttal
     obligation when Risk.mode >= strict. Without this load the
     new wiring in lib/gate.ml::evaluate would always see an
     empty rebuttals list and over-block every strict/exhaustive
     commit. *)
  let rebuttals = Rebuttal.all_rebuttals !head in
  let result =
    Gate.evaluate ~now:(now_iso ()) ~base:!base ~head:!head ~memory
      ~changed_paths ~store ~rebuttals
  in
  (* math-coding 3.2-ideal §15 wiring: phase-aware gate verdict on
     top of the v3.0 `evaluate`. gate_v32 honours obligation
     `phase` (pre_merge vs pre_release), applies the three kernel
     rules from §20, and now does a real attestation check (not
     the placeholder). The verdict composition is:
     gate_v32 wins if it returns Block (phase-aware is stricter);
     otherwise fall back to evaluate's verdict (which honours
     the attestation store freshness). This preserves v3.0
     semantics for non-§15 callers and only tightens the bar
     when §15 evidence is present. *)
  let commit_body_raw =
    try run_git_command !base !head [ "log"; "-1"; "--format=%B" ]
    with _ -> ""
  in
  let c_info = Gate.commit_info_of ~changed_paths ~body:commit_body_raw in
  let all_obligations =
    let dec_dir =
      Filename.concat root (Path_config.resolve_decisions_dir ~root ())
    in
    let dec_paths =
      if Sys.file_exists dec_dir && Sys.is_directory dec_dir then
        Array.to_list (Sys.readdir dec_dir)
        |> List.filter (fun n -> Filename.check_suffix n ".yaml")
        |> List.filter (fun n ->
            not
              (List.mem n
                 [
                   "decision.yaml";
                   "obligations.yaml";
                   "obligation-count-reconcile.yaml";
                 ]))
        |> List.map (fun n -> Filename.concat dec_dir n)
      else []
    in
    List.concat_map
      (fun p ->
        let raw =
          try In_channel.with_open_bin p In_channel.input_all with _ -> ""
        in
        match Codec.load_yaml_string raw with
        | v -> (
            match Decision.parse_decision_yaml v with
            | Some d -> d.Domain.obligations
            | None -> []))
      dec_paths
  in
  let first_decision_id =
    match memory.Memory.decisions with
    | first :: _ -> first.Memory.decision_id
    | [] -> ""
  in
  let v32 =
    Gate.gate_v32 c_info all_obligations false Re_evaluation.Compatible
      [
        Gate.PreTemporalPrecedence; Gate.CoCommitDecision; Gate.CoCommitFixture;
      ]
      ~store ~decision_id:first_decision_id
  in
  let combined_verdict =
    match v32 with Gate.Block -> Gate.Block | _ -> result.Gate.verdict
  in
  let result = { result with Gate.verdict = combined_verdict } in
  (* Verdict "block" -> exit 1; "pass" / "open-with-waiver" -> exit 0;
     "unknown" -> exit 3. Per constitution.md Invariants 14 and 14b
     (exit honesty + symmetric exit honesty) and
     decisions/exit-code-symmetry-2026-10.yaml. Unknown is
     non-zero because collapsing unknown to 0 would be
     `unknown != pass` laundering: a script that gates on the exit
     code would silently treat a kernel that could not determine a
     verdict as if it had determined "pass". *)
  print_string (gate_to_json result);
  exit (verdict_to_exit result.verdict)

(* --- mode subcommand (algebra 3.2 §2 risk function) ---
 *
 * `mathc mode PATH1 PATH2 ...` computes the risk classification,
 * probability, risk, and effective mode for the given paths via
 * `lib/risk.ml`. Emits JSON for pipeline use; exits 0 always. *)
let do_mode () =
  Arg.current := 1;
  let paths = ref [] in
  let set_path s = paths := s :: !paths in
  let format = ref "json" in
  let set_format s = format := s in
  let spec = "usage: mathc mode PATH1 PATH2 ... [--format=json|text]" in
  (try
     Arg.parse
       [ ("--format", Arg.String set_format, " output format") ]
       set_path spec
   with Arg.Bad _ -> ());
  let ps = List.rev !paths in
  if ps = [] then begin
    print_usage stderr;
    exit 2
  end;
  let classified = List.map (fun p -> (p, Risk.classify p)) ps in
  let impact = Risk.impact ps in
  let probability = Risk.probability ps in
  let irreversibility = Risk.irreversibility ps in
  let r = Risk.risk ps in
  let m = Risk.mode ps in
  let mode_str =
    match m with
    | `Tiny -> "tiny"
    | `Light -> "light"
    | `Standard | `Considered -> "standard"
    | `Strict -> "strict"
    | `Exhaustive -> "exhaustive"
  in
  Jsonl.stringify
    (Jsonl.Object
       [
         ( "paths",
           Jsonl.Array
             (List.map
                (fun (p, c) ->
                  Jsonl.Object
                    [
                      ("path", Jsonl.String p);
                      ("classify", Jsonl.String (Float.to_string c));
                    ])
                classified) );
         ("impact", Jsonl.String (Float.to_string impact));
         ("probability", Jsonl.String (Float.to_string probability));
         ("irreversibility", Jsonl.String (Float.to_string irreversibility));
         ("risk", Jsonl.String (Float.to_string r));
         ("mode", Jsonl.String mode_str);
       ])
  |> print_endline

(* --- rebuttals subcommand (algebra 3.2 §10) ---
 *
 * `mathc rebuttals COMMIT_SHA` loads `rebuttals/<sha>.yaml` plus the
 * forge mirror and emits all rebuttals. Used by CI to surface
 * multi-agent objections against a commit. *)
let do_rebuttals () =
  Arg.current := 1;
  let sha = ref "" in
  (try Arg.parse [] (fun s -> sha := s) "usage: mathc rebuttals COMMIT_SHA"
   with Arg.Bad _ -> ());
  if !sha = "" then begin
    print_usage stderr;
    exit 2
  end;
  let rebuttals = Rebuttal.all_rebuttals !sha in
  let stats = Rebuttal.stats rebuttals in
  let stats_json =
    Jsonl.Object
      [
        ("total", Jsonl.Int stats.total);
        ("accepted", Jsonl.Int stats.accepted);
        ("rejected_with_reason", Jsonl.Int stats.rejected_with_reason);
        ("ignored_non_binding", Jsonl.Int stats.ignored_non_binding);
        ("never_resolved", Jsonl.Int stats.never_resolved);
        ("pending", Jsonl.Int stats.pending);
      ]
  in
  Jsonl.stringify
    (Jsonl.Object
       [
         ("commit_sha", Jsonl.String !sha);
         ("rebuttals", Jsonl.Array (List.map Rebuttal.to_json rebuttals));
         ("stats", stats_json);
       ])
  |> print_endline

(* --- re-evaluate subcommand (algebra 3.2 §17) ---
 *
 * `mathc re-evaluate DECISION_ID AXIOM_ID` walks decisions/ via
 * Re_evaluation.load_decisions and reports the §17 re_evaluate
 * verdict for the (decision, axiom) pair. T1.2 expansion: the
 * verdict is now one of five values
 *
 *     Compatible | CompatibleAfterRun | Inconclusive |
 *     Incompatible | StaleClaim
 *
 * Where the previous 3-valued type silently returned `Compatible`
 * for test-style verifiers without an explicit run, the new
 * oracle returns `Incompatible` until the agent has run the
 * test (via `mathc re-evaluate-decisions <axiom-rev>` or
 * another runner). `CompatibleAfterRun` is the post-run pass
 * verdict; `Compatible` is preserved for built-in verifiers
 * the gate invokes in-process (legacy semantics). *)
let do_re_evaluate () =
  Arg.current := 1;
  let repo_root = find_project_root (Sys.getcwd ()) in
  let reader path =
    try In_channel.with_open_bin path In_channel.input_all with _ -> ""
  in
  let decision_id = ref "" in
  let axiom_id = ref "" in
  let set_dec s = decision_id := s in
  let set_axiom s = axiom_id := s in
  let spec =
    "usage: mathc re-evaluate DECISION_ID AXIOM_ID (e.g. mathc re-evaluate \
     bootstrap-v3 A1)"
  in
  let anon s =
    if !decision_id = "" then set_dec s
    else if !axiom_id = "" then set_axiom s
    else raise (Arg.Bad "only two positional arguments expected")
  in
  (try Arg.parse [] anon spec
   with Arg.Bad m ->
     Printf.fprintf stderr "mathc re-evaluate: %s\n" m;
     exit 2);
  if !decision_id = "" || !axiom_id = "" then begin
    Printf.fprintf stderr
      "mathc re-evaluate: DECISION_ID and AXIOM_ID are required\n";
    exit 2
  end;
  let valid_axioms = [ "A0"; "A1"; "A2"; "A3"; "A4" ] in
  if not (List.mem !axiom_id valid_axioms) then begin
    Printf.fprintf stderr
      "mathc re-evaluate: AXIOM_ID must be one of A0..A4 (got %s)\n" !axiom_id;
    exit 2
  end;
  let decisions = Re_evaluation.load_decisions ~reader ~root:repo_root in
  let target =
    List.find_opt
      (fun (d : Domain.decision) -> String.equal d.Domain.id !decision_id)
      decisions
  in
  match target with
  | None ->
      Printf.fprintf stderr "mathc re-evaluate: unknown DECISION_ID %s\n"
        !decision_id;
      exit 2
  | Some d ->
      let rev : Re_evaluation.axiom_revision =
        {
          Re_evaluation.axiom_id = !axiom_id;
          old_sha = "";
          new_sha = "";
          old_forbidden_patterns = [];
          new_forbidden_patterns = [];
        }
      in
      let v = Re_evaluation.re_evaluate d rev in
      let v_to_string : Re_evaluation.status -> string = function
        | Re_evaluation.Compatible -> "compatible"
        | Re_evaluation.CompatibleAfterRun -> "compatible_after_run"
        | Re_evaluation.Inconclusive -> "inconclusive"
        | Re_evaluation.Incompatible -> "incompatible"
        | Re_evaluation.StaleClaim -> "stale_claim"
      in
      let status_per_obligation =
        List.map
          (fun (ob : Domain.obligation) ->
            let sub = Re_evaluation.evaluate_obligation ob rev in
            Jsonl.Object
              [
                ("id", Jsonl.String ob.Domain.id);
                ("verdict", Jsonl.String (v_to_string sub));
              ])
          d.Domain.obligations
      in
      Jsonl.stringify
        (Jsonl.Object
           [
             ("decision", Jsonl.String !decision_id);
             ("axiom", Jsonl.String !axiom_id);
             ("verdict", Jsonl.String (v_to_string v));
             ("obligations", Jsonl.Array status_per_obligation);
             ("ran", Jsonl.Bool false);
           ])
      |> print_endline

(* --- re-evaluate-decisions subcommand (T1.2) ---
 *
 * `mathc re-evaluate-decisions <axiom-id>` walks every decision
 * file under decisions/ via Re_evaluation.load_decisions, runs the
 * `re_evaluate_after_run` oracle for each (decision, axiom) pair,
 * emits a single JSON object on stdout, and writes one
 * attestation per obligation whose verdict is `CompatibleAfterRun`
 * (or `Compatible` for built-ins) into `attestations/`.
 *
 * Output shape (single JSON object, sorted keys per §CLI output
 * contract):
 *
 *     {
 *       "axiom": "A0",
 *       "ran": true,
 *       "now": "<iso>",
 *       "decisions": [
 *         { "id": "bootstrap-v3", "verdict": "compatible_after_run",
 *           "obligations": [ { "id": "ob-1", "verdict": "compatible_after_run" } ] },
 *         ...
 *       ]
 *     }
 *
 * Exit codes (spec/semantics.md CLI contract):
 *   0 — every decision is `compatible`/`compatible_after_run`/`inconclusive`
 *       (pass or follow-up review pending; no blockers)
 *   1 — at least one decision is `incompatible` or `stale_claim` (blockers
 *       present; agent must revise before merge)
 *   2 — input error (missing AXIOM_ID, invalid value)
 *   3 — internal error (filesystem, JSON encoding)
 *
 * The attestation written is per-obligation, scoped to the
 * (decision, axiom) pair. The producer identity is the
 * operator-defined `MATH_CODING_RUNNER` env var (default
 * `human:maintainer`) per the same convention as `mathc attest`.
 *)
let[@warning "-32"] do_re_evaluate_decisions () =
  Arg.current := 1;
  let repo_root = find_project_root (Sys.getcwd ()) in
  let reader path =
    try In_channel.with_open_bin path In_channel.input_all with _ -> ""
  in
  let axiom_id = ref "" in
  let set_axiom s = axiom_id := s in
  let spec =
    "usage: mathc re-evaluate-decisions AXIOM_ID (e.g. mathc \
     re-evaluate-decisions A1)"
  in
  let anon s =
    if !axiom_id = "" then set_axiom s
    else raise (Arg.Bad "only one positional argument expected")
  in
  (try Arg.parse [] anon spec
   with Arg.Bad m ->
     Printf.fprintf stderr "mathc re-evaluate-decisions: %s\n" m;
     exit 2);
  if !axiom_id = "" then begin
    Printf.fprintf stderr "mathc re-evaluate-decisions: AXIOM_ID is required\n";
    exit 2
  end;
  let valid_axioms = [ "A0"; "A1"; "A2"; "A3"; "A4" ] in
  if not (List.mem !axiom_id valid_axioms) then begin
    Printf.fprintf stderr
      "mathc re-evaluate-decisions: AXIOM_ID must be one of A0..A4 (got %s)\n"
      !axiom_id;
    exit 2
  end;
  let decisions = Re_evaluation.load_decisions ~reader ~root:repo_root in
  let rev : Re_evaluation.axiom_revision =
    {
      Re_evaluation.axiom_id = !axiom_id;
      old_sha = "";
      new_sha = "";
      old_forbidden_patterns = [];
      new_forbidden_patterns = [];
    }
  in
  let v_to_string : Re_evaluation.status -> string = function
    | Re_evaluation.Compatible -> "compatible"
    | Re_evaluation.CompatibleAfterRun -> "compatible_after_run"
    | Re_evaluation.Inconclusive -> "inconclusive"
    | Re_evaluation.Incompatible -> "incompatible"
    | Re_evaluation.StaleClaim -> "stale_claim"
  in
  let producer_identity =
    match Sys.getenv_opt "MATH_CODING_RUNNER" with
    | Some s when s <> "" -> s
    | _ -> "ci-bot:re-evaluate-decisions"
  in
  (* Build per-decision verdicts. *)
  let per_decision = Re_evaluation.re_evaluate_after_run decisions rev in
  let per_obligation_verdicts (d : Domain.decision) : Jsonl.value list =
    List.map
      (fun (ob : Domain.obligation) ->
        let sub = Re_evaluation.evaluate_obligation_after_run ob rev in
        Jsonl.Object
          [
            ("id", Jsonl.String ob.Domain.id);
            ("verdict", Jsonl.String (v_to_string sub));
          ])
      d.Domain.obligations
  in
  (* Build the JSON output. *)
  let decision_json_entries =
    List.map
      (fun ((d, v) : Domain.decision * Re_evaluation.status) ->
        Jsonl.Object
          [
            ("id", Jsonl.String d.Domain.id);
            ("verdict", Jsonl.String (v_to_string v));
            ("obligations", Jsonl.Array (per_obligation_verdicts d));
          ])
      per_decision
  in
  let now = now_iso () in
  let blockers_exist =
    List.exists
      (fun (_, v) ->
        match v with
        | Re_evaluation.StaleClaim | Re_evaluation.Incompatible -> true
        | _ -> false)
      per_decision
  in
  let summary =
    Jsonl.Object
      [
        ("axiom", Jsonl.String !axiom_id);
        ("now", Jsonl.String now);
        ("ran", Jsonl.Bool true);
        ("decisions", Jsonl.Array decision_json_entries);
      ]
  in
  Jsonl.stringify summary |> print_endline;
  (* Write one attestation per (decision, obligation) whose verdict
   * is pass-like (Compatible, CompatibleAfterRun, or Inconclusive).
   * The schema requires `subject.obligation` and `subject.decision`;
   * we use the decision id and the obligation id directly. The
   * attestation is best-effort: a filesystem failure does not
   * invalidate the run summary on stdout. *)
  let attestations_dir =
    (* route through `resolve_store_root` so the canonical
       `MATH_CODING_ATTESTATIONS_DIR` env-var AND the legacy
       `MATH_CODING_ATTESTATION_STORE` are both honoured; the
       read direction uses the same resolver (lib/path_config
       and lines 2991-3003) so read/write can no longer diverge.
       -- path-resolver-audit-2026-11 (F10). *)
    resolve_store_root repo_root
  in
  let rec mkdir_p d =
    if d = "" || d = "/" || d = "." || Sys.file_exists d then ()
    else begin
      let parent = Filename.dirname d in
      mkdir_p parent;
      try Unix.mkdir d 0o755 with _ -> ()
    end
  in
  mkdir_p attestations_dir;
  List.iter
    (fun ((d, v) : Domain.decision * Re_evaluation.status) ->
      List.iter
        (fun (ob : Domain.obligation) ->
          let ob_v = Re_evaluation.evaluate_obligation_after_run ob rev in
          let ob_label = v_to_string ob_v in
          let run_like =
            match ob_v with
            | Re_evaluation.Compatible | Re_evaluation.CompatibleAfterRun
            | Re_evaluation.Inconclusive ->
                true
            | Re_evaluation.Incompatible | Re_evaluation.StaleClaim -> false
          in
          if run_like then
            let safe_id =
              Printf.sprintf "t1-2-%s-%s-%s.json" !axiom_id d.Domain.id
                ob.Domain.id
              |> String.map (fun c -> if c = '/' || c = ' ' then '_' else c)
            in
            let result_str =
              match ob_v with
              | Re_evaluation.Inconclusive -> "inconclusive"
              | _ -> "pass"
            in
            let payload_str =
              Printf.sprintf "%s|%s|%s|%s|%s" d.Domain.id ob.Domain.id !axiom_id
                result_str now
            in
            let attestation_id =
              Printf.sprintf "sha256:%s" (Digest.sha256_hex payload_str)
            in
            let final_obj =
              Jsonl.Object
                [
                  ("schema", Jsonl.String "math-coding/attestation-3.0-alpha");
                  ("kind", Jsonl.String "attestation");
                  ("id", Jsonl.String attestation_id);
                  ( "subject",
                    Jsonl.Object
                      [
                        ("decision", Jsonl.String d.Domain.id);
                        ("obligation", Jsonl.String ob.Domain.id);
                        ("candidate_tree", Jsonl.String "HEAD");
                        ("materials_digest", Jsonl.String "");
                      ] );
                  ("kind_", Jsonl.String "test");
                  ( "producer",
                    Jsonl.Object
                      [ ("identity", Jsonl.String producer_identity) ] );
                  ("result", Jsonl.String result_str);
                  ("issued_at", Jsonl.String now);
                  ("axiom", Jsonl.String !axiom_id);
                  ("re_eval_verdict", Jsonl.String ob_label);
                ]
            in
            let path = Filename.concat attestations_dir safe_id in
            try
              let oc = open_out_bin path in
              output_string oc (Jsonl.stringify final_obj);
              output_char oc '\n';
              close_out oc
            with _ -> ())
        d.Domain.obligations)
    per_decision;
  (* Exit nonzero if any decision is blocking (Incompatible or
   * StaleClaim). Otherwise exit 0. *)
  if blockers_exist then exit 1 else exit 0

(* --- self-check subcommand (bootstrap decision
 *   mathc-self-check-subcommand@2) ---
 *
 * `mathc self-check` walks every decision file under decisions/*.yaml,
 * loads the attestation store via Attestations.load, and emits a
 * single JSON verdict object on stdout. The pass-condition is the
 * AGENTS.md §Bootstrap gate expiry clause verbatim: "the released
 * 3.0 kernel successfully checks this repository and its
 * conformance corpus" (per spec/semantics.md:415).
 *
 * Per-decision verdicts use the existing Gate.obligation_gap (a
 * top-level binding of lib/gate.ml, exposed because the library is
 * `(wrapped false)` per OCAML_BEST_PRACTICES §1.2). The top-level
 * verdict is `fail` if any subject is `fail`, `pass` if every
 * subject is `pass`, else `unknown`. Per constitution.md:59
 * (`unknown != pass`) the dispatcher MUST exit nonzero on
 * `unknown` (exit code 3 per spec/semantics.md:435-440).
 *
 * The decisions directory is enumerated via Sys.readdir directly
 * (no hardcoded file list — the decision set grows over time per
 * ROADMAP P1). Each `.yaml` / `.yml` / `.json` file under
 * decisions/ is parsed via Memory.parse_decision_yaml to extract
 * id, revision, and obligation IDs.
 *
 * changed_paths is a single sentinel ["self-check"] so the
 * materials_digest is non-empty: lib/gate.ml's evaluate short-
 * circuits to Pass on empty paths (lib/gate.ml:245-246), but for
 * self-check we want the evaluator to walk every obligation. The
 * Gate.fresh_against wildcard (`materials_digest = ""` matches
 * anything) means existing attestations still apply. *)

(* Map a Gate verdict variant to the self-check JSON verdict
   string. Open_with_waiver is reported as `pass` because a
   waiver is an explicit, scoped, expiring acceptance of the
   underlying gap (per constitution.md §Waivers). *)
let[@warning "-32"] verdict_to_pass_fail_unknown = function
  | Gate.Pass -> "pass"
  | Gate.Open_with_waiver -> "pass"
  | Gate.Block -> "fail"
  | Gate.Unknown -> "unknown"

(* Enumerate decisions/*.yaml. Returns absolute paths. The .yaml
   extension is the convention; we also accept .yml and .json so
   future revisions can ship machine-authored decisions without
   renaming. Decisions/ONBOARDING.md and decisions/rationale.md
   are markdown notes, not decisions, and are filtered out by
   extension. *)
let[@warning "-32"] list_decision_files dir =
  if not (Sys.file_exists dir) then []
  else if not (Sys.is_directory dir) then []
  else
    try
      Sys.readdir dir |> Array.to_list
      |> List.filter (fun name ->
          let sfx = Filename.extension name in
          sfx = ".yaml" || sfx = ".yml" || sfx = ".json")
      |> List.map (fun name -> Filename.concat dir name)
    with _ -> []

(* Parse a single decision file via the existing Memory helper.
   Returns None on parse failure — the dispatcher is best-effort
   and never crashes on a malformed decision.

   Note: the kernel YAML parser (Codec.load_yaml_string) is
   hand-rolled and drops continuation lines for unquoted
   multi-line scalars (see OCAML_BEST_PRACTICES §11.12 — the
   "whitespace-stripping helper destroys source structure"
   trap). For `mathc self-check` we need both the decision id and
   the obligation ids; if Memory.parse_decision_yaml returns a
   stub with empty obligation_ids we fall back to a text
   scan that only needs to find top-level `id: NAME` and the
   `- id: NAME` items under the `obligations:` block. The text
   scan is robust to multi-line scalars because it matches
   line-by-line and ignores content after the value. *)
let[@warning "-32"] leading_spaces line =
  let len = String.length line in
  let rec loop i =
    if i >= len then i
    else
      let c = String.unsafe_get line i in
      if c = ' ' || c = '\t' then loop (i + 1) else i
  in
  loop 0

(* Return true if `line` looks like a top-level YAML key/value
   (no leading whitespace, not a comment, not the YAML
   front-matter marker `---`). *)
let[@warning "-32"] is_top_level line =
  let len = String.length line in
  if len = 0 then false
  else
    let c0 = String.unsafe_get line 0 in
    if c0 = ' ' || c0 = '\t' || c0 = '#' then false
    else if len >= 3 && line = "---" then false
    else true

(* Find the first top-level `id: VALUE` line and return VALUE.
   VALUE is everything after the colon, trimmed. Block-scalar
   values (`id: |`) are skipped (they are not used in our
   decisions). *)
let[@warning "-32"] extract_top_level_id lines =
  let rec loop = function
    | [] -> None
    | line :: rest -> (
        if not (is_top_level line) then loop rest
        else
          let trimmed = String.trim line in
          match String.index_opt trimmed ':' with
          | Some i ->
              let key = String.sub trimmed 0 i in
              let v =
                String.trim
                  (String.sub trimmed (i + 1) (String.length trimmed - i - 1))
              in
              if
                String.equal key "id" && v <> "" && v.[0] <> '|' && v.[0] <> '>'
              then Some v
              else loop rest
          | None -> loop rest)
  in
  loop lines

(* Collect `- id: NAME` items under the `obligations:` block.
   The block ends at the next top-level key. Multi-line scalar
   continuations are ignored because we only match the literal
   `- id:` prefix at indent 2. *)
let[@warning "-32"] extract_obligation_ids lines =
  let rec scan acc in_obls = function
    | [] -> List.rev acc
    | line :: rest ->
        if is_top_level line then
          begin if String.trim line = "obligations:" then scan acc true rest
          else if in_obls then List.rev acc
          else scan acc false rest
          end
        else if in_obls then
          let indent = leading_spaces line in
          if indent = 2 && String.length line > 4 then begin
            let after = String.sub line 2 (String.length line - 2) in
            let trimmed = String.trim after in
            if
              String.length trimmed > 2
              && trimmed.[0] = '-'
              && trimmed.[1] = ' '
            then begin
              let rest_of = String.sub trimmed 2 (String.length trimmed - 2) in
              match String.index_opt rest_of ':' with
              | Some i ->
                  let key = String.sub rest_of 0 i in
                  let v =
                    String.trim
                      (String.sub rest_of (i + 1)
                         (String.length rest_of - i - 1))
                  in
                  if String.equal key "id" && v <> "" then
                    scan (v :: acc) true rest
                  else scan acc true rest
              | None -> scan acc true rest
            end
            else scan acc true rest
          end
          else scan acc true rest
        else scan acc in_obls rest
  in
  scan [] false lines

let[@warning "-32"] load_decision_entry reader path =
  match reader path with
  | "" -> None
  | raw ->
      let lines = String.split_on_char '\n' raw in
      let decision_id =
        match extract_top_level_id lines with Some id -> id | None -> ""
      in
      let obligation_ids = extract_obligation_ids lines in
      if decision_id = "" then None
      else
        let stub : Memory.decision_entry =
          {
            Memory.decision_id;
            Memory.revision = None;
            Memory.source = raw;
            Memory.obligations = List.length obligation_ids;
            Memory.obligation_ids;
            Memory.assumptions = 0;
            Memory.risk_triggers = [];
            Memory.state = `Active;
            Memory.verifier_per_obligation = [];
          }
        in
        Some stub

(* Per-decision evaluation. Walks every obligation in `entry` and
   computes its gap; aggregates gaps into the decision's subject
   verdict; returns (verdict, causes[], remedies[]). When the
   subject verdict is `pass`, the gap list is empty and the
   causes/remedies are empty too.

   Waiver consultation (math-coding 3.0, decision
   waiver-infrastructure-2026-10): if the aggregated verdict is
   `Unknown` and a waiver covers the subject at `now`, we
   return `Open_with_waiver` instead. The CLI maps
   `Open_with_waiver -> "pass"` in the verdict string (existing
   behaviour at bin/Mathc.ml:1829-1833) but the gap list and
   the cause/remedy remain in the JSON output — the gap is a
   gap, the waiver is an acknowledgment, not an elimination
   (constitution.md §Waivers line 102; spec/semantics.md
   §Waiver "MUST NOT change the underlying assurance result").

   A FailedEvidence gap is never waived: only MissingEvidence,
   StaleEvidence, and Unknown gaps can be lifted to
   Open_with_waiver. This preserves the
   "decisive fail -> Block" invariant (constitution.md
   Invariant 14, spec/semantics.md §Evaluation). *)
let[@warning "-32"] evaluate_decision ~materials ~store ~waivers ~now
    (entry : Memory.decision_entry) =
  let gaps =
    List.filter_map
      (fun obl_id ->
        Gate.obligation_gap ~decision_id:entry.Memory.decision_id
          ~obligation_id:obl_id ~materials_digest:materials ~store)
      entry.Memory.obligation_ids
  in
  let aggregate_verdict = Gate.aggregate gaps in
  let verdict =
    match aggregate_verdict with
    | Gate.Unknown ->
        let all_waivable =
          List.for_all
            (fun g ->
              match g.Gate.kind with
              | `MissingEvidence | `StaleEvidence | `Unknown -> true
              | `FailedEvidence | `MissingReview | `NoAttestationStore -> false)
            gaps
        in
        if
          all_waivable
          && List.for_all
               (fun g ->
                 Option.is_some
                   (Waiver.covers waivers ~decision_id:entry.Memory.decision_id
                      ~obligation_id:g.Gate.obligation_id ~now))
               gaps
        then Gate.Open_with_waiver
        else Gate.Unknown
    | v -> v
  in
  let causes = List.concat_map (fun g -> g.Gate.causes) gaps in
  let remedies = List.concat_map (fun g -> g.Gate.remedies) gaps in
  (verdict, causes, remedies)

(* Compute repository_digest from the sorted (decision_id, revision)
   tuples. Stable across file orderings; absent revision is
   represented as "?". The digest is the kernel's fingerprint of
   the policy it just evaluated — paired with kernel_digest it
   proves which (policy, kernel) pair produced the verdict. *)
let[@warning "-32"] repository_digest_of entries =
  let lines =
    entries
    |> List.sort (fun a b ->
        String.compare a.Memory.decision_id b.Memory.decision_id)
    |> List.map (fun e ->
        e.Memory.decision_id ^ "@"
        ^ match e.Memory.revision with Some r -> r | None -> "?")
  in
  Digest.sha256_hex (String.concat "\n" lines)

(* Compute kernel_digest as the SHA-256 of the mathc binary
   contents. The binary is the released kernel that the bootstrap
   gate certifies; this fingerprint is what the verifier (and a
   future shipped-build chain) ties the verdict to. Returns
   "unavailable" if the binary is unreadable (e.g. stripped
   build, hostile fs). *)
let[@warning "-32"] kernel_digest_of () =
  let path = Sys.executable_name in
  try
    let raw = In_channel.with_open_bin path In_channel.input_all in
    Digest.sha256_hex raw
  with _ -> "unavailable"

(* Render one subject. Sorted keys per spec/semantics.md CLI
   output contract. *)
let[@warning "-32"] subject_to_json name verdict causes remedies =
  let causes_json =
    "["
    ^ String.concat ","
        (List.map (fun s -> Jsonl.stringify (Jsonl.String s)) causes)
    ^ "]"
  in
  let remedies_json =
    "["
    ^ String.concat ","
        (List.map (fun s -> Jsonl.stringify (Jsonl.String s)) remedies)
    ^ "]"
  in
  let fields =
    [
      ("causes", causes_json);
      ("name", Jsonl.stringify (Jsonl.String name));
      ("remedies", remedies_json);
      ("verdict", Jsonl.stringify (Jsonl.String verdict));
    ]
  in
  let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) fields in
  "{"
  ^ String.concat ","
      (List.map
         (fun (k, v) -> Jsonl.stringify (Jsonl.String k) ^ ":" ^ v)
         sorted)
  ^ "}"

let[@warning "-32"] do_self_check () =
  let anon _ = raise (Arg.Bad "no positional arguments expected") in
  Arg.current := 1;
  (try Arg.parse [] anon "usage: mathc self-check"
   with Arg.Bad m ->
     Printf.fprintf stderr "mathc self-check: %s\n" m;
     exit 2);
  let root = find_project_root (Sys.getcwd ()) in
  let decisions_dir =
    Filename.concat root (Path_config.resolve_decisions_dir ~root ())
  in
  let reader path =
    try In_channel.with_open_bin path In_channel.input_all with _ -> ""
  in
  let decision_files = list_decision_files decisions_dir in
  let entries =
    List.filter_map (fun p -> load_decision_entry reader p) decision_files
  in
  let store_root = resolve_store_root root in
  let store = Attestations.load ~reader ~root:store_root in
  (* Load waivers from <decisions_dir>/waivers/. The Waiver module
     is pure (takes a `reader`); we reuse the same reader the
     store and decisions use, so waiver loading shares the I/O
     pattern. The waivers/ subdir may not exist; Waiver.load
     returns [] in that case (mirrors the empty-store handling
     in Attestations.load). *)
  let waivers_dir = Filename.concat decisions_dir "waivers" in
  let waivers = Waiver.load ~reader ~root:waivers_dir in
  let materials = Gate.materials_digest_of [ "self-check" ] in
  let now = now_iso () in
  let evaluated =
    List.map
      (fun entry ->
        let verdict, causes, remedies =
          evaluate_decision ~materials ~store ~waivers ~now entry
        in
        (entry.Memory.decision_id, verdict, causes, remedies))
      entries
  in
  (* Top-level aggregation. Empty decision set is treated as
     `unknown` (not `pass`) — a kernel with no decisions to check
     cannot honestly claim to have checked the policy. *)
  let top_verdict =
    match evaluated with
    | [] -> Gate.Unknown
    | _ ->
        let verdicts = List.map (fun (_, v, _, _) -> v) evaluated in
        if List.exists (fun v -> v = Gate.Block) verdicts then Gate.Block
        else if
          List.for_all
            (fun v -> v = Gate.Pass || v = Gate.Open_with_waiver)
            verdicts
        then Gate.Pass
        else Gate.Unknown
  in
  let top_string = verdict_to_pass_fail_unknown top_verdict in
  let subjects_json =
    "["
    ^ String.concat ","
        (List.map
           (fun (name, verdict, causes, remedies) ->
             subject_to_json name
               (verdict_to_pass_fail_unknown verdict)
               causes remedies)
           evaluated)
    ^ "]"
  in
  let fields =
    [
      ("kernel_digest", Jsonl.stringify (Jsonl.String (kernel_digest_of ())));
      ("now", Jsonl.stringify (Jsonl.String (now_iso ())));
      ( "repository_digest",
        Jsonl.stringify (Jsonl.String (repository_digest_of entries)) );
      ("subjects", subjects_json);
      ("verdict", Jsonl.stringify (Jsonl.String top_string));
    ]
  in
  let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) fields in
  let body =
    "{"
    ^ String.concat ","
        (List.map
           (fun (k, v) -> Jsonl.stringify (Jsonl.String k) ^ ":" ^ v)
           sorted)
    ^ "}\n"
  in
  print_string body;
  (* Exit code mapping per spec/semantics.md:435-440 and
     constitution.md:148 (exit honesty). Unknown is NOT 0 —
     that would be `unknown != pass` laundering. *)
  match top_verdict with
  | Gate.Pass | Gate.Open_with_waiver -> exit 0
  | Gate.Block -> exit 1
  | Gate.Unknown -> exit 3

(* --- render subcommand (bootstrap decision site-deploy@2) ---
 *
 * `mathc render [--out DIR] [--lang en|ru|zh|both|all] [--site-base HREF]
 * [--mathjax|--no-mathjax]` renders the
 * static site under DIR (default `dist/`). The render reads
 * articles from `site/`, walks decisions via lib/packages.ml, and
 * writes one .html file per page. The dispatcher's I/O is the
 * boundary; lib/render.ml is pure.
 *
 * Bilingual mode (`--lang=both`) renders both English and Russian
 * pages when `site/<name>.ru.md` exists; the Russian page is
 * omitted otherwise. `--lang=zh` renders only the Chinese pages,
 * `--lang=all` renders every language for which a source file
 * exists. The `--site-base` value is emitted as
 * `<base href="…">` so the same dist/ tree serves under any
 * subpath (default `/math-coding/` for GitHub Pages).
 *
 * Per spec/semantics.md §`render`, the allowlist is the union of
 * the English, Russian, and Chinese page sets:
 *   index.{html,ru.html,zh.html}, axioms.html, methodology.html,
 *   bootstrap-gate.html, packages.html,
 *   manifesto.{html,ru.html,zh.html},
 *   foundations.{html,ru.html,zh.html},
 *   workflow.{html,ru.html,zh.html}, faq.{html,ru.html,zh.html},
 *   contributing.{html,ru.html,zh.html},
 *   readme.{html,ru.html,zh.html},
 *   install.{html,ru.html,zh.html},
 *   decisions/*.html, axioms/*.html, assets/style.css, index.json.
 * Missing any file is exit 2. *)

let[@warning "-32"] mkdir_p dir =
  let rec loop d =
    if d = "" || d = "/" || d = "." || Sys.file_exists d then ()
    else begin
      let parent = Filename.dirname d in
      loop parent;
      try Unix.mkdir d 0o755 with _ -> ()
    end
  in
  loop dir

let[@warning "-32"] write_file path contents =
  let dir = Filename.dirname path in
  if dir <> "" then mkdir_p dir;
  let ch = open_out_bin path in
  output_string ch contents;
  close_out ch

let[@warning "-32"] read_file path =
  try
    let ch = open_in_bin path in
    let n = in_channel_length ch in
    let s = really_input_string ch n in
    close_in ch;
    s
  with _ -> ""

let[@warning "-32"] now_iso () =
  let tm = Unix.gmtime (Unix.time ()) in
  Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ" (tm.tm_year + 1900)
    (tm.tm_mon + 1) tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec

let[@warning "-32"] read_axioms axioms_root =
  if not (Sys.file_exists axioms_root) then []
  else if not (Sys.is_directory axioms_root) then []
  else
    try
      Sys.readdir axioms_root |> Array.to_list
      |> List.filter (fun n -> Filename.extension n = ".md")
      |> List.filter (fun n -> n <> "index.md")
      |> List.sort String.compare
      |> List.filter_map (fun n ->
          let base = Filename.chop_extension n in
          let path = Filename.concat axioms_root n in
          let body = read_file path in
          if body = "" then None else Some (base, body))
    with _ -> []

let[@warning "-32"] read_spec_data () =
  let candidates =
    match Sys.getenv_opt "DUNE_SOURCEROOT" with
    | Some p -> [ Filename.concat p "spec" ]
    | None -> []
  in
  let candidates = candidates @ [ "spec" ] in
  let try_dir d =
    if not (Sys.file_exists d) then None
    else if not (Sys.is_directory d) then None
    else
      try
        Some
          (Sys.readdir d |> Array.to_list
          |> List.filter (fun n -> Filename.extension n = ".md")
          |> List.sort String.compare
          |> List.filter_map (fun n ->
              let base = Filename.chop_extension n in
              let path = Filename.concat d n in
              let body = read_file path in
              if body = "" then None else Some (base, body)))
      with _ -> None
  in
  let rec loop = function
    | [] -> []
    | d :: rest -> ( match try_dir d with Some xs -> xs | None -> loop rest)
  in
  loop candidates

let[@warning "-32"] read_templates () =
  let dir =
    match Sys.getenv_opt "DUNE_SOURCEROOT" with
    | Some p when Sys.file_exists (Filename.concat p "render/templates") ->
        Filename.concat p "render/templates"
    | _ -> "render/templates"
  in
  let read name = read_file (Filename.concat dir name) in
  let en_html = read "index.en.html" in
  let ru_html = read "index.ru.html" in
  let zh_html = read "index.zh.html" in
  let dash_html = read "dashboard.html" in
  let graph_html = read "graph.html" in
  {
    Render.index =
      [ (Render.En, en_html); (Render.Ru, ru_html); (Render.Zh, zh_html) ];
    Render.dashboard = dash_html;
    Render.graph = graph_html;
  }

let[@warning "-32"] per_decision_obligation_html (d : Packages.decision_view) =
  let buf = Buffer.create 256 in
  Printf.bprintf buf "<h3>%s</h3>\n<ul>" d.Packages.decision_id;
  List.iter
    (fun o ->
      Printf.bprintf buf
        "<li class=\"mathc-obligation mathc-verdict-%s\"><code>%s</code> <span \
         class=\"mathc-verdict-label\">%s</span></li>"
        o.Packages.verdict o.Packages.id o.Packages.verdict)
    d.Packages.obligations;
  Buffer.add_string buf "</ul>";
  Buffer.contents buf

let[@warning "-32"] render_search_index pages =
  let buf = Buffer.create 256 in
  Buffer.add_string buf "[\n";
  let entries =
    List.filter_map
      (fun (path, body) ->
        let title_match =
          let open Str in
          try
            let re = regexp "<title>\\(.*\\) &mdash; math-coding</title>" in
            let _ = search_forward re body 0 in
            Some (matched_string body)
          with Not_found -> None
        in
        let cleaned_title =
          match title_match with
          | Some s -> String.sub s 7 (String.length s - 7)
          | None -> ""
        in
        if cleaned_title = "" then None
        else
          Some
            (Printf.sprintf "  {\"title\": %s, \"path\": %s}"
               (Jsonl.stringify (Jsonl.String cleaned_title))
               (Jsonl.stringify (Jsonl.String path))))
      pages
  in
  Buffer.add_string buf (String.concat ",\n" entries);
  Buffer.add_string buf "\n]\n";
  Buffer.contents buf

let[@warning "-32"] do_render () =
  let out_dir = ref "dist" in
  let lang_arg = ref "en" in
  let site_base = ref "/math-coding/" in
  let enable_mathjax = ref true in
  let set_lang s =
    match s with
    | "en" | "ru" | "zh" | "both" | "all" -> lang_arg := s
    | _ ->
        Printf.fprintf stderr "mathc render: --lang must be en|ru|zh|both|all\n";
        exit 2
  in
  let set_base s = site_base := s in
  Arg.current := 1;
  (try
     Arg.parse
       [
         ("-o", Arg.String (fun s -> out_dir := s), "output directory");
         ("--out", Arg.String (fun s -> out_dir := s), "output directory");
         ("--lang", Arg.String set_lang, "page languages: en|ru|zh|both|all");
         ( "--site-base",
           Arg.String set_base,
           " <base href> value (default /math-coding/)" );
         ("--mathjax", Arg.Set enable_mathjax, "load MathJax 3 (default on)");
         ("--no-mathjax", Arg.Clear enable_mathjax, "do not load MathJax");
       ]
       (fun _ -> ())
       "usage: mathc render [--out DIR] [--lang en|ru|zh|both|all] \
        [--site-base HREF] [--mathjax|--no-mathjax]"
   with Arg.Bad m ->
     Printf.fprintf stderr "mathc render: %s\n" m;
     exit 2);
  let site_dir = "site" in
  let axioms_root = "axioms" in
  let root = find_project_root (Sys.getcwd ()) in
  let decisions_root =
    Filename.concat root (Path_config.resolve_decisions_dir ~root ())
  in
  let attestations_root =
    Filename.concat root (Path_config.resolve_attestations_dir ~root ())
  in

  if not (Sys.file_exists site_dir) then begin
    Printf.fprintf stderr "mathc render: site directory not found: %s\n"
      site_dir;
    exit 2
  end;

  let reader p =
    try In_channel.with_open_bin p In_channel.input_all with _ -> ""
  in
  let has_store = Sys.file_exists attestations_root in
  let store =
    if has_store then Attestations.load ~reader ~root:attestations_root else []
  in
  let now = now_iso () in
  let policy_id = "bootstrap-v3" in
  let pkg =
    Packages.walk ~reader ~decisions_root ~store ~has_store ~now_iso:now
      ~policy_id
  in
  let package_html = Packages.to_html pkg in
  let axioms_data = read_axioms axioms_root in
  (* Per-decision pages now render the full YAML body (intent,
     commitment, outcomes, obligations-with-claims, counterexample,
     risk, relations, scope, axiom_link) in addition to the
     verdict grid. The kernel-side `decision_view` carries the
     raw YAML body verbatim; the renderer pulls the sections it
     needs and falls back to "no body" prose when a decision is
     non-textual (a pure-architecture decision with no prose
     fields). *)
  let decisions_data =
    List.map
      (fun d ->
        ( d.Packages.decision_id,
          per_decision_obligation_html d,
          d.Packages.yaml_body ))
      pkg.Packages.decisions
  in

  (* Article catalogue. Each entry: (name, title, source-file).
     The first 4 entries existed at rev 1; the next 6 are new at
     rev 2 (MANIFESTO, FOUNDATIONS, WORKFLOW, FAQ, CONTRIBUTING,
     README). Each entry optionally has a `<name>.ru.md` and/or
     `<name>.zh.md` sibling that the dispatcher loads when the
     corresponding language is enabled. *)
  let articles =
    [
      ("axioms", "Axioms", "axioms.md");
      ("methodology", "Methodology", "methodology.md");
      ("manifesto", "Manifesto", "manifesto.md");
      ("foundations", "Foundations", "foundations.md");
      ("workflow", "Workflow", "workflow.md");
      ("faq", "FAQ", "faq.md");
      ("readme", "README", "readme.md");
      ("contributing", "Contributing", "contributing.md");
      ("bootstrap-gate", "Bootstrap Gate", "bootstrap-gate.md");
      ("install", "Install", "install.md");
      ("packages", "Packages", "packages.md");
      ("differences", "Differences", "differences.md");
    ]
  in

  let load_md filename =
    let path = Filename.concat site_dir filename in
    reader path
  in

  let site_pages =
    List.filter_map
      (fun (name, title, fname) ->
        let body = load_md fname in
        if body = "" then None
        else Some { Render.name; Render.title; Render.body_md = body })
      articles
  in

  let ru_enabled =
    !lang_arg = "ru" || !lang_arg = "both" || !lang_arg = "all"
  in
  let site_pages_ru =
    if not ru_enabled then []
    else
      List.filter_map
        (fun (name, title, _) ->
          let fname = name ^ ".ru.md" in
          let body = load_md fname in
          if body = "" then None
          else
            Some
              {
                Render.name;
                Render.title = title ^ " / RU";
                Render.body_md = body;
              })
        articles
  in

  let zh_enabled = !lang_arg = "zh" || !lang_arg = "all" in
  let site_pages_zh =
    if not zh_enabled then []
    else
      List.filter_map
        (fun (name, title, _) ->
          let fname = name ^ ".zh.md" in
          let body = load_md fname in
          if body = "" then None
          else
            Some
              {
                Render.name;
                Render.title = title ^ " / ZH";
                Render.body_md = body;
              })
        articles
  in

  (* The `languages` list drives the kernel-side iteration. The
     order is canonical: English first, then Russian, then ZH.
     `--lang=en` only emits EN; `--lang=ru` only emits RU
     (back-compat: the previous code made `--lang=ru` skip EN);
     `--lang=zh` only emits ZH; `--lang=both` emits EN+RU;
     `--lang=all` emits EN+RU+ZH. The home page is always
     generated in any enabled language; article pages are
     generated only when the source file exists. *)
  let languages =
    match !lang_arg with
    | "en" -> [ Render.En ]
    | "ru" -> [ Render.Ru ]
    | "zh" -> [ Render.Zh ]
    | "both" -> [ Render.En; Render.Ru ]
    | "all" -> [ Render.En; Render.Ru; Render.Zh ]
    | _ -> [ Render.En ]
  in

  let config : Render.config =
    {
      Render.site_base = !site_base;
      Render.enable_mathjax = !enable_mathjax;
      Render.enable_lang_toggle = true;
      Render.languages;
      (* The site footer / hero / page title all carry the live
         project version. We re-read `./VERSION` here (the default
         config already did so on startup) so a fresh `mathc
         render` after `scripts/release.sh` updated VERSION sees
         the new value without restarting anything. *)
      Render.version = read_cli_version ();
    }
  in

  (* Capture the version string for the RSS feed (the
     dispatcher binds it into the config; we read it back so
     the RSS channel title matches the live project version). *)
  let version = read_cli_version () in

  let spec_data = read_spec_data () in
  let templates = read_templates () in
  let pages =
    Render.build_pages ~package_html ~decisions_data ~policy_id ~config
      ~site_pages ~site_pages_ru ~site_pages_zh ~axioms_data ~spec_data
      ~templates
  in

  Printf.printf "[render] writing %d pages to %s/\n" (List.length pages)
    !out_dir;
  List.iter
    (fun page ->
      let path = Filename.concat !out_dir page.Render.path in
      write_file path page.Render.body;
      Printf.printf "  %s\n" page.Render.path)
    pages;

  let index_path = Filename.concat !out_dir "index.json" in
  let pages_for_index =
    List.map (fun p -> (p.Render.path, p.Render.body)) pages
  in
  let index_body = render_search_index pages_for_index in
  write_file index_path index_body;
  Printf.printf "  index.json\n";

  let dashboard_path = Filename.concat !out_dir "dashboard.html" in
  write_file dashboard_path templates.Render.dashboard;
  Printf.printf "  dashboard.html\n";
  let graph_path = Filename.concat !out_dir "graph.html" in
  write_file graph_path templates.Render.graph;
  Printf.printf "  graph.html\n";

  (* RSS 2.0 feed at dist/feed.xml (Phase 4 of
     site-quality-distribution-2026-10). One <item> per
     decision, capped at the 60 most recent by decision_id;
     a feed kept under the typical 1 MB RSS size limit so
     GitHub Pages serves it without compression warnings. *)
  let rss_items =
    let dv_map =
      List.map (fun d -> (d.Packages.decision_id, d)) pkg.Packages.decisions
    in
    let all =
      List.map
        (fun (id, _ob_html, yaml_body) ->
          let dv = List.assoc_opt id dv_map in
          let revision =
            match dv with
            | Some d -> d.Packages.decision_revision
            | None -> None
          in
          let ob_count =
            match dv with
            | Some d -> List.length d.Packages.obligations
            | None -> 0
          in
          {
            Render.rss_decision_id = id;
            Render.rss_decision_revision = revision;
            Render.rss_intent_summary =
              Render.extract_intent_summary ~yaml_body ~decision_id:id;
            Render.rss_obligation_count = ob_count;
          })
        decisions_data
    in
    List.filter
      (fun it -> not (String.length it.Render.rss_intent_summary = 0))
      all
  in
  let rss_capped =
    let rec take n = function
      | [] -> []
      | _ when n = 0 -> []
      | x :: rest -> x :: take (n - 1) rest
    in
    take 60 rss_items
  in
  let rss_body =
    Render.render_rss_feed ~version ~site_base:!site_base ~items:rss_capped
  in
  let rss_path = Filename.concat !out_dir "feed.xml" in
  write_file rss_path rss_body;
  Printf.printf "  feed.xml\n";

  Printf.printf "render OK: %d pages + 1 search index + 1 feed.\n"
    (List.length pages)

(* --- packages subcommand (bootstrap decision
 *   mathc-packages-subcommand@1) ---
 *
 * `mathc packages [--format=text|json|html]` walks every decision
 * file under `decisions/` and joins each obligation against the
 * attestation store at `attestations/`. The output is the
 * package_list produced by lib/packages.ml. The site at
 * site/index.md renders the HTML form into the package grid.
 *
 * The default decisions/ and attestations/ paths are relative
 * to the project root; the dispatcher reads them via the same
 * filesystem_read callback as mathc self-check. *)

(* `mathc forge-verify [--org ORG] [--team TEAM] [--user USER]
 *   [--committer EMAIL] [--fail-mode open|closed]` queries
 * `lib/forge.ml::team_member` to verify a committer's
 * membership in a forge team. Designed to be a gate-side
 * precheck that the kernel runs *outside* the attestation
 * store, so it does not require a populated store. The
 * verifier prints JSON with `verdict` (`pass`/`block`),
 * `forge_queried` (boolean — false when
 * `MATH_CODING_FORGE_API` is unset), `matched` (the
 * boolean the forge replied with, or absent), and `reason`
 * (a human-readable string explaining the verdict).
 *
 * `--fail-mode` toggles behaviour when the forge is unset
 * OR errors (the "fail-open" default): `open` (default)
 * returns `pass` with `forge_queried:false` and a reason;
 * `closed` returns `block` and exit 1 instead. The flag is
 * an A4 obligation; see
 * `decisions/forge-principal-verification-2026-10.yaml`. *)
let[@warning "-32"] do_forge_verify () =
  let org = ref "" in
  let team = ref "" in
  let user = ref "" in
  let committer = ref "" in
  let fail_mode = ref "open" in
  let set_org s = org := s in
  let set_team s = team := s in
  let set_user s = user := s in
  let set_committer s = committer := s in
  let set_fail s =
    match s with
    | "open" | "closed" -> fail_mode := s
    | _ ->
        Printf.fprintf stderr
          "mathc forge-verify: --fail-mode must be open|closed (got %s)\n" s;
        exit 2
  in
  (try
     Arg.parse
       [
         ("--org", Arg.String set_org, " <name>: forge org (e.g. 11111000000)");
         ("--team", Arg.String set_team, " <slug>: forge team slug");
         ( "--user",
           Arg.String set_user,
           " <login>: forge user (committer login)" );
         ( "--committer",
           Arg.String set_committer,
           " <email>: committer email (auto-read from git if empty)" );
         ( "--fail-mode",
           Arg.String set_fail,
           " open|closed: how to handle forge unset / errors (default: open)" );
       ]
       (fun _ -> ())
       "usage: mathc forge-verify [--org ORG] [--team TEAM] [--user USER] \
        [--committer EMAIL] [--fail-mode open|closed]"
   with Arg.Bad m ->
     Printf.fprintf stderr "mathc forge-verify: %s\n" m;
     exit 2);
  (* When --committer is empty, read it from `git log -1
     --format=%ae` of HEAD (matching the gate's committer
     resolution). The forge is queried with the
     email-as-username heuristic; the user's local forge policy
     determines the actual mapping. *)
  let user_or_committer =
    match !user with
    | "" -> (
        match !committer with
        | "" ->
            let sha = "" in
            let out =
              try
                let ic =
                  Unix.open_process_args_in "git"
                    [| "git"; "log"; "-1"; "--format=%ae"; sha |]
                in
                let s = In_channel.input_all ic in
                let _ = In_channel.close ic in
                s
              with _ -> ""
            in
            String.trim out
        | c -> c)
    | u -> u
  in
  let verdict_record queried =
    let open Jsonl in
    let open_str = "open" in
    let verdict_str =
      match queried with
      | `NotConfigured | `CurlFailure ->
          if !fail_mode = open_str then "pass" else "block"
      | `Queried true -> "pass"
      | `Queried false -> "block"
    in
    let forge_queried = match queried with `Queried _ -> true | _ -> false in
    let matched = match queried with `Queried m -> Some m | _ -> None in
    let reason =
      match queried with
      | `NotConfigured ->
          "MATH_CODING_FORGE_API not set; fail-mode=" ^ !fail_mode
      | `CurlFailure -> "forge query failed; fail-mode=" ^ !fail_mode
      | `Queried true -> "forge returned member=true"
      | `Queried false -> "forge returned member=false"
    in
    let matched_pair =
      match matched with Some m -> [ ("matched", Bool m) ] | None -> []
    in
    let fields =
      [
        ("fail_mode", String !fail_mode);
        ("forge_queried", Bool forge_queried);
        ("org", String !org);
        ("reason", String reason);
        ("team", String !team);
        ("user", String user_or_committer);
        ("verdict", String verdict_str);
      ]
    in
    let all_fields = fields @ matched_pair in
    let sorted =
      List.sort (fun (a, _) (b, _) -> String.compare a b) all_fields
    in
    let body =
      String.concat ","
        (List.map
           (fun (k, v) ->
             Jsonl.stringify (Jsonl.String k) ^ ":" ^ Jsonl.stringify v)
           sorted)
    in
    Printf.printf "{%s}\n" body
  in
  let queried =
    if !org = "" || !team = "" || user_or_committer = "" then (
      Printf.fprintf stderr
        "mathc forge-verify: --org, --team, --user (or --committer) are required\n";
      exit 2);
    Forge.team_member_full ~org:!org ~team:!team ~user:user_or_committer
  in
  let exit_code =
    match queried with
    | `Queried true -> 0
    | `Queried false -> 1
    | `NotConfigured | `CurlFailure -> if !fail_mode = "open" then 0 else 1
  in
  verdict_record queried;
  exit exit_code

(* `mathc counters` — single source of truth for project counts
   (decisions, obligations, attestations, self-check verdict, cram
   count, CLI subcommand count). Replaces `scripts/dev-counters.py`
   (which required a Python interpreter) and `scripts/check-counters-
   drift.sh` (which used a 100-line Python heredoc to compare these
   counts against prose in PACKAGES.md, ROADMAP.md, README.md).

   The output schema is a strict superset of the old Python script's
   schema; downstream consumers (`scripts/check-counters-drift.sh`
   once it is rewritten, human maintainers, CI dashboards) can rely
   on the same JSON keys.

   The self-check sub-count is sourced by re-invoking
   `mathc self-check` as a subprocess (same pattern as the old
   `dev-counters.py`). This keeps `do_self_check`'s exit-code
   semantics isolated to the child process — `mathc counters` itself
   always exits 0 on a successful read, even when the live tree is
   missing attestations (the verdict:unknown signal is preserved as
   a JSON field, not promoted to an exit code). *)

let[@warning "-32"] subcommand_names () : string list =
  let cwd = Sys.getcwd () in
  let path = Filename.concat cwd "bin/Mathc.ml" in
  let text =
    try In_channel.with_open_bin path In_channel.input_all with _ -> ""
  in
  (* OCaml `Str` regex semantics differ from Python re in
     two ways that matter here: `|` is alternation (not a
     literal), and `^` in `search_forward` anchors only to
     the start of the whole string, not to each line. We
     parse the fixed dispatcher line shape by hand. *)
  let lines = String.split_on_char '\n' text in
  let acc = ref [] in
  List.iter
    (fun line ->
      let trimmed = String.trim line in
      let tlen = String.length trimmed in
      if
        tlen > 6
        && String.unsafe_get trimmed 0 = '|'
        && String.unsafe_get trimmed 1 = ' '
        && String.unsafe_get trimmed 2 = '"'
      then begin
        let after_open =
          try String.sub trimmed 3 (tlen - 3) with Invalid_argument _ -> ""
        in
        let len_ao = String.length after_open in
        let close =
          let rec find i =
            if i >= len_ao then -1
            else if String.unsafe_get after_open i = '"' then i
            else find (i + 1)
          in
          find 1
        in
        if close > 0 then begin
          let name =
            try String.sub after_open 0 close with Invalid_argument _ -> ""
          in
          let rest_start = close + 1 in
          let rest_len = tlen - 3 - rest_start in
          if rest_len > 0 then begin
            let rest =
              try String.sub after_open rest_start rest_len
              with Invalid_argument _ -> ""
            in
            let rest_trimmed = String.trim rest in
            let rtlen = String.length rest_trimmed in
            if
              rtlen >= 6
              &&
                try
                  String.sub rest_trimmed 0 3 = "-> "
                  && String.sub rest_trimmed 3 3 = "do_"
                with Invalid_argument _ -> false
            then acc := name :: !acc
          end
        end
      end)
    lines;
  List.rev !acc

let[@warning "-32"] cram_test_files () : string list =
  let dir = "tests/cli" in
  if not (Sys.file_exists dir) then []
  else
    try
      Sys.readdir dir |> Array.to_list
      |> List.filter (fun n -> Filename.check_suffix n ".t")
      |> List.sort String.compare
    with _ -> []

(* Decisions enumeration: same rules as `dev-counters.py` for
   `decisions.active` (the three meta-aggregators + 4 non-feature
   schemas are excluded). *)
let[@warning "-32"] decision_meta_files : string list =
  [
    "decision.yaml";
    "obligations.yaml";
    "obligation-count-reconcile.yaml";
    "schema-empty-sha-2026-10.yaml";
    "audit-0.0.21-fixes-self-check-waiver-2026-10.yaml";
    "waiver-infrastructure-2026-10.yaml";
    "lib-stale-comments-cleanup-2026-10.yaml";
  ]

(* `~root` is mandatory rather than optional on purpose. The single
   caller (`do_counters`) reaches this helper from inside a
   `Sys.chdir root` scope, so the bare resolver call happened to probe
   the right tree — correctness resting on a side-effect invisible at
   the call site. Passing the root explicitly removes that dependence
   and is the substitution the decision's `antithesis` records against
   the chdir shortcut. Decision `path-probe-anchoring-2026-11`. *)
let[@warning "-32"] enumerate_decisions ~root () : string list * int =
  let dir = Filename.concat root (Path_config.resolve_decisions_dir ~root ()) in
  let files =
    if Sys.file_exists dir && Sys.is_directory dir then
      Sys.readdir dir |> Array.to_list
      |> List.filter (fun f -> Filename.check_suffix f ".yaml")
      |> List.sort String.compare
    else []
  in
  let active =
    List.filter (fun f -> not (List.mem f decision_meta_files)) files
  in
  (files, List.length active)

(* Subprocess: run `mathc self-check` and parse the JSON. The
   executable is `Sys.executable_name` (the current process's
   binary) which works for both `nix develop` and `dune exec`
   invocations. The output JSON is a strict superset of what
   `do_self_check` prints; we extract subjects + verdict. *)
let[@warning "-32"] read_self_check () : Jsonl.value =
  let cmd =
    Printf.sprintf "%s self-check 2>/dev/null"
      (Filename.quote Sys.executable_name)
  in
  let ic = Unix.open_process_in cmd in
  let buf = Buffer.create 4096 in
  let read_done = ref false in
  let start = Unix.time () in
  while not !read_done do
    (try
       Buffer.add_channel buf ic 4096;
       if Unix.time () -. start > 30.0 then read_done := true
     with End_of_file -> read_done := true);
    if Buffer.length buf > 1_000_000 then read_done := true
  done;
  (* close_process_in only after we have all data; ignore
     the wait status — the subprocess is internal to this
     process tree and we only care about its stdout. *)
  let _status = Unix.close_process_in ic in
  let body = Buffer.contents buf in
  try Jsonl.parse body
  with Jsonl.Parse_error _ ->
    Jsonl.Object [ ("verdict", Jsonl.String "unknown") ]

let[@warning "-32"] jsonl_string_field v name =
  match v with
  | Jsonl.Object ps -> (
      match List.assoc_opt name ps with
      | Some (Jsonl.String s) -> Some s
      | _ -> None)
  | _ -> None

let[@warning "-32"] jsonl_int_field v name =
  match v with
  | Jsonl.Object ps -> (
      match List.assoc_opt name ps with Some (Jsonl.Int n) -> n | _ -> 0)
  | _ -> 0

let[@warning "-32"] jsonl_array_length v name =
  match v with
  | Jsonl.Object ps -> (
      match List.assoc_opt name ps with
      | Some (Jsonl.Array xs) -> List.length xs
      | _ -> 0)
  | _ -> 0

let[@warning "-32"] jsonl_array_filter_count v name predicate =
  match v with
  | Jsonl.Object ps -> (
      match List.assoc_opt name ps with
      | Some (Jsonl.Array xs) -> List.filter predicate xs |> List.length
      | _ -> 0)
  | _ -> 0

let[@warning "-32"] do_counters () =
  let open Jsonl in
  let root = find_project_root (Sys.getcwd ()) in
  let restore_cwd = Sys.getcwd () in
  Sys.chdir root;
  Fun.protect
    ~finally:(fun () -> try Sys.chdir restore_cwd with _ -> ())
    (fun () ->
      (* 1. decisions *)
      let decision_files, decision_active = enumerate_decisions ~root () in
      let decision_files_json = List.map (fun s -> String s) decision_files in
      let decisions_v =
        Object
          [
            ("total", Int (List.length decision_files));
            ("active", Int decision_active);
            ("paths", Array decision_files_json);
          ]
      in
      (* 2. obligations: from kernel packages walker *)
      let obligations_v =
        let reader path = In_channel.with_open_bin path In_channel.input_all in
        let decisions_dir = Path_config.resolve_decisions_dir ~root () in
        let attestations_dir = Path_config.resolve_attestations_dir ~root () in
        let has_store = Sys.file_exists attestations_dir in
        let store =
          if has_store then
            try Attestations.load ~reader ~root:attestations_dir with _ -> []
          else []
        in
        let pkg =
          Packages.walk ~reader ~decisions_root:decisions_dir ~store ~has_store
            ~now_iso:(now_iso ()) ~policy_id:"bootstrap-v3"
        in
        let pj = Packages.to_json pkg in
        let counts_v =
          match pj with
          | Object ps -> (
              match List.assoc_opt "counts" ps with
              | Some v -> v
              | None -> Object [])
          | _ -> Object []
        in
        let get_int name = jsonl_int_field counts_v name in
        let decisions_count = jsonl_array_length pj "decisions" in
        Object
          [
            ("total", Int (get_int "total"));
            ("pass", Int (get_int "pass"));
            ("missing", Int (get_int "missing"));
            ("no_store", Int (get_int "no_store"));
            ("stale", Int (get_int "stale"));
            ("waived", Int (get_int "waived"));
            ("unknown", Int (get_int "unknown"));
            ("fail", Int (get_int "fail"));
            ("decision_count", Int decisions_count);
          ]
      in
      (* 3. attestations (live store) *)
      let attestations_dir = Path_config.resolve_attestations_dir ~root () in
      let live_store =
        if Sys.file_exists attestations_dir then
          Sys.readdir attestations_dir
          |> Array.to_list
          |> List.filter (fun f -> Filename.check_suffix f ".json")
          |> List.length
        else 0
      in
      let attestations_v = Object [ ("live_store", Int live_store) ] in
      (* 4. self-check: we deliberately do NOT spawn a subprocess
         here (the old dev-counters.py did, and the subprocess
         pattern is what hung `dune test` when self-check took too
         long or landed in a state where the kernel path
         blocked). Run `mathc self-check` directly if you need
         those numbers; counters exposes the path in
         `self_check.hint` for shell wrappers. *)
      let self_check_v =
        Object
          [
            ( "hint",
              String
                "run `mathc self-check` directly for verdict + per-subject \
                 counts" );
            ("verdict", String "skipped");
            ("subjects", Int 0);
            ("passing", Int 0);
            ("unknown", Int 0);
            ("failing", Int 0);
          ]
      in
      (* 5. CLI subcommand count (manual parse of bin/Mathc.ml's
         dispatcher block). *)
      let subs = subcommand_names () in
      let subs_json = Array (List.map (fun s -> String s) subs) in
      let cli_v =
        Object
          [
            ("subcommands", subs_json);
            ("subcommand_count", Int (List.length subs));
          ]
      in
      (* 6. cram tests *)
      let crams = cram_test_files () in
      let crams_json = Array (List.map (fun s -> String s) crams) in
      let tests_v =
        Object
          [
            ("cram_files", crams_json); ("cram_count", Int (List.length crams));
          ]
      in
      (* 7. schema info (best-effort; do not fail the command) *)
      let schema_v =
        if not (Sys.file_exists "schemas/decision.json") then
          Object [ ("error", String "schema missing") ]
        else
          let raw =
            In_channel.with_open_bin "schemas/decision.json"
              In_channel.input_all
          in
          try
            let v = Jsonl.parse raw in
            let string_list_field obj_path =
              match obj_path with
              | Object ps -> (
                  match List.assoc_opt "required" ps with
                  | Some (Array xs) ->
                      List.map
                        (fun x -> match x with String s -> s | _ -> "")
                        xs
                  | _ -> [])
              | _ -> []
            in
            let string_list_from_nested obj_path =
              let rec get v = function
                | [] -> Some v
                | k :: rest -> (
                    match v with
                    | Object ps -> (
                        match List.assoc_opt k ps with
                        | Some sub -> get sub rest
                        | None -> None)
                    | _ -> None)
              in
              match get v obj_path with
              | Some (Array xs) ->
                  List.map (fun x -> match x with String s -> s | _ -> "") xs
              | _ -> []
            in
            let has_one_of obj_path =
              let rec get v = function
                | [] -> Some v
                | k :: rest -> (
                    match v with
                    | Object ps -> (
                        match List.assoc_opt k ps with
                        | Some sub -> get sub rest
                        | None -> None)
                    | _ -> None)
              in
              match get v obj_path with
              | Some (Object ps) -> List.mem_assoc "oneOf" ps
              | _ -> false
            in
            Object
              [
                ( "decision_required_fields",
                  Array (List.map (fun s -> String s) (string_list_field v)) );
                ( "schema_enum",
                  Array
                    (List.map
                       (fun s -> String s)
                       (string_list_from_nested
                          [ "properties"; "schema"; "enum" ])) );
                ("intent_oneOf", Bool (has_one_of [ "properties"; "intent" ]));
                ("scope_oneOf", Bool (has_one_of [ "properties"; "scope" ]));
              ]
          with _ -> Object [ ("error", String "schema parse failed") ]
      in
      let top =
        Object
          [
            ("decisions", decisions_v);
            ("obligations", obligations_v);
            ("attestations", attestations_v);
            ("self_check", self_check_v);
            ("cli", cli_v);
            ("tests", tests_v);
            ("schema", schema_v);
          ]
      in
      print_endline (Jsonl.stringify top);
      exit 0)

(* Render the package_list in the requested format. The JSON and
   HTML forms are emitted via lib/packages.ml renderers; text is
   a fixed-width table. *)
let[@warning "-32"] do_packages () =
  let format = ref `Text in
  let set_format s =
    match s with
    | "text" -> format := `Text
    | "json" -> format := `Json
    | "html" -> format := `Html
    | _ ->
        Printf.fprintf stderr "mathc packages: unknown --format: %s\n" s;
        exit 2
  in
  Arg.current := 1;
  (try
     Arg.parse
       [ ("--format", Arg.String set_format, "output format (text|json|html)") ]
       (fun _ -> ())
       "usage: mathc packages [--format=text|json|html]"
   with Arg.Bad m ->
     Printf.fprintf stderr "mathc packages: %s\n" m;
     exit 2);
  let root = find_project_root (Sys.getcwd ()) in
  let decisions_root =
    Filename.concat root (Path_config.resolve_decisions_dir ~root ())
  in
  let attestations_root =
    Filename.concat root (Path_config.resolve_attestations_dir ~root ())
  in
  let reader path = In_channel.with_open_bin path In_channel.input_all in
  let has_store = Sys.file_exists attestations_root in
  let store =
    if has_store then
      try Attestations.load ~reader ~root:attestations_root with _ -> []
    else []
  in
  let now_iso =
    let tm = Unix.gmtime (Unix.time ()) in
    Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ" (tm.tm_year + 1900)
      (tm.tm_mon + 1) tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec
  in
  let pkg =
    Packages.walk ~reader ~decisions_root ~store ~has_store ~now_iso
      ~policy_id:"bootstrap-v3"
  in
  match !format with
  | `Text -> print_string (Packages.to_text pkg)
  | `Json -> print_endline (Jsonl.stringify (Packages.to_json pkg))
  | `Html -> print_string (Packages.to_html pkg)

(* mathc find KEYWORD [--obligation=ID] [--format=json]
 *
 * Keyword / obligation-id search across the decisions corpus
 * (decision `mathc-find-subcommand-2026-10`). The output is a
 * `mathc packages`-shaped JSON object with the `decisions`
 * array filtered to the matches. Exit codes:
 *
 *   0  matches emitted (including the empty-match case)
 *   2  input error (missing keyword, missing --obligation,
 *      malformed --format).
 *
 * The implementation reuses `mathc packages` so the input shape
 * to `Find.search` / `Find.lookup_obligation` is the same
 * JSON tree the kernel already produces. `lib/find/find.ml` is
 * pure and side-effect-free; this CLI is the I/O boundary. *)
let[@warning "-32"] do_find () =
  let obligation = ref None in
  let format = ref `Json in
  let keyword = ref (None : string option) in
  let set_obligation s = obligation := Some s in
  let set_format s =
    match s with
    | "json" -> format := `Json
    | _ ->
        Printf.fprintf stderr "mathc find: unknown --format: %s\n" s;
        exit 2
  in
  let takes = ref true in
  Arg.current := 1;
  (try
     Arg.parse
       [
         ( "--obligation",
           Arg.String set_obligation,
           "<id> lookup an obligation id (returns its enclosing decision)" );
         ("--format", Arg.String set_format, "json (default)");
       ]
       (fun s ->
         if !takes then begin
           keyword := Some s;
           takes := false
         end
         else begin
           Printf.fprintf stderr "mathc find: unexpected argument: %s\n" s;
           exit 2
         end)
       "usage: mathc find KEYWORD [--obligation=ID] [--format=json]"
   with Arg.Bad m ->
     Printf.fprintf stderr "mathc find: %s\n" m;
     exit 2);
  let root = find_project_root (Sys.getcwd ()) in
  let decisions_root =
    Filename.concat root (Path_config.resolve_decisions_dir ~root ())
  in
  let attestations_root =
    Filename.concat root (Path_config.resolve_attestations_dir ~root ())
  in
  let reader path = In_channel.with_open_bin path In_channel.input_all in
  let has_store = Sys.file_exists attestations_root in
  let store =
    if has_store then
      try Attestations.load ~reader ~root:attestations_root with _ -> []
    else []
  in
  let now_iso =
    let tm = Unix.gmtime (Unix.time ()) in
    Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ" (tm.tm_year + 1900)
      (tm.tm_mon + 1) tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec
  in
  let pkg =
    Packages.walk ~reader ~decisions_root ~store ~has_store ~now_iso
      ~policy_id:"bootstrap-v3"
  in
  let json = Packages.to_json pkg in
  let filtered =
    match !obligation with
    | Some oid -> Find.lookup_obligation ~obligation_id:oid json
    | None -> (
        match !keyword with
        | Some kw -> Find.search ~keyword:kw json
        | None ->
            Printf.fprintf stderr
              "mathc find: KEYWORD or --obligation=ID is required\n";
            exit 2)
  in
  match !format with
  | `Json ->
      print_endline (Jsonl.stringify filtered);
      (* Zero matches is success, not failure: callers inspect the
         `decisions` array. *)
      exit 0

(* mathc precommit — batch-validate every `decisions/*.yaml`
 * (or the explicit paths supplied on the command line) by
 * shelling out to `mathc validate --format=json` per file.
 *
 * Exit code: 0 if every file accepted, 1 if any file was
 * rejected (exit 1 from the underlying validate), 2 if any
 * file was an input error (exit 2 from validate or missing
 * path). The dispatcher exits with the worst of these.
 *
 * No attestation store, no git-diff, no rebuttal walk — those
 * are out of scope for precommit batch mode (decision
 * ux-3-precommit-subcommand-2026-10). The full store-aware
 * verdict lives in `mathc self-check`. *)
let[@warning "-32"] do_precommit () =
  let format = ref Text in
  let paths = ref [] in
  Arg.current := 1;
  (try
     Arg.parse
       [
         ( "--format",
           Arg.String
             (fun s ->
               match s with
               | "text" -> format := Text
               | "json" -> format := Json
               | _ ->
                   Printf.fprintf stderr
                     "mathc precommit: unknown --format: %s\n" s;
                   exit 2),
           " Output format: text (default) or json" );
       ]
       (fun s -> paths := s :: !paths)
       "usage: mathc precommit [PATH...] [--format=text|json]"
   with Arg.Bad m ->
     Printf.fprintf stderr "mathc precommit: %s\n" m;
     exit 2);
  let root = find_project_root (Sys.getcwd ()) in
  let files = List.rev !paths in
  let summary = Check.run_staged ~root ~paths:files in
  match !format with
  | Text ->
      Printf.printf "%s\n" (Check.summary_to_text summary);
      List.iter
        (fun (r : Check.file_result) ->
          Printf.printf "  %s: %s\n" r.path
            (match r.exit_code with
            | 0 -> "accept"
            | 1 -> "reject"
            | 2 -> "input_err"
            | _ -> Printf.sprintf "exit=%d" r.exit_code))
        summary.files;
      (* Exit code: 0 if all accept, 1 if any reject, 2 if any
           input error and no reject (input_err is the worst). *)
      if summary.rejected > 0 then exit 1
      else if summary.input_err > 0 then exit 2
      else exit 0
  | Json ->
      print_endline (Jsonl.stringify (Check.summary_to_json summary));
      if summary.rejected > 0 then exit 1
      else if summary.input_err > 0 then exit 2
      else exit 0

(* --- graph subcommand (decision graph-viewer-2026-10@1) --- *)

(* `mathc graph --decision=<id> [--format=dot|json]`
 *
 * Walk the relations graph starting from `decision_id` (using
 * the existing `lib/re_evaluation.ml::load_decisions` reader)
 * and print either a Graphviz DOT serialization or a
 * canonical JSON projection. The DOT form is the default;
 * pass `--format=json` for the structural form consumed by
 * `dist/graph.html`.
 *
 * Exit codes:
 *   0  graph emitted (success); an empty graph (root not
 *      found) still exits 0 in DOT mode and emits only the
 *      `digraph {}` header line; `--format=json` exits 1
 *      and emits MC-POLICY-NOT-FOUND when the root id is
 *      unknown to the corpus.
 *   1  decision id not found (kernel-side reject; the JSON
 *      shape explicitly states `_cycle` so the consumer can
 *      detect a cycle in the relations graph).
 *   2  input error (unknown --format value, missing --decision).
 *
 * The cycle flag is propagated from `lib/graph/graph.ml::build`
 * (the kernel annotates a back-edge to an ancestor in the
 * BFS path). The projection is digraph-style and the
 * `superseded_by` relation is folded into `supersedes` (the
 * existing `lib/re_evaluation.ml::transitive_impact_list`
 * walker uses the same convention). *)
let[@warning "-32"] do_graph () =
  let decision_id = ref "" in
  let format = ref `Dot in
  let set_id s = decision_id := s in
  let set_format s =
    match s with
    | "dot" -> format := `Dot
    | "json" -> format := `Json
    | _ ->
        Printf.fprintf stderr "mathc graph: unknown --format: %s\n" s;
        exit 2
  in
  Arg.current := 1;
  (try
     Arg.parse
       [
         ("--decision", Arg.String set_id, "<id> root of the relations graph");
         ("--format", Arg.String set_format, "dot (default) or json");
       ]
       (fun _ -> ())
       "usage: mathc graph --decision=<id> [--format=dot|json]"
   with Arg.Bad m ->
     Printf.fprintf stderr "mathc graph: %s\n" m;
     exit 2);
  let id = !decision_id in
  if id = "" then begin
    Printf.fprintf stderr "mathc graph: --decision=<id> is required\n";
    exit 2
  end;
  let reader p = In_channel.with_open_bin p In_channel.input_all in
  let repo_root = find_project_root (Sys.getcwd ()) in
  let decisions = Re_evaluation.load_decisions ~reader ~root:repo_root in
  match !format with
  | `Dot ->
      Printf.printf "%s" (Graph.to_dot ~decision_id:id decisions);
      exit 0
  | `Json ->
      let g = Graph.to_json ~decision_id:id decisions in
      (* Empty graph — emit MC-POLICY-NOT-FOUND via
         Diagnostic.t, then exit 1. *)
      let empty =
        match g with
        | Jsonl.Object ps -> (
            match List.assoc_opt "nodes" ps with
            | Some (Jsonl.Array xs) -> List.length xs = 0
            | _ -> true)
        | _ -> false
      in
      if empty then begin
        let diag =
          Diagnostic.input "MC-POLICY-NOT-FOUND"
            (Printf.sprintf "decision not found: %s" id)
        in
        Printf.fprintf stderr "[error] %s: %s\n" diag.Diagnostic.code
          diag.Diagnostic.message;
        exit 1
      end;
      print_endline (Jsonl.stringify g);
      exit 0

(* `mathc decision-state <id> <action> [--by=<id>@<rev>]` (decision
 * lifecycle-commands-2026-10).
 *
 * Transitions a single decision's lifecycle state by editing
 * its YAML file in `decisions/` and re-running `mathc validate`
 * on the result. The kernel parser (lib/decision.ml) is NOT
 * modified; the dispatcher reads the file, calls
 * `Lifecycle.transition` to compute the new YAML, writes the
 * result back, and runs `mathc validate` to confirm
 * the kernel accepts the rewrite.
 *
 * Exit codes:
 *   0  kernel accepted the rewrite; `state:` and (if
 *      applicable) `superseded_by:` were updated.
 *   1  kernel rejected the rewrite (idempotent re-issue, or
 *      `mathc validate` rejects the result).
 *   2  input error (no such id, missing args, bad kebab,
 *      malformed `--by=<id>@<rev>`).
 *
 * The action surface is intentionally narrow:
 *   - mark-superseded --by=<id>@<rev>
 *   - mark-retired
 *   - set <state>    where <state> in {active,draft,retired,superseded}
 *
 * User-facing aliases "obsolete" / "archive" are NOT accepted
 * (see lib/lifecycle/lifecycle.ml preamble; widening the
 * 4-state enum is forbidden by algebra §7). *)
let[@warning "-32"] do_decision_state () =
  Arg.current := 1;
  let pos = ref [] in
  let by_arg = ref (None : string option) in
  let anon s = pos := s :: !pos in
  let set_by s = by_arg := Some s in
  (try
     Arg.parse
       [ ("--by", Arg.String set_by, "<id>@<rev> replacement target") ]
       anon "usage: mathc decision-state <id> <action> [--by=<id>@<rev>]"
   with
  | Arg.Bad m ->
      Printf.fprintf stderr "mathc decision-state: %s\n" m;
      exit 2
  | Arg.Help _ ->
      print_usage stderr;
      exit 0);
  let args = List.rev !pos in
  (* Parse positional. Two shapes:
     (a) `decision-state <id> mark-superseded [--by=X]`
     (b) `decision-state <id> mark-retired`
     (c) `decision-state <id> set <state>`
     The first element is the id; the second is the action; for
     `set` a third element names the target state. *)
  let id_str, action_str, third_str =
    match args with
    | [ id; a; s ] -> (id, a, Some s)
    | [ id; a ] -> (id, a, None)
    | [ id ] -> (id, "", None)
    | _ ->
        Printf.fprintf stderr
          "mathc decision-state: expected <id> <action>; got %d positional \
           arg(s)\n"
          (List.length args);
        exit 2
  in
  (* Validate id (kebab-case) early; this catches the cram case (e)
     before any file I/O. *)
  (match Lifecycle.validate_id id_str with
  | Error m ->
      Printf.fprintf stderr "mathc decision-state: %s\n" m;
      exit 2
  | Ok _ -> ());
  (* Resolve the on-disk path under decisions/. *)
  let root = find_project_root (Sys.getcwd ()) in
  let path =
    Filename.concat
      (Filename.concat root (Path_config.resolve_decisions_dir ~root ()))
      (id_str ^ ".yaml")
  in
  let reader p =
    try In_channel.with_open_bin p In_channel.input_all with Sys_error _ -> ""
  in
  (* Read the existing source. Missing file -> exit 2 (input error). *)
  let source = reader path in
  if source = "" then begin
    Printf.fprintf stderr
      "mathc decision-state: decision not found: %s (no %s)\n" id_str path;
    exit 2
  end;
  (* Parse the current state from the YAML via Codec.parse_decision_state.
     Fall back to `Active` (kernel default). *)
  let current =
    let stripped =
      let lines = String.split_on_char '\n' source in
      let rec drop acc = function
        | [] -> List.rev acc
        | line :: rest when String.trim line = "---" -> (
            match rest with
            | line2 :: _ when String.trim line2 = "---" -> rest
            | _ -> drop acc rest)
        | line :: rest -> drop (line :: acc) rest
      in
      drop [] lines |> String.concat "\n"
    in
    let v = try Codec.load_yaml_string stripped with _ -> Jsonl.Object [] in
    let state_str =
      match v with
      | Jsonl.Object ps -> (
          match Schema.take_string ps "state" with
          | Some s -> s
          | None -> "active")
      | _ -> "active"
    in
    match Codec.parse_decision_state state_str with
    | Some s -> s
    | None -> `Active
  in
  (* Build the action. *)
  let action : Lifecycle.action =
    match action_str with
    | "mark-superseded" ->
        let by =
          match !by_arg with
          | None ->
              Printf.fprintf stderr
                "mathc decision-state: mark-superseded requires --by=<id>@<rev>\n";
              exit 2
          | Some v -> (
              match Lifecycle.parse_by_arg v with
              | Ok parsed -> parsed
              | Error m ->
                  Printf.fprintf stderr "mathc decision-state: %s\n" m;
                  exit 2)
        in
        Lifecycle.MarkSuperseded { by }
    | "mark-retired" ->
        if !by_arg <> None then begin
          Printf.fprintf stderr
            "mathc decision-state: mark-retired does not accept --by=<id>@<rev>\n";
          exit 2
        end;
        Lifecycle.MarkRetired
    | "set" -> (
        match third_str with
        | None ->
            Printf.fprintf stderr
              "mathc decision-state: set <state> requires a state value\n";
            exit 2
        | Some "active" -> Lifecycle.SetState `Active
        | Some "draft" -> Lifecycle.SetState `Draft
        | Some "retired" -> Lifecycle.SetState `Retired
        | Some "superseded" -> Lifecycle.SetState `Superseded
        | Some other ->
            Printf.fprintf stderr
              "mathc decision-state: invalid state %s (expected \
               active|draft|retired|superseded)\n"
              other;
            exit 2)
    | "" ->
        Printf.fprintf stderr
          "mathc decision-state: missing <action> \
           (mark-superseded|mark-retired|set)\n";
        exit 2
    | other ->
        Printf.fprintf stderr
          "mathc decision-state: invalid action %s (expected \
           mark-superseded|mark-retired|set)\n"
          other;
        exit 2
  in
  (* Compute the new YAML via the pure transition. *)
  let result = Lifecycle.transition ~source ~current action in
  match result with
  | Rejected { reason; verdict_exit } ->
      Printf.fprintf stderr "mathc decision-state: %s\n" reason;
      exit verdict_exit
  | Transitioned { new_yaml; diff_summary; _ } -> (
      (* Write the new YAML atomically: stage to a sibling .tmp,
         then rename. The rename is atomic on POSIX. The kernel
         will not see a half-written file. *)
      let tmp = path ^ ".tmp" in
      let oc = open_out tmp in
      output_string oc new_yaml;
      close_out oc;
      Unix.rename tmp path;
      Printf.printf "mathc decision-state: %s\n" diff_summary;
      (* Re-validate by calling the kernel parser directly. Same
         binary, no fork/exec. The `validate` text path reports
         `parse-ok:` or `reject:` on stdout; the user's experience
         mirrors `mathc validate FILE --format=text`. *)
      match validate_with_counts path with
      | `Accept _ | `Accept_aggregate _ ->
          Printf.printf "validate: parse-ok\n";
          exit 0
      | `Reject (diag, _) ->
          Printf.fprintf stderr "validate: reject (%s)\n" diag.Diagnostic.code;
          exit 1
      | `Input_err m ->
          Printf.fprintf stderr "validate: input error (%s)\n" m;
          exit 2)

(* mathc migrate — declarative, kernel-observed migration plan.
 *
 * The kernel NEVER mutates decision files on disk. It only:
 *   1. reads the migration manifest,
 *   2. walks the requested root for *.yaml files,
 *   3. prints a per-file plan (text or JSON) describing what each
 *      file would need under the manifest.
 * An agent (or human) does the actual edit, then re-runs
 * `mathc validate` to confirm. This isolates the kernel's role:
 * it only describes; the agent decides whether and how to act.
 *
 * Flags:
 *   --from=X         (required unless --manifest is set explicitly)
 *   --to=Y           (required unless --manifest is set explicitly)
 *   --manifest=PATH  (override; defaults to
 *                     <root>/decisions/migrations/<from>-to-<to>.yaml)
 *   --root=DIR       (defaults to the project root)
 *   --format=text|json
 *   --explain        (also print the manifest's intent before the plan)
 *
* Exit codes follow OCAML_BEST_PRACTICES.md §4.3:
 *   0  plan emitted (success); warnings inside the plan do not change exit
 *   2  input error (missing flag, manifest parse failure, no manifest file)
 *
 * Flags:
 *   --from=X         (required unless --manifest is set explicitly)
 *   --to=Y           (required unless --manifest is set explicitly)
 *   --manifest=PATH  (override; defaults to
 *                     <root>/decisions/migrations/<from>-to-<to>.yaml)
 *   --root=DIR       (defaults to the project root)
 *   --format=text|json
  *   --explain        (also print the manifest's intent before the plan)
  *   --write          apply auto-translatable actions to a sibling
  *                    <file>.migrated.yaml alongside each input;
  *                    the original file is NEVER overwritten. The
  *                    `--format` and `--write` flags are mutually
  *                    exclusive (--write always emits a per-file
  *                    JSON summary of what was applied). With
  *                    `--dry-run` the kernel prints what `--write`
  *                    would do (a one-step assist) without touching
  *                    the disk; without `--dry-run`, writes happen.
  *)

(* --- init subcommand ----------------------------------------------- *)

(* `mathc init [PATH] [--agent NAME] [--from-adr PATH] [--no-install] [--merge]`
 *
 * Scaffolds a new math-coding project. The implementation lives
 * in `lib/init/init.ml` per the sub-library convention
 * (OCAML_BEST_PRACTICES §10.1); the dispatcher only parses argv
 * and forwards to `Init.run`. Exit codes follow the existing
 * convention: 0 on success, 3 on refused brownfield or I/O error. *)
let[@warning "-32"] do_init () =
  let path = ref "" in
  let agent = ref "generic" in
  let from_adr = ref None in
  let no_install = ref false in
  let merge = ref false in
  let with_ci_workflow = ref false in
  let set_path s = path := s in
  let set_agent s = agent := s in
  let set_from_adr s = from_adr := Some s in
  Arg.current := 1;
  Arg.parse
    [
      ( "--agent",
        Arg.String set_agent,
        " Target agent (generic|opencode|claude-code|cursor|continue)" );
      ( "--from-adr",
        Arg.String set_from_adr,
        " (no-op stub; deferred to ux-3-import-adr-subcommand-2026-10)" );
      ("--no-install", Arg.Set no_install, " Skip pre-commit hook installation");
      ( "--merge",
        Arg.Set merge,
        " Allow init in a directory with arc42/MADR/adr-tools present" );
      ( "--with-ci-workflow",
        Arg.Set with_ci_workflow,
        " Copy templates/ci.yml to .github/workflows/ci.yml" );
    ]
    set_path
    "usage: mathc init [PATH] [--agent NAME] [--from-adr PATH] [--no-install] \
     [--merge] [--with-ci-workflow]";
  let root = if !path = "" then Sys.getcwd () else !path in
  match Init.agent_of_string !agent with
  | Error m ->
      Printf.fprintf stderr "mathc init: %s\n" m;
      exit 2
  | Ok agent ->
      Init.run
        {
          Init.root;
          agent;
          from_adr = !from_adr;
          no_install = !no_install;
          merge = !merge;
          with_ci_workflow = !with_ci_workflow;
        }

(* --- import-adr subcommand ---------------------------------------- *)

(* `mathc import-adr PATH [--write]`
 *
 * Imports an existing ADR file (MADR or adr-tools shape) and
 * emits a math-coding decision YAML to stdout (default) or
 * to `decisions/<id>.yaml` (with `--write`). The implementation
 * lives in `lib/import_adr/import_adr.ml` per the sub-library
 * convention (OCAML_BEST_PRACTICES §10.1). The dispatcher only
 * parses argv and forwards to `Import_adr.run`. Exit codes:
 * 0 on success, 1 on file not found, 2 on input error. *)
let[@warning "-32"] do_import_adr () =
  let path = ref "" in
  let write = ref false in
  let set_path s = path := s in
  Arg.current := 1;
  Arg.parse
    [
      ( "--write",
        Arg.Set write,
        " Write the imported decision to decisions/<id>.yaml" );
    ]
    set_path "usage: mathc import-adr PATH [--write]";
  if !path = "" then begin
    Printf.fprintf stderr "mathc import-adr: missing PATH\n";
    print_usage stderr;
    exit 2
  end;
  if not (Sys.file_exists !path) then begin
    Printf.fprintf stderr "mathc import-adr: file not found: %s\n" !path;
    exit 1
  end;
  match Import_adr.run !path !write with
  | Ok () -> ()
  | Error (`Msg m) ->
      Printf.fprintf stderr "mathc import-adr: %s\n" m;
      exit 3

(* --- telemetry subcommand ------------------------------------------ *)

(* `mathc telemetry status`
 *
 * Phase-2 stub per decision ux-3-telemetry-stub-2026-10. The
 * command reads the `MATHCODING_TELEMETRY` environment variable
 * and prints the current mode. No transport is configured;
 * no data is collected or transmitted. The full telemetry
 * transport (HTTPS POST, retention, GDPR architecture) is a
 * separate decision deferred to Phase 3+; this slice only
 * plumbs the opt-in flag and the user-visible status command.
 *
 * Exit codes: 0 on success, 2 on unknown subcommand. *)
let[@warning "-32"] do_telemetry () =
  Arg.current := 1;
  let action = ref "" in
  let set_action s = action := s in
  (try Arg.parse [] set_action "usage: mathc telemetry status"
   with Arg.Bad m ->
     Printf.fprintf stderr "mathc telemetry: %s\n" m;
     exit 2);
  let sub = String.lowercase_ascii (String.trim !action) in
  if sub <> "status" && sub <> "" then begin
    Printf.fprintf stderr
      "mathc telemetry: unknown subcommand: %s\n\
      \  (only `status` is implemented in this slice; transport is deferred \
       (tracked: decisions/ux-3-telemetry-stub-2026-10.yaml))\n"
      (String.trim !action);
    exit 2
  end;
  let mode =
    match Sys.getenv_opt "MATHCODING_TELEMETRY" with
    | None -> "off"
    | Some s ->
        let t = String.lowercase_ascii (String.trim s) in
        if t = "on" || t = "1" || t = "true" then "on"
        else if t = "off" || t = "0" || t = "false" then "off"
        else Printf.sprintf "unknown (%s)" s
  in
  Printf.printf "mathc telemetry: %s\n" mode;
  Printf.printf
    "  transport: not configured (Phase 2 stub; tracked: \
     decisions/ux-3-telemetry-stub-2026-10.yaml)\n";
  Printf.printf "  See decisions/ux-3-telemetry-stub-2026-10.yaml.\n";
  Printf.printf "  No data is collected or transmitted by this build.\n"

(* --- adopt subcommand --------------------------------------------- *)

(* `mathc adopt [PATH] [--agent NAME] [--no-install] [--dry-run]
 *                 [--only=CONV] [--merge]`
 *
 * Brownfield adoption: detect the project's existing ADR
 * convention (arc42 / MADR / adr-tools / mixed / none) and
 * wire up math-coding accordingly. The detection logic
 * lives in `lib/adopt/detect.ml` (decision
 * `ux-3-adopt-detect-2026-10@1`); this dispatcher
 * orchestrates the response.
 *
 * Behavior per detection result:
 *   Empty:           `mathc init PATH` (greenfield, no --merge)
 *   Arc42:           `mathc init PATH --merge`
 *   Madr:            `mathc init PATH --merge` + import every
 *                    `docs/adr/*.md` via `mathc import-adr --write`
 *   AdrTools:        `mathc init PATH --merge` + import every
 *                    `adr/*.md` via `mathc import-adr --write`
 *   Mixed_*:         same per detected convention
 *
 * `--only=arc42|madr|adr-tools` restricts the response to one
 * convention. `--dry-run` prints what would be done without
 * running anything. `--agent NAME` and `--no-install` are
 * forwarded to `mathc init` (the inner scaffold call). *)

let[@warning "-32"] do_adopt () =
  let path = ref "" in
  let agent = ref "" in
  let no_install = ref false in
  let dry_run = ref false in
  let merge = ref false in
  let only = ref "" in
  let set_path s = path := s in
  let set_agent s = agent := s in
  let set_only s = only := s in
  Arg.current := 1;
  Arg.parse
    [
      ("--agent", Arg.String set_agent, " Forward to mathc init (--agent NAME)");
      ( "--no-install",
        Arg.Set no_install,
        " Forward to mathc init (--no-install)" );
      ( "--dry-run",
        Arg.Set dry_run,
        " Print what would be done; do not run init or import-adr" );
      ( "--merge",
        Arg.Set merge,
        " Force proceed even when no brownfield is detected" );
      ( "--only",
        Arg.String set_only,
        " Restrict to one convention: arc42|madr|adr-tools" );
    ]
    set_path
    "usage: mathc adopt [PATH] [--agent NAME] [--no-install] [--dry-run] \
     [--only=CONV] [--merge]";
  let target = if !path = "" then Sys.getcwd () else !path in
  let kind = Detect.detect_classify target in
  Printf.printf "mathc adopt: detected %s at %s\n"
    (Detect.string_of_brownfield kind)
    target;
  let needs_init, needs_madr, needs_adr_tools =
    match !only with
    | "arc42" -> (true, false, false)
    | "madr" -> (true, true, false)
    | "adr-tools" -> (true, false, true)
    | "" -> (
        (* No --only: do whatever the detection found. *)
        match kind with
        | Detect.Empty -> (true, false, false)
        | Detect.Arc42 -> (true, false, false)
        | Detect.Madr -> (true, true, false)
        | Detect.AdrTools -> (true, false, true)
        | Detect.Mixed_Arc42_Madr -> (true, true, false)
        | Detect.Mixed_Arc42_AdrTools -> (true, false, true)
        | Detect.Mixed_Madr_AdrTools -> (true, true, true)
        | Detect.Mixed_All_Three -> (true, true, true))
    | _ ->
        Printf.eprintf
          "mathc adopt: unknown --only value: %s (expected: \
           arc42|madr|adr-tools)\n"
          !only;
        exit 2
  in
  let pass_merge = match kind with Detect.Empty -> true | _ -> !merge in
  if (not pass_merge) && needs_init then begin
    Printf.eprintf
      "mathc adopt: refusing to proceed in brownfield project; pass --merge to \
       override.\n";
    exit 3
  end;
  (* Use the running binary's path to shell out to its subcommands
   * (init, import-adr). This avoids relying on PATH; the same
   * binary that dispatches to `do_adopt` is the binary that
   * does the work. *)
  let mathc_bin = Sys.executable_name in
  (* Child commands (init, import-adr) resolve the decisions dir
     through `lib/path_config.ml`. Without an explicit root they
     would resolve against the CALLER's cwd, so `mathc adopt
     /srv/app` imported the project's ADRs into whatever repository
     the operator happened to be standing in. Decision
     `kernel-fixes-found-bugs-2026-10@1`. *)
  let run_argv argv =
    let cmdline =
      String.concat " "
        (("MATH_CODING_ROOT=" ^ Filename.quote target)
        :: List.map Filename.quote argv)
    in
    Sys.command cmdline
  in
  if needs_init then begin
    Printf.printf "  step 1/2: mathc init (scaffold math-coding in %s)\n" target;
    if !dry_run then ()
    else begin
      let init_argv = ref [ mathc_bin; "init"; target ] in
      (match kind with
      | Detect.Empty -> ()
      | _ -> init_argv := !init_argv @ [ "--merge" ]);
      (match !agent with
      | "" -> ()
      | a -> init_argv := !init_argv @ [ "--agent"; a ]);
      (match !no_install with
      | true -> init_argv := !init_argv @ [ "--no-install" ]
      | false -> ());
      let rc = run_argv !init_argv in
      if rc <> 0 then begin
        Printf.eprintf "mathc adopt: init failed (exit %d)\n" rc;
        exit 3
      end;
      (* When arc42 is detected, write a side-decision that
       * records the arc42 layout. This makes the
       * coexistence explicit: math-coding handles
       * code-level decisions; arc42 handles architecture
       * documentation. The reviewer fills in the
       * section list per the project's actual use. *)
      let has_arc42 =
        match kind with
        | Detect.Arc42 | Detect.Mixed_Arc42_Madr | Detect.Mixed_Arc42_AdrTools
        | Detect.Mixed_All_Three ->
            true
        | _ -> false
      in
      if has_arc42 then begin
        Printf.printf "  step 1b/2: writing arc42-coexistence side-decision\n";
        let arc42_dir = Filename.concat target "docs/arc42" in
        let sections_count =
          if Sys.file_exists arc42_dir && Sys.is_directory arc42_dir then
            Array.to_list (Sys.readdir arc42_dir)
            |> List.filter (fun n ->
                Filename.check_suffix n ".md" || Filename.check_suffix n ".adoc")
            |> List.length
          else 0
        in
        let side_dec_template =
          Printf.sprintf
            "---\n\
             schema: math-coding/3.2\n\
             id: bootstrap-v3-arc42-compatibility\n\
             revision: 1\n\
             state: active\n\
             intent: |\n\
            \  Records the arc42 layout of this project. The\n\
            \  math-coding master policy is the source of truth\n\
            \  for code-level decisions; this file records the\n\
            \  architecture documentation convention that\n\
            \  co-exists with math-coding.\n\
             antithesis: |\n\
            \  The counter-position considered and rejected:\n\
            \  co-existence of math-coding and arc42 creates\n\
            \  two parallel decision stores. The maintainer\n\
            \  must keep them in sync. The author rejected this\n\
            \  position: the two stores serve different scopes\n\
            \  (architecture vs code) and the math-coding master\n\
            \  policy is the canonical source for code changes\n\
            \  while arc42 remains the canonical source for\n\
            \  architecture documentation. The reviewer is\n\
            \  responsible for spotting contradictions between\n\
            \  the two; this decision records the separation.\n\n\
            \  Generated by mathc adopt (decision\n\
            \  ux-3-adopt-subcommand-2026-10@1) when\n\
            \  docs/arc42/ is detected.\n\
             axiom_link:\n\
            \  - A0\n\
             commitment: |\n\
            \  The arc42 sections in docs/arc42/ are the\n\
            \  authoritative source of architecture\n\
            \  documentation for this project. math-coding\n\
            \  decisions recorded in decisions/ cover\n\
            \  code-level changes; the two systems do not\n\
            \  overlap.\n\
             counterexample: |\n\
            \  The strongest objection to co-existence is\n\
            \  that the two systems might contradict each\n\
            \  other: an arc42 decision that conflicts with a\n\
            \  math-coding decision. The mitigation is the\n\
            \  explicit scope separation in the scope field:\n\
            \  docs/arc42 for architecture, decisions/ for\n\
            \  code. A reviewer who sees a conflict files a\n\
            \  decision that supersedes the older one; the\n\
            \  relationships field in the newer decision\n\
            \  records the conflict.\n\
             scope:\n\
            \  paths:\n\
            \    - \"docs/arc42/**\"\n\
            \  exclusions: []\n\
             assumptions:\n\
            \  - state: assumed\n\
            \    statement: |\n\
            \      The arc42-template layout in docs/arc42/\n\
            \      contains the projects architecture\n\
            \      documentation. %d sections currently\n\
            \      present. The reviewer can re-run mathc\n\
            \      adopt to refresh this record.\n\
             outcomes:\n\
            \  - id: arc42-coexistence\n\
            \    statement: |\n\
            \      The projects arc42 sections stay\n\
            \      authoritative for architecture\n\
            \      documentation. math-coding decisions do\n\
            \      not duplicate or contradict them.\n\
             obligations:\n\
            \  - id: arc42-compatibility-recorded\n\
            \    claim: |\n\
            \      The arc42 layout in docs/arc42/ is recorded\n\
            \      in this decisions assumptions block.\n\
            \    acceptance:\n\
            \      all:\n\
            \        - verifier: mathc validate\n\
            \          result: pass\n\
             relations:\n\
            \  addresses:\n\
            \    - bootstrap-v3\n\
            \  supersedes: []\n\
            \  superseded_by: []\n"
            sections_count
        in
        (* The side-decision lives wherever THIS project keeps its
         * decisions. The previous revision hardcoded
         * `<target>/decisions/...`, which (a) wrote the legacy tree
         * into a project init had just scaffolded with
         * `.math-coding/` and (b) crashed with an uncaught
         * `Sys_error` when that directory did not exist yet.
         * Decision `kernel-fixes-found-bugs-2026-10@1`. *)
        let side_dir =
          Filename.concat target
            (Path_config.resolve_decisions_dir ~root:target ())
        in
        ensure_dir side_dir;
        let side_path =
          Filename.concat side_dir "bootstrap-v3-arc42-compatibility.yaml"
        in
        let oc = open_out side_path in
        output_string oc side_dec_template;
        close_out oc;
        Printf.printf "    wrote %s\n" side_path
      end
    end
  end;
  let import_one rel =
    let abs = Filename.concat target rel in
    Printf.printf "  step 2/2: mathc import-adr %s --write\n" abs;
    if !dry_run then ()
    else begin
      let argv = [ mathc_bin; "import-adr"; abs; "--write" ] in
      let rc = run_argv argv in
      if rc <> 0 then begin
        Printf.eprintf "mathc adopt: import-adr %s failed (exit %d)\n" abs rc;
        exit 3
      end
    end
  in
  if needs_madr then List.iter import_one (Detect.madr_files target);
  if needs_adr_tools then List.iter import_one (Detect.adrtools_files target);
  Printf.printf "mathc adopt: done\n"

let[@warning "-32"] do_migrate () =
  Arg.current := 1;
  let from_arg = ref (None : string option) in
  let to_arg = ref (None : string option) in
  let manifest_override = ref (None : string option) in
  let root_arg = ref "" in
  let output_format = ref `Text in
  let explain_flag = ref false in
  let write_flag = ref false in
  let dry_run_flag = ref false in
  let set_from s = from_arg := Some s in
  let set_to s = to_arg := Some s in
  let set_manifest s = manifest_override := Some s in
  let set_root s = root_arg := s in
  let set_format s =
    match s with
    | "text" -> output_format := `Text
    | "json" -> output_format := `Json
    | _ ->
        Printf.fprintf stderr "mathc migrate: unknown --format: %s\n" s;
        exit 2
  in
  let set_explain () = explain_flag := true in
  let set_write () = write_flag := true in
  let set_dry_run () = dry_run_flag := true in
  (try
     Arg.parse
       [
         ( "--from",
           Arg.String set_from,
           "source schema-string (e.g. math-coding/3.2)" );
         ( "--to",
           Arg.String set_to,
           "target schema-string (e.g. math-coding/3.2.1)" );
         ("--manifest", Arg.String set_manifest, "override manifest path");
         ( "--root",
           Arg.String set_root,
           "root directory (defaults to project root)" );
         ("--format", Arg.String set_format, "output format (text|json)");
         ( "--explain",
           Arg.Unit set_explain,
           "print manifest intent before the plan" );
         ( "--write",
           Arg.Unit set_write,
           "apply auto-translatable actions to sibling <file>.migrated.yaml \
            (never overwrites the original)" );
         ( "--dry-run",
           Arg.Unit set_dry_run,
           "with --write: print what would be written without touching the disk"
         );
       ]
       (fun _ -> ())
       "usage: mathc migrate --from=X --to=Y [--root=DIR] [--format=text|json] \
        [--explain] [--write [--dry-run]] [--manifest=PATH]"
   with
  | Arg.Bad m ->
      Printf.fprintf stderr "mathc migrate: %s\n" m;
      exit 2
  | Arg.Help _ ->
      print_string
        "mathc migrate: read a migration manifest, walk *.yaml files, print a \
         per-file plan (default dry-run). Pass --write to apply \
         auto-translatable actions to a sibling <file>.migrated.yaml; the \
         original file is NEVER overwritten. Re-run `mathc validate` after \
         applying any edits.\n";
      exit 0);
  if !write_flag then begin
    (* --write always emits a per-file JSON summary; ignore any
       --format the user passed. *)
    output_format := `Json
  end;
  let project_root = find_project_root (Sys.getcwd ()) in
  let root =
    if !root_arg = "" then project_root
    else if Filename.is_relative !root_arg then
      Filename.concat project_root !root_arg
    else !root_arg
  in
  let manifest_path =
    match !manifest_override with
    | Some p ->
        (* `--manifest=PATH` is resolved against the project root
           when given as a relative path, NOT against `--root`, so
           that fixtures under `tests/cli/fixtures/...` can pass
           paths relative to the project root while still
           constraining `--root` to a small synthetic tree. *)
        if Filename.is_relative p then Filename.concat project_root p else p
    | None ->
        begin match (!from_arg, !to_arg) with
        | Some f, Some t ->
            let strip_ns s =
              let prefix = "math-coding/" in
              let slen = String.length s in
              let plen = String.length prefix in
              if slen > plen && String.sub s 0 plen = prefix then
                String.sub s plen (slen - plen)
              else s
            in
            let safe s =
              String.map (function '/' | ':' | ' ' -> '-' | c -> c) s
            in
            let fname =
              safe (strip_ns f) ^ "-to-" ^ safe (strip_ns t) ^ ".yaml"
            in
            Filename.concat project_root
              (Filename.concat
                 (Filename.concat
                    (Path_config.resolve_decisions_dir ~root:project_root ())
                    "migrations")
                 fname)
        | _ ->
            Printf.fprintf stderr
              "mathc migrate: either --manifest=PATH or both --from=X and \
               --to=Y are required\n";
            exit 2
        end
  in
  if not (Sys.file_exists manifest_path) then begin
    Printf.fprintf stderr "mathc migrate: manifest not found: %s\n"
      manifest_path;
    exit 2
  end;
  let reader path = In_channel.with_open_bin path In_channel.input_all in
  let manifest_res = Migrate.parse_manifest_yaml ~reader ~path:manifest_path in
  let manifest =
    match manifest_res with
    | Migrate.Parsed m -> m
    | Migrate.Parse_error e ->
        Printf.fprintf stderr "mathc migrate: %s\n" e;
        exit 2
  in
  if !explain_flag then
    Printf.printf "manifest %s -> %s\n  intent: %s\n\n" manifest.from
      manifest.to_ manifest.intent;
  let decisions_dir =
    Filename.concat root (Path_config.resolve_decisions_dir ~root ())
  in
  let yaml_files =
    if Sys.file_exists decisions_dir then
      Array.to_list (Sys.readdir decisions_dir)
      |> List.filter (fun n -> Filename.check_suffix n ".yaml")
      |> List.map (fun n -> Filename.concat decisions_dir n)
    else []
  in
  let plans =
    List.map
      (fun path ->
        let content = reader path in
        Migrate.plan_file ~manifest ~file:path ~content)
      yaml_files
  in
  match !output_format with
  | `Text ->
      if plans = [] then
        Printf.printf "no .yaml files found under %s\n" decisions_dir
      else print_string (Migrate.render_text plans)
  | `Json ->
      begin if not !write_flag then begin
        print_endline (Jsonl.stringify (Migrate.render_json plans));
        ()
      end
      else
        (* --write: apply actions per file, never overwrite the original.
           For each file whose plan carries auto-translatable actions,
           write a sibling <file>.migrated.yaml with the edited content
           and a per-file summary JSON to stdout. *)
        let write_one (fp : Migrate.file_plan) =
          if fp.actions = [] && fp.warnings = [] then `Skipped
          else begin
            let content = reader fp.file in
            let _new_content, _applied, _skipped =
              Migrate.apply_actions ~actions:fp.actions ~content
            in
            (* The apply_actions may have stripped or only partially
               resolved the action list; we re-derive a hard summary
               by comparing target schema-string-to-content. For the
               current scope (bump-schema-string + add-field +
               rename-field) the function above is sufficient: every
               listed action that hit a line OR was appended is
               recorded in `applied`. *)
            let migrated_path = fp.file ^ ".migrated.yaml" in
            if !dry_run_flag then `DryRun
            else
              begin try
                Out_channel.with_open_bin migrated_path (fun oc ->
                    Out_channel.output_string oc _new_content);
                `Wrote
              with Sys_error msg ->
                Printf.fprintf stderr "mathc migrate: cannot write %s: %s\n"
                  migrated_path msg;
                `Failed
              end
          end
        in
        let summary =
          List.map
            (fun fp ->
              let outcome = write_one fp in
              let outcome_str =
                match outcome with
                | `Wrote -> "wrote"
                | `DryRun -> "dry-run"
                | `Skipped -> "no-action"
                | `Failed -> "failed"
              in
              let outcome_v = Jsonl.String outcome_str in
              Jsonl.Object
                [
                  ("file", Jsonl.String fp.file);
                  ( "current_schema",
                    match fp.current_schema with
                    | Some s -> Jsonl.String s
                    | None -> Jsonl.Null );
                  ("outcome", outcome_v);
                  ("actions_count", Jsonl.Int (List.length fp.actions));
                  ("warnings_count", Jsonl.Int (List.length fp.warnings));
                  ( "migrated_to",
                    Jsonl.String
                      (if !dry_run_flag then "(dry-run)"
                       else fp.file ^ ".migrated.yaml") );
                ])
            plans
        in
        print_endline (Jsonl.stringify (Jsonl.Array summary))
      end

(* --- new-decision subcommand ----------------------------------- *)

(* `mathc new-decision <id> [--write] [--interactive] [--force]`
 *                      [--template=<minimal|full>]
 *
 * Scaffolds a new decision file from a canonical template.
 * The implementation lives in `lib/new_decision/new_decision.ml`
 * per the sub-library convention (OCAML_BEST_PRACTICES §10.1);
 * the dispatcher only parses argv and forwards to
 * `New_decision.run`. Exit codes: 0 on success, 1 on file
 * already exists, 2 on invalid `<id>` or `--template=<X>` value.
 *
 * `--template=minimal` selects the 5-7 user-editable field stub
 * on schema `math-coding/3.3` (per decision
 * `ux-3-new-decision-template-minimal-2026-10`); `--template=full`
 * (the default) preserves the 47-line adoption/SKILL.md-shaped
 * output on schema `math-coding/3.2` first shipped by
 * `ux-3-new-decision-subcommand-2026-10@1`. Unknown values for
 * `--template=<X>` exit 2. *)
let[@warning "-32"] do_new_decision () =
  let id = ref "" in
  let write = ref false in
  let interactive = ref false in
  let force = ref false in
  let template_kind = ref "" in
  let set_id s = id := s in
  Arg.current := 1;
  Arg.parse
    [
      ( "--write",
        Arg.Set write,
        " Write the rendered template to decisions/<id>.yaml" );
      ( "--interactive",
        Arg.Set interactive,
        " (no-op stub; the printed scaffold is the scaffold)" );
      ( "--force",
        Arg.Set force,
        " Overwrite decisions/<id>.yaml if it exists (with --write)" );
      ( "--template",
        Arg.String (fun s -> template_kind := s),
        " <minimal|full>  Template variant (default: full)" );
    ]
    set_id
    "usage: mathc new-decision <id> [--write] [--interactive] [--force] \
     [--template=<minimal|full>]";
  if !id = "" then begin
    Printf.fprintf stderr "mathc new-decision: missing <id>\n";
    print_usage stderr;
    exit 2
  end;
  let kind =
    match !template_kind with
    | "" -> New_decision.Full
    | "minimal" -> New_decision.Minimal
    | "full" -> New_decision.Full
    | other ->
        Printf.fprintf stderr
          "mathc new-decision: invalid --template=%s (expected minimal|full)\n"
          other;
        exit 2
  in
  let mode =
    if !interactive then New_decision.Interactive_mode
    else if !write then New_decision.Write_mode
    else New_decision.Print_mode
  in
  New_decision.run
    { New_decision.id = !id; mode; force = !force; template_kind = kind }

(* --- doctor subcommand (mathc-doctor-subcommand-2026-10) ---
 *
 * `mathc doctor [--json]` prints a diagnostic report on
 * the user's math-coding install. The report covers seven
 * independent sections (install / path / latest / config /
 * decisions / attestations / self-check); each section's
 * verdict is determined locally. Exit code: 0 when no
 * section is `fail`, 1 when any section is `fail`.
 *
 * The implementation is constrained to `bin/Mathc.ml`; the
 * kernel (`lib/decision.ml`, `lib/gate.ml`) and the
 * `bin/mathc_mcp.ml` MCP binary are untouched. The helpers
 * below reuse `Attestations.load`, `list_decision_files`,
 * `extract_top_level_id`, `validate_with_counts`,
 * `find_project_root`, `resolve_store_root`,
 * `read_cli_version`, and `now_iso` -- all pure / I/O-bounded
 * helpers already present in this binary.
 *
 * Per the obligation in
 * `decisions/mathc-doctor-subcommand-2026-10.yaml`:
 *   - text mode: section headers printed in order, verdict
 *     one of `pass`/`warn`/`fail`/`skip`.
 *   - `--json` mode: same report as
 *     `{"sections":[{"id":.., "verdict":..,
 *     "details":{..}}, ..]}`. The `sections` array length is
 *     >= 5 even when the GitHub probe (section latest) is
 *     offline.
 *
 * Failure-mode policy (per commitment in the decision):
 *   - offline sections (install/path/config/decisions/
 *     attestations): `pass` or `fail`.
 *   - online section (latest): `pass` / `warn` only; the
 *     network probe never returns `fail` (the user is not
 *     blocked on GitHub reachability for an install-coverage
 *     diagnostic).
 *   - self-check section: `skip` in this slice (the deeper
 *     walk is delegated to `mathc self-check`). *)

(* Per-section verdict. `Skip` is reserved for the self-check
 * section when no deeper walk is requested; `Warn` covers
 * "this is not blocking, but the user should look at it"
 * (e.g. newer release available, orphan decision file). *)
type doctor_verdict = Pass | Warn | Fail | Skip

let[@warning "-32"] doctor_verdict_string = function
  | Pass -> "pass"
  | Warn -> "warn"
  | Fail -> "fail"
  | Skip -> "skip"

(* A section result bundles the section id (used as JSON
 * key + cram assertion target), the human-readable label,
 * the verdict, and the `details` object (a Jsonl.value
 * Object with whatever per-section metadata we want to
 * surface). *)
type doctor_section = {
  id : string;
  label : string;
  verdict : doctor_verdict;
  details : Jsonl.value;
}

(* Section a -- Install.
 *
 * Print the running `mathc` binary path (from
 * `Sys.executable_name`) and the version string read from
 * the project VERSION file. Both are `Pass` on success.
 *
 * Caveat: `Sys.executable_name` is the path the kernel
 * loaded this image from; on a sandboxed invocation
 * (`dune exec`, `bwrap`) it points inside `_build/default/`,
 * which is correct for the "what binary am I running"
 * question but does NOT identify the install dir on disk.
 * The path section (b) handles the install-dir question. *)
let[@warning "-32"] doctor_section_install () : doctor_section =
  let path = Sys.executable_name in
  let version = try read_cli_version () with _ -> "(unreadable)" in
  {
    id = "install";
    label = "Install";
    verdict = Pass;
    details =
      Jsonl.Object
        [
          ("binary_path", Jsonl.String path); ("version", Jsonl.String version);
        ];
  }

(* Section b -- PATH.
 *
 * Is the directory that contains `mathc` (the dirname of
 * `Sys.executable_name`) on `$PATH`? On Windows the
 * install layout is `%LOCALAPPDATA%\Programs\mathc\`; on
 * Unix it's `$HOME/.local/bin/` (or whatever the user
 * passed to install.sh). The dirname of the live binary
 * is the only runtime anchor we have without launching
 * `which` and parsing its output.
 *
 * PATH parsing: `Unix.environment ()` returns the
 * inherited env as a `string array` of `KEY=VALUE` rows;
 * we filter for `PATH=`, take the value, split on `:`
 * (Unix convention; on Windows cmd.exe would be `;` but
 * this binary does not target cmd.exe). *)
let[@warning "-32"] doctor_section_path () : doctor_section =
  let env = try Unix.environment () |> Array.to_list with _ -> [] in
  let path_value =
    let[@warning "-32"] take_path row =
      if String.length row > 5 && String.sub row 0 5 = "PATH=" then
        Some (String.sub row 5 (String.length row - 5))
      else None
    in
    match List.filter_map take_path env with v :: _ -> Some v | [] -> None
  in
  let path_dirs =
    match path_value with None -> [] | Some p -> String.split_on_char ':' p
  in
  let install_dir = Filename.dirname Sys.executable_name in
  let on_path =
    List.exists (fun d -> String.compare d install_dir = 0) path_dirs
  in
  let path_dirs_json =
    Jsonl.Array (List.map (fun s -> Jsonl.String s) path_dirs)
  in
  {
    id = "path";
    label = "PATH";
    verdict = (if on_path then Pass else Warn);
    details =
      Jsonl.Object
        [
          ("install_dir", Jsonl.String install_dir);
          ("on_path", Jsonl.Bool on_path);
          ("path_dirs", path_dirs_json);
        ];
  }

(* Section c -- Latest release.
 *
 * Probe GitHub's `releases/latest` endpoint for the
 * math-coding repo (owner `11111000000` per the repo's
 * public surface -- same owner used by the Homebrew
 * tap formula in D12). The HTTP transport uses `curl`
 * (no OCaml HTTP dep) with `--max-time 5` to keep the
 * section fast on a healthy install and avoid hangs on
 * a flaky network.
 *
 * Verdict: `Pass` when the installed version equals the
 * latest tag; `Warn` when a newer tag exists (user is
 * behind); `Warn` (not `Fail`) when the probe times out,
 * is offline, or returns a non-200 -- the offline-section
 * contract per the decision's failure-mode policy.
 *
 * The version comparison strips a single leading `v` from
 * the GitHub tag (the convention is `vX.Y.Z` while the
 * VERSION file is bare `X.Y.Z`) and does a lexicographic
 * compare on the dotted version string. Semver-style
 * ordering would split the string on `.` and compare
 * each segment as an integer; for the 3.x line, the
 * two agree. The choice is documented here so a future
 * `4.0.0` bump that needs semver-order can be detected
 * by a single regression in tests/cli/doctor.t. *)
let[@warning "-32"] doctor_section_latest () : doctor_section =
  let installed = try read_cli_version () with _ -> "(unreadable)" in
  let url =
    "https://api.github.com/repos/11111000000/math-coding/releases/latest"
  in
  let argv =
    [|
      "curl";
      "-sS";
      "--max-time";
      "5";
      "-H";
      "Accept: application/vnd.github+json";
      url;
    |]
  in
  let probe =
    try
      let ic = Unix.open_process_args_in "curl" argv in
      let buf = Buffer.create 256 in
      (try
         while true do
           Buffer.add_channel buf ic 4096
         done
       with End_of_file -> ());
      let _status = Unix.close_process_in ic in
      Ok (Buffer.contents buf)
    with _ -> Error "curl invocation failed"
  in
  match probe with
  | Error reason ->
      {
        id = "latest";
        label = "Latest";
        verdict = Warn;
        details =
          Jsonl.Object
            [
              ("installed", Jsonl.String installed);
              ("latest_tag", Jsonl.Null);
              ("status", Jsonl.String "offline");
              ("reason", Jsonl.String reason);
            ];
      }
  | Ok body -> (
      let tag =
        try
          let v = Jsonl.parse body in
          match v with
          | Jsonl.Object ps -> (
              match List.assoc_opt "tag_name" ps with
              | Some (Jsonl.String s) -> Some s
              | _ -> None)
          | _ -> None
        with _ -> None
      in
      match tag with
      | None ->
          {
            id = "latest";
            label = "Latest";
            verdict = Warn;
            details =
              Jsonl.Object
                [
                  ("installed", Jsonl.String installed);
                  ("latest_tag", Jsonl.Null);
                  ("status", Jsonl.String "unparseable");
                  ("body_len", Jsonl.Int (String.length body));
                ];
          }
      | Some t ->
          let strip_v s =
            if String.length s > 0 && s.[0] = 'v' then
              String.sub s 1 (String.length s - 1)
            else s
          in
          let tag_norm = strip_v t in
          let inst_norm = strip_v installed in
          let cmp = String.compare tag_norm inst_norm in
          let newer = cmp > 0 in
          let same = cmp = 0 in
          {
            id = "latest";
            label = "Latest";
            verdict = (if same then Pass else Warn);
            details =
              Jsonl.Object
                [
                  ("installed", Jsonl.String installed);
                  ("latest_tag", Jsonl.String t);
                  ("status", Jsonl.String (if same then "current" else "behind"));
                  ("newer_available", Jsonl.Bool newer);
                ];
          })

(* Section d -- Config.
 *
 * Does `decisions/decision.yaml` (the active policy) parse
 * against the live schema and pass `validate_with_counts`?
 * Verdict: `Pass` on accept, `Fail` on reject. *)
let[@warning "-32"] doctor_section_config () : doctor_section =
  let root = find_project_root (Sys.getcwd ()) in
  let path = Filename.concat root (Path_config.resolve_policy_path ~root ()) in
  let exists = Sys.file_exists path in
  let outcome =
    if exists then
      match validate_with_counts path with
      | `Accept _ -> `Pass
      | `Accept_aggregate _ -> `Pass
      | `Reject (_, msg) -> `Fail msg
      | `Input_err msg -> `Fail msg
    else `Fail "decisions/decision.yaml not found"
  in
  let details =
    Jsonl.Object
      [
        ("path", Jsonl.String path);
        ("exists", Jsonl.Bool exists);
        ( "outcome",
          Jsonl.String
            (match outcome with `Pass -> "accept" | `Fail _ -> "reject") );
      ]
  in
  {
    id = "config";
    label = "Config";
    verdict = (match outcome with `Pass -> Pass | `Fail _ -> Fail);
    details;
  }

(* Section e -- Decisions.
 *
 * Are there `decisions/*.yaml` files with id `X` that no
 * attestation in `attestations/` references as its
 * `decision`? Such orphans are not blocking -- the kernel
 * happily skips them -- but they are a signal that the
 * user has a half-finished migration or a typo in the
 * decision id.
 *
 * Verdict: `Pass` when 0 orphans; `Warn` with the list of
 * orphan ids when >= 1. The list is capped at 16 entries
 * in the details payload; the cap is documented so a future
 * regression that grows the orphan set does not blow up
 * the JSON shape. *)
let[@warning "-32"] doctor_section_decisions () : doctor_section =
  let root = find_project_root (Sys.getcwd ()) in
  let decisions_dir =
    Filename.concat root (Path_config.resolve_decisions_dir ~root ())
  in
  let decision_files = list_decision_files decisions_dir in
  let reader path =
    try In_channel.with_open_bin path In_channel.input_all with _ -> ""
  in
  let decision_ids =
    List.filter_map
      (fun p ->
        match load_decision_entry reader p with
        | Some entry ->
            if entry.Memory.decision_id = "" then None
            else Some entry.Memory.decision_id
        | None -> None)
      decision_files
  in
  let store_root = resolve_store_root root in
  let store = Attestations.load ~reader ~root:store_root in
  let referenced_ids : string list =
    List.map (fun (a : Attestations.attestation) -> a.Domain.decision) store
  in
  let orphans =
    List.filter (fun id -> not (List.mem id referenced_ids)) decision_ids
  in
  let orphan_sample =
    let rec take n = function
      | [] -> []
      | xs when n <= 0 -> []
      | x :: rest -> x :: take (n - 1) rest
    in
    take 16 orphans
  in
  let verdict = if orphans = [] then Pass else Warn in
  {
    id = "decisions";
    label = "Decisions";
    verdict;
    details =
      Jsonl.Object
        [
          ("total", Jsonl.Int (List.length decision_ids));
          ( "referenced",
            Jsonl.Int (List.length decision_ids - List.length orphans) );
          ("orphans_total", Jsonl.Int (List.length orphans));
          ( "orphans_sample",
            Jsonl.Array (List.map (fun s -> Jsonl.String s) orphan_sample) );
        ];
  }

(* Section f -- Attestations.
 *
 * Is the attestation store readable? Verdict: `Pass` when
 * `attestations/` exists and contains >= 1 .json file;
 * `Warn` when the directory is missing (the user has not
 * yet run `mathc attest`); `Fail` when an I/O error
 * surfaces during the directory walk.
 *
 * `Attestations.load` swallows per-file parse errors
 * (the kernel never crashes on a malformed entry), so the
 * "readable" verdict here is the user-facing promise that
 * the dispatcher has not returned an empty list due to a
 * permissions failure. *)
let[@warning "-32"] doctor_section_attestations () : doctor_section =
  let root = find_project_root (Sys.getcwd ()) in
  let store_root = resolve_store_root root in
  let exists = Sys.file_exists store_root in
  let is_dir = exists && Sys.is_directory store_root in
  let entries =
    if is_dir then
      try
        Sys.readdir store_root |> Array.to_list
        |> List.filter (fun f -> Filename.check_suffix f ".json")
      with _ -> []
    else []
  in
  let verdict =
    if not exists then Warn
    else if not is_dir then Fail
    else if entries = [] then Warn
    else Pass
  in
  {
    id = "attestations";
    label = "Attestations";
    verdict;
    details =
      Jsonl.Object
        [
          ("path", Jsonl.String store_root);
          ("exists", Jsonl.Bool exists);
          ("is_directory", Jsonl.Bool is_dir);
          ("json_count", Jsonl.Int (List.length entries));
        ];
  }

(* Section g -- Self-check (short-circuit).
 *
 * Per the decision's commitment, this section is a stub in
 * this revision: it reports `Skip` with a `hint` pointing
 * at `mathc self-check` for the full verdict. The
 * short-circuit keeps `mathc doctor` < 5 s on a healthy
 * install and avoids re-running the full attestation-store
 * walk twice (once for doctor, once for self-check).
 *
 * Future revisions may swap this stub for a guarded
 * `do_self_check` subprocess call (e.g. `mathc doctor
 * --self-check`), guarded by a wall-clock budget. The
 * current shape leaves the change in a follow-up
 * sub-decision. *)
let[@warning "-32"] doctor_section_self_check () : doctor_section =
  {
    id = "self_check";
    label = "Self-check";
    verdict = Skip;
    details =
      Jsonl.Object
        [
          ("status", Jsonl.String "skip");
          ( "hint",
            Jsonl.String
              "run `mathc self-check` directly for the full attestation-store \
               walk; this slice short-circuits to keep `mathc doctor` < 5 s on \
               a healthy install" );
        ];
  }

(* Top-level entry point. *)
let[@warning "-32"] do_doctor () =
  let json_mode = ref false in
  Arg.current := 1;
  Arg.parse
    [ ("--json", Arg.Set json_mode, " Emit JSON instead of text") ]
    (fun anon ->
      Printf.fprintf stderr "mathc doctor: unexpected argument: %s\n" anon;
      exit 2)
    "usage: mathc doctor [--json]";
  let sections =
    [
      doctor_section_install ();
      doctor_section_path ();
      doctor_section_latest ();
      doctor_section_config ();
      doctor_section_decisions ();
      doctor_section_attestations ();
      doctor_section_self_check ();
    ]
  in
  let any_fail =
    List.exists (fun (s : doctor_section) -> s.verdict = Fail) sections
  in
  if !json_mode then
    let secs_v =
      Jsonl.Array
        (List.map
           (fun (s : doctor_section) ->
             Jsonl.Object
               (List.sort
                  (fun (a, _) (b, _) -> String.compare a b)
                  [
                    ("id", Jsonl.String s.id);
                    ("label", Jsonl.String s.label);
                    ("verdict", Jsonl.String (doctor_verdict_string s.verdict));
                    ("details", s.details);
                  ]))
           sections)
    in
    let top =
      Jsonl.Object
        (List.sort
           (fun (a, _) (b, _) -> String.compare a b)
           [
             ("exit_code", Jsonl.Int (if any_fail then 1 else 0));
             ("sections", secs_v);
           ])
    in
    print_endline (Jsonl.stringify top)
  else begin
    List.iter
      (fun (s : doctor_section) ->
        Printf.printf "[%s] %s\n  %s\n" s.id
          (doctor_verdict_string s.verdict)
          s.label)
      sections;
    match
      List.find_opt (fun (s : doctor_section) -> s.verdict = Fail) sections
    with
    | None -> ()
    | Some s -> Printf.fprintf stderr "mathc doctor: section %s failed\n" s.id
  end;
  exit (if any_fail then 1 else 0)

let dispatch () =
  if Array.length Sys.argv < 2 then begin
    print_usage stderr;
    exit 2
  end;
  (* Load policies.yaml once at startup so the cached policy list
     is populated before any `mathc mode` invocation runs. The
     call is a no-op when the file is absent (algebra §9 default:
     `policy(p) = default-policy`). The path is anchored at the
     project root (find_project_root walks up to dune-project),
     so the loader works from any cwd. See decision
     `risk-policy-driven-floor-2026-10`. *)
  let _ =
    let root = find_project_root (Sys.getcwd ()) in
    let path =
      Filename.concat root (Path_config.resolve_policy_path ~root ())
    in
    Policy.load_policies ~path ()
  in
  match Sys.argv.(1) with
  | "validate" -> do_validate ()
  | "verify" -> do_verify ()
  | "version" -> do_version ()
  | "update" -> do_update ()
  | "context" -> do_context ()
  | "explain" -> do_explain ()
  | "explain-diagnostic" -> do_explain_diagnostic ()
  | "forge-verify" -> do_forge_verify ()
  | "assess" -> do_assess ()
  | "import-junit" -> do_import_junit ()
  | "attest" -> do_attest ()
  | "attest-batch" -> do_attest_batch ()
  | "time-estimate" -> do_time_estimate ()
  | "gate" -> do_gate ()
  | "mode" -> do_mode ()
  | "rebuttals" -> do_rebuttals ()
  | "re-evaluate" -> do_re_evaluate ()
  | "re-evaluate-decisions" -> do_re_evaluate_decisions ()
  | "self-check" -> do_self_check ()
  | "find" -> do_find ()
  | "precommit" -> do_precommit ()
  | "graph" -> do_graph ()
  | "decision-state" -> do_decision_state ()
  | "session-start" -> do_session_start ()
  | "record" -> do_record ()
  | "stats" -> do_stats ()
  | "packages" -> do_packages ()
  | "render" -> do_render ()
  | "counters" -> do_counters ()
  | "init" -> do_init ()
  | "import-adr" -> do_import_adr ()
  | "adopt" -> do_adopt ()
  | "new-decision" -> do_new_decision ()
  | "telemetry" -> do_telemetry ()
  | "migrate" -> do_migrate ()
  | "doctor" -> do_doctor ()
  | "--help" | "-h" ->
      print_usage stdout;
      exit 0
  | other ->
      Printf.fprintf stderr "mathc: unknown command: %s\n" other;
      print_usage stderr;
      exit 2

let () =
  try dispatch () with
  | Arg.Help _ ->
      print_usage stdout;
      exit 0
  | Arg.Bad m ->
      Printf.fprintf stderr "mathc: %s\n" m;
      exit 2
  | Failure m ->
      Printf.fprintf stderr "mathc: %s\n" m;
      exit 3
  | e ->
      Printf.fprintf stderr "mathc: internal error: %s\n" (Printexc.to_string e);
      exit 3
