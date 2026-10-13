(* lib/import_adr/import_adr.ml — `mathc import-adr` implementation.
 *
 * Reads a MADR-shaped or adr-tools-shaped ADR markdown file and
 * prints a math-coding decision YAML to stdout (or writes it
 * to decisions/<id>.yaml with --write).
 *
 * Best-effort, not lossless:
 *   - title (first `#` heading)  -> id (kebab-case) + intent
 *   - status (MADR/adr-tools)    -> state
 *   - context section            -> assumptions[]
 *   - decision section           -> commitment
 *   - consequences section        -> outcomes[]
 *
 * The output is a decision DRAFT; the user reviews and adjusts
 * before `mathc validate` accepts the file. The OCaml output
 * is never auto-committed; it is reviewed by a human whose
 * `kind_: review` attestation closes the obligation.
 *
 * Adapter convention: lives in `lib/import_adr/` as a sub-library
 * per OCAML_BEST_PRACTICES §10.1. *)

type adr_kind = Madr | AdrTools | Unknown

type parsed = {
  id : string;
  title : string;
  state : string;
  intent : string;
  commitment : string;
  assumptions : string;
  outcomes : string list;
  source_kind : adr_kind;
}

(* --- section extraction ------------------------------------------- *)

let section_body (lines : string list) (header : string) : string =
  let rec aux = function
    | [] -> ""
    | h :: t ->
        if String.length h >= 3 && String.sub h 0 3 = "## " then
          let rest = String.sub h 3 (String.length h - 3) in
          if rest = header then
            let rec take_until_section = function
              | [] -> ""
              | h2 :: t2 ->
                  if String.length h2 >= 3 && String.sub h2 0 3 = "## " then
                    ""
                  else
                    h2 ^ "\n" ^ take_until_section t2
            in
            take_until_section t
          else
            aux t
        else
          aux t
  in
  let body = aux lines in
  String.trim body

let first_h1 (lines : string list) : string option =
  let rec aux = function
    | [] -> None
    | h :: t ->
        if String.length h >= 2 && String.sub h 0 2 = "# "
           && (String.length h < 3 || String.sub h 2 1 <> "#") then
          Some (String.sub h 2 (String.length h - 2) |> String.trim)
        else
          aux t
  in
  aux lines

(* --- status extraction ------------------------------------------- *)

let extract_status_madr (text : string) : string option =
  let lines = Str.split (Str.regexp "\n") text in
  let rec aux = function
    | [] -> None
    | h :: t ->
        if String.length h >= 7 && String.sub h 0 7 = "status:" then
          Some (String.sub h 7 (String.length h - 7) |> String.trim)
        else
          aux t
  in
  aux lines

let extract_status_adrtools (lines : string list) : string option =
  let rec aux = function
    | [] -> None
    | h :: t -> begin
        match Str.split (Str.regexp "[ \t]+") (String.trim h) with
        | "##" :: "Status" :: rest ->
            let status = String.trim (String.concat " " rest) in
            if status = "" then begin
              match t with
              | h2 :: t2 -> Some (String.trim h2)
              | [] -> None
            end
            else Some status
        | _ -> aux t
      end
  in
  aux lines

(* --- MADR vs adr-tools detection --------------------------------- *)

let detect_kind (text : string) : adr_kind =
  let lines = Str.split (Str.regexp "\n") text in
  let rec first_n n = function
    | _ when n <= 0 -> []
    | [] -> []
    | h :: t -> h :: first_n (n - 1) t
  in
  let head = first_n 20 lines in
  let has_madr_frontmatter =
    List.exists
      (fun l -> String.length l >= 7 && String.sub l 0 7 = "status:")
      head
  in
  let has_adrtools_status_section =
    List.exists
      (fun l ->
        let trimmed = String.trim l in
        trimmed = "## Status" || trimmed = "## status")
      head
  in
  if has_madr_frontmatter then Madr
  else if has_adrtools_status_section then AdrTools
  else Unknown

(* --- id derivation ------------------------------------------------- *)

let slugify (s : string) : string =
  let buf = Buffer.create (String.length s) in
  let last_dash = ref false in
  String.iter
    (fun c ->
      match c with
      | 'a'..'z' | '0'..'9' ->
          Buffer.add_char buf c;
          last_dash := false
      | 'A'..'Z' ->
          Buffer.add_char buf (Char.lowercase_ascii c);
          last_dash := false
      | '-' | '_' | ' ' ->
          if not !last_dash then begin
            Buffer.add_char buf '-';
            last_dash := true
          end
      | _ -> ())
    s;
  let result = Buffer.contents buf in
  let len = String.length result in
  if len > 0 && result.[len - 1] = '-' then
    String.sub result 0 (len - 1)
  else
    result

(* --- mapping: ADR status -> math-coding state --------------------- *)

let map_status (s : string) : string =
  match String.lowercase_ascii (String.trim s) with
  | "accepted" | "approved" -> "active"
  | "proposed" -> "draft"
  | "rejected" | "deprecated" -> "retired"
  | "superseded" -> "superseded"
  | s when String.length s > 0 -> s
  | _ -> "active"

(* --- top-level parse --------------------------------------------- *)

