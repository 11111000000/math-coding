open Helpers

(* The canon of the method is a set of documents. A wrong number, a repeated
   number or a lost document is invisible to the reader and fatal to the method,
   so the check lives in the tree and not in the head of a reviewer.

   The check reads the tree it is given, so it can be pointed at a copy: the
   live canon is checked, and a broken copy of it is refused. The check of the
   check below proves that it can fail at all. *)

(* Every document the method names as normative. A canon that names a document
   it does not have is a promise without a carrier. *)
let required =
  [ "AXIOMS.md";
    "PHILOSOPHY.md";
    "GOAL.md";
    "skills/math-coding/references/METHODOLOGY.md";
    "skills/math-coding/SKILL.md";
    "docs/ENGINEERING-PRACTICES.md";
    "docs/V5-DEFECT-CATALOG.md" ]

(* The documents the check reads besides the canon: the block for agents and the
   specification that carries the number of claims. *)
let read_also = [ "AGENTS.md"; "spec.json" ]

let documents = required @ read_also

let read root relative = Io.read_file (Filename.concat root relative)

(* The numbered items of a document: the lines that open with a number and a
   dot. A number inside an item does not open a line, so it opens no item. *)
let numbered_items text =
  String.split_on_char '\n' text
  |> List.filter_map (fun line ->
         match String.index_opt line '.' with
         | Some index when index > 0 ->
             let number = String.sub line 0 index in
             if number <> "" && String.for_all (fun c -> c >= '0' && c <= '9') number then
               Some (int_of_string number)
             else None
         | _ -> None)

(* The items of a numbered list run from one to the last without a gap and
   without a repeat: the sequence is the contract of the list. *)
let sequential numbers =
  let rec walk expected = function
    | [] -> true
    | number :: rest -> number = expected && walk (expected + 1) rest
  in
  walk 1 numbers

(* The number of claims the specification holds. *)
let claims_of_spec root =
  match Yojson.Safe.from_string (read root "spec.json") with
  | `Assoc fields -> (
      match List.assoc_opt "claims" fields with
      | Some (`List claims) -> List.length claims
      | _ -> 0)
  | _ -> 0

(* The number the block for agents states. The block is written by the tool, so
   a stale number in it is a number the tool would not write today: the reader
   of the block is misled and nobody checks it. *)
let stated_claims text =
  let marker = " claim(s)." in
  let length = String.length text and marker_length = String.length marker in
  let rec find index =
    if index + marker_length > length then None
    else if String.sub text index marker_length = marker then Some index
    else find (index + 1)
  in
  match find 0 with
  | None -> None
  | Some index ->
      let rec digits position =
        if position >= 0 && text.[position] >= '0' && text.[position] <= '9' then
          digits (position - 1)
        else position + 1
      in
      let start = digits (index - 1) in
      if start > index - 1 then None
      else Some (int_of_string (String.sub text start (index - start)))

(* The check of the canon of one tree. *)
let check_canon root =
  List.iter
    (fun document -> check ("the canon names " ^ document) (Sys.file_exists (Filename.concat root document)))
    required;

  let axioms = numbered_items (read root "AXIOMS.md") in
  check "AXIOMS.md has a numbered list" (axioms <> []);
  check "the numbered list of AXIOMS.md is sequential" (sequential axioms);

  let philosophy = numbered_items (read root "PHILOSOPHY.md") in
  check "PHILOSOPHY.md has a numbered list" (philosophy <> []);
  check "the numbered list of PHILOSOPHY.md is sequential" (sequential philosophy);

  let catalogue = numbered_items (read root "docs/V5-DEFECT-CATALOG.md") in
  check "the defect catalogue has a numbered list" (catalogue <> []);
  check "the numbered list of the defect catalogue is sequential" (sequential catalogue);

  check "the block for agents states the number of claims"
    (stated_claims (read root "AGENTS.md") = Some (claims_of_spec root))

(* The check refuses a tree: it answers with a failure, and the failure is the
   answer. *)
let refuses root =
  match check_canon root with
  | exception Failure _ -> true
  | () -> false

(* A copy of the canon in a temporary directory: the same documents, so the
   copy is a fair subject of the same check. *)
let copy_canon target =
  List.iter
    (fun document ->
      let destination = Filename.concat target document in
      Io.mkdir_p (Filename.dirname destination);
      Io.copy_file (Filename.concat (in_repo "") document) destination)
    documents

