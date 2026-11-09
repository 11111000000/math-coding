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

(* A temporary git repository with NOTHING in it. The greenfield
   subject: a project that has a repository and no code yet. The method
   calls an empty project a legal state, and a legal state the method
   cannot leave is a dead end - so the first claim of such a project
   must be declarable, and it must bind when the code appears. *)
let with_empty_repository (f : string -> unit) =
  let path = Filename.temp_file "mathc-cli" ".dir" in
  Sys.remove path;
  Unix.mkdir path 0o755;
  let root = path in
  shell (Printf.sprintf "git -C %s init -q ." (Filename.quote root));
  let cleanup () = ignore (Sys.command ("rm -rf " ^ Filename.quote root)) in
  (try f root with e ->
     cleanup ();
     raise e);
  cleanup ()

(* How much of the uncertainty budget the map says is spent. The map is
   the instrument that reports it, so the test asks the instrument
   rather than keeping a second count of its own - two counts would
   be two truths. *)
let consumed_by_map (text : string) : int =
  let prefix = "uncertainty: " in
  match
    String.split_on_char '\n' text
    |> List.find_opt (fun line ->
           String.length line > String.length prefix
           && String.sub line 0 (String.length prefix) = prefix)
  with
  | None -> -1
  | Some line ->
      let rest = String.sub line (String.length prefix) (String.length line - String.length prefix) in
      (match String.split_on_char ' ' (String.trim rest) with
      | number :: _ -> (
          match int_of_string_opt number with Some n -> n | None -> -1)
      | [] -> -1)

(* --- the battery -------------------------------------------------------- *)

(* The verbs. This list is the method's vocabulary, and the battery
   checks it twice: against the tool, which must know every verb here,
   and against the README, which must name every verb here. *)