let parse (text : string) : parsed =
  let lines = Str.split (Str.regexp "\n") text in
  let kind = detect_kind text in
  let title =
    match first_h1 lines with
    | Some t -> t
    | None -> "imported-adr"
  in
  let id = slugify title in
  let status =
    match kind with
    | Madr -> extract_status_madr text
    | AdrTools -> extract_status_adrtools lines
    | Unknown -> None
  in
  let state = match status with
    | Some s -> map_status s
    | None -> "active"
  in
  let context_section =
    match kind with
    | Madr -> "Context and Problem Statement"
    | AdrTools | Unknown -> "Context"
  in
  let context = section_body lines context_section in
  let decision_section =
    match kind with
    | Madr -> "Decision Outcome"
    | AdrTools | Unknown -> "Decision"
  in
  let decision = section_body lines decision_section in
  let consequences = section_body lines "Consequences" in
  let outcomes =
    let items =
      Str.split (Str.regexp_string "* ") consequences
    in
    let trimmed =
      List.filter (fun s -> String.trim s <> "") items
    in
    let rec skip_first = function
      | [] -> []
      | _ :: t -> t
    in
    skip_first trimmed
  in
  {
    id;
    title;
    state;
    intent = title;
    commitment = if decision = "" then "Imported from ADR; review and adjust." else decision;
    assumptions = if context = "" then "Imported from ADR; context not detected." else context;
    outcomes =
      (if outcomes = [] then
         ["Imported from ADR; consequences not detected."]
       else
         outcomes);
    source_kind = kind;
  }

(* --- YAML emission ------------------------------------------------ *)

let yaml_escape (s : string) : string =
  let buf = Buffer.create (String.length s) in
  String.iter
    (fun c ->
      if c = '\n' then Buffer.add_string buf "\\n"
      else if c = '"' then Buffer.add_string buf "\\\""
      else if c = '\\' then Buffer.add_string buf "\\\\"
      else Buffer.add_char buf c)
    s;
  Buffer.contents buf

let block_scalar (s : string) : string =
  Printf.sprintf "  |\n    %s" (yaml_escape s)

let outcome_yaml (i : int) (s : string) : string =
  Printf.sprintf
    "  - id: outcome-%d\n    statement: |\n      %s\n"
    (i + 1)
    (yaml_escape s)

let to_decision_yaml (p : parsed) : string =
  let outcomes_str =
    String.concat "" (List.mapi outcome_yaml p.outcomes)
  in
  Printf.sprintf
    "---\n\
     schema: math-coding/3.2\n\
     id: %s\n\
     revision: 1\n\
     state: %s\n\
     intent: |\n\
     \  %s\n\
     axiom_link:\n\
     \  - A0\n\
     antithesis: |\n\
     \  The counter-position considered and rejected (per the v3\n\
     \  dialectic method, spec/algebra-3.2.md section 11): the\n\
     \  imported ADR may be wrong about its chosen option, or\n\
     \  may be missing considerations that the math-coding\n\
     \  schema requires. The reviewer must verify the import\n\
     \  before this decision is merged; the import is\n\
     \  best-effort, not lossless.\n\
     commitment: |\n\
     \  %s\n\
     counterexample: |\n\
     \  Imported from an existing ADR; the strongest objection to\n\
     \  this decision is whatever the original ADR author(s)\n\
     \  considered when they rejected the alternatives. The\n\
     \  reviewer should fill this section in or move the rejection\n\
     \  rationale from the ADR's \xC2\xABConsidered Options\xC2\xBB block.\n\
     scope:\n\
     \  paths:\n\
     \    - \"<path/glob/that/this/decision/touches/**>\"\n\
     \  exclusions: []\n\
     assumptions:\n\
     \  - state: assumed\n\
     \    statement: |\n\
     \      %s\n\
     outcomes:\n\
     %s\
     obligations:\n\
     \  - id: %s-imported-review\n\
     \    claim: |\n\
     \      The imported content is reviewed by a human. The reviewer\n\
     \      may adjust the field mapping before \xC2\xABmathc validate\xC2\xBB\n\
     \      accepts the file. The ADR provenance is recorded in this\n\
     \      decision's \xC2\xABassumptions\xC2\xBB block.\n\
     \    acceptance:\n\
     \      all:\n\
     \        - verifier: mathc validate\n\
     \          result: pass\n\
     relations:\n\
     \  addresses: []\n\
     \  supersedes: []\n\
     \  superseded_by: []\n"
    p.id
    p.state
    (yaml_escape p.intent)
    (yaml_escape p.commitment)
    (yaml_escape p.assumptions)
    outcomes_str
    p.id

(* --- run ----------------------------------------------------------- *)

let read_file (path : string) : (string, [> `Msg of string]) result =
  try
    let ic = open_in path in
    let n = in_channel_length ic in
    let s = really_input_string ic n in
    close_in ic;
    Ok s
  with
  | Sys_error m -> Error (`Msg ("cannot read " ^ path ^ ": " ^ m))

let run (path : string) (write : bool) : (unit, [> `Msg of string]) result =
  match read_file path with
  | Error e -> Error e
  | Ok text ->
      let parsed = parse text in
      let yaml = to_decision_yaml parsed in
      if write then begin
        let out_path =
          Filename.concat "decisions" (parsed.id ^ ".yaml")
        in
        (try Unix.mkdir "decisions" 0o755 with
         | Unix.Unix_error (Unix.EEXIST, _, _) -> ());
        let oc = open_out out_path in
        output_string oc yaml;
        close_out oc;
        Printf.printf "wrote %s (id=%s, source_kind=%s)\n"
          out_path parsed.id
          (match parsed.source_kind with
           | Madr -> "MADR"
           | AdrTools -> "adr-tools"
           | Unknown -> "unknown");
        Ok ()
      end
      else begin
        print_string yaml;
        Ok ()
      end
