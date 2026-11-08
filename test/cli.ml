(* The tool itself, end to end.

   THE GAP THIS FILLS. The method's instruments covered the laws and the
   shape of the tree, and NOTHING covered the TOOL: the ten verbs were
   never run by a test. So a verb could be broken while the whole suite
   stayed green - and one was. `--requirement` was in the usage text for
   six days, the parser had no branch for it, `add` refused every claim,
   and every test passed throughout. A verb that is never run is a verb
   that may not work.

   THE SUBJECT. A temporary git repository with one committed file. The
   method's own tree is not the subject: a test that ran against it would
   pass or fail with the method's own commits, and its failure would say
   nothing about the tool.

   THE NEGATIVE CONTROL. The same battery, pointed at a tool that refuses
   everything, must FAIL. A battery that passes against both the real
   tool and a broken one is not a battery, it is a comment. *)

open Domain

(* --- the tool under test ---------------------------------------------- *)

(* Where the tool is. The test runs from the build directory, and the
   tool is built beside it. The path is looked for rather than assumed:
   a test that silently skipped itself would be the same defect it
   exists to catch. *)
let method_binary () =
  let candidates =
    match Sys.getenv_opt "MATHC" with
    | Some p -> [ p ]
    | None ->
        let here = Filename.dirname Sys.argv.(0) in
        let cwd = Sys.getcwd () in
        [
          Filename.concat (Filename.dirname here) "bin/mathc.exe";
          Filename.concat (Filename.dirname cwd) "bin/mathc.exe";
        ]
  in
  match List.find_opt Sys.file_exists candidates with
  | Some p -> p
  | None ->
      failwith
        (Printf.sprintf "the tool under test was not found; looked at %s"
           (String.concat ", " candidates))

let read_file path =
  let channel = open_in path in
  let content = In_channel.input_all channel in
  close_in channel;
  content

let contains (haystack : string) (needle : string) =
  let n = String.length haystack and m = String.length needle in
  let found = ref false in
  let i = ref 0 in
  while (not !found) && !i + m <= n do
    if String.sub haystack !i m = needle then found := true else i := !i + 1
  done;
  !found

let shell (cmd : string) =
  let code = Sys.command cmd in
  if code <> 0 then
    failwith (Printf.sprintf "the test's own setup failed: %s (exit %d)" cmd code)

(* --- running the tool -------------------------------------------------- *)

(* The tool is run, and what it said is read back. *)
let run_tool (binary : string) (root : string) (args : string list) : int * string =
  let out = Filename.temp_file "mathc-cli" ".out" in
  let cmd =
    Printf.sprintf "%s --root %s %s > %s 2>&1"
      (Filename.quote binary) (Filename.quote root)
      (String.concat " " (List.map Filename.quote args))
      (Filename.quote out)
  in
  let code = Sys.command cmd in
  let text = read_file out in
  Sys.remove out;
  (code, text)

let fail what code text =
  failwith (Printf.sprintf "%s: exit %d\n%s" what code text)

let expect_code what expected (code, text) =
  if code <> expected then fail what code text

let expect_ok what result = expect_code what 0 result

(* A refusal is the method saying no. It is not an error: it is the
   friction, and it is the thing that has to be checked. *)
let expect_refusal what result =
  let code, text = result in
  if code = 0 then fail what code text

(* --- the subject -------------------------------------------------------- *)

(* A temporary git repository with one committed file. *)
let with_repository (f : string -> unit) =
  let path = Filename.temp_file "mathc-cli" ".dir" in
  Sys.remove path;
  Unix.mkdir path 0o755;
  let root = path in
  shell (Printf.sprintf "git -C %s init -q ." (Filename.quote root));
  let file = Filename.concat root "subject.txt" in
  let channel = open_out file in
  output_string channel "the subject\n";
  close_out channel;
  shell (Printf.sprintf "git -C %s add -A ." (Filename.quote root));
  shell
    (Printf.sprintf
       "git -C %s -c user.email=test@example -c user.name=test commit -qm init ."
       (Filename.quote root));
  (* The subject is cleaned up: a suite that runs often must not leave
     a repository behind every time. *)
  let cleanup () = ignore (Sys.command ("rm -rf " ^ Filename.quote root)) in
  (try f root with e ->
     cleanup ();
     raise e);
  cleanup ()