let the_verbs =
  [ "init"; "goal"; "add"; "run"; "record"; "accept"; "close"; "route"; "map";
    "next"; "wave"; "draft"; "install"; "doctor"; "propose"; "budget"; "mcp" ]

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
  (* The trail holds acts as well as proofs - a decision of a person is
     an act, not a check - so the first PROOF is looked for, and not
     simply the first line. *)
  let line =
    String.split_on_char '\n' text
    |> List.find (fun l ->
           String.length l > 0
           && (try
                let json = Yojson.Safe.from_string l in
                match json with
                | `Assoc pairs ->
                    List.mem_assoc "at_commit" pairs
                    && List.mem_assoc "producer" pairs
                | _ -> false
              with Yojson.Json_error _ -> false))
  in
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
      expect_ok "goal"
        (call [ "goal"; "the aim"; "subject.txt,planned.txt"; "the owner" ]);
      expect_refusal "goal without a reason"
        (call [ "goal"; "another aim"; "subject.txt,planned.txt"; "the owner" ]);
      expect_ok "goal with a reason"
        (call
           [
             "goal"; "another aim"; "subject.txt,planned.txt"; "the owner"; "--reason";
             "because the aim was wrong";
           ]);

      (* install: the page for agents.

         THE PAGE NEVER REACHED ANYBODY. It travelled with the portable
         binary as a path nobody put anywhere, and the only way it ever
         got into a project was a human copying it by hand - and the
         page that was copied was written for THIS repository, naming
         this repository's tree. So the page is GENERATED now, out of
         the tool's own help and the standing specification, and it is
         written into a marked block: a project that has its own
         AGENTS.md keeps it, because everything outside the block
         belongs to the project. *)
      let page = Filename.concat root "AGENTS.md" in
      let channel = open_out page in
      output_string channel "# the project's own page\n\ndo not touch this\n";
      close_out channel;
      expect_ok "install" (call [ "install" ]);
      let text = read_file page in
      assert (contains text "do not touch this");
      assert (contains text "math-coding:begin");
      assert (contains text "math-coding:end");
      (* And the page names every verb the tool has: a page that omits
         one hides a tool the agent needed, and a page that names a
         verb the tool does not have sends the agent into a verb that
         is not there. *)
      List.iter (fun verb -> assert (contains text ("mathc " ^ verb))) the_verbs;
      (* THE BUDGET OF THE PAGE. The page is read by every agent that opens
         the repository, so its cost is paid every time - and it is the
         method's own cost, not the project's. The page carries the next
         step and the counts; the map is one command away. A page that
         grows with the corpus is a page that taxes every agent that
         arrives. *)
      let page_bytes = String.length text in
      assert (page_bytes <= 1600);
      (* The doctor checks the setup and changes nothing. *)
      expect_ok "doctor" (call [ "doctor" ]);
      (* The page goes stale when the specification changes - and the
         doctor says so instead of letting a stale page rot quietly. *)
      expect_ok "add a claim after the page"
        (call
           [
             "add"; "c-late"; "a claim"; "subject.txt"; "falsifier"; "fact";
             "--requirement"; "verifier:true";
           ]);
      expect_code "doctor with a stale page" 1 (call [ "doctor" ]);
      expect_ok "install again" (call [ "install" ]);
      expect_ok "doctor again" (call [ "doctor" ]);

      (* propose: drafts for a project that has code and no claims.

         THE GAP. The map prints the uncovered surface and nothing
         turned it into a claim: the first claims of every foreign
         project were written by hand. So the drafts are made - and they
         are drafts: the control must be written by whoever owns the
         claim, and the checks the project has are taken from the
         project where it says them out loud. *)
      (* A file that no claim covers - the brownfield case in one file. *)
      let extra = Filename.concat root "extra.txt" in
      let channel = open_out extra in
      output_string channel "nobody claims this\n";
      close_out channel;
      shell (Printf.sprintf "git -C %s add -A ." (Filename.quote root));
      expect_ok "propose with no known check"
        (call [ "propose" ]);
      let _, text = call [ "propose" ] in
      assert (contains text "no draft");
      assert (contains text "extra.txt");
      let _, text = call [ "propose"; "--check"; "true" ] in
      assert (contains text "the uncovered surface");
      assert (contains text "a draft");
      (* A draft decides nothing: it says so, and it leaves the control
         to be written. *)
      assert (contains text "WRITE ME");
      (* And the flag belongs to the verbs that own it, and to no
         other. *)
      expect_refusal "--check outside its verbs"
        (call [ "map"; "--check"; "true" ]);
      (* The file goes away again: the test must not leave debt behind,
         and a suite that runs often must not leave a repository behind
         either. *)
      Sys.remove extra;
      shell (Printf.sprintf "git -C %s add -A ." (Filename.quote root));

      (* version: the binary says which binary it is. The rule was
         declared in the README for a long time and not kept; it is kept
         now, and the hash is of the bytes that are actually running. *)
      let code, text = call [ "--version" ] in
      expect_code "version" 0 (code, text);
      assert (contains text "mathc");
      assert (contains text "build ");

      (* budget: the price of uncertainty, changed by a person - and
         only with a reason. The budget used to be set once, by `init`,
         and never again: a project that grew past it had no way to
         say so except by editing the specification by hand. *)
      expect_refusal "budget without a reason" (call [ "budget"; "5" ]);
      expect_ok "budget with a reason"
        (call [ "budget"; "5"; "--reason"; "the project has grown" ]);
      let spec = read_file (Filename.concat root "spec.json") in
      assert (contains spec "\"uncertainty_budget\": 5");
      (* And the reason is RECORDED, not only printed: a reason that
         lives in the output of one process is a reason nobody can
         check. *)
      let trail = read_file (Filename.concat root ".math/trail.jsonl") in
      assert (contains trail "the project has grown");

      (* add: the agent's move. It refuses a claim with no requirement, a
         claim outside the aim, and a claim about a path that is not
         there. *)
      expect_refusal "add without a requirement"
        (call [ "add"; "c1"; "a claim"; "subject.txt"; "falsifier"; "fact" ]);
      (* A claim may be DECLARED without a control - the control is
         asked for, not forced, because a forced one would be a
         formality and a formality is what the method refuses to be.
         But it is not ESTABLISHED without one: the control is what
         shows the check can fail, and a check that was never shown
         able to fail proves nothing (law A16). So the claim runs, and
         it comes out inconclusive rather than holding. *)
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
      (* A promise about a subject that is not there yet is a PLAN, and
         the method accepts a plan: the refusal that used to stand
         here made the method unusable in an empty repository, whose
         empty state the method itself calls legal. What the method
         will not do is pretend the plan is proven - so the claim stays
         unknown, and the map says which of the two it is. *)
      let _, before = call [ "map" ] in
      let consumed_before = consumed_by_map before in
      expect_ok "add about a path that is not there yet"
        (call
           [
             "add"; "c-plan"; "a promise about code that does not exist yet";
             "planned.txt"; "falsifier"; "fact"; "--requirement"; "verifier:true";
           ]);
      let _, text = call [ "map" ] in
      assert (contains text "the subject is not there yet");
      (* And a plan costs no budget: it is not an uncertainty, it is a
         plan, and it is resolved by writing the code - not by checking
         it. The claim before it IS about code that exists, and that one
         costs. *)
      assert (consumed_by_map text = consumed_before);
      (* And the plan becomes a claim when the code appears: the promise
         was not a dead end, it was a promise - and the queue said so
         all along. *)
      let planned = Filename.concat root "planned.txt" in
      let channel = open_out planned in
      output_string channel "the planned subject\n";
      close_out channel;
      shell (Printf.sprintf "git -C %s add -A ." (Filename.quote root));
      let code, text = call [ "run" ] in
      (* The run is UNKNOWN, not green: one of the claims in this
         repository has no control, so its check was never shown able
         to fail, and the method says "I do not know" instead of
         "it holds". *)
      expect_code "run" 3 (code, text);
      assert (contains text "c-plan: verified");
      expect_ok "add"
        (call
           [
             "add"; "c1"; "a claim about the subject"; "subject.txt";
             "the claim stops holding"; "fact"; "--requirement";
             "verifier:test ! -e probe.txt"; "--requirement"; "review:owner";
             "--control"; "touch probe.txt";
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
         human reads, not only in the JSON a program reads. And it is
         named from the EVIDENCE, not from the declaration: the map
         used to say "the check is proven able to fail" about a control
         that had never run. *)
      assert (contains text "no control is declared");

      (* run: the verifier runs and its control bites, so the verifier is
         closed - but the review is not, so the claim is partly known,
         which is not the same as holding, and the verdict is UNKNOWN,
         not green. The exit code says so: 3, and not 0. *)
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

      (* wave: a unit of work, made by a verb. The mechanism used to be
         WRITE-ONLY: `next` read the waves, `close` read them, and
         nothing made them - the only way to have one was to write the
         JSON by hand. In this repository that was survivable. In a
         foreign project it made the mechanism unusable: the queue
         never named a wave, and closing one always answered "no wave".

         And the verb keeps the discipline of the format rather than
         softening it: a wave without its reasoning, or without the
         objection against it, or without a promise about a claim that
         is declared, is not a wave. *)
      expect_refusal "a wave without its intent"
        (call [ "wave"; "wave-w"; "a wave"; "--check"; "true" ]);
      expect_refusal "a wave without the objection"
        (call
           [
             "wave"; "wave-w"; "a wave"; "--check"; "true"; "--intent"; "why";
           ]);
      expect_refusal "a wave without a check"
        (call
           [
             "wave"; "wave-w"; "a wave"; "--intent"; "why"; "--objection";
             "against"; "--refuted-by"; "how"; "--commit"; "c1=holds";
           ]);
      expect_refusal "a wave promising a claim nobody declared"
        (call
           [
             "wave"; "wave-w"; "a wave"; "--check"; "true"; "--intent"; "why";
             "--objection"; "against"; "--refuted-by"; "how"; "--commit";
             "nosuchclaim=holds";
           ]);
      expect_ok "wave"
        (call
           [
             "wave"; "wave-w"; "a wave"; "--check"; "true"; "--intent"; "why";
             "--objection"; "against"; "--refuted-by"; "how"; "--commit";
             "c1=holds";
           ]);
      assert (Sys.file_exists (Filename.concat root "waves/wave-w.json"));
      (* And the wave the verb wrote is a wave the tool can read: the
         same codec reads it back, so a wave that could not be read
         could not have been written. *)
      let _, text = call [ "next" ] in
      assert (contains text "wave wave-w");
      expect_ok "close a wave the verb made" (call [ "close"; "wave-w" ]);

      (* close: a wave whose checks pass and whose declared verdict is
         established is closed - and it LEAVES THE QUEUE. *)
      write_wave root "wave-x";
      expect_ok "close" (call [ "close"; "wave-x" ]);
      expect_refusal "close a wave that is not there" (call [ "close"; "wave-y" ]);
      let _, text = call [ "next" ] in
      assert (not (contains text "wave wave-x"));

      (* And the control can be given to a claim that was declared
         without one: the method does not leave the agent at a dead
         end. Before the law of A16 entered the core, such a claim was
         green like any other; now it is a request, and a request has
         to be closable - so the control can be attached later. *)
      expect_ok "attach a control to a declared claim"
        (call [ "control"; "c-nocontrol"; "printf broken > subject.txt" ]);
      expect_refusal "a control for a claim that is not there"
        (call [ "control"; "c-nothing"; "true" ]);

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

(* THE CONTROL THAT NEVER RAN.

   The law A16 asks a check to be shown able to fail, and the control
   is how it is shown. A control that DID NOT RUN shows nothing - and
   the method used to read "the control's exit code is not zero" as
   "the control failed", so a control naming a command that does not
   exist (exit 127) certified a check the method had never seen fail.
   A claim with a typo in its control read as PROVEN.

   So the control must run and report a failure. Everything else - it
   could not be executed, it was killed, it could not tell - says the
   same thing: the control proves nothing, and the claim is not
   established. *)
let check_the_control_that_never_ran (binary : string) (prefix : string list) =
  with_repository (fun root ->
      let call args = run_tool binary root (prefix @ args) in
      expect_ok "init" (call [ "init"; "3" ]);
      expect_ok "goal" (call [ "goal"; "the aim"; "subject.txt"; "the owner" ]);
      expect_ok "add"
        (call
           [
             "add"; "c1"; "a claim"; "subject.txt"; "falsifier"; "fact";
             "--requirement"; "verifier:true"; "--control";
             "a-command-that-does-not-exist";
           ]);
      let code, text = call [ "run" ] in
      (* Not established: the check passed, but the control could not
         run, so nothing showed that the check can fail. *)
      expect_code "run with a control that never ran" 3 (code, text);
      assert (contains text "unresolved");
      let _, text = call [ "map" ] in
      assert (contains text "the control did not run");
      assert (contains text "inconclusive");
      (* And the claim is not established: the map says so, and the
         uncertainty budget counts it - a promise nobody could prove
         is worth exactly what an unproven promise is worth. *)
      assert (contains text "uncertainty: 1 of 3 consumed"))

(* THE PROMISED BUT NOT VERIFIED.

   The coverage number counted a file as covered when a claim spoke
   about it - so three never-checked claims over a three-file tree
   gave "uncovered: 0" and the tree looked fully covered while nothing
   in it had been checked. The coverage number is still what it says
   (nobody speaks about the rest), and the surface that is spoken about
   but not checked is now shown BESIDE it, so nothing is hidden. *)
let check_the_promised_surface (binary : string) (prefix : string list) =
  with_repository (fun root ->
      let call args = run_tool binary root (prefix @ args) in
      expect_ok "init" (call [ "init"; "3" ]);
      expect_ok "goal" (call [ "goal"; "the aim"; "subject.txt"; "the owner" ]);
      expect_ok "add"
        (call
           [
             "add"; "c1"; "a claim"; "subject.txt"; "falsifier"; "fact";
             (* The check and the control that breaks it: the check says
                the subject is there, and the control takes it away. A
                check that cannot be shown to fail proves nothing, so
                the pair is what makes the claim establishable. *)
             "--requirement"; "verifier:test -f subject.txt"; "--control";
             "rm -f subject.txt";
           ]);
      let _, text = call [ "map" ] in
      assert (contains text "uncovered: 0 tracked file(s) no claim covers");
      assert (contains text "promised, not verified: 1 tracked file(s)");
      assert (contains text "subject.txt");
      (* And after the check runs, the file is verified - and the
         promised surface is empty. *)
      expect_ok "run" (call [ "run" ]);
      let _, text = call [ "map" ] in
      assert (contains text "promised, not verified: 0");
      (* The machine form of the map says the same thing: the two forms
         must not disagree about the same project. *)
      let _, json = call [ "map"; "--json" ] in
      assert (contains json "\"promised_not_verified\": []"))

(* THE CONTROL THAT BITES.

   A control is only a control if the check goes red on the subject it
   broke. The tool used to accept a command that merely FAILED: "false"
   exits 1, so a claim whose control was "false" read as proven - and
   the method certified checks it had never seen fail.

   Now the control breaks the subject, the check runs on the broken
   subject, and the check must fail THERE. The tree is put back
   afterwards, so the next run of the check sees the same tree it saw
   before, and the trail says that the control bit. *)
let check_the_control_that_bites (binary : string) (prefix : string list) =
  with_repository (fun root ->
      let call args = run_tool binary root (prefix @ args) in
      expect_ok "init" (call [ "init"; "3" ]);
      expect_ok "goal" (call [ "goal"; "the aim"; "subject.txt"; "the owner" ]);
      (* The check: the probe file is not there. The control: the command
         that puts it there. *)
      expect_ok "add"
        (call
           [
             "add"; "c-control"; "the probe file is absent"; "subject.txt";
             "the probe file appears"; "fact"; "--requirement";
             "verifier:test ! -e probe.txt"; "--control"; "touch probe.txt";
           ]);
      let code, text = call [ "run" ] in
      expect_code "run" 0 (code, text);
      assert (contains text "c-control: verified");
      (* THE TREE IS PUT BACK: the control broke the subject on purpose,
         and the method put it back. *)
      assert (not (Sys.file_exists (Filename.concat root "probe.txt")));
      (* AND THE TRAIL SAYS THE CONTROL BIT - a proof made with a
         control and a proof made without one are different facts. *)
      let trail = read_file (Filename.concat root ".math/trail.jsonl") in
      assert (contains trail "\"control\":\"falsified\"");
      let _, text = call [ "map" ] in
      assert (contains text "holds"))

(* --- the documentation -------------------------------------------------- *)

(* THE GREENFIELD. A repository with nothing in it.

   The method calls an empty project a legal state, and a legal state
   the method cannot leave is a dead end: the refusal that used to
   stand in `add` made the first claim of a new project
   undeclareable, so a greenfield project could adopt the method and
   never use it.

   So the promise comes first, the code comes second, and the promise
   binds when the code is there. That is the whole of it - and it is
   checked all the way through, because a promise that can never be
   kept would be worse than no promise. *)
let check_the_greenfield (binary : string) (prefix : string list) =
  with_empty_repository (fun root ->
      let call args = run_tool binary root (prefix @ args) in
      expect_ok "init" (call [ "init"; "3" ]);
      expect_ok "goal" (call [ "goal"; "the aim"; "src/"; "the owner" ]);
      (* The promise comes first. *)
      expect_ok "add a promise about code that does not exist yet"
        (call
           [
             "add"; "c1"; "the parser and its tests"; "src/"; "falsifier";
             "fact"; "--requirement"; "verifier:test -f src/parser.py";
             (* The control is written before the subject exists: it
                names WHAT to break, and there is nothing to break yet -
                which is fine, because the control runs only when the
                subject is there. *)
             "--control"; "rm -f src/parser.py";
           ]);
      (* The map says what it is: a plan, not a proof - and not an
         uncertainty either, so it costs no budget. *)
      let _, text = call [ "map" ] in
      assert (contains text "the subject is not there yet");
      assert (contains text "uncertainty: 0 of 3 consumed");
      (* And the next work is to WRITE it, not to check it: telling the
         agent to check a thing that does not exist is how a queue
         leads an agent in a circle. *)
      let _, text = call [ "next" ] in
      assert (contains text "write the subject");
      (* The check cannot run against a subject that is not there, and
         the method says so instead of pretending. *)
      let code, text = call [ "run" ] in
      expect_code "run" 3 (code, text);
      assert (contains text "the subject is not there yet");
      (* Now the code appears - and the promise binds to it. THIS is
         the point: a promise made before its subject is not a promise
         that can never be kept. *)
      let dir = Filename.concat root "src" in
      Unix.mkdir dir 0o755;
      let file = Filename.concat dir "parser.py" in
      let channel = open_out file in
      output_string channel "def parse():\n    return 1\n";
      close_out channel;
      shell (Printf.sprintf "git -C %s add -A ." (Filename.quote root));
      let code, text = call [ "run" ] in
      expect_code "run" 0 (code, text);
      assert (contains text "c1: verified");
      let _, text = call [ "map" ] in
      assert (contains text "holds"))

(* THE WORK THAT WAS NOT COMMITTED.

   A control breaks the subject on purpose, and the tree is put back
   afterwards. The old way put it back with git, and that is what
   destroyed somebody's work: a path that was ALREADY changed before
   the control was EXCLUDED from the restore - on the right principle,
   "the method does not know what was in it, and throwing away
   somebody's unfinished work would be a worse fault than the mess it
   prevents" - but the control had already OVERWRITTEN it, and the
   method DID know: it had just asked git. So the work was lost, the
   tool said nothing, and it exited successfully.

   The fix is to keep the CONTENT, not the fact of the change. And this
   is the check for it: the claim "the tree is left as the control
   found it" was HOLDS in the method's own repository while it was
   false, because the test it was proved by only ever broke a file
   that was not there before - the easy case. *)
let check_the_control_keeps_the_uncommitted_work (binary : string)
    (prefix : string list) =
  with_repository (fun root ->
      let call args = run_tool binary root (prefix @ args) in
      expect_ok "init" (call [ "init"; "3" ]);
      expect_ok "goal" (call [ "goal"; "the aim"; "subject.txt"; "the owner" ]);
      expect_ok "add"
        (call
           [
             "add"; "c-dirty"; "the subject"; "subject.txt"; "falsifier";
             "fact"; "--requirement"; "verifier:grep -q the.subject subject.txt";
             "--control"; "printf broken > subject.txt";
           ]);
      (* THE WORK THAT IS NOT COMMITTED. The file the control is going
         to break is a file the user has already changed. *)
      let subject = Filename.concat root "subject.txt" in
      let channel = open_out_gen [ Open_append; Open_creat; Open_wronly ] 0o644 subject in
      output_string channel "MY UNSAVED WORK\n";
      close_out channel;
      let code, text = call [ "run" ] in
      expect_code "run" 0 (code, text);
      assert (contains text "c-dirty: verified");
      (* THE WORK IS STILL THERE. The control broke the subject on
         purpose and the method put the subject back - and the subject
         was the user's, not the method's. *)
      let after = read_file subject in
      assert (contains after "MY UNSAVED WORK");
      assert (contains after "the subject"))

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
    the_verbs

let () =
  (* The real tool. *)
  check_the_tool (method_binary ()) [];
  check_the_greenfield (method_binary ()) [];
  check_the_control_that_never_ran (method_binary ()) [];
  check_the_control_that_bites (method_binary ()) [];
  check_the_control_keeps_the_uncommitted_work (method_binary ()) [];
  check_the_promised_surface (method_binary ()) [];

  (* THE NEGATIVE CONTROL. The same battery, pointed at a tool that
     refuses everything: the battery must fail there. A battery that
     passes against both the real tool and a broken one is not a
     battery, it is a comment. *)
  let detected =
    try
      check_the_tool (method_binary ()) [ "--help" ];
      check_the_greenfield (method_binary ()) [ "--help" ];
      check_the_control_that_never_ran (method_binary ()) [ "--help" ];
      check_the_control_that_bites (method_binary ()) [ "--help" ];
      check_the_control_keeps_the_uncommitted_work (method_binary ()) [ "--help" ];
      check_the_promised_surface (method_binary ()) [ "--help" ];
      false
    with _ -> true
  in
  assert detected;

  (* And the greenfield battery has one too: the same check, against the
     same broken tool, must fail there as well. *)
  let greenfield_detected =
    try
      check_the_greenfield (method_binary ()) [ "--help" ];
      false
    with _ -> true
  in
  assert greenfield_detected;

  check_the_documentation_names_every_verb ();
  print_endline "cli: PASS"
