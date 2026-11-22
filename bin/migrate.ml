open Domain

(* The migration of a project of the previous version of the format to the
   version of this method.

   It is a human action: the agent surface does not move the journals of a
   project, because the tool that reads them is not the tool that wrote them.

   The migration reads the project of the previous version and writes the
   project of this one. The old files stay where they are - they are the
   evidence of what happened - and the tool says where they stayed.

   Nothing is written before everything has been read: a project that cannot
   be read is refused whole, and the tree stays as it was. *)

(* The journals of the previous version, read. *)
type journals = {
  evidence : evidence list;
  approval : Approval.record list;
  authorization : Policy.authorization option;
  runs : Run_log.run_record list;
}

let refuse message =
  Printf.eprintf "mathc: %s\n" message;
  2

let internal message =
  Printf.eprintf "mathc: %s\n" message;
  Exit_code.internal_failure

(* The journals of the previous version. A journal that cannot be read whole
   stops the migration: a record that cannot be read may have been the one
   that refuted a claim, and a migration that drops it silently would make a
   refuted claim look like a claim nobody checked. *)
let read_journals root =
  match Trail.read_previous root with
  | Error error -> Error error
  | Ok journal ->
      if journal.damaged <> [] then
        Error
          ("the evidence trail of the previous version is not whole: "
          ^ Next_action.damage_words journal.damaged)
      else
        match Approval.read_previous root with
        | Error error -> Error ("the approval of the previous version cannot be read: " ^ error)
        | Ok approval ->
            match Policy.read_previous_authorization root with
            | Error error -> Error ("the authorization of the previous version cannot be read: " ^ error)
            | Ok authorization ->
                match Run_log.read_previous root with
                | Error error -> Error ("the journal of the runs of the previous version cannot be read: " ^ error)
                | Ok runs -> Ok { evidence = journal.records; approval; authorization; runs }

(* The claims that cannot keep their evidence: the definition of the claim
   changed with the format, and the environment of the record no longer
   matches the environment of this method - the binary left the fingerprint of
   the environment and became the fingerprint of the tool. Either way the
   claim has to be checked again. *)
let claims_that_need_a_run root spec records =
  let now = int_of_float (Unix.time ()) in
  let environment = Evaluation.environment root in
  let tool = Evaluation.tool () in
  List.filter
    (fun (claim : claim) ->
      match Verdict.explain_claim ~now ~environment ~tool claim records with
      | ((Outdated | NeverChecked | Inconclusive), _) -> true
      | _ -> false)
    spec.claims

(* The files of the previous version that stayed where they were. *)
let old_files root =
  [ Trail.previous_path root;
    Approval.previous_path root;
    Policy.previous_authorization_path root;
    Run_log.previous_path root ]
  |> List.filter (fun path -> Sys.file_exists path)

let report spec journals claims old dry_run =
  let moved = if dry_run then "would be moved" else "moved" in
  let kept =
    if old = [] then [ "  none" ]
    else List.map (fun path -> "  " ^ path) old
  in
  let authorization =
    match journals.authorization with
    | None -> "  authorization: there is none"
    | Some _ -> "  authorization: " ^ moved ^ " to .math/v6/authorization.json"
  in
  let claims =
    Printf.sprintf "%d of %d claim(s) need a new run" (List.length claims) (List.length spec.claims)
  in
  String.concat "\n"
    ([ (if dry_run then "the project would be migrated to version 6" else "the project is migrated to version 6");
       "  specification: spec.json (schema_version 6)";
       Printf.sprintf "  evidence: %d record(s) %s to .math/v6/evidence.jsonl"
         (List.length journals.evidence) moved;
       Printf.sprintf "  approval: %d record(s) %s to .math/v6/approval.json"
         (List.length journals.approval) moved;
       authorization;
       Printf.sprintf "  runs: %d record(s) %s to .math/v6/runs.jsonl"
         (List.length journals.runs) moved;
       "the files of the previous version stayed where they were:" ]
    @ kept
    @ [ "";
        "the migrated records keep the tool of the previous version as unknown: that version";
        "wrote the binary into the fingerprint of the environment, so the binary cannot be";
        "taken out of it, and the tool says that it does not know rather than guessing";
        "which build wrote the record";
        "";
        "the definition of a claim did not change with the format - the fields the previous";
        "version hashed and this one does not read were never part of what the method reads";
        "- so the migrated records are bound to the definition of the migrated claim";
        "";
        "the gate of the project must read the migrated specification: the previous version";
        "cannot read schema_version 6, so the tool the project uses - the one its CI calls and";
        "the one it installs - must be this version BEFORE the migration lands in the tree;";
        "otherwise the project's own gate fails on the migrated specification";
        "the page for agents was rewritten with the verbs of this version";
        "";
        "next: " ^ claims ^ ": the environment of the record no longer matches the environment";
        "of this method - the binary is no longer part of it";
        "next: mathc run" ])

