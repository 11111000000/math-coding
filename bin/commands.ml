open Domain
open Run_log

let fail code message = Printf.eprintf "mathc: %s\n" message; exit code
let load root =
  match Project.load_spec root with
  | Ok spec -> spec
  | Error error -> Printf.eprintf "mathc: %s\n" error; exit 3

let init root =
  if Sys.file_exists (Filename.concat root "spec.json") then fail 2 "there is already a standing specification"
  else (
    Project.save_spec root { goal = None; claims = []; environment = None };
    print_endline "the standing specification is created\nnext: state the aim (mathc goal TEXT SCOPE BY)";
    0)

let goal root text scope by reason =
  let spec = load root in
  if text = "" || scope = [] || by = "" then fail 2 "goal needs TEXT SCOPE BY"
  else if spec.goal <> None && reason = "" then fail 2 "replacing the aim needs --reason"
  else (
    Project.save_spec root { spec with goal = Some { text; scope; by; at = Execution.now (); reason = (if reason = "" then None else Some reason) } };
    print_endline "the aim is set";
    0)

let rec has_verifier = function
  | Verifier _ -> true
  | Review _ -> false
  | All requirements | Any requirements -> List.exists has_verifier requirements

let rec has_review = function
  | Verifier _ -> false
  | Review _ -> true
  | All requirements | Any requirements -> List.exists has_review requirements

let add root id text scope falsifier register requirements control source_path =
  let spec = load root in
  let inside_aim goal_scope prefix =
    List.exists (fun allowed -> Git.path_contains ~dir:allowed ~path:prefix) goal_scope
  in
  let problem =
    match spec.goal with
    | None -> Some "state the aim first"
    | Some goal ->
        if id = "" || text = "" || falsifier = "" then Some "id, text and falsifier are required"
        else if scope = [] then Some "the scope is empty"
        else if requirements = [] then Some "at least one requirement is required"
        else if List.exists (fun claim -> claim.id = id) spec.claims then Some "the claim id is already used"
        else if not (List.for_all Spec.valid_path scope) then Some "scope contains an invalid path"
        else if not (List.for_all (inside_aim goal.scope) scope) then Some "the scope is outside the aim"
        else None
  in
  match problem with
  | Some error -> fail 2 error
  | None ->
      let register =
        match register_of_string register with
        | Some value -> value
        | None -> fail 2 "register must be fact, hypothesis, judgment or unknown"
      in
      (if register = Judgment && List.exists has_verifier requirements then
         fail 2 "a judgment cannot be established by a machine verifier"
       else if register = Judgment && not (List.exists has_review requirements) then
         fail 2 "a judgment needs a human review requirement");
      let source =
        if source_path = "" then None
        else if not (Spec.valid_path source_path) then fail 2 "source path must stay inside the project"
        else
          match Git.digest_of_repo_file root source_path with
          | Some digest -> Some { kind = Madr; path = source_path; section = None; digest; review = None }
          | None -> fail 2 ("source file not found or not a regular project file: " ^ source_path)
      in
      let claim = {
        id; text; scope; source; kind = Acceptance; phase = Pre_merge;
        owner = Option.map (fun goal -> goal.by) spec.goal; review_on = [];
        requirements; falsifier; register; control = (if control = "" then None else Some control);
        waiver = None; environment = None;
      } in
      Project.save_spec root { spec with claims = spec.claims @ [ claim ] };
      Printf.printf "claim %s declared\n" id;
      0

(* A journal with a damaged record is not whole. The records that can be read
   still stand, so the run rewrites the journal with them and keeps the damaged
   original beside it: nothing that can be read is lost, and the fact of the
   damage stays visible. *)
let repair_trail root =
  match Trail.read root with
  | Error error -> Error error
  | Ok journal -> (
      match Trail.rewrite root journal (Execution.now ()) with
      | Error error -> Error error
      | Ok None -> Ok None
      | Ok (Some backup) -> Ok (Some (List.length journal.damaged, backup)))

(* The price of the run, in words: what the machine spent and where. The
   slowest claims come first, because that is what a consumer has to see to
   know which check to look at. *)
let cost_words (durations : Run_log.priced_claim list) =
  let total =
    List.fold_left (fun sum (priced : Run_log.priced_claim) -> sum +. priced.cost.value) 0.0 durations
  in
  let sorted = List.sort (fun a b -> compare b.cost.value a.cost.value) durations in
  let shown = List.take 10 sorted in
  let header =
    Printf.sprintf "machine time: %.1f s in %d claim(s); the slowest first:" total (List.length durations)
  in
  let lines =
    List.map (fun (priced : Run_log.priced_claim) ->
        Printf.sprintf "  %.1f s  %s" priced.cost.value priced.claim_id) shown
  in
  let rest =
    match List.length sorted - List.length shown with
    | 0 -> []
    | count -> [ Printf.sprintf "  (%d more claim(s) not shown)" count ]
  in
  String.concat "\n" (header :: lines @ rest)

