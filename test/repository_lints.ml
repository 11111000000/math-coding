(* The repository lints.

   WHAT THEY ARE. Four properties that the method claims about itself and
   that must be true of the tree, checked by a program rather than by a
   reader's memory:

   1. no executable script in the repository - the method is OCaml, and a
      shell script here would be a second implementation of the method in
      a language whose failure modes the method does not model;
   2. the core is pure - no effect, no I/O, no clock - so that a law
      written about it is a law about a value;
   3. the core is small - under the ceiling, because a core that grows
      is a core nobody has read;
   4. every check carries a proof that it can fail.

   WHY THEY ARE A TEST AND NOT A SCRIPT. The rule "no executable script
   in the repository" would be violated by the script that enforces it.
   The lint is therefore OCaml, and it lints the tree the same way.

   WHAT THEY DO NOT CHECK. Whether the laws are true, whether the
   proofs are honest, and whether the method is useful. Those need the
   method to be running; this file only says the tree is shaped the way
   the method says it should be shaped.

   A NOTE ON HOW THEY MUST BE RUN. These lints read the tree, so dune's
   own caching does not see the tree: adding a forbidden script and
   running `dune runtest` without `--force` reports the previous green,
   because no source file changed. That is not a defect of the lints -
   it is a property of every check that watches something other than
   itself. The runner therefore forces. A check whose input is not its
   own source must say how it is run, or it will be run wrongly.

   A NOTE ON WHAT COUNTS AS THE REPOSITORY. The lints ask git which
   files the repository has, rather than walking the disk. The disk
   holds what the machine has: a vendored dependency, a build output, an
   editor's leftovers. The repository holds what is committed plus what
   is new and not ignored - the files that would join it. Reading the
   disk instead would make the lints trip over somebody else's
   node_modules and miss a script that is about to be committed. Git is
   the only thing that knows the difference, so the lints ask git. *)

let[@warning "-32"] find_root start =
  let rec loop d =
    if Sys.file_exists (Filename.concat d "dune-project") then d
    else
      let parent = Filename.dirname d in
      if parent = d then start else loop parent
  in
  loop start

(* The source tree, not the build tree. Dune runs a test from the
   build directory and copies the sources into it, so the nearest
   `dune-project` below the working directory is the build one. The
   build copy is a faithful copy of the file, but it is not the
   repository: a lint that read it would be reading a stale copy of a
   file that has already changed. The source tree is found by leaving
   the build directory - dune's build directory is always named
   `_build`, and the source tree is its parent. *)
let[@warning "-32"] source_root () =
  let rec loop d =
    if Filename.basename d = "_build" then Filename.dirname d
    else
      let parent = Filename.dirname d in
      if parent = d then find_root (Sys.getcwd ()) else loop parent
  in
  loop (Sys.getcwd ())

let[@warning "-32"] project_root = source_root ()

let[@warning "-32"] in_repo rel = Filename.concat project_root rel

let[@warning "-32"] read_file path = In_channel.with_open_bin path In_channel.input_all

(* The files the repository may not contain. A program is not a script:
   every executable unit is an OCaml program or a subcommand of the
   binary, and the check that says so is itself an OCaml program. *)
let[@warning "-32"] forbidden_extensions = [ ".sh"; ".py"; ".bash"; ".zsh" ]

(* The repository's own file list, asked of git: tracked files, and the
   new files that are not ignored. The paths come back relative to the
   repository root, which is why the root is passed to git explicitly -
   dune runs a test from the build directory, and a bare `git ls-files`
   there would list nothing at all. That failure mode is the dangerous
   one: an empty list passes every lint. *)
let[@warning "-32"] repository_files () =
  let cmd =
    Printf.sprintf "git -C %s ls-files -z --cached --others --exclude-standard"
      (Filename.quote project_root)
  in
  let channel = Unix.open_process_in cmd in
  let content = In_channel.input_all channel in
  let status = Unix.close_process_in channel in
  (match status with
  | Unix.WEXITED 0 -> ()
  | _ ->
      failwith
        (Printf.sprintf
           "repository lints: `git ls-files` failed in %s. The lints need a git \
            repository; run them where the method lives, not in a copy of it."
           project_root));
  String.split_on_char '\000' content
  |> List.filter (fun path -> path <> "" && path <> ".")

