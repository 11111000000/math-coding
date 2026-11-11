open Domain

let check label condition = if not condition then failwith label

let contains haystack needle =
  let n = String.length haystack and m = String.length needle in
  let found = ref false and index = ref 0 in
  while not !found && !index + m <= n do
    if String.sub haystack !index m = needle then found := true;
    incr index
  done;
  !found

let with_repo f =
  let root = Io.temp_dir "mathc-v5-test" in
  Fun.protect ~finally:(fun () -> Io.remove_tree root) (fun () ->
      ignore (Process.run ~root "git init -q");
      f root)

let write root path content =
  let full_path = Filename.concat root path in
  Io.mkdir_p (Filename.dirname full_path);
  Out_channel.with_open_bin full_path (fun channel -> output_string channel content)

let binary () =
  Filename.concat (Filename.dirname Sys.executable_name) "../bin/mathc.exe"

let run root arguments =
  let command = Printf.sprintf "%s --root %s %s" (Filename.quote (binary ())) (Filename.quote root) arguments in
  let result = Process.run ~timeout:90.0 ~root command in
  if result.code <> 0 && result.stderr <> "" then prerr_endline result.stderr;
  result

let expect root arguments code =
  let result = run root arguments in
  if result.code <> code then (
    Printf.eprintf "%s: expected %d, got %d\n%s%s" arguments code result.code result.stdout result.stderr;
    failwith arguments)

let claim = {
  id = "sample"; text = "the subject is expected"; scope = [ "subject.txt" ];
  source = None; kind = Acceptance; phase = Pre_merge; owner = None; review_on = [];
  requirements = [ Verifier "grep -q expected subject.txt" ];
  falsifier = "the subject is not expected"; register = Fact;
  control = Some "printf broken > subject.txt"; waiver = None;
}

let evidence claim =
  { claim_id = claim.id;
    requirement = Verifier "grep -q expected subject.txt";
    candidate_tree = "tree"; materials_digest = "materials";
    definition_digest = definition_digest claim; verifier_digest = verifier_digest claim;
    environment = { class_ = "local"; fingerprint = "environment" };
    producer = { class_ = "mathc"; identity = "runner"; run = Some "true" };
    independence = Fresh_context; outcome = Pass; issued_at = 1; valid_until = None;
    evidence_ref = None; control_reach = Some "subject" }

let field name json =
  match json with `Assoc pairs -> List.assoc_opt name pairs | _ -> None

let in_repo path =
  let start = Sys.getcwd () in
  let rec find directory =
    if Filename.basename directory = "_build" then Filename.dirname directory
    else if Sys.file_exists (Filename.concat directory "dune-project") then directory
    else
      let parent = Filename.dirname directory in
      if parent = directory then start else find parent
  in
  Filename.concat (find start) path
