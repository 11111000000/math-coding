open Domain

let fail code message = Printf.eprintf "mathc: %s\n" message; exit code
let now () = int_of_float (Unix.time ())
let load root =
  match Project.load_spec root with
  | Ok spec -> spec
  | Error error -> Printf.eprintf "mathc: %s\n" error; exit 3

let init root =
  if Sys.file_exists (Filename.concat root "spec.json") then fail 2 "there is already a standing specification"
  else (
    Project.save_spec root { goal = None; claims = [] };
    print_endline "the standing specification is created\nnext: state the aim (mathc goal TEXT SCOPE BY)";
    0)

let goal root text scope by reason =
  let spec = load root in
  if text = "" || scope = [] || by = "" then fail 2 "goal needs TEXT SCOPE BY"
  else if spec.goal <> None && reason = "" then fail 2 "replacing the aim needs --reason"
  else (
    Project.save_spec root { spec with goal = Some { text; scope; by; at = now (); reason = (if reason = "" then None else Some reason) } };
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
        waiver = None;
      } in
      Project.save_spec root { spec with claims = spec.claims @ [ claim ] };
      Printf.printf "claim %s declared\n" id;
      0

let evidence_for ?files root (claim : claim) requirement command outcome control_reach =
  let binding = Option.value ~default:"" (Git.digest_of_scope ?files root ~scope:claim.scope) in
  { claim_id = claim.id; requirement;
    candidate_tree = Option.value ~default:"unborn" (Git.head_commit root);
    materials_digest = binding;
    definition_digest = definition_digest claim;
    verifier_digest = verifier_digest claim;
    environment = Project.environment root;
    producer = { class_ = "mathc"; identity = Sys.executable_name; run = Some command };
    independence = Fresh_context; outcome; issued_at = now (); valid_until = None;
    evidence_ref = None; control_reach }

let report_failure label (result : Process.result) =
  if result.code <> 0 || result.truncated then (
    Printf.eprintf "mathc: %s exited %d%s\n%s%s" label result.code
      (if result.truncated then " (output truncated)" else "") result.stdout result.stderr;
    if result.stdout = "" && result.stderr = "" then prerr_newline ())

let rec execute_requirement ?files ?(quiet = false) root claim items requirement : Domain.outcome =
  match requirement with
  | Review { authority; _ } ->
      if not quiet then Printf.printf "%s: review by %s is not the method's to do\n" claim.id authority;
      Inconclusive
  | Verifier command -> (
      match Git.digest_of_scope ?files root ~scope:claim.scope with
      | None ->
          if not quiet then Printf.printf "%s: the subject is not whole or does not exist\n" claim.id;
          Inconclusive
      | Some _ ->
          let result = Process.run ~timeout:60.0 ~root command in
          report_failure command result;
          let outcome = if result.truncated then Infrastructure_error else result.outcome in
          let outcome, reach =
            match outcome, claim.control with
            | Pass, Some control -> (
                match Isolated_run.with_copy root (fun copy ->
                    let before = Git.digest_of_scope copy ~scope:claim.scope in
                    let mutation = Process.run ~timeout:30.0 ~root:copy control in
                    report_failure ("negative control: " ^ control) mutation;
                    let after = Git.digest_of_scope copy ~scope:claim.scope in
                    let reach = if before = after then "nothing" else "subject" in
                    let check = Process.run ~timeout:60.0 ~root:copy command in
                    report_failure ("verifier after negative control: " ^ command) check;
                    if reach = "subject" && check.code = 1 then Pass, Some reach
                    else Inconclusive, Some reach) with
                | Error error ->
                    Printf.eprintf "mathc: control setup failed: %s\n" error;
                    Infrastructure_error, None
                | Ok (outcome, reach) -> outcome, reach)
            | Pass, None -> Not_run, None
            | outcome, _ -> outcome, None
          in
          let evidence = evidence_for ?files root claim requirement command outcome reach in
          items := evidence :: !items;
          if not quiet then (
            Printf.printf "%s: %s\n" claim.id (outcome_to_string outcome);
            if outcome = Pass && reach = Some "subject" then
              Printf.printf "%s: negative control proven (subject changed; verifier failed)\n" claim.id);
          outcome)
  | All requirements ->
      let rec run_all (requirements : requirement list) : outcome =
        match requirements with
        | [] -> Pass
        | requirement :: rest ->
            let outcome = execute_requirement ?files ~quiet root claim items requirement in
            (match outcome with
            | Pass -> run_all rest
            | Fail -> Fail
            | Inconclusive | Infrastructure_error | Not_run -> (
                match run_all rest with
                | Fail -> Fail
                | Pass | Inconclusive | Infrastructure_error | Not_run -> outcome))
      in
      (run_all requirements : Domain.outcome)
  | Any requirements ->
      let rec run_any (requirements : requirement list) : outcome =
        match requirements with
        | [] -> Inconclusive
        | requirement :: rest ->
            let outcome = execute_requirement ?files ~quiet root claim items requirement in
            if outcome = Pass then Pass else run_any rest
      in
      (run_any requirements : Domain.outcome)