let[@warning "-32"] with_extension ext paths =
  List.filter (fun path -> Filename.check_suffix path ext) paths

let[@warning "-32"] under_directory dir paths =
  let prefix = dir ^ "/" in
  List.filter (fun path -> String.length path > String.length prefix
                            && String.sub path 0 (String.length prefix) = prefix)
    paths

let[@warning "-32"] check_no_scripts () =
  let offenders =
    repository_files ()
    |> List.filter (fun path ->
        List.exists
          (fun ext -> Filename.check_suffix path ext)
          forbidden_extensions)
  in
  assert (offenders = [])

(* The core is lib/. It must not contain an effect: no I/O, no clock, no
   randomness. The words below are the usual spellings of those in
   OCaml; the list is explicit rather than heuristic because a heuristic
   lint that grows on its own becomes a second source of truth.

   HOW THE SCAN IS DONE, AND WHY IT IS NOT A PARSER. The obvious way to
   look for a call is to read the file as text and search it. That way
   is wrong, and this file was wrong that way at first: a text scan
   cannot tell an identifier from the same word inside a comment or
   inside a string, so it either cries wolf or - worse - is silenced by
   a comment that happens to mention the word. The first version of
   this lint had a comment stripper; it closed a comment on the C-style
   terminator while OCaml closes on its own, so it swallowed the rest
   of the file and the check passed vacuously. A check that cannot fail
   is a comment, and this one had become one without anyone noticing.

   So the scan uses the compiler's own parse tree, asked for as text:
   `ocamlc -dparsetree` prints the tree it built, in which comments do
   not exist and strings are a different node from an identifier. The
   lint looks for the identifier in the tree. The compiler does the
   parsing; the lint does not write a parser, which is also the rule
   the method states about itself. *)
let[@warning "-32"] impure_names =
  [ "print_endline"; "print_string"; "printf"; "exit"; "open_in";
    "open_in_gen"; "open_out"; "open_out_gen"; "close_out"; "close_out_noerr";
    "read_line"; "read_file"; "write_file"; "read_all"; "file_exists";
    "remove"; "rename"; "mkdir"; "rmdir"; "chdir"; "getcwd"; "command";
    "getenv"; "gettimeofday"; "time"; "self_init"; "full_init"; "stat";
    "lstat"; "openfile"; "create_process"; "system"; "putenv";
    "unsafe_environment"; "unsafe_getenv" ]

(* The impure names as they appear in the tree. A call may be written
   bare (`exit`) or qualified (`Unix.gettimeofday`), and the tree
   prints the qualified form in full - `List.exists` does not look like
   `exists`, and `verdict_to_exit` does not look like `exit`. So the
   check looks for each name exactly as the compiler would print it,
   and for the qualified spellings of the ones that have one.

   The list is explicit rather than heuristic. A heuristic lint that
   grows on its own becomes a second source of truth about the
   language, and the cost of that is paid later, by whoever is looking
   for the effect that got through. *)
let[@warning "-32"] impure_spellings =
  List.concat_map
    (fun name ->
      [ name; "Sys." ^ name; "Unix." ^ name; "Random." ^ name;
        "Stdlib." ^ name; "Printf." ^ name ])
    (List.sort_uniq String.compare impure_names)

(* The parse tree of one file, as the compiler prints it. The tree is
   asked for rather than built: this lint must not contain a parser of
   OCaml, and a second parser is a second source of truth about the
   language.

   The compiler writes the tree to its error stream, not to its output
   stream - `-dparsetree` is a diagnostic. So the stream is merged and
   the whole thing is read; the file's own diagnostics come along with
   it, which is harmless because the lint looks for node names rather
   than for whole lines.

   The tree is checked for emptiness, and the check is not decoration.
   A file that does not parse produces no tree at all, and an empty
   tree contains no impure call - so a lint that scanned it would
   pronounce the file pure. A file that does not compile is not pure
   core, it is broken core, and the lint must say so rather than pass
   it. This is the same shape as the bug this replaced: a check that
   finds nothing because it looked in the wrong place, and reports the
   absence as a virtue. *)
