(* lib/migrate.ml — pure migration manifest parser + per-file planner.
 *
 * A migration "manifest" is a declarative artifact that says what
 * would have to change for a decision file at FROM-version to be
 * acceptable under TO-version. The kernel NEVER modifies YAML on
 * disk; it only:
 *
 *   1. reads the manifest,
 *   2. walks a root of YAML files (typically `decisions/*.yaml`),
 *   3. prints a per-file plan (text or JSON) listing what would
 *      change if an agent applied it.
 *
 * An agent (or human) doing the actual edit reads the plan and
 * applies the changes itself, then re-runs `mathc validate` to
 * confirm. This isolates the kernel's role: it only observes and
 * describes; it does not mutate content. The decision to mutate
 * lives with the agent, who can stage, review, and `git revert`.
 *
 * Vocabulary (declared in the manifest itself; the kernel accepts
 * these kinds and refuses unknown kinds):
 *
 *   - rename-field      { from_; to_ }      (both at root level)
 *   - add-field         { path; default_ }  (only when path absent)
 *   - bump-schema-string { from; to }       (mutate the schema field)
 *   - manual-review     { reason }          (no kernel transform;
 *                                            surface as warning so the
 *                                            agent decides)
 *
 * No I/O is performed in this module. Callers pass reader funcs
 * and decoded content strings; the module returns pure values.
 *)

(* --- types ------------------------------------------------------------- *)

type field_ref = string

type migration =
  | Rename_field of { from_ : field_ref; to_ : field_ref }
  | Add_field of { path : field_ref; default_ : string }
  | Bump_schema of { from : string; to_ : string }
  | Manual_review of { reason : string }

type manifest = {
  from : string;
  to_ : string;
  intent : string;
  migrations : migration list;
}

type file_plan = {
  file : string;
  current_schema : string option;
  actions : migration list;
  warnings : string list;
}

type result_ =
  | Parsed of manifest
  | Parse_error of string

(* --- manifest parser (no I/O) ----------------------------------------- *)

let empty_result = Parse_error "manifest is not a YAML object"

(* Extract the `schema` top-level string field; the migration
   manifest must declare either `math-coding/migration-manifest` or
   be missing it (some shops use no schema-string on internal
   artefacts). We accept either. *)
let manifest_schema_ok v =
  match v with
  | Jsonl.Object pairs ->
      (match Schema.take_string pairs "schema" with
       | None -> true
       | Some s -> s = "math-coding/migration-manifest")
  | _ -> false

let parse_migration v : (migration, string) result =
  match v with
  | Jsonl.Object pairs ->
      let kind =
        match Schema.take_string pairs "kind" with
        | Some s -> s
        | None -> ""
      in
      (match kind with
       | "rename-field" -> begin
           match Schema.take_string pairs "from",
                 Schema.take_string pairs "to" with
           | Some f, Some t ->
               Ok (Rename_field { from_ = f; to_ = t })
           | _ ->
               Error "rename-field requires from + to (both strings)"
         end
       | "add-field" -> begin
           match Schema.take_string pairs "path",
                 Schema.take_string pairs "default" with
           | Some p, Some d ->
               Ok (Add_field { path = p; default_ = d })
           | _ ->
               Error "add-field requires path + default (both strings)"
         end
| "bump-schema-string" -> begin
               match Schema.take_string pairs "from",
                     Schema.take_string pairs "to" with
               | Some f, Some t ->
                   Ok (Bump_schema { from = f; to_ = t })
               | _ ->
                   Error
                     "bump-schema-string requires from + to (both strings)"
             end
       | "manual-review" -> begin
           match Schema.take_string pairs "reason" with
           | Some r -> Ok (Manual_review { reason = r })
           | None -> Error "manual-review requires reason (string)"
         end
       | "" ->
           Error "migration.kind: missing required field `kind`"
       | other ->
           Error ("migration.kind: unknown kind `" ^ other ^ "`"))
  | _ -> Error "migration: not a YAML object"

let parse_manifest_yaml
    ~(reader : string -> string)
    ~(path : string) : result_ =
  let raw = reader path in
  let v = Codec.load_yaml_string raw in
  match v with
  | v when not (manifest_schema_ok v) ->
      Parse_error
        ("manifest schema-string is not `math-coding/migration-manifest`: "
        ^ path)
  | Jsonl.Object pairs -> (
      let from =
        match Schema.take_string pairs "from" with
        | Some s -> s
        | None -> ""
      in
      let to_ =
        match Schema.take_string pairs "to" with
        | Some s -> s
        | None -> ""
      in
      let intent =
        match Schema.take_string pairs "intent" with
        | Some s -> s
        | None -> ""
      in
      let migrations_v =
        match Schema.take_array pairs "migrations" with
        | Some xs -> xs
        | None -> []
      in
      if from = "" then
        Parse_error "manifest: missing required field `from` (string)"
      else if to_ = "" then
        Parse_error "manifest: missing required field `to` (string)"
      else
        let parsed, errs =
          List.fold_left
            (fun (acc_ok, acc_err) it ->
              match parse_migration it with
              | Ok m -> (m :: acc_ok, acc_err)
              | Error e -> (acc_ok, e :: acc_err))
            ([], []) migrations_v
        in
        (match errs with
         | [] -> Parsed { from; to_; intent; migrations = List.rev parsed }
         | _ :: _ ->
             Parse_error
               ("manifest migrations[] errors: "
                ^ String.concat "; " errs)))
  | _ -> empty_result

(* --- per-file plan (no I/O) -------------------------------------------- *)

