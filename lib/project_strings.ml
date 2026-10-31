(* lib/project_strings.ml — the project's own names, parsed from ONE
 * file and matched by a pure kernel.
 *
 * THE LIST LIVES IN THE PROJECT, NOT IN THE KERNEL.
 * `scripts/project-strings.txt` is the single answer to the question
 * "which of THIS project's names does the kernel need to know?".
 * Two kinds of name are held here:
 *
 *   - the book: the project's conventions document (this repository
 *     renamed its best-practices book, and the old name the kernel
 *     hardcoded read a file that no longer exists);
 *   - the axiom-link inference table: which axiom ids to suggest for
 *     a decision whose scope lives under a given directory prefix.
 *     `lib/** -> A0,A1`, `tests/** -> A1` and so on is ONE
 *     repository's directory layout, not a fact about the protocol.
 *
 * An adopter's tree has neither this repository's book nor this
 * repository's directory layout, so the kernel must not carry either.
 * The pattern is the one the protected paths already use
 * (lib/protected_paths.ml): the kernel module is pure — it parses
 * text and answers lookups — and the only filesystem touch is the
 * thin `load` wrapper, which mirrors `lib/policy.ml::
 * load_policies_from_file`. bin/Mathc.ml reads the file and passes
 * the parsed value in, the way it passes the attestation store and
 * the materials resolver.
 *
 * AN EMPTY FILE means "this project declares no project strings":
 * `book` is None (the capsule emits no Supporting item) and
 * `axiom_link_rules` is [] (the inference falls back to the universal
 * `A0`, which is the function's documented contract). The check
 * degrades to as permissive as it was, never to "reads nothing".
 * The repository's own fixture asserts that the file EXISTS and is
 * non-empty, so a deletion in THIS repository is caught by a check
 * rather than silently disarming the inference. *)

type t = {
  book : string option;
  axiom_link_rules : (string * string list) list;
}

(* --- the rule ------------------------------------------------------- *)

(* Parse the contents of the project-strings file.
 *
 * A line whose first non-blank character is `#` is a comment; a blank
 * line is ignored. Every other line is `key: value`:
 *
 *   book: <conventions-document>
 *       the project's conventions document, project-relative. ONE
 *       value; the first non-empty occurrence wins.
 *   axiom-link: lib/ A0 A1
 *       one inference rule: a directory prefix, then the axiom ids to
 *       suggest for a path under that prefix, whitespace-separated.
 *       Repeated lines ACCUMULATE, in file order.
 *
 * An unknown key is ignored (forward-compatible), so a future key
 * does not break an older kernel. Pure: the string in, the value
 * out. *)
let[@warning "-32"] parse (content : string) : t =
  let is_blank s =
    String.for_all (fun c -> c = ' ' || c = '\t' || c = '\r') s
  in
  let strip_comment s =
    match String.index_opt s '#' with None -> s | Some i -> String.sub s 0 i
  in
  let lines =
    content |> String.split_on_char '\n' |> List.map strip_comment
    |> List.map String.trim
    |> List.filter (fun s -> not (is_blank s))
  in
  let split_kv line =
    match String.index_opt line ':' with
    | None -> None
    | Some i ->
        let k = String.trim (String.sub line 0 i) in
        let v =
          String.trim (String.sub line (i + 1) (String.length line - i - 1))
        in
        Some (k, v)
  in
  let words s =
    s |> String.split_on_char ' ' |> List.map String.trim
    |> List.filter (fun w -> not (is_blank w))
  in
  let rec fold book rules = function
    | [] -> { book; axiom_link_rules = List.rev rules }
    | line :: rest -> (
        match split_kv line with
        | Some ("book", v) when book = None && v <> "" ->
            fold (Some v) rules rest
        | Some ("axiom-link", v) -> (
            match words v with
            | prefix :: axioms when axioms <> [] ->
                fold book ((prefix, axioms) :: rules) rest
            | _ -> fold book rules rest)
        | _ -> fold book rules rest)
  in
  fold None [] lines

(* Read a project-strings file from disk.
 *
 * The ONE function here that touches the filesystem, and it is a thin
 * wrapper for the same reason `lib/protected_paths.ml::load` is one:
 * the parse path has to be testable without a filesystem.
 *
 * A MISSING file yields the empty record: "this project declares no
 * project strings". That is a fact about the project, not an error. *)
let[@warning "-32"] load (path : string) : t =
  if not (Sys.file_exists path) then { book = None; axiom_link_rules = [] }
  else
    match In_channel.with_open_text path In_channel.input_all with
    | content -> parse content
    | exception _ -> { book = None; axiom_link_rules = [] }