let run ?(changed = false) root json =
  (match Policy.check root with Ok () -> () | Error error -> fail 1 error);
  let spec = load root in
  (* The journal is repaired before the run: a record that cannot be read
     cannot be kept either, and the records that can be read still stand. *)
  (match repair_trail root with
   | Error error -> fail 3 error
   | Ok None -> ()
   | Ok (Some (count, backup)) ->
       let message =
         Printf.sprintf
           "the evidence trail had %d record(s) that could not be read; the journal was rewritten with the records that can be read and the damaged original is kept at %s"
           count backup
       in
       if json then prerr_endline ("mathc: " ^ message) else print_endline ("mathc: " ^ message));
  let files = match Git.repository_files root with Error error -> fail 3 error | Ok files -> files in
  (* A partial run takes the claims whose evidence no longer holds. The
     selection is made before the run: the state of a claim is the state of
     the evidence that is in the journal now. *)
  let selection =
    if changed then
      match Project.selection root spec with
      | Error error -> fail 3 error
      | Ok selection -> Some selection
    else None
  in
  let claims =
    match selection with None -> spec.claims | Some selection -> selection.to_execute
  in
  let emit = Trail.append root in
  let started_at = Execution.now () in
  let started = Unix.gettimeofday () in
  let durations = ref [] in
  List.iter
    (fun claim ->
      (* The environment of the claim is its own when it declares one, and the
         environment of the specification otherwise. It covers the check and
         its negative control alike. *)
      let environment = effective_environment spec claim in
      let claim_started = Unix.gettimeofday () in
      List.iter
        (fun requirement -> ignore (Execution.execute_requirement ~files ~quiet:json ~environment root claim emit requirement))
        claim.requirements;
      (* The price of the claim is measured around all of its work: the check,
         its negative control and the check once more. *)
      let seconds = Unix.gettimeofday () -. claim_started in
      let cost = { scale = Wall_clock_seconds; value = seconds;
                    observed_at = Execution.now (); observed_by = "mathc" } in
      durations := { claim_id = claim.id; cost } :: !durations)
    claims;
  let durations = List.rev !durations in
  let machine_seconds =
    List.fold_left (fun sum (priced : Run_log.priced_claim) -> sum +. priced.cost.value) 0.0 durations
  in
  let record : run_record =
    { started_at; finished_at = Execution.now ();
      wall_seconds = Unix.gettimeofday () -. started; machine_seconds;
      claims = List.length spec.claims; executed = List.length durations;
      stopped = false; durations }
  in
  Run_log.append root record;
  (match selection with
   | None -> ()
   | Some selection ->
       let words = Project.selection_words selection in
       let blind = match Project.blind_words selection with Some words -> words | None -> "" in
       let report =
         if blind = "" then words else words ^ "; " ^ blind
       in
       if json then prerr_endline ("mathc: " ^ report) else print_endline report);
  let cost = cost_words durations in
  if json then prerr_endline ("mathc: " ^ cost) else print_endline cost;
  match Project.map_output root spec with
  | Error error -> fail 3 error
  | Ok output ->
      if json then print_endline (Yojson.Safe.pretty_to_string output.json) else print_string output.text;
      output.exit_code

let map root json =
  let spec = load root in
  match Project.map_output root spec with
  | Error error -> fail 3 error
  | Ok output ->
      if json then print_endline (Yojson.Safe.pretty_to_string output.json) else print_string output.text;
      output.exit_code

let next root =
  let spec = load root in
  match Project.next_text root spec with
  | Error error -> fail 3 error
  | Ok text -> print_endline text; 0

let context root =
  let spec = load root in
  match Project.map_json root spec with
  | Error error -> fail 3 error
  | Ok value -> print_endline (Yojson.Safe.pretty_to_string value); 0

let waive root id by reason valid_for recovery =
  let spec = load root in
  match List.find_opt (fun claim -> claim.id = id) spec.claims with
  | None -> fail 2 ("there is no claim " ^ id)
  | Some claim -> (
      match Project.states root spec with
      | Error error -> fail 3 error
      | Ok states ->
          if by = "" || reason = "" || recovery = "" || valid_for <= 0 then
            fail 2 "waive needs --by, --reason, --valid-for DAYS and --recovery"
          else if List.assoc_opt id states = Some Refuted then fail 2 "a refuted claim cannot be waived"
          else
            let waiver = {
              gap = id; scope = claim.scope; issuer = by; issued_at = Execution.now ();
              expires_at = Execution.now () + (valid_for * 86400); reason;
              compensating_controls = []; recovery; review_on = [];
            } in
            let claims = List.map (fun current -> if current.id = id then { current with waiver = Some waiver } else current) spec.claims in
            Project.save_spec root { spec with claims };
            Printf.printf "claim %s: waived until %d\n" id waiver.expires_at;
            0)