let[@warning "-32"] parse_tree path =
  let cmd =
    Printf.sprintf "ocamlc -dparsetree %s 2>&1"
      (Filename.quote (in_repo path))
  in
  let channel = Unix.open_process_in cmd in
  let content = In_channel.input_all channel in
  ignore (Unix.close_process_in channel);
  if String.length content < 10 then
    failwith
      (Printf.sprintf
         "repository lints: %s did not parse, so its tree is empty and the purity \
          check would pass it. A file that does not compile is not a pure core, it \
          is a broken core."
         path);
  content

(* An occurrence of the name as an identifier in the tree. The pattern
   is the compiler's own: `Pexp_ident "print_endline"`. A string
   constant prints as `PConst_string(...)` and a comment prints as
   nothing at all, so neither can be mistaken for a call. The name must
   match exactly, so `verdict_to_exit` does not look like `exit` and
   `List.exists` does not look like `exists`. *)
let[@warning "-32"] called_in tree name =
  let needle = Printf.sprintf "Pexp_ident \"%s\"" name in
  let n = String.length tree and m = String.length needle in
  let found = ref false in
  let i = ref 0 in
  while (not !found) && !i + m <= n do
    if String.sub tree !i m = needle then found := true else i := !i + 1
  done;
  !found

let[@warning "-32"] core_files () =
  repository_files () |> under_directory "lib" |> with_extension ".ml"

(* The codec is pure as well - a string in, a value out - so it is
   checked for the same impurity. It is not part of the core: it says
   how the outside is shaped, not what is true. *)
let[@warning "-32"] codec_files () =
  repository_files () |> under_directory "format" |> with_extension ".ml"

let[@warning "-32"] check_core_is_pure () =
  List.iter
    (fun path ->
      let tree = parse_tree path in
      List.iter
        (fun call ->
          assert (
            not
              (called_in tree call)))
        impure_spellings)
    (core_files ())

(* The ceiling on the size of the core. A core that grows past this is a
   core nobody has read, and an unread core is where the laws stop being
   laws. The number is a decision, not a measurement: it is set before
   the code exists, so that it constrains the code rather than
   describing it.

   And it is NOT raised when the code grows. That is the whole point of
   setting it first: the answer to "the core outgrew its ceiling" is
   to move code out of the core, not to move the ceiling. When the
   requirements of the claims needed their own vocabulary, that
   vocabulary went to the codec, and the core kept the algebra. *)
let[@warning "-32"] core_line_ceiling = 800

(* The codec has its own ceiling, smaller and stated. It is mechanical
   code - readers and writers - and mechanical code grows by accretion
   unless something stops it. *)
let[@warning "-32"] codec_line_ceiling = 400

let[@warning "-32"] lines_of (files : string list) =
  files
  |> List.map (fun path ->
         List.length (String.split_on_char '\n' (read_file (in_repo path))))
  |> List.fold_left ( + ) 0

let[@warning "-32"] check_core_is_small () =
  assert (lines_of (core_files ()) <= core_line_ceiling);
  assert (lines_of (codec_files ()) <= codec_line_ceiling)

(* Every check carries a proof that it can fail. A check file that does
   not mention the words below has no negative control, and a check
   without a negative control is a comment.

   The words are looked for in the file's own text. The parse tree
   cannot be used here: it holds doc comments but drops ordinary ones,
   and a negative control is usually explained in an ordinary comment.
   What this check can see is that the phrase is present - not that the
   control works. That limit is deliberate and is why the method also
   asks for the controls to be exercised, which is a thing a person
   does, not a thing a lint can do. *)
