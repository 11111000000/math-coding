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

type decision_entry = {
  decision_id : string;
  revision : string option;
  source : string; (* raw YAML/JSON, opaque here *)
  obligations : int;
  assumptions : int;
  risk_triggers : string list;
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

let[@warning "-32"] empty =
  {
    decisions = [];
    spec = [];
    axioms = [];
    best_practices = None;
    recent_commits = [];
    changed_paths = [];
  }

(* --- helpers --- *)

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

(* Best-effort YAML/JSON extraction of a few scalars we want for
   prioritisation. We do not need full schema validation here — that
   belongs to Decision.parse_decision in lib/decision.ml. The capsule
   loader only needs:
     - id, revision
     - count of obligations and assumptions (for budget estimation)
     - declared_triggers list (for the HighRisk priority bucket)
   Missing fields default to safe values; the loader is total.

   Note: lib/codec.ml's load_yaml_string does not handle YAML
   front-matter (a leading '---' line). The bootstrap/*.yaml files
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
        let assumptions = count_array_field ps "assumptions" in
        let risk_triggers =
          match Schema.take_object ps "risk" with
          | Some rps -> string_list_field rps "declared_triggers"
          | None -> []
        in
        if id = "" then None
        else
          Some
            {
              decision_id = id;
              revision = rev;
              source = raw;
              obligations;
              assumptions;
              risk_triggers;
            }
    | _ -> None
  with _ -> None

(* Read a file via `reader`, returning None on missing/empty.
   The reader is total from the kernel's perspective; missing files
   are surfaced as None and the caller decides the priority. *)
let[@warning "-32"] read reader path =
  match reader path with "" -> None | s -> Some s

(* --- loader --- *)

let[@warning "-32"] load_decisions reader root =
  let paths =
    [
      Filename.concat root "bootstrap/decision.yaml";
      Filename.concat root "bootstrap/infrastructure-honesty.yaml";
      Filename.concat root "bootstrap/kernel-conformance-runner.yaml";
      Filename.concat root "bootstrap/validate-and-context.md";
    ]
  in
  List.filter_map
    (fun p ->
      match read reader p with
      | None -> None
      | Some raw -> (
          (* .yaml files parse cleanly; .md files (validate-and-context.md)
           embed front-matter that the YAML loader can still consume
           because the leading '---' block is plain YAML. If parsing
           fails, fall back to a minimal entry so the capsule still
           names the decision file. *)
          match parse_decision_yaml raw with
          | Some entry -> Some entry
          | None ->
              let id =
                let base = Filename.basename p in
                match Filename.chop_suffix_opt ~suffix:".yaml" base with
                | Some s -> s
                | None -> (
                    match Filename.chop_suffix_opt ~suffix:".md" base with
                    | Some s -> s
                    | None -> base)
              in
              Some
                {
                  decision_id = id;
                  revision = None;
                  source = raw;
                  obligations = 0;
                  assumptions = 0;
                  risk_triggers = [];
                }))
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