(* --- the battery -------------------------------------------------------- *)

(* The ten verbs. This list is the method's vocabulary, and the battery
   checks it twice: against the tool, which must know every verb here,
   and against the README, which must name every verb here. *)
let the_ten_verbs =
  [ "init"; "goal"; "add"; "run"; "record"; "accept"; "close"; "route"; "map";
    "next" ]

let write_wave root id =
  let dir = Filename.concat root "waves" in
  if not (Sys.file_exists dir) then Unix.mkdir dir 0o755;
  let path = Filename.concat dir (id ^ ".json") in
  let channel = open_out path in
  output_string channel
    (Printf.sprintf
       {|{"id": "%s", "title": "a wave of the test", "intent": "to check that the tool works at all", "touches": ["subject.txt"], "checks": ["true"], "claims": ["c1"], "commitment": [{"claim": "c1", "state": "holds"}], "objection": "the tool may not work at all", "refuted_by": "the battery below"}|}
       id);
  close_out channel

(* A wave whose promise is not met. The promise is the criterion of
   the closing, so a wave that promises something the claims do not
   deliver must not close - and must stay in the queue. *)
let write_wave_promising root id state =
  let dir = Filename.concat root "waves" in
  if not (Sys.file_exists dir) then Unix.mkdir dir 0o755;
  let path = Filename.concat dir (id ^ ".json") in
  let channel = open_out path in
  output_string channel
    (Printf.sprintf
       {|{"id": "%s", "title": "a wave whose promise is not met", "intent": "to check that the promise is the criterion", "touches": ["subject.txt"], "checks": ["true"], "claims": ["c1"], "commitment": [{"claim": "c1", "state": "%s"}], "objection": "a promise nobody checks is a wish", "refuted_by": "the closing refuses it"}|}
       id state);
  close_out channel

(** The proof is anchored to the act: the commit its content was read
    from, and the moment it was produced.

    The content the method binds to is the content of HEAD, so the
    commit is exactly the one the proof is about - not an approximation
    of it. The third version carried this anchor in every attestation
    and the fourth lost it with the whole corpus; without a check it
    would be lost again silently, because a field nobody reads and
    nobody checks is a field that disappears.

    So the check is here: the trail line must name the very commit the
    temporary repository is at. If the anchor were dropped, the line
    would have no commit and this would fail. *)
let check_the_trail_anchors_the_act (root : string) =
  let path = Filename.concat root ".math/trail.jsonl" in
  let text = read_file path in
  let line = String.split_on_char '\n' text |> List.hd in
  let json = Yojson.Safe.from_string line in
  let get name =
    match json with
    | `Assoc pairs -> (
        match List.assoc_opt name pairs with
        | Some (`String s) -> Some s
        | _ -> None)
    | _ -> None
  in
  (* The commit the repository is at. *)
  let out = Filename.temp_file "mathc-head" ".txt" in
  let cmd =
    Printf.sprintf "git -C %s rev-parse HEAD > %s 2>/dev/null"
      (Filename.quote root) (Filename.quote out)
  in
  ignore (Sys.command cmd);
  let head = String.trim (read_file out) in
  Sys.remove out;
  assert (head <> "");
  assert (get "at_commit" = Some head);
  (* And the moment of production is there too. *)
  assert (get "at" <> None)