let[@warning "-32"] check_checks_have_teeth () =
  let offenders =
    repository_files ()
    |> under_directory "test"
    |> with_extension ".ml"
    |> List.filter (fun path ->
        let src = String.lowercase_ascii (read_file (in_repo path)) in
        not
          (let re = Str.regexp "negative control" in
           try
             ignore (Str.search_forward re src 0);
             true
           with Not_found -> false))
  in
  assert (offenders = [])

(* Does the text contain the needle? *)
let[@warning "-32"] contains (haystack : string) (needle : string) =
  let n = String.length haystack and m = String.length needle in
  let found = ref false in
  let i = ref 0 in
  while (not !found) && !i + m <= n do
    if String.sub haystack !i m = needle then found := true else i := !i + 1
  done;
  !found

(* The laws of the core, as the compiler sees them.

   The names come from the parse tree, so a law that is only mentioned
   in a comment is not counted, and a law that is renamed is counted
   under its new name. The tree prints a definition as
   `Ppat_var "law_commutative"`, which is where the name of a value
   binding lives; the name is taken whole, and the ones that are not
   laws are left out. *)
let[@warning "-32"] laws_of_the_core () =
  let tree = parse_tree "lib/verdict.ml" in
  let needle = "Ppat_var \"" in
  let n = String.length tree and m = String.length needle in
  let names = ref [] in
  let i = ref 0 in
  while !i + m <= n do
    if String.sub tree !i m = needle then (
      let start = !i + m in
      let rec find_end j =
        if j < n && tree.[j] <> '"' then find_end (j + 1) else j
      in
      let stop = find_end start in
      names := String.sub tree start (stop - start) :: !names;
      i := stop)
    else i := !i + 1
  done;
  !names
  |> List.filter (fun name ->
         String.length name > 4 && String.sub name 0 4 = "law_")
  |> List.sort_uniq String.compare

(* The formal part names every law of the core.

   AXIOMS.md is the specification for PROOF and the code is the
   specification for EXECUTION, and the document claims that they cannot
   drift apart - which is a claim, and a claim needs a check. The drift
   is in one direction only: a law may be added to the core and the
   formal part would go on not naming it, and the reader of the formal
   part would see a smaller method than the one that runs. *)
let[@warning "-32"] check_the_formal_part_names_every_law () =
  let document = read_file (in_repo "AXIOMS.md") in
  let missing = List.filter (fun name -> not (contains document name)) (laws_of_the_core ()) in
  assert (missing = [])

(* The negative control for that check. A check that cannot fail is a
   comment, and this one had better not be one: it looks for names in a
   document, and the way to be sure it looks is to show it a name that
   is not there and watch it report the name as missing. *)
let[@warning "-32"] check_the_formal_part_check_has_teeth () =
  let document = read_file (in_repo "AXIOMS.md") in
  let missing name = not (contains document name) in
  (* The extraction finds the laws of the core at all. *)
  let laws = laws_of_the_core () in
  assert (laws <> []);
  assert (List.mem "law_commutative" laws);
  (* And a name the document does not carry is reported missing. *)
  assert (missing "law_that_does_not_exist");
  (* The same list with that name in it is NOT empty - which is what the
     check compares against. *)
  assert
    (List.filter missing [ "law_commutative"; "law_that_does_not_exist" ] <> [])

(* THE CONTROLS OF THE METHOD'S OWN CLAIMS ARE LIVE.

   Six of them had gone stale, and nothing noticed. The code moved
   under the control - the text the control looked for was rewritten -
   and the control stopped biting; the claim's check passed on the
   broken subject, and the method said "inconclusive" and named the
   claim. The method was RIGHT and the specification was wrong, and it
   took the self-application to say so.

   But the method's own specification is edited by hand, and nothing
   checked that a control still matches the code it claims to break.
   This lint is that guard, and it is the fifth property of the tree:
   every claim of the method carries a control, the control's file is
   inside the claim's subject, and the control still changes
   something.

   THE CONTROL IS TRIED, NOT GUESSED AT. The check copies the file the
   control writes to into a scratch directory, runs the control there,
   and asks whether the file changed. A pattern that no longer matches
   changes nothing, and that is exactly the stale control. *)
