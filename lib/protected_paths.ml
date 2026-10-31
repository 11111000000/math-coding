(* lib/protected_paths.ml — the ONE list of protected paths, and the
 * rule that decides whether a path is in it.
 *
 * THE LIST LIVES IN THE PROJECT, NOT IN THE KERNEL.
 * `scripts/protected-paths.txt` is the single answer to the question
 * "which paths of this repository are protected?". It was read by
 * three consumers with three different answers:
 *
 *   lib/gate.ml:1016                    lib/ bin/Mathc.ml spec/
 *                                        schemas/ axioms/
 *   scripts/pre-commit/...-co-commit.sh lib/*.ml bin/Mathc.ml
 *                                        spec/*.md schemas/*.json
 *   .github/workflows/release-pending.yml bin/Mathc.ml bin/* lib/*
 *                                        scripts/install-tooling/*
 *
 * `lib/` against `lib/*.ml` against `lib/*`: three lists for one
 * question, and nothing that could tell which list a gate meant. The
 * list is now ONE file and the three consumers keep their own RULES
 * (what they require of a protected path) over the same SET.
 *
 * WHY THE KERNEL GETS THE LIST AS A VALUE. This module is pure: it
 * parses text and matches paths, and it never touches the filesystem
 * except in `load`, the thin I/O wrapper that mirrors
 * `lib/policy.ml::load_policies_from_file`. The gate itself stays
 * offline (OCAML_BEST_PRACTICES §1.3): bin/Mathc.ml reads the file and
 * passes the patterns in, the way it passes the attestation store and
 * the materials resolver.
 *
 * THE RULE, and why it is this rule. A pattern matches a path with
 * the semantics of a shell `case` pattern — fnmatch without
 * FNM_PATHNAME: `*` matches any run of characters INCLUDING `/`, `?`
 * matches exactly one character, everything else is literal. Two
 * reasons:
 *
 *   1. It is the semantics the two shell consumers already had. The
 *      pre-commit hook and the release workflow both matched with
 *      `case`, where `*` crosses `/`; a rule that did not would have
 *      silently narrowed what they protect (and widened what the
 *      gate, which used a prefix comparison, protected).
 *   2. It is expressible in one place in two languages without a
 *      translation table. The kernel's own `glob_match`
 *      (lib/gate.ml) has the OPPOSITE convention — `*` stays inside a
 *      path segment and `**` crosses — because it matches DECISION
 *      SCOPES, where the segment distinction is the point. Two
 *      conventions in one repository is one too many, but they
 *      answer different questions: a scope says which files a
 *      decision is ABOUT, and a protected path says which files
 *      require a decision next to the change.
 *
 * The shell implementation (scripts/protected-paths.sh) and this one
 * are compared path by path by
 * tests/fixtures/protected-paths-single-source.sh, so the two cannot
 * drift apart without a check going red. *)

(* --- the rule ------------------------------------------------------- *)

(* Does the pattern [pat] match the path [s]?
 *
 * `*` matches any run of characters, including `/` and the empty run.
 * `?` matches exactly one character. Every other character is
 * literal. The recursion is the standard backtracking matcher: a
 * `*` tries every split of the remaining path, shortest first. *)
let[@warning "-32"] rec glob_match (pat : string) (s : string) : bool =
  let n = String.length pat and m = String.length s in
  if n = 0 then m = 0
  else
    match pat.[0] with
    | '*' ->
        let rec try_split k =
          if k > m then false
          else if glob_match (String.sub pat 1 (n - 1)) (String.sub s k (m - k))
          then true
          else try_split (k + 1)
        in
        try_split 0
    | '?' ->
        m > 0 && glob_match (String.sub pat 1 (n - 1)) (String.sub s 1 (m - 1))
    | c ->
        m > 0
        && s.[0] = c
        && glob_match (String.sub pat 1 (n - 1)) (String.sub s 1 (m - 1))

(* Does any pattern in [patterns] match [path]? *)
let[@warning "-32"] matches (patterns : string list) (path : string) : bool =
  List.exists (fun p -> glob_match p path) patterns

(* Does any pattern in [patterns] match any path in [paths]?
 *
 * The question the §20 CoCommitDecision rule asks: "does this change
 * touch a protected path?" *)
let[@warning "-32"] touches (patterns : string list) (paths : string list) :
    bool =
  List.exists (fun path -> matches patterns path) paths

(* --- the list ------------------------------------------------------- *)

(* Parse the contents of a protected-path list.
 *
 * A line whose first non-blank character is `#` is a comment; a blank
 * line is ignored; every other line is one pattern, trimmed of the
 * whitespace around it. A line that is empty AFTER the comment is
 * removed is not a pattern.
 *
 * Pure: the string in, the patterns out. *)
let[@warning "-32"] parse (content : string) : string list =
  let is_blank s =
    String.for_all (fun c -> c = ' ' || c = '\t' || c = '\r') s
  in
  let strip_comment s =
    match String.index_opt s '#' with None -> s | Some i -> String.sub s 0 i
  in
  content |> String.split_on_char '\n' |> List.map strip_comment
  |> List.map String.trim
  |> List.filter (fun s -> not (is_blank s))

(* Read a protected-path list from disk.
 *
 * The ONE function here that touches the filesystem, and it is a thin
 * wrapper for the same reason `lib/policy.ml::load_policies_from_file`
 * is one: the parse path has to be testable without a filesystem, and
 * a list of patterns is small enough that reading it is cheaper than
 * the ceremony of injecting a reader.
 *
 * A MISSING file yields the empty list: "this project declares no
 * protected paths". That is a fact about the project, not an error —
 * a project that has no protected paths has nothing the gate must
 * ask about. It is NOT the same as "the list could not be read", and
 * the difference matters: the repository's own check
 * (tests/fixtures/protected-paths-single-source.sh) asserts that the
 * list EXISTS and is non-empty, so a deletion in THIS repository is
 * caught there rather than silently disabling the rule here. *)
let[@warning "-32"] load (path : string) : string list =
  if not (Sys.file_exists path) then []
  else
    match In_channel.with_open_text path In_channel.input_all with
    | content -> parse content
    | exception _ -> []