let check_the_tool (binary : string) (prefix : string list) =
  with_repository (fun root ->
      let call args = run_tool binary root (prefix @ args) in

      (* init: one file, and no aim and no claims. Adoption must cost
         nothing, and a second init must not overwrite what is there. *)
      expect_ok "init" (call [ "init"; "3" ]);
      assert (Sys.file_exists (Filename.concat root "spec.json"));
      expect_refusal "init twice" (call [ "init"; "3" ]);

      (* goal: the human's move. Replacing the aim needs a reason. *)
      expect_ok "goal" (call [ "goal"; "the aim"; "subject.txt"; "the owner" ]);
      expect_refusal "goal without a reason"
        (call [ "goal"; "another aim"; "subject.txt"; "the owner" ]);
      expect_ok "goal with a reason"
        (call
           [
             "goal"; "another aim"; "subject.txt"; "the owner"; "--reason";
             "because the aim was wrong";
           ]);

      (* add: the agent's move. It refuses a claim with no requirement, a
         claim outside the aim, and a claim about a path that is not
         there. *)
      expect_refusal "add without a requirement"
        (call [ "add"; "c1"; "a claim"; "subject.txt"; "falsifier"; "fact" ]);
      (* A claim may be declared without a control - but then the map
         says that its check is not proven able to fail. The control is
         asked for, not forced: a forced one would be a formality, and a
         formality is what the method refuses to be. *)
      expect_ok "add without a negative control"
        (call
           [
             "add"; "c-nocontrol"; "a claim"; "subject.txt"; "falsifier";
             "fact"; "--requirement"; "verifier:true";
           ]);
      expect_refusal "add outside the aim"
        (call
           [
             "add"; "c1"; "a claim"; "elsewhere.txt"; "falsifier"; "fact";
             "--requirement"; "verifier:true";
           ]);
      expect_refusal "add about a path that is not there"
        (call
           [
             "add"; "c1"; "a claim"; "missing.txt"; "falsifier"; "fact";
             "--requirement"; "verifier:true";
           ]);
      expect_ok "add"
        (call
           [
             "add"; "c1"; "a claim about the subject"; "subject.txt";
             "the claim stops holding"; "fact"; "--requirement";
             "verifier:true"; "--requirement"; "review:owner"; "--control";
             "false";
           ]);

      (* map: the claim is there, and the map is data as well as prose. *)
      let _, text = call [ "map" ] in
      assert (contains text "c1");
      let code, json = call [ "map"; "--json" ] in
      assert (contains json "\"id\": \"c1\"");

      (* THE MAP SAYS WHOSE CHECK WAS SHOWN ABLE TO FAIL. The machine
         form of the map has said this for a while, and the human form
         did not, so the two forms of one map disagreed about one claim:
         a claim whose check has never been shown to fail looked exactly
         like a claim whose check has.

         The law is A16, and the map is where a law becomes visible. So
         the claim without a control is named as such - in the prose the
         human reads, not only in the JSON a program reads. *)
      assert (contains text "the check is not proven able to fail");

      (* run: the verifier runs, and one of the two requirements is
         closed - so the claim is partly known, which is not the same as
         holding, and the verdict is UNKNOWN, not green. The exit code
         says so: 3, and not 0. *)
      let code, text = call [ "run" ] in
      expect_code "run" 3 (code, text);
      assert (contains text "c1: verified");
      let _, text = call [ "map" ] in
      assert (contains text "inconclusive");

      (* route: what waits for a person is shown, even though there is
         no evidence for it at all. *)
      let _, text = call [ "route" ] in
      assert (contains text "owner");

      (* record: evidence from outside closes the review requirement.
         The requirement is named by what it names - the authority. It
         goes to the SPECIFICATION: the trail is rebuilt by running
         the checks, and a person's word cannot be produced again by
         anybody. The reason must not be lost either. *)
      expect_ok "record"
        (call
           [
             "record"; "c1"; "owner"; "--by"; "owner"; "--outcome"; "verified";
             "--reason"; "the owner looked";
           ]);
      let spec = read_file (Filename.concat root "spec.json") in
      assert (contains spec "attestations");
      assert (contains spec "the owner looked");
      let _, text = call [ "map" ] in
      assert (contains text "holds");

      (* accept: a person takes responsibility for an uncertainty. It
         needs a name and a reason. *)
      expect_ok "add a second claim"
        (call
           [
             "add"; "c2"; "a claim nobody checked"; "subject.txt";
             "falsifier"; "hypothesis"; "--requirement"; "verifier:false";
             "--control"; "false";
           ]);
      expect_refusal "accept without a name"
        (call [ "accept"; "c2"; ""; "because" ]);
      expect_refusal "accept without a reason" (call [ "accept"; "c2"; "owner"; "" ]);
      expect_ok "accept" (call [ "accept"; "c2"; "owner"; "because" ]);
      let _, text = call [ "map" ] in
      assert (contains text "accepted");

      (* close: a wave whose checks pass and whose declared verdict is
         established is closed - and it LEAVES THE QUEUE. *)
      write_wave root "wave-x";
      expect_ok "close" (call [ "close"; "wave-x" ]);
      expect_refusal "close a wave that is not there" (call [ "close"; "wave-y" ]);
      let _, text = call [ "next" ] in
      assert (not (contains text "wave wave-x"));

      (* next: the work that is left. Nothing is left here, and saying
         so is the answer. *)
      let code, text = call [ "next" ] in
      expect_code "next" 0 (code, text);
      assert (contains text "nothing to do");

      (* A wave whose promise is not met does not close, and it stays
         in the queue. The promise is the criterion: a wave that
         promises what the claims do not deliver is a wish, and a wish
         is not a wave. *)
      write_wave_promising root "wave-p" "refuted";
      expect_refusal "close a wave whose promise is not met"
        (call [ "close"; "wave-p" ]);
      let _, text = call [ "next" ] in
      assert (contains text "wave wave-p");
      (* THE LAW OF THE NEGATIVE CONTROL. A check that passes where its
         control had to fail cannot see the subject, and the proof it
         produced is no proof: the claim is not established, and the map
         says why.

         The blind claim here has a control that PASSES where it had to
         fail - and its check passes too. So the check is blind, and
         the claim must not read as established. *)
      expect_ok "add a claim with a blind check"
        (call
           [
             "add"; "c-blind"; "a claim whose check cannot fail";
             "subject.txt"; "falsifier"; "fact"; "--requirement";
             "verifier:true"; "--control"; "true";
           ]);
      (* The check is run, and it passes - and so does the control,
         where it had to fail. So the check is blind. *)
      (* The run exits 1 - red - because the second claim of the
         battery is falsified by its own check, and the blind one is
         unresolved. The verdict of the project is no longer green, and
         that is the point of the law: a check that cannot fail does
         not get to say "verified". *)
      expect_code "run with the blind claim" 1 (call [ "run" ]);
      let _, text = call [ "map" ] in
      assert (contains text "c-blind");
      assert (contains text "inconclusive");
      (* And the reason is named, not hidden: the route must show that
         this claim waits for a person, and why. *)
      let _, text = call [ "route" ] in
      assert (contains text "cannot see the subject");

      (* A flag that belongs to one verb must not be accepted by
         another. *)
      expect_refusal "--requirement outside add"
        (call [ "map"; "--requirement"; "verifier:true" ]);

      (* And the proof is anchored to the act. *)
      check_the_trail_anchors_the_act root)

(* --- the documentation -------------------------------------------------- *)

(* The source tree. Dune runs the test from the build directory, and the
   build directory is always named _build, so the source tree is its
   parent. *)
let source_root () =
  let rec loop d =
    if Filename.basename d = "_build" then Filename.dirname d
    else
      let parent = Filename.dirname d in
      if parent = d then failwith "the source tree was not found" else loop parent
  in
  loop (Sys.getcwd ())

(* Every verb of the tool is named in the README. The README is how an
   agent reading the repository learns what the tool can do, so an
   instrument that is not described there is an instrument nobody will
   use - and the verb table is the only place the list is written
   down. *)
let check_the_documentation_names_every_verb () =
  let text = read_file (Filename.concat (source_root ()) "README.md") in
  List.iter
    (fun verb -> assert (contains text ("mathc " ^ verb)))
    the_ten_verbs

let () =
  (* The real tool. *)
  check_the_tool (method_binary ()) [];

  (* THE NEGATIVE CONTROL. The same battery, pointed at a tool that
     refuses everything: the battery must fail there. A battery that
     passes against both the real tool and a broken one is not a
     battery, it is a comment. *)
  let detected =
    try
      check_the_tool (method_binary ()) [ "--help" ];
      false
    with _ -> true
  in
  assert detected;

  check_the_documentation_names_every_verb ();
  print_endline "cli: PASS"