(* A copy of the canon with one document broken. *)
let with_broken_canon break f =
  Io.with_temp_dir (fun target ->
      copy_canon target;
      break target;
      f target)

(* The first item of the axioms gets the number of the second one: the list
   loses its sequence. *)
let repeat_number target =
  let path = Filename.concat target "AXIOMS.md" in
  let lines = String.split_on_char '\n' (Io.read_file path) in
  let broken =
    List.map
      (fun line -> if String.length line > 2 && String.sub line 0 2 = "1." then "2." ^ String.sub line 2 (String.length line - 2) else line)
      lines
  in
  Io.write_atomic path (String.concat "\n" broken)

(* A document of the canon is gone. *)
let lose_document target = Sys.remove (Filename.concat target "GOAL.md")

(* The method text is the subject of the claim that reads it: a change of the
   text changes the materials of that claim, and the evidence that relied on the
   old text becomes stale. The binding runs through the scope of the claim, not
   through the fingerprint of the tool: the tool is the observer, the text is
   what was checked. A change of the text that left every evidence in force
   would change the behaviour of the agent in silence. *)
let method_text = "skills/math-coding/references/METHODOLOGY.md"

(* The scope of a claim of the specification. *)
let scope_of_claim root id =
  match Yojson.Safe.from_string (read root "spec.json") with
  | `Assoc fields -> (
      match List.assoc_opt "claims" fields with
      | Some (`List claims) ->
          List.find_map
            (fun claim ->
              match claim with
              | `Assoc pairs ->
                  (match List.assoc_opt "id" pairs with
                  | Some (`String name) when name = id ->
                      (match List.assoc_opt "scope" pairs with
                      | Some (`List scope) ->
                          Some (List.filter_map (function `String path -> Some path | _ -> None) scope)
                      | _ -> None)
                  | _ -> None)
              | _ -> None)
            claims
      | _ -> None)
  | _ -> None

(* The files a scope names, as the repository holds them. *)
let files_of_scope root scope =
  match Git.repository_files root with
  | Ok files -> Git.files_under files ~scope
  | Error _ -> []

(* A copy of a scope in a temporary repository: the same documents, so the
   materials of the claim are computed the same way. *)
let copy_scope root target scope =
  List.iter
    (fun file ->
      let destination = Filename.concat target file in
      Io.mkdir_p (Filename.dirname destination);
      Io.copy_file (Filename.concat root file) destination)
    (files_of_scope root scope)

let () =
  (* The live canon. *)
  check_canon (in_repo "");

  (* The check of the number refuses a repeat and a gap, so a passing run says
     something. *)
  check "a repeated number is rejected" (not (sequential [ 1; 2; 2; 4 ]));
  check "a gap is rejected" (not (sequential [ 1; 2; 4 ]));
  check "a list that starts below one is rejected" (not (sequential [ 2; 3 ]));

  (* A copy of the canon is a fair subject: the same check passes on it. *)
  Io.with_temp_dir (fun target ->
      copy_canon target;
      check_canon target);

  (* And the check refuses a broken copy: a repeated number and a lost document
     are both a defect of the canon, not a matter of taste. *)
  check "the canon is refused when a number is repeated"
    (with_broken_canon repeat_number refuses);
  check "the canon is refused when a document is lost"
    (with_broken_canon lose_document refuses);

  (* The method text is a material of the claim that reads it: a change of the
     text changes the materials of that claim, and the evidence that relied on
     the old text becomes stale. *)
  let scope =
    match scope_of_claim (in_repo "") "canon-integrity" with
    | Some scope -> scope
    | None -> failwith "the canon claim has no scope"
  in
  check "the method text is a material of the canon claim"
    (List.exists
       (fun prefix -> prefix = method_text || Git.path_contains ~dir:prefix ~path:method_text)
       scope);
  with_repo (fun target ->
      copy_scope (in_repo "") target scope;
      let before = Git.digest_of_scope target ~scope in
      check "the scope of the claim has materials to compare" (before <> None);
      let path = Filename.concat target method_text in
      Io.write_atomic path (Io.read_file path ^ "\nA sentence the method did not have.\n");
      let after = Git.digest_of_scope target ~scope in
      check "a change of the method text changes the materials of the claim"
        (before <> after));

  print_endline "canon: PASS"