(* Read the schema-string at root of a decision file (best-effort;
   a parse failure means the file is not a recognised decision file
   and the plan surfaces a manual-review warning). *)
let decision_schema_string content : (string option, string) result =
  try
    let v = Codec.load_yaml_string content in
    match v with
    | Jsonl.Object pairs ->
        Ok (Schema.take_string pairs "schema")
    | _ -> Error "decision file: not a YAML object at root"
  with _ -> Error "decision file: could not be parsed as YAML"

(* True iff `name` appears as a top-level scalar key in a decision
   object. Returns false on parse failure or non-object. *)
let has_top_field content name : bool =
  match Codec.load_yaml_string content with
  | Jsonl.Object pairs ->
      List.exists (fun (k, _) -> k = name) pairs
  | _ -> false

(* Plan a single file. Returns zero actions for files whose
   schema-string already matches `to_`. *)
let plan_file
    ~(manifest : manifest)
    ~(file : string)
    ~(content : string) : file_plan =
  let schema_res = decision_schema_string content in
  match schema_res with
  | Error e ->
      {
        file;
        current_schema = None;
        actions = [];
        warnings = [ "manual-review: " ^ e ];
      }
  | Ok (Some cs) when cs = manifest.to_ ->
      (* file is already at target version; no actions *)
      { file; current_schema = Some cs; actions = []; warnings = [] }
  | Ok (Some cs) when cs <> manifest.from ->
      (* file is at some other version — neither from nor to;
         agent must reconcile manually. *)
      {
        file;
        current_schema = Some cs;
        actions = [];
        warnings =
          [
            Printf.sprintf
              "manual-review: file is at `%s`; manifest expects `%s` \
               (neither matches the target `%s`)"
              cs manifest.from manifest.to_;
          ];
      }
  | Ok (Some _) ->
      (* current_schema matches manifest.from (or is None,
         which we treat as "from"). Apply auto-translatable steps
         and record warnings for the rest. *)
      let actions =
        List.filter_map
          (fun m ->
            match m with
            | Rename_field { from_; to_ } ->
                if has_top_field content from_ then Some m else None
            | Add_field { path; _ } ->
                if has_top_field content path then None else Some m
            | Bump_schema { from = bf; to_ = bt } ->
                Some (Bump_schema { from = bf; to_ = bt })
            | Manual_review _ -> None)
          manifest.migrations
      in
      let warnings =
        List.filter_map
          (fun m ->
            match m with
            | Manual_review { reason } -> Some ("manual-review: " ^ reason)
            | _ -> None)
          manifest.migrations
      in
      {
        file;
        current_schema = Some manifest.from;
        actions;
        warnings;
      }
  | Ok None ->
      {
        file;
        current_schema = None;
        actions = [];
        warnings =
          [ "manual-review: decision file has no schema-string" ];
      }

(* --- renderers --------------------------------------------------------- *)

let migration_to_string = function
  | Rename_field { from_; to_ } -> "rename-field: " ^ from_ ^ " -> " ^ to_
  | Add_field { path; default_ } ->
      Printf.sprintf "add-field: %s = %S" path default_
  | Bump_schema { from; to_ } ->
      "bump-schema-string: " ^ from ^ " -> " ^ to_
  | Manual_review { reason } -> "manual-review: " ^ reason

let render_text (plans : file_plan list) : string =
  let buf = Buffer.create 256 in
  List.iter
    (fun p ->
      Buffer.add_string buf p.file;
      Buffer.add_string buf "\n  schema: ";
      Buffer.add_string buf
        (Option.value p.current_schema ~default:"<unparsed>");
      Buffer.add_char buf '\n';
      List.iter
        (fun a ->
          Buffer.add_string buf "  action: ";
          Buffer.add_string buf (migration_to_string a);
          Buffer.add_char buf '\n')
        p.actions;
      List.iter
        (fun w ->
          Buffer.add_string buf "  warning: ";
          Buffer.add_string buf w;
          Buffer.add_char buf '\n')
        p.warnings)
    plans;
  Buffer.contents buf

let plan_to_json (p : file_plan) : Jsonl.value =
  let actions_v =
    Jsonl.Array
      (List.map
         (fun m ->
           match m with
           | Rename_field { from_; to_ } ->
               Jsonl.Object
                 [
                   ("kind", Jsonl.String "rename-field");
                   ("from", Jsonl.String from_);
                   ("to", Jsonl.String to_);
                 ]
           | Add_field { path; default_ } ->
               Jsonl.Object
                 [
                   ("kind", Jsonl.String "add-field");
                   ("path", Jsonl.String path);
                   ("default", Jsonl.String default_);
                 ]
           | Bump_schema { from; to_ } ->
               Jsonl.Object
                 [
                   ("kind", Jsonl.String "bump-schema-string");
                   ("from", Jsonl.String from);
                   ("to", Jsonl.String to_);
                 ]
           | Manual_review { reason } ->
               Jsonl.Object
                 [
                   ("kind", Jsonl.String "manual-review");
                   ("reason", Jsonl.String reason);
                 ])
         p.actions)
  in
  let warnings_v =
    Jsonl.Array (List.map (fun s -> Jsonl.String s) p.warnings)
  in
  let cs_v =
    match p.current_schema with
    | Some s -> Jsonl.String s
    | None -> Jsonl.Null
  in
  Jsonl.Object
    [
      ("file", Jsonl.String p.file);
      ("current_schema", cs_v);
      ("actions", actions_v);
      ("warnings", warnings_v);
    ]

let render_json (plans : file_plan list) : Jsonl.value =
  Jsonl.Array (List.map plan_to_json plans)
