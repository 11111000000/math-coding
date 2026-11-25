open Helpers

(* The migration is a new verb of the method, so it has an accepting fixture
   and a rejecting one. The accepting fixture is a project of the previous
   version of the format; the rejecting ones are the three ways the migration
   must not happen: a project that is already of this version, a project whose
   journal of the previous version is not whole, and a place where there is no
   project at all. *)

(* A project of the previous version: the specification does not yet name the
   risk or the lifecycle of a claim. *)
let v5_spec =
  "{\"schema_version\":6,"
  ^ "\"goal\":{\"text\":\"the goal\",\"scope\":[\"subject.txt\"],\"by\":\"owner\",\"at\":1,\"reason\":null},"
  ^ "\"claims\":[{"
  ^ "\"id\":\"sample\",\"text\":\"the subject is expected\",\"scope\":[\"subject.txt\"],"
  ^ "\"source\":null,\"owner\":null,"
  ^ "\"requirements\":[{\"kind\":\"verifier\",\"spec\":\"grep -q expected subject.txt\"}],"
  ^ "\"falsifier\":\"the subject is not expected\",\"register\":\"fact\",\"control\":null,"
  ^ "\"waiver\":null,\"environment\":null}]}"

(* A record of the previous version: the binary stood in the fingerprint of
   the environment, and there is no tool of its own. *)
let v5_record =
  "{\"schema_version\":6,\"claim_id\":\"sample\","
  ^ "\"requirement\":{\"kind\":\"verifier\",\"spec\":\"grep -q expected subject.txt\"},"
  ^ "\"candidate_tree\":\"tree\",\"materials_digest\":\"materials\",\"definition_digest\":\"definition\","
  ^ "\"verifier_digest\":\"verifier\",\"environment\":{\"class\":\"local\",\"fingerprint\":\"environment\"},"
  ^ "\"tool\":{\"class\":\"mathc\",\"fingerprint\":\"previous-tool\"},"
  ^ "\"producer\":{\"class\":\"mathc\",\"identity\":\"runner\",\"run\":\"true\"},"
  ^ "\"independence\":\"fresh-context\",\"outcome\":\"pass\",\"issued_at\":1,\"valid_until\":null,"
  ^ "\"evidence_ref\":null,\"control_reach\":\"subject\"}"

let json_of_file root path = Yojson.Safe.from_string (Io.read_file (Filename.concat root path))