let run root json =
  (match Policy.check root with Ok () -> () | Error error -> fail 1 error);
  let spec = load root in
  let files = match Git.repository_files root with Error error -> fail 3 error | Ok files -> files in
  let items = ref [] in
  List.iter
    (fun claim ->
      List.iter
        (fun requirement -> ignore (execute_requirement ~files ~quiet:json root claim items requirement))
        claim.requirements)
    spec.claims;
  List.iter (Trail.append root) (List.rev !items);
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
              gap = id; scope = claim.scope; issuer = by; issued_at = now ();
              expires_at = now () + (valid_for * 86400); reason;
              compensating_controls = []; recovery; review_on = [];
            } in
            let claims = List.map (fun current -> if current.id = id then { current with waiver = Some waiver } else current) spec.claims in
            Project.save_spec root { spec with claims };
            Printf.printf "claim %s: waived until %d\n" id waiver.expires_at;
            0)

let record root id authority by outcome valid_for run_ref =
  let spec = load root in
  match List.find_opt (fun claim -> claim.id = id) spec.claims with
  | None -> fail 2 ("there is no claim " ^ id)
  | Some claim ->
      let requirement = Review { authority; minimum_independence = External } in
      if not (List.mem requirement claim.requirements) then fail 2 "the claim has no such review requirement"
      else if by = "" then fail 2 "record needs --by"
      else if Option.exists (fun days -> days <= 0) valid_for then
        fail 2 "record --valid-for must be a positive number of days"
      else
        match outcome_of_string outcome with
        | None -> fail 2 "record --outcome must be pass, fail, inconclusive, infrastructure-error or not-run"
        | Some outcome ->
            let evidence = {
              claim_id = id; requirement;
              candidate_tree = Option.value ~default:"unborn" (Git.head_commit root);
              materials_digest = Option.value ~default:"" (Git.digest_of_scope root ~scope:claim.scope);
              definition_digest = definition_digest claim; verifier_digest = verifier_digest claim;
              environment = Project.environment root;
              producer = { class_ = "human"; identity = by; run = run_ref };
              independence = External; outcome; issued_at = now ();
              valid_until = Option.map (fun days -> now () + (days * 86400)) valid_for;
              evidence_ref = run_ref; control_reach = None;
            } in
            Trail.append root evidence;
            print_endline "recorded";
            0

let block_begin = "<!-- math-coding:begin -->"
let block_end = "<!-- math-coding:end -->"

let usage_verbs = [ "help"; "init"; "goal"; "add"; "run"; "map"; "next"; "context"; "waive"; "record"; "install"; "doctor"; "adopt"; "import-adr"; "import-junit"; "authorize"; "re-evaluate"; "review-source"; "mcp" ]

let entry_page root =
  let spec = load root in
  let claims = List.length spec.claims in
  let goal = match spec.goal with Some goal -> goal.text | None -> "No aim is stated yet." in
  Printf.sprintf
    "## math-coding in this project\n\n%s\n\n%d claim(s).\n\n```sh\nmathc run\n```\n\nEvery verb: %s\n"
    goal claims (String.concat " " (List.map (fun verb -> "mathc " ^ verb) usage_verbs))

let index_of haystack needle =
  let n = String.length haystack and m = String.length needle in
  let found = ref None and index = ref 0 in
  while !found = None && !index + m <= n do
    if String.sub haystack !index m = needle then found := Some !index;
    incr index
  done;
  !found

let contains haystack needle = index_of haystack needle <> None

let with_block existing block =
  match index_of existing block_begin with
  | None -> (if existing = "" then block else existing ^ "\n" ^ block)
  | Some first -> (
      match index_of (String.sub existing (first + String.length block_begin)
                         (String.length existing - first - String.length block_begin)) block_end with
      | None -> existing ^ "\n" ^ block
      | Some last ->
          let last = first + String.length block_begin + last in
          let tail = String.sub existing (last + String.length block_end)
              (String.length existing - last - String.length block_end) in
          let tail = if String.length tail > 0 && tail.[0] = '\n' then String.sub tail 1 (String.length tail - 1) else tail in
          String.sub existing 0 first ^ block ^ tail)

let install root =
  let path = Filename.concat root "AGENTS.md" in
  let existing = if Sys.file_exists path then Io.read_file path else "" in
  let block = block_begin ^ "\n" ^ entry_page root ^ block_end ^ "\n" in
  Io.write_atomic path (with_block existing block);
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
                let review = Some { by; reason; at = now (); previous_digest } in
                let source = { source with digest; review } in
                let claims = List.map (fun current ->
                  if current.id = id then { current with source = Some source; waiver = None } else current) spec.claims in
                Project.save_spec root { spec with claims };
                Printf.printf "claim %s source review recorded; next: mathc run\n" id;
                0)

let doctor root =
  let broken = ref 0 in
  let report ok message = if not ok then incr broken; Printf.printf "  %s %s\n" (if ok then "ok" else "wrong") message in
  report (Git.is_repository root) "this is a git repository";
  report (Sys.file_exists (Filename.concat root "spec.json")) "the standing specification is there";
  let spec = load root in
  report (spec.goal <> None) "the aim is stated";
  (match Policy.check root with Ok () -> report true "protected transitions are authorized" | Error _ -> report false "protected transitions are authorized");
  let page = Filename.concat root "AGENTS.md" in
  if not (Sys.file_exists page) then report false "there is no page for agents: mathc install"
  else (
    let text = Io.read_file page in
    report (contains text block_begin && contains text block_end) "the page has a math-coding block";
    let expected = with_block text (block_begin ^ "\n" ^ entry_page root ^ block_end ^ "\n") in
    report (expected = text) "the page is current";
    List.iter (fun verb -> report (contains text verb) ("the page names " ^ verb)) usage_verbs);
  if !broken = 0 then 0 else 1