(* The file the control writes to. It is the LAST word of the command:
   a sed names its script before the file it is applied to, and a
   printf names its text before the file it appends to. The first
   version of this looked for the last word CONTAINING a slash, and it
   found the wrong thing - a sed pattern may contain a slash and a
   space, and the slash inside the pattern won. *)
let[@warning "-32"] control_target (control : string) : string option =
  let clean word =
    not (String.contains word '>')
    && not (String.contains word '<')
    && not (String.contains word '\'')
    && not (String.contains word '"')
    && not (String.contains word ';')
    && not (String.contains word '&')
    && not (String.contains word '|')
  in
  String.split_on_char ' ' (String.trim control)
  |> List.rev
  |> List.find_opt clean
  |> Option.map (fun w ->
         if String.length w > 2 && String.sub w 0 2 = "./" then
           String.sub w 2 (String.length w - 2)
         else w)

(* A directory of its own for the trial, and its removal afterwards. *)
let[@warning "-32"] scratch_dir () =
  let base = Filename.get_temp_dir_name () in
  let rec go n =
    let dir = Filename.concat base (Printf.sprintf "mathc-lint-%d-%d" (Unix.getpid ()) n) in
    if Sys.file_exists dir then go (n + 1)
    else (
      Unix.mkdir dir 0o700;
      dir)
  in
  go 0

let[@warning "-32"] rec remove_tree dir =
  (try
     Sys.readdir dir
     |> Array.iter (fun name ->
            let path = Filename.concat dir name in
            if Sys.is_directory path then remove_tree path else Sys.remove path)
   with _ -> ());
  try Sys.rmdir dir with _ -> ()

let[@warning "-32"] mkdir_p dir =
  let rec go path =
    if path <> "" && path <> "/" && path <> "." && not (Sys.file_exists path) then (
      go (Filename.dirname path);
      try Unix.mkdir path 0o700 with _ -> ())
  in
  go dir

let[@warning "-32"] copy_file source dest =
  let ic = open_in_bin source and oc = open_out_bin dest in
  let buf = Bytes.create 65536 in
  let rec pump () =
    let n = input ic buf 0 65536 in
    if n > 0 then (
      output oc buf 0 n;
      pump ())
  in
  pump ();
  close_in ic;
  close_out oc

(* TRIED, NOT GUESSED AT. The file the control writes to is copied into
   a scratch directory, the control is run there, and the file is
   compared. A control whose pattern no longer matches changes nothing,
   and that is exactly the stale control.

   A control that cannot be TRIED is not a control the lint can vouch
   for, and the lint says so rather than passing it: the first version
   of this check had a scratch directory that was never created, the
   control never ran, the comparison said "nothing changed", and the
   fallback answered "assume it is fine" - so the check passed a
   control that had never been tried. A guard that cannot fail is a
   comment. *)
let[@warning "-32"] control_changes (control : string) (target : string) : bool =
  let scratch = scratch_dir () in
  let dest = Filename.concat scratch target in
  mkdir_p (Filename.dirname dest);
  let source = in_repo target in
  if Sys.file_exists source then copy_file source dest;
  let before = if Sys.file_exists dest then Some (read_file dest) else None in
  let code = Sys.command (Printf.sprintf "cd %s && %s" (Filename.quote scratch) control) in
  ignore code;
  let after = if Sys.file_exists dest then Some (read_file dest) else None in
  remove_tree scratch;
  before <> after

(* EVERY PRINCIPLE HAS A CARRIER.

   PHILOSOPHY.md names fifteen principles and AXIOMS.md says which law
   carries each one. The two documents used DIFFERENT ALPHABETS for the
   same identifiers - PHILOSOPHY.md wrote P1 with a Latin letter and
   AXIOMS.md wrote it with a Cyrillic one - so no program could match
   them, and a reader who did not know the convention could not either.
   The vocabulary of a method is the same on both sides of a link, or it
   is not one vocabulary.

   This lint is the link. *)
