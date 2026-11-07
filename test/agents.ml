(* The entry point for an agent, and the proof that it agrees with the
   tool.

   WHY THIS EXISTS. The agent arm of 2026-11-07 measured what the
   protocol costs, and the largest part of it was not the bookkeeping:
   it was the agent reading the method's SOURCE to learn the
   interface - 35 of the 47 extra tool calls. A guide that names every
   verb and every rule costs one read instead of thirty-five, and this
   file is that guide.

   WHY IT NEEDS A CHECK. A guide is prose, and prose does not fail -
   it just gets stale. The verbs of the tool change, and the guide
   keeps naming the old ones, and an agent follows the guide into a
   verb that no longer exists. So the check is here: every verb the
   tool's own help lists must be named in the guide. The guide is bound
   to the tool, the same way the formal part is bound to the code.

   THE NEGATIVE CONTROL. The check must be able to say no. A guide that
   misses a verb is offered to it and must be rejected - otherwise the
   check is a comment with a file name on it. *)

(* The verbs the tool has, as the tool's own help lists them. The help
   is the tool's output, so this is not a second list of the verbs
   maintained by hand: it is read from the same place an agent reads
   it. *)
let verbs_of_help (help : string) : string list =
  help
  |> String.split_on_char '\n'
  |> List.filter_map (fun line ->
         let trimmed = String.trim line in
         if String.length trimmed > 6 && String.sub trimmed 0 6 = "mathc " then
           let rest = String.sub trimmed 6 (String.length trimmed - 6) in
           match String.index_opt rest ' ' with
           | Some i -> Some (String.sub rest 0 i)
           | None -> Some rest
         else None)

(** Does the text contain the needle at all? *)
let contains (haystack : string) (needle : string) =
  let n = String.length haystack and m = String.length needle in
  let found = ref false in
  let i = ref 0 in
  while (not !found) && !i + m <= n do
    if String.sub haystack !i m = needle then found := true else i := !i + 1
  done;
  !found

let is_word_char c =
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')
  || c = '_'

(** Does the text contain the word, and not a longer word with it
    inside? "init" must not be found in "initialise", and "run" must not
    be found in "runtime". *)
let contains_word (haystack : string) (needle : string) =
  let n = String.length haystack and m = String.length needle in
  let found = ref false in
  let i = ref 0 in
  while (not !found) && !i + m <= n do
    (* The index ALWAYS moves: a substring that matches but is not a
       whole word is not the word, and standing still on it would
       search for ever. *)
    let at = !i in
    if String.sub haystack at m = needle then (
      let before_ok = at = 0 || not (is_word_char haystack.[at - 1]) in
      let after = at + m in
      let after_ok = after >= n || not (is_word_char haystack.[after]) in
      if before_ok && after_ok then found := true);
    i := !i + 1
  done;
  !found

(* The guide must name every verb the tool has. *)
let check_the_guide (guide : string) (help : string) =
  let verbs = verbs_of_help help in
  assert (verbs <> []);
  (* The guide is about the tool, so it must name the tool. *)
  assert (contains guide "mathc");
  List.iter (fun verb -> assert (contains_word guide verb)) verbs

(* The source tree. Dune runs the test from the build directory, and the
   build directory is always named _build, so the source tree is its
   parent - and the guide lives there, while the binary lives in the
   build tree. Two roots, and the test has to know both. *)
let source_root () =
  let rec loop d =
    if Filename.basename d = "_build" then Filename.dirname d
    else
      let parent = Filename.dirname d in
      if parent = d then d else loop parent
  in
  loop (Sys.getcwd ())

let () =
  (* The tool's own help, run here rather than copied here. *)
  (* The binary is in the bin directory of the BUILD tree. Dune runs the
     test from that tree's test directory, so the walk goes up until it
     finds the tool - and a path that is looked for is a path that
     works; a path that is assumed is a path that breaks when the
     runner changes. *)
  let rec find_tool d =
    let candidate = Filename.concat d "bin/mathc.exe" in
    if Sys.file_exists candidate then candidate
    else
      let parent = Filename.dirname d in
      if parent = d then failwith "the tool was not found in the build tree"
      else find_tool parent
  in
  let binary = find_tool (Sys.getcwd ()) in
  let help =
    let out = Filename.temp_file "mathc-help" ".txt" in
    let cmd = Printf.sprintf "%s --help > %s 2>&1" (Filename.quote binary) (Filename.quote out) in
    ignore (Sys.command cmd);
    let channel = open_in out in
    let content = In_channel.input_all channel in
    close_in channel;
    Sys.remove out;
    content
  in
  (* The guide of this repository. *)
  let guide_path = Filename.concat (source_root ()) "AGENTS.md" in
  assert (Sys.file_exists guide_path);
  let channel = open_in guide_path in
  let guide = In_channel.input_all channel in
  close_in channel;
  check_the_guide guide help;

  (* THE NEGATIVE CONTROL: a guide that misses a verb must be rejected.
     The check reads the verbs from the tool, so the control takes one
     away - and the check must notice. *)
  let verbs = verbs_of_help help in
  let without_one =
    match verbs with
    | [] -> ""
    | first :: rest -> String.concat "\n" rest
  in
  let rejected =
    try
      check_the_guide without_one help;
      false
    with _ -> true
  in
  assert rejected;

  print_endline "agents: PASS"