let write_journals root spec journals =
  Project.save_spec root spec;
  Trail.write root journals.evidence;
  (match Approval.write root journals.approval with
   | Ok _ -> ()
   | Error error -> failwith ("approval: " ^ error));
  (match journals.authorization with
   | None -> ()
   | Some authorization -> (
       match Policy.write_authorization root authorization with
       | Ok _ -> ()
       | Error error -> failwith ("authorization: " ^ error)));
  (match Run_log.write root journals.runs with
   | Ok _ -> ()
   | Error error -> failwith ("run log: " ^ error))

(* The page for agents is part of the gate of the project: it names the verbs
   of the method and the claims of the project, and the doctor checks it. A
   migration that leaves it naming the verbs of the previous version leaves
   the instruction of the project wrong, so the migration rewrites it. *)
let refresh_agent_page root spec =
  let path = Filename.concat root "AGENTS.md" in
  let existing = if Sys.file_exists path then Io.read_file path else "" in
  let block =
    Agent_page.block_begin ^ "\n" ^ Agent_page.entry_page spec ^ Agent_page.block_end ^ "\n"
  in
  let updated = Agent_page.with_block existing block in
  if updated <> existing then Io.write_atomic path updated;
  updated <> existing

let migrate root dry_run =
  let path = Project.spec_path root in
  if not (Sys.file_exists path) then
    refuse "there is no standing specification here (run from the project root or use --root)"
  else
    let text = Io.read_file path in
    match Spec.version_of_string text with
    | Error error -> refuse ("the standing specification is not readable: " ^ error)
    | Ok version when version = Spec.version ->
        refuse "this project is already of the version of this method; there is nothing to migrate"
    | Ok version when version <> Migration.previous_version ->
        refuse
          (Printf.sprintf "the standing specification is of version %d; only version %d can be migrated"
             version Migration.previous_version)
    | Ok _ -> (
        match Migration.read_spec text with
        | Error error -> refuse ("the project of the previous version cannot be read: " ^ error)
        | Ok spec -> (
            match read_journals root with
            | Error error -> refuse error
            | Ok journals ->
                (* The definition of a claim did not change with the format, so
                   the migrated records are bound to the definition of the
                   migrated claim. The binding that really changed is the
                   environment, and it is not faked away. *)
                let evidence = Migration.rebind_definitions spec journals.evidence in
                let journals = { journals with evidence } in
                let claims = claims_that_need_a_run root spec evidence in
                let old = old_files root in
                let written =
                  if dry_run then Ok ()
                  else
                    try
                      write_journals root spec journals;
                      ignore (refresh_agent_page root spec);
                      Ok ()
                    with error -> Error (Printexc.to_string error)
                in
                (match written with
                 | Error message -> internal message
                 | Ok () ->
                     print_endline (report spec journals claims old dry_run);
                     0)))

let run root dry_run = migrate root dry_run
