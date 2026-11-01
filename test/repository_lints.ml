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
   own source must say how it is run, or it will be run wrongly. *)

let[@warning "-32"] find_root start =
  let rec loop d =
    if Sys.file_exists (Filename.concat d "dune-project") then d
    else
      let parent = Filename.dirname d in
      if parent = d then start else loop parent
  in
  loop start

let[@warning "-32"] project_root = find_root (Sys.getcwd ())

let[@warning "-32"] in_repo rel = Filename.concat project_root rel

let[@warning "-32"] read_file path = In_channel.with_open_bin path In_channel.input_all

(* The files the repository may not contain. A program is not a script:
   every executable unit is an OCaml program or a subcommand of the
   binary, and the check that says so is itself an OCaml program. *)
let[@warning "-32"] forbidden_extensions = [ ".sh"; ".py"; ".bash"; ".zsh" ]

(* The directories the lints do not read. `.git` is the repository's
   history and `_build` is the compiler's output; neither is part of the
   method, and both are excluded while descending rather than after:
   filtering after the walk would still read thousands of files. *)
let[@warning "-32"] skipped_directories = [ ".git"; "_build" ]

let rec list_files dir =
  Sys.readdir dir |> Array.to_list |> List.concat_map (fun name ->
      let path = Filename.concat dir name in
      if Sys.is_directory path then
        if List.mem name skipped_directories then [] else list_files path
      else [ path ])

let[@warning "-32"] relative path =
  let root = String.length project_root + 1 in
  if String.length path > root then String.sub path root (String.length path - root) else path

let[@warning "-32"] check_no_scripts () =
  let offenders =
    list_files project_root
    |> List.filter (fun path ->
        List.exists
          (fun ext -> Filename.check_suffix path ext)
          forbidden_extensions)
    |> List.map relative
  in
  assert (offenders = [])

(* The core is lib/. It must not contain an effect: no I/O, no clock, no
   randomness. The words below are the usual spellings of those in
   OCaml; the list is explicit rather than heuristic because a heuristic
   lint that grows on its own becomes a second source of truth.

   Comments are removed before the scan. A lint that reads prose finds
   prose: the comment above this line says "exit code", and the name
   [verdict_to_exit] contains "exit", neither of which is a call. What
   is scanned is the code, and only the code. *)
let[@warning "-32"] strip_comments src =
  let lines = String.split_on_char '\n' src in
  let buffer = Buffer.create (String.length src) in
  let in_block = ref false in
  List.iter
    (fun line ->
      let out = Buffer.create (String.length line) in
      let i = ref 0 in
      let n = String.length line in
      while !i < n do
        if !in_block then
          if !i + 1 < n && line.[!i] = '*' && line.[!i + 1] = '/' then (
            in_block := false;
            i := !i + 2)
          else i := !i + 1
        else if !i + 1 < n && line.[!i] = '(' && line.[!i + 1] = '*' then (
          in_block := true;
          i := !i + 2)
        else if !i + 1 < n && line.[!i] = '*' && line.[!i + 1] = ')' then (
          i := !i + 2;
          while !i < n && not (!i + 1 < n && line.[!i] = '*' && line.[!i + 1] = ')') do
            i := !i + 1
          done;
          if !i < n then i := !i + 2)
        else (
          Buffer.add_char out line.[!i];
          i := !i + 1)
      done;
      Buffer.add_string buffer (Buffer.contents out);
      Buffer.add_char buffer '\n')
    lines;
  Buffer.contents buffer

let[@warning "-32"] impure_calls =
  [ "open_in"; "open_out"; "open_out_gen"; "close_out"; "Sys.file_exists";
    "Sys.readdir"; "Sys.is_directory"; "Unix.stat"; "Unix.openfile"; "Unix.mkdir";
    "Unix.gettimeofday"; "Random.self_init"; "Sys.command"; "Sys.getenv";
    "print_endline"; "print_string"; "Printf.printf"; "exit" ]

let[@warning "-32"] check_core_is_pure () =
  let core = in_repo "lib" in
  List.iter
    (fun path ->
      if Filename.check_suffix path ".ml" then
        let src = strip_comments (read_file path) in
        List.iter
          (fun call ->
            let needle = call ^ " " in
            assert (
              not
                (let re = Str.regexp (Str.quote needle) in
                 try
                   ignore (Str.search_forward re src 0);
                   true
                 with Not_found -> false)))
          impure_calls)
    (list_files core)

(* The ceiling on the size of the core. A core that grows past this is a
   core nobody has read, and an unread core is where the laws stop being
   laws. The number is a decision, not a measurement: it is set before
   the code exists, so that it constrains the code rather than
   describing it. *)
let[@warning "-32"] core_line_ceiling = 800

let[@warning "-32"] check_core_is_small () =
  let core = in_repo "lib" in
  let lines =
    list_files core
    |> List.filter (fun path -> Filename.check_suffix path ".ml")
    |> List.map (fun path -> List.length (String.split_on_char '\n' (read_file path)))
    |> List.fold_left ( + ) 0
  in
  assert (lines <= core_line_ceiling)

(* Every check carries a proof that it can fail. A check file that does
   not mention the words below has no negative control, and a check
   without a negative control is a comment. *)
let[@warning "-32"] check_checks_have_teeth () =
  let tests = in_repo "test" in
  let offenders =
    list_files tests
    |> List.filter (fun path -> Filename.check_suffix path ".ml")
    |> List.filter (fun path ->
        let src = read_file path in
        not
          (let re = Str.regexp "negative control" in
           try
             ignore (Str.search_forward re src 0);
             true
           with Not_found -> false))
    |> List.map relative
  in
  assert (offenders = [])

let () =
  check_no_scripts ();
  check_core_is_pure ();
  check_core_is_small ();
  check_checks_have_teeth ();
  print_endline "repository-lints: PASS"