let () =
  (* A project of the previous version is moved to this version. *)
  with_repo (fun root ->
      write root "spec.json" v5_spec;
      write root ".math/v6/evidence.jsonl" (v5_record ^ "\n");
      let result = run root "migrate" in
      check "the migration succeeds" (result.code = 0);
      check "the migration says what it moved"
        (contains result.stdout "specification: spec.json (schema_version 7)");
      let spec = json_of_file root "spec.json" in
      check "the specification is of this version"
        (match field "schema_version" spec with Some (`Int 7) -> true | _ -> false);
      check "the specification keeps its claims"
        (match field "claims" spec with Some (`List claims) -> List.length claims = 1 | _ -> false);
      (match field "claims" spec with
       | Some (`List [ claim ]) ->
           check "the dead fields of the previous version are gone"
             (field "kind" claim = None && field "phase" claim = None && field "review_on" claim = None);
           check "the fields of this version are kept"
             (field "id" claim = Some (`String "sample"))
       | _ -> check "the claim of the migrated project is read" false);
      let journal = Filename.concat root ".math/v7/evidence.jsonl" in
      check "the journal of this version is written"
        (Sys.file_exists journal);
      let record = Yojson.Safe.from_string (Io.read_file journal) in
      check "the migrated record is of this version"
        (match field "schema_version" record with Some (`Int 7) -> true | _ -> false);
      (match field "tool" record with
       | Some (`Assoc [ "class", `String "mathc"; "fingerprint", `String fingerprint ]) ->
           check "the migrated record keeps the tool of the previous version" (fingerprint = "previous-tool")
       | _ -> check "the migrated record carries the tool" false);
      check "the file of the previous version stayed where it was"
        (Sys.file_exists (Filename.concat root ".math/v6/evidence.jsonl")));

  (* The dry run says what it would do and changes nothing. *)
  with_repo (fun root ->
      write root "spec.json" v5_spec;
      write root ".math/v6/evidence.jsonl" (v5_record ^ "\n");
      let result = run root "migrate --dry-run" in
      check "the dry run succeeds" (result.code = 0);
      check "the dry run says that it would move the journal"
        (contains result.stdout "would be moved");
      let spec = json_of_file root "spec.json" in
      check "the dry run leaves the specification of the previous version alone"
        (match field "schema_version" spec with Some (`Int 6) -> true | _ -> false);
      check "the dry run writes no journal of this version"
        (not (Sys.file_exists (Filename.concat root ".math/v7/evidence.jsonl"))));

  (* A project that is already of this version is not migrated again. *)
  with_repo (fun root ->
      write root "spec.json"
        "{\"schema_version\":7,\"goal\":null,\"claims\":[]}";
      let result = run root "migrate" in
      check "a project of this version is refused" (result.code = 2);
      check "the refusal says that there is nothing to migrate"
        (contains result.stderr "already of the version of this method"));

  (* A journal of the previous version that is not whole stops the migration:
     a record that cannot be read may have been the one that refuted a claim,
     and dropping it silently would make a refuted claim look unchecked. *)
  with_repo (fun root ->
      write root "spec.json" v5_spec;
      write root ".math/v6/evidence.jsonl" "not-json\n";
      let result = run root "migrate" in
      check "a damaged journal stops the migration" (result.code = 2);
      check "the refusal names the damaged trail"
        (contains result.stderr "not whole");
      let spec = json_of_file root "spec.json" in
      check "the refused migration leaves the project as it was"
        (match field "schema_version" spec with Some (`Int 6) -> true | _ -> false);
      check "the refused migration writes no journal of this version"
        (not (Sys.file_exists (Filename.concat root ".math/v7/evidence.jsonl"))));

  (* A place where there is no project at all. *)
  with_repo (fun root ->
      let result = run root "migrate" in
      check "there is nothing to migrate without a specification" (result.code = 2);
      check "the refusal says that there is no standing specification"
        (contains result.stderr "no standing specification"));

  print_endline "migrate: PASS"

(* The gate of the project must read the migrated specification. The page for
   agents is part of that gate: after the migration it must name the verbs of
   this version, and the migration must say that the tool of the project has
   to be this one before the migration lands in the tree. *)
let () =
  with_repo (fun root ->
      write root "spec.json" v5_spec;
      write root ".math/v6/evidence.jsonl" (v5_record ^ "\n");
      write root "AGENTS.md"
        "# Project\n\n<!-- math-coding:begin -->\n## math-coding in this project\n\nstale\n<!-- math-coding:end -->\n";
      let result = run root "migrate" in
      check "the migration succeeds" (result.code = 0);
      check "the migration names the gate of the project"
        (contains result.stdout "the gate of the project must read the migrated specification");
      check "the migration says which tool the project needs"
        (contains result.stdout "must be this version BEFORE the migration lands in the tree");
      let page = Io.read_file (Filename.concat root "AGENTS.md") in
      check "the page for agents names the verbs of this version"
        (contains page "mathc migrate" && contains page "mathc review-decision");
      check "the page for agents names the claims of the project"
        (contains page "1 claim(s).");
      check "the text of the project around the block is kept"
        (contains page "# Project");
      (* A dry run changes nothing: neither the journals nor the page. *)
      with_repo (fun dry ->
          write dry "spec.json" v5_spec;
          write dry ".math/v6/evidence.jsonl" (v5_record ^ "\n");
          write dry "AGENTS.md" "<!-- math-coding:begin -->\nstale\n<!-- math-coding:end -->\n";
          let answer = run dry "migrate --dry-run" in
          check "the dry run succeeds" (answer.code = 0);
          check "the dry run leaves the page alone"
            (contains (Io.read_file (Filename.concat dry "AGENTS.md")) "stale");
          check "the dry run says that it would migrate"
            (contains answer.stdout "would be migrated")));
  print_endline "migrate-gate: PASS"