(* The review requirement that the authority answers, anywhere in the tree of
   the requirements of a claim. *)
let rec review_of_authority authority = function
  | (Review { authority = named; _ } as requirement) when named = authority -> Some requirement
  | All requirements | Any requirements -> List.find_map (review_of_authority authority) requirements
  | _ -> None

let record root id authority by outcome valid_for run_ref =
  let spec = load root in
  match List.find_opt (fun claim -> claim.id = id) spec.claims with
  | None -> fail 2 ("there is no claim " ^ id)
  | Some claim ->
      (* The record answers the requirement as the claim declares it: the
         journal finds the evidence by the requirement it belongs to. A record
         is an external attestation, so it satisfies any independence the
         claim asks for. *)
      (match List.find_map (review_of_authority authority) claim.requirements with
       | None -> fail 2 "the claim has no such review requirement"
       | Some requirement ->
           if by = "" then fail 2 "record needs --by"
           else if Option.exists (fun days -> days <= 0) valid_for then
             fail 2 "record --valid-for must be a positive number of days"
           else
             match outcome_of_string outcome with
             | None -> fail 2 "record --outcome must be pass, fail, inconclusive, infrastructure-error or not-run"
             | Some outcome ->
                 let evidence = {
                   claim_id = id; requirement;
                   candidate_tree = Option.value ~default:"unborn" (Git.head_commit root);
                   materials_digest = Git.binding_of_scope root ~scope:claim.scope;
                   definition_digest = definition_digest claim; verifier_digest = verifier_digest claim;
                   environment = Project.environment root;
                   producer = { class_ = "human"; identity = by; run = run_ref };
                   independence = External; outcome; issued_at = Execution.now ();
                   valid_until = Option.map (fun days -> Execution.now () + (days * 86400)) valid_for;
                   evidence_ref = run_ref; control_reach = None;
                 } in
                 Trail.append root evidence;
                 print_endline "recorded";
                 0)

let install root =
  let path = Filename.concat root "AGENTS.md" in
  let existing = if Sys.file_exists path then Io.read_file path else "" in
  let block = Agent_page.block_begin ^ "\n" ^ Agent_page.entry_page (load root) ^ Agent_page.block_end ^ "\n" in
  Io.write_atomic path (Agent_page.with_block existing block);
  print_endline "the page for agents is written";
  0

let version () =
  let build = match Git.digest_of_file Sys.executable_name with Some digest -> digest | None -> "unknown" in
  Printf.printf "mathc 5\nbuild %s\n" build;
  0

let authorize root by reason =
  match Policy.load root with
  | Error error -> fail 2 error
  | Ok None -> fail 2 "there is no policy.json; protected transitions are not configured"
  | Ok (Some policy) -> Policy.authorize root policy by reason

let re_evaluate root =
  let spec = load root in
  match Re_evaluation.pending root spec with
  | Error error -> fail 3 error
  | Ok pending -> print_endline (Yojson.Safe.pretty_to_string (`Assoc [ "needs_re_evaluation", `List (List.map (fun id -> `String id) pending) ])); 0

let review_source root id by reason =
  let spec = load root in
  match List.find_opt (fun claim -> claim.id = id) spec.claims with
  | None -> fail 2 ("there is no claim " ^ id)
  | Some claim -> (
      match claim.source with
      | None -> fail 2 "the claim has no source to review"
      | Some source ->
          if by = "" || reason = "" then fail 2 "review-source needs --by and --reason"
          else if claim.owner <> Some by then fail 2 "only the claim owner can review its source"
          else
            match Git.digest_of_repo_file root source.path with
            | None -> fail 2 ("source file not found: " ^ source.path)
            | Some digest when digest = source.digest -> fail 2 "the source has not changed"
            | Some digest ->
                let previous_digest = source.digest in
                let review = Some { by; reason; at = Execution.now (); previous_digest } in
                let source = { source with digest; review } in
                let claims = List.map (fun current ->
                  if current.id = id then { current with source = Some source; waiver = None } else current) spec.claims in
                Project.save_spec root { spec with claims };
                Printf.printf "claim %s source review recorded; next: mathc run\n" id;
                0)
