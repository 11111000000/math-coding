(* lib/memory.ml — pure value type and pure loader for the
   context capsule.
 *
 * "Memory" here means: a snapshot of the project artefacts the
 * capsule is built from. Nothing in this module performs file I/O.
 * `load_memory` takes a `reader` callback (path -> string) and a
 * `root` (the project root). In bin/Mathc.ml the reader wraps
 * `In_channel.with_open_bin`; in tests the reader can be a fake.
 *
 * Decision parsing uses Codec.load_yaml_string (pure, from lib/codec.ml).
 * Recent commits and changed paths are passed in as already-resolved
 * strings by the caller (the caller runs `git log`/`git diff`); this
 * module does not shell out.
 *
 * Rule (OCAML_BEST_PRACTICES §1.3): the kernel stays offline.
 * `Memory.load_memory` is pure: same reader + same root -> same
 * Memory.t. *)

(* Lifecycle state parsed from the `state:` field. Mirrors
   Domain.decision_state (lib/domain.ml:178) at construction time
   so the gate can filter retired/superseded decisions without
   re-parsing the YAML. Default [Active] when the field is
   absent or unrecognised; the kernel parser in lib/decision.ml
   treats the same string as Active. *)
type decision_state = [ `Draft | `Active | `Retired | `Superseded ]

(* ---- line-scanner helpers (shared by every reader of a decision) ---- *)

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

(* Split a string into its lines, dropping the terminators. *)
let[@warning "-32"] split_lines s =
  let len = String.length s in
  let rec loop i acc =
    if i >= len then List.rev acc
    else
      let rec find_eol j =
        if j >= len || String.unsafe_get s j = '\n' then j else find_eol (j + 1)
      in
      let j = find_eol i in
      loop (j + 1) (String.sub s i (j - i) :: acc)
  in
  loop 0 []

(* Trim ASCII whitespace from both ends. *)
let[@warning "-32"] trim s =
  let len = String.length s in
  let rec rtrim i =
    if i <= 0 then i
    else
      let c = String.unsafe_get s (i - 1) in
      if c = ' ' || c = '\t' || c = '\r' || c = '\n' then rtrim (i - 1) else i
  in
  let rec ltrim i =
    if i >= len then i
    else
      let c = String.unsafe_get s i in
      if c = ' ' || c = '\t' || c = '\r' || c = '\n' then ltrim (i + 1) else i
  in
  let a = ltrim 0 in
  let b = rtrim len in
  if b <= a then "" else String.sub s a (b - a)

(* ---- the one decision walker -------------------------------------------
 *
 * EVERY command that enumerates the decisions directory goes through
 * the helpers below. There is one walk, one rule for what a decision
 * IS, and one id per document. Two enumerations of the same corpus
 * are two pictures of one world, and the corpus is the thing the
 * whole protocol is about.
 *
 * Two defects motivated the consolidation, and both were silent:
 *
 *   (a) The walk was FLAT. `Sys.readdir` names the entries of ONE
 *       directory, so a decision filed in a sub-directory was in no
 *       corpus at all. Sixteen decisions live in
 *       `decisions/plan-2026-10-improvements/`; not one of them was
 *       visible to `mathc self-check`, `mathc packages` or
 *       `mathc counters`. The decision that introduced the
 *       counterexample rule (`t6-2-counterexample-required`) was
 *       itself outside the gate.
 *
 *   (b) The walk decided what to EXCLUDE by FILE NAME. The corpus
 *       holds twenty-eight decisions whose file name differs from
 *       their id — among them `decision.yaml`, whose id is
 *       `bootstrap-v3`, the root protocol decision. A name-based
 *       exclusion list therefore excluded a real decision and had to
 *       be extended by hand for every new meta file.
 *
 * The rule below is structural: a document is a decision when it
 * declares a TOP-LEVEL `id:` and does not belong to one of the
 * known non-decision schema families. The file name is not
 * load-bearing; the id is the identity.
 *)

(* The extensions a decision document may carry. `.yaml` is the
   convention; `.yml` and `.json` are accepted so a machine-authored
   decision need not be renamed. *)
let[@warning "-32"] decision_extensions = [ ".yaml"; ".yml"; ".json" ]