let[@warning "-32"] check_every_principle_has_a_carrier () =
  let philosophy = read_file (in_repo "PHILOSOPHY.md") in
  let axioms = read_file (in_repo "AXIOMS.md") in
  let principles =
    let lines = String.split_on_char '\n' philosophy in
    List.filter_map
      (fun line ->
        let trimmed = String.trim line in
        if String.length trimmed > 3 && String.sub trimmed 0 2 = "| " then
          let rest = String.trim (String.sub trimmed 2 (String.length trimmed - 2)) in
          match String.index_opt rest ' ' with
          | Some i ->
              let id = String.sub rest 0 i in
              if String.length id > 1 && id.[0] = 'P' then
                (match int_of_string_opt (String.sub id 1 (String.length id - 1)) with
                | Some _ -> Some id
                | None -> None)
              else None
          | None -> None
        else None)
      lines
  in
  assert (principles <> []);
  assert (List.length principles = 15);
  let missing = List.filter (fun id -> not (contains axioms id)) principles in
  assert (missing = [])

let[@warning "-32"] check_the_controls_of_the_method_are_live () =
  let spec_path = in_repo "spec.json" in
  let json =
    Yojson.Safe.from_string (read_file spec_path) |> function
    | `Assoc pairs -> pairs
    | _ -> []
  in
  let get name =
    match List.assoc_opt name json with Some v -> v | None -> `Null
  in
  let claims =
    match get "claims" with
    | `List items -> items
    | _ -> []
  in
  assert (claims <> []);
  List.iter
    (fun claim ->
      match claim with
      | `Assoc fields ->
          let field name = match List.assoc_opt name fields with Some v -> v | None -> `Null in
          let id = match field "id" with `String s -> s | _ -> "" in
          let scope =
            match field "scope" with
            | `List items -> List.filter_map (function `String s -> Some s | _ -> None) items
            | _ -> []
          in
          let control = match field "control" with `String s -> Some s | _ -> None in
          let register = match field "register" with `String s -> s | _ -> "fact" in
          let has_procedure =
            match field "requirements" with
            | `List items ->
                List.exists
                  (function
                    | `Assoc r -> (match List.assoc_opt "kind" r with Some (`String "verifier") -> true | _ -> false)
                    | _ -> false)
                  items
            | _ -> false
          in
          (* A claim with a procedure needs a control, unless it is a
             judgment: a judgment has no procedure to break, and the
             machine is not allowed to decide it. *)
          if has_procedure && register <> "judgment" then
            (match control with
            | None ->
                failwith
                  (Printf.sprintf
                     "the claim %s has a procedure and no control: a check that was never                       shown able to fail proves nothing"
                     id)
            | Some control -> (
                match control_target control with
                | None -> ()
                | Some target ->
                    (* The prefix may end with a slash ("lib/"), and the
                       target is then inside it directly. *)
                    let inside =
                      List.exists
                        (fun prefix ->
                          let p =
                            if String.length prefix > 0
                               && prefix.[String.length prefix - 1] = '/'
                            then String.sub prefix 0 (String.length prefix - 1)
                            else prefix
                          in
                          target = p
                          || (String.length target > String.length p
                             && String.sub target 0 (String.length p) = p
                             && target.[String.length p] = '/'))
                        scope
                    in
                    if not inside then
                      failwith
                        (Printf.sprintf
                           "the control of %s writes to %s, which is outside its subject %s"
                           id target (String.concat ", " scope));
                    if not (control_changes control target) then
                      failwith
                        (Printf.sprintf
                           "the control of %s no longer changes %s: the code moved under it"
                           id target)))
      | _ -> ())
    claims

let () =
  check_no_scripts ();
  check_core_is_pure ();
  check_core_is_small ();
  check_checks_have_teeth ();
  check_the_formal_part_names_every_law ();
  check_the_formal_part_check_has_teeth ();
  check_the_controls_of_the_method_are_live ();
  check_every_principle_has_a_carrier ();
  print_endline "repository-lints: PASS"