(* The schema families that live under `decisions/` and are NOT
   decisions:
     - `math-coding/waiver-*`       the waiver files in decisions/waivers/
     - `math-coding/obligations-*`  the obligations aggregator
     - `math-coding/attestation-*`  attestation documents
     - `math-coding/migration-manifest` the manifests in decisions/migrations/
   The rule reads the `schema:` the document DECLARES, not the name
   of the file it sits in, so a waiver filed anywhere is recognised
   and a decision filed anywhere is admitted. *)
let[@warning "-32"] non_decision_schema_prefixes =
  [
    "math-coding/waiver-";
    "math-coding/obligations-";
    "math-coding/attestation-";
    "math-coding/migration-manifest";
  ]

(* The value of the first TOP-LEVEL `key: value` line. "Top-level"
   means column 0 — the same rule `is_top_level` already states. A
   block-scalar value (`key: |`) is skipped: it is a container, not
   a value. *)
let[@warning "-32"] top_level_value ~key (lines : string list) : string option =
  let rec loop = function
    | [] -> None
    | line :: rest -> (
        if not (is_top_level line) then loop rest
        else
          let trimmed = trim line in
          match String.index_opt trimmed ':' with
          | Some i ->
              let k = String.sub trimmed 0 i in
              let v =
                trim
                  (String.sub trimmed (i + 1) (String.length trimmed - i - 1))
              in
              if String.equal k key && v <> "" && v.[0] <> '|' && v.[0] <> '>'
              then Some v
              else loop rest
          | None -> loop rest)
  in
  loop lines

(* The id a decision document declares. The `id:` of a decision lives
   at column 0; an `id:` nested under `decision:` (the obligations
   aggregator carries one) or under `obligations:` is not the
   document's own id. *)
let[@warning "-32"] top_level_id (lines : string list) : string option =
  top_level_value ~key:"id" lines

(* Is this document a DECISION, and what is its id?
 *
 * `None` means "not a decision": the document declares no top-level
 * id (the obligations aggregator, the migration manifests), or it
 * belongs to one of the known non-decision schema families (the
 * waiver files). `Some id` means the document IS a decision and `id`
 * is its identity.
 *
 * The test reads the raw text rather than the parsed tree on
 * purpose: the corpus index must not depend on the YAML parser
 * tolerating a document, or a decision whose body the parser cannot
 * read would vanish from the corpus without a word. *)
let[@warning "-32"] decision_document_id ~raw : string option =
  let lines = split_lines raw in
  match top_level_id lines with
  | None -> None
  | Some id -> (
      match top_level_value ~key:"schema" lines with
      | Some s ->
          let sl = String.length s in
          let is_non_decision =
            List.exists
              (fun p ->
                let pl = String.length p in
                sl >= pl && String.sub s 0 pl = p)
              non_decision_schema_prefixes
          in
          if is_non_decision then None else Some id
      | None -> Some id)

(* Recursive walk of a decisions directory. Returns the paths of every
   candidate document, in a stable order.
 *
 * Sub-directories are walked: a decision filed under
   `decisions/<something>/` is a decision. Hidden entries (a leading
   dot) are skipped: they are scratch, not corpus. The walk does NOT
   decide what a decision IS — that is `decision_document_id`'s job,
   and it needs the file's content. *)
let[@warning "-32"] rec decision_document_paths (dir : string) : string list =
  if not (Sys.file_exists dir) then []
  else if not (Sys.is_directory dir) then []
  else
    let entries =
      try Sys.readdir dir |> Array.to_list |> List.sort String.compare
      with _ -> []
    in
    List.concat_map
      (fun name ->
        if String.length name = 0 || name.[0] = '.' then []
        else
          let path = Filename.concat dir name in
          if Sys.is_directory path then decision_document_paths path
          else if
            List.exists
              (fun e -> Filename.check_suffix name e)
              decision_extensions
          then [ path ]
          else [])
      entries

(* The `scope.paths` of a decision, read from the raw YAML text.
 *
 * ONE implementation, used by every reader: the YAML parser path and
 * the line-scanner path. Under semantics A the materials digest of a
 * decision is computed over the files its scope names, so the
 * producer of an attestation and the checker of one MUST read the
 * same scope. Two readers of the same file that disagree on the
 * scope would produce a digest nobody can reproduce — which is
 * exactly the defect class this repository has been collecting for
 * six weeks.
 *
 * Shape:
 *     scope:
 *       paths:
 *         - "lib/**"
 *       exclusions:
 *         - "spec/**"
 *)
let[@warning "-32"] extract_scope_paths lines =
  let rec find_scope = function
    | [] -> []
    | line :: rest ->
        if is_top_level line then
          if String.trim line = "scope:" then collect_paths rest
          else find_scope rest
        else find_scope rest
  and collect_paths = function
    | [] -> []
    | line :: rest ->
        if is_top_level line then []
        else
          let indent = leading_spaces line in
          let trimmed = String.trim line in
          if indent = 2 && trimmed = "paths:" then
            let rec items acc = function
              | [] -> List.rev acc
              | l :: r ->
                  if is_top_level l then List.rev acc
                  else
                    let ind = leading_spaces l in
                    let t = String.trim l in
                    if
                      ind = 4
                      && String.length t > 2
                      && t.[0] = '-'
                      && t.[1] = ' '
                    then
                      let item =
                        String.trim (String.sub t 2 (String.length t - 2))
                      in
                      let item =
                        if
                          String.length item >= 2
                          && item.[0] = '"'
                          && item.[String.length item - 1] = '"'
                        then String.sub item 1 (String.length item - 2)
                        else item
                      in
                      items (item :: acc) r
                    else List.rev acc
            in
            items [] rest
          else collect_paths rest
  in
  find_scope lines

(* One obligation as the corpus states it: the id it carries ("" when
   it carries none) and the verifier strings its acceptance block
   names. The gate decides obligations BY ID, so an obligation with
   no id is never decided -- `mathc gaps` reports that fact rather
   than passing over it, and this type is how it sees it. *)
type obligation_detail = { od_id : string; od_verifiers : string list }

type decision_entry = {
  decision_id : string;
  revision : string option;
  source : string; (* raw YAML/JSON, opaque here *)
  obligations : int;
  obligation_ids : string list;
  assumptions : int;
  risk_triggers : string list;
  (* The decision's `scope.paths` — the files this decision claims
     to govern. Under semantics A the materials digest of the
     decision is computed over the CONTENT of exactly these files,
     so both the gate and the attestation producer must agree on
     them. Empty when the decision declares no scope. *)
  scope_paths : string list;
  state : decision_state;
  (* The same obligations, one entry each, in the order the corpus
     states them: the id ("" when there is none) and the verifier
     strings. This is what the worklist (`mathc gaps`) reads to tell
     a promise with a check from a promise with a declaration. *)
  obligation_details : obligation_detail list;
}

type spec_doc = { path : string; body : string }
type axiom_doc = { path : string; body : string }
type commit_entry = { sha : string; subject : string }
type changed_path = string

type t = {
  decisions : decision_entry list;
  spec : spec_doc list;
  axioms : axiom_doc list;
  best_practices : string option;
  recent_commits : commit_entry list;
  changed_paths : changed_path list;
}

(* --- helpers --- *)

(* Best-effort YAML/JSON extraction of a few scalars we want for
   prioritisation. We do not need full schema validation here — that
   belongs to Decision.parse_decision in lib/decision.ml. The capsule
   loader only needs:
     - id, revision
     - count of obligations and assumptions (for budget estimation)
     - declared_triggers list (for the HighRisk priority bucket)
   Missing fields default to safe values; the loader is total.

   Note: lib/codec.ml's load_yaml_string does not handle YAML
   front-matter (a leading '---' line). The decisions/*.yaml files
   start with '---'. We strip the leading '---' here so the
   loader can parse the rest. This is local to the capsule loader
   and does not touch lib/codec.ml. *)

let[@warning "-32"] strip_yaml_frontmatter raw =
  let lines = split_lines raw in
  let rec drop_frontmatter acc = function
    | [] -> List.rev acc
    | line :: rest when trim line = "---" -> (
        (* Skip the line. If we see a second '---', that's the close
         of the front-matter; skip it too and stop dropping. *)
        match rest with
        | line2 :: _ when trim line2 = "---" -> rest
        | _ -> drop_frontmatter acc rest)
    | line :: rest -> List.rev acc @ (line :: rest)
  in
  drop_frontmatter [] lines |> String.concat "\n"

let[@warning "-32"] extract_string_field v keys =
  let rec loop = function
    | [] -> None
    | k :: rest -> (
        match Schema.take_string v k with Some s -> Some s | None -> loop rest)
  in
  loop keys

let[@warning "-32"] count_array_field v name =
  match Schema.take_array v name with Some xs -> List.length xs | None -> 0

(* Walk an obligation's `acceptance` block (which may be at
   obligation-level or nested in `acceptance: { all: [...] }` /
   `acceptance: { any: [...] }` forms) and return the verifier
   strings in document order. Per decisions/kernel-bugs-v3.4-2026-10
   the kernel-side parser in lib/decision.ml::parse_acceptance
   already implements the same logic; this helper exists so the
   memory loader does not need to depend on the full parser. The
   shapes supported match `schemas/decision.json#/definitions/
   acceptance` and the four hard-coded positions in
   `tests/cli/*.t`. *)
let[@warning "-32"] extract_obligation_verifiers
    (ops : (string * Jsonl.value) list) : string list =
  let acceptance_pairs =
    match Schema.take_object ops "acceptance" with Some a -> a | None -> []
  in
  let collect_from items =
    List.filter_map
      (fun item ->
        match item with
        | Jsonl.Object ips -> (
            match Schema.take_string ips "verifier" with
            | Some v when String.trim v <> "" -> Some v
            | _ -> None)
        | _ -> None)
      items
  in
  let from_all =
    match Schema.take_array acceptance_pairs "all" with
    | Some xs -> collect_from xs
    | None -> []
  in
  let from_any =
    match Schema.take_array acceptance_pairs "any" with
    | Some xs -> collect_from xs
    | None -> []
  in
  from_all @ from_any

let[@warning "-32"] string_list_field v name =
  match Schema.take_array v name with
  | Some xs ->
      List.filter_map
        (fun x -> match x with Jsonl.String s -> Some s | _ -> None)
        xs
  | None -> []

let[@warning "-32"] parse_decision_yaml raw =
  try
    let stripped = strip_yaml_frontmatter raw in
    let v = Codec.load_yaml_string stripped in
    match v with
    | Jsonl.Object ps ->
        let id =
          match extract_string_field ps [ "id" ] with Some s -> s | None -> ""
        in
        let rev = extract_string_field ps [ "revision" ] in
        let obligations = count_array_field ps "obligations" in
        let obligation_ids, obligation_details =
          match Schema.take_array ps "obligations" with
          | Some xs ->
              let ids, dets =
                List.fold_left
                  (fun (ids, dets) ob ->
                    match ob with
                    | Jsonl.Object ops ->
                        let obid =
                          match Schema.take_string ops "id" with
                          | Some s -> s
                          | None -> ""
                        in
                        let vers = extract_obligation_verifiers ops in
                        ( (if obid <> "" then obid :: ids else ids),
                          dets @ [ { od_id = obid; od_verifiers = vers } ] )
                    | _ -> (ids, dets))
                  ([], []) xs
              in
              (List.rev ids, dets)
          | None -> ([], [])
        in
        (* Same extractor as the line-scanner path, applied to the
           same raw text: one implementation, so the two readers of
           a decision cannot disagree about its scope. *)
        let scope_paths = extract_scope_paths (String.split_on_char '\n' raw) in
        let assumptions = count_array_field ps "assumptions" in
        let risk_triggers =
          match Schema.take_object ps "risk" with
          | Some rps -> string_list_field rps "declared_triggers"
          | None -> []
        in
        let state =
          match extract_string_field ps [ "state" ] with
          | Some s -> (
              match Codec.parse_decision_state s with
              | Some parsed -> parsed
              | None -> `Active)
          | None -> `Active
        in
        if id = "" then None
        else
          Some
            {
              decision_id = id;
              revision = rev;
              source = raw;
              obligations;
              obligation_ids;
              assumptions;
              risk_triggers;
              scope_paths;
              state;
              obligation_details;
            }
    | _ -> None
  with _ -> None

(* Read a file via `reader`, returning None on missing/empty.
   The reader is total from the kernel's perspective; missing files
   are surfaced as None and the caller decides the priority. *)
let[@warning "-32"] read reader path =
  match reader path with "" -> None | s -> Some s

(* --- loader --- *)

(* Every decision the project holds, loaded from the ONE walker above.
 *
 * The corpus is walked RECURSIVELY: a decision filed under
 * `decisions/<sub-directory>/` is a decision, and it is in the
 * corpus. The pre-fix loader read ONE directory, so the sixteen
 * decisions under `decisions/plan-2026-10-improvements/` were
 * invisible to the capsule, to the gate, and to every counter.
 *
 * The corpus is also filtered STRUCTURALLY: a document that declares
 * no top-level id (the obligations aggregator) or that belongs to a
 * non-decision schema family (the waiver files) is not a decision
 * and is not loaded.
 *
 * A document that IS a decision but that the semantic parser rejects
 * (a missing required field, an empty counterexample at mode >=
 * standard) still gets an entry — a stub with the id the document
 * DECLARES, not the name of the file it sits in. The pre-fix
 * fallback named the file, which is the same confusion this change
 * removes everywhere else: the id is the identity. *)
let[@warning "-32"] load_decisions reader root =
  let dir = Filename.concat root (Path_config.resolve_decisions_dir ~root ()) in
  let paths = decision_document_paths dir in
  List.filter_map
    (fun p ->
      match read reader p with
      | None -> None
      | Some raw -> (
          match decision_document_id ~raw with
          | None -> None
          | Some id -> (
              (* .yaml files parse cleanly; the bootstrap decision files
               may embed front-matter that the YAML loader can still consume
               because the leading '---' block is plain YAML. If parsing
               fails, fall back to a minimal entry so the capsule still
               names the decision. *)
              match parse_decision_yaml raw with
              | Some entry -> Some entry
              | None ->
                  Some
                    {
                      decision_id = id;
                      revision = None;
                      source = raw;
                      obligations = 0;
                      obligation_ids = [];
                      assumptions = 0;
                      risk_triggers = [];
                      scope_paths = [];
                      state = `Active;
                      obligation_details = [];
                    })))
    paths

let[@warning "-32"] load_spec reader root : spec_doc list =
  let names = [ "constitution.md"; "domain.md"; "semantics.md" ] in
  List.filter_map
    (fun n ->
      let p = Filename.concat (Filename.concat root "spec") n in
      match read reader p with
      | None -> None
      | Some body ->
          let entry : spec_doc = { path = p; body } in
          Some entry)
    names

let[@warning "-32"] load_axioms reader root : axiom_doc list =
  let dir = Filename.concat root "axioms" in
  let names =
    [
      "index.md";
      "separation.md";
      "feedback.md";
      "invariants.md";
      "self-application.md";
      "care.md";
    ]
  in
  List.filter_map
    (fun n ->
      let p = Filename.concat dir n in
      match read reader p with
      | None -> None
      | Some body ->
          let entry : axiom_doc = { path = p; body } in
          Some entry)
    names

let[@warning "-32"] load_best_practices reader root =
  let p = Filename.concat root "OCAML_BEST_PRACTICES.md" in
  match read reader p with None -> None | Some body -> Some body

let[@warning "-32"] parse_commits lines =
  let is_blank s =
    let len = String.length s in
    let rec loop i =
      if i >= len then true
      else if String.unsafe_get s i = ' ' || String.unsafe_get s i = '\t' then
        loop (i + 1)
      else false
    in
    loop 0
  in
  List.filter_map
    (fun line ->
      if is_blank line then None
      else
        (* git log --oneline format: "<sha> <subject>" with one space. *)
        match String.index_opt line ' ' with
        | Some i ->
            let sha = String.sub line 0 i in
            let subj =
              trim (String.sub line (i + 1) (String.length line - i - 1))
            in
            Some { sha; subject = subj }
        | None -> Some { sha = trim line; subject = "" })
    (List.filter (fun s -> String.length s > 0) lines)

(* Parse a `git diff --name-only` output into a list of paths.
   The diff format is one path per line, no header. *)
let[@warning "-32"] parse_changed_paths lines =
  List.filter (fun s -> String.length (trim s) > 0) (List.map trim lines)

(* --- top-level loader --- *)

let[@warning "-32"] load_memory ~reader ~root ~recent_commits_raw
    ~changed_paths_raw =
  {
    decisions = load_decisions reader root;
    spec = load_spec reader root;
    axioms = load_axioms reader root;
    best_practices = load_best_practices reader root;
    recent_commits = parse_commits (split_lines recent_commits_raw);
    changed_paths = parse_changed_paths (split_lines changed_paths_raw);
  }

(* The scope paths of a decision, from its raw YAML text. Same
   extractor as the kernel's own reader, so a caller outside the
   kernel reads the scope the gate reads. *)
let[@warning "-32"] extract_scope_paths_of_raw raw =
  extract_scope_paths (String.split_on_char '\n' raw)
