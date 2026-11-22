(* The golden corpus: three frozen projects and the maps the tool must
   produce for them. Every build of the tool runs the corpus, so a change
   that quietly moves a verdict or a state is caught by the comparison
   instead of by a consumer. The reasons of the states are not compared:
   the build that froze the evidence differs from the build that reads it,
   and the method says exactly that a tool change keeps the state. What
   must not move is the verdict, the state of every claim and the coverage.

   The last control of this file tamper one expectation and requires the
   comparison to reject it: a comparison that accepts a doctored verdict is
   not a comparison. *)

let corpus_dir name = Helpers.in_repo (Printf.sprintf "test/golden_corpus/%s" name)

let with_work f =
  let work = Io.temp_dir "mathc-corpus-test" in
  Fun.protect ~finally:(fun () -> Io.remove_tree work) (fun () -> f work)

let copy_fixture name work =
  let dir = Filename.concat work name in
  ignore
    (Process.run ~root:work
       (Printf.sprintf "cp -R %s %s" (Filename.quote (corpus_dir name))
          (Filename.quote dir)));
  (* The frozen evidence travels beside the expectation and takes its
     project place in the copy: the repository does not carry a .math
     directory, because a project's journals are its own. *)
  let frozen = Filename.concat dir "evidence.jsonl" in
  if Sys.file_exists frozen then (
    Io.mkdir_p (Filename.concat dir ".math/v6");
    ignore
      (Process.run ~root:dir
         (Printf.sprintf "mv %s .math/v6/evidence.jsonl" (Filename.quote frozen))));
  ignore (Process.run ~root:dir "git init -q");
  ignore (Process.run ~root:dir "git add -A -- .");
  ignore
    (Process.run ~root:dir "git -c user.email=corpus@local -c user.name=corpus commit -qm corpus");
  dir

type frozen = {
  verdict : string;
  states : (string * string) list;
  uncovered : int;
}

let read_frozen root =
  let result = Helpers.run root "map --json" in
  if result.code <> 0 && result.code <> 1 && result.code <> 3 then (
    prerr_endline result.stderr;
    failwith (Printf.sprintf "the corpus map failed with exit %d" result.code));
  let json = Yojson.Safe.from_string result.stdout in
  let fields =
    match json with
    | `Assoc fields -> fields
    | _ -> failwith "the map of the corpus is not an object"
  in
  let field name =
    match List.assoc_opt name fields with
    | Some value -> value
    | None -> failwith (Printf.sprintf "the map of the corpus has no %s" name)
  in
  let verdict =
    match field "verdict" with `String value -> value | _ -> failwith "the corpus verdict is not a string"
  in
  let states =
    match field "states" with
    | `List items ->
        List.map
          (fun item ->
            match item with
            | `Assoc pairs -> (
                match (List.assoc_opt "id" pairs, List.assoc_opt "state" pairs) with
                | Some (`String id), Some (`String state) -> (id, state)
                | _ -> failwith "a corpus state entry is malformed")
            | _ -> failwith "a corpus state entry is not an object")
          items
    | _ -> failwith "the corpus states are not a list"
  in
  let uncovered =
    match field "uncovered" with
    | `List items -> List.length items
    | _ -> failwith "the corpus uncovered files are not a list"
  in
  { verdict; states; uncovered }

let canonical frozen =
  let states =
    frozen.states |> List.map (fun (id, state) -> Printf.sprintf "%s=%s" id state)
    |> String.concat ","
  in
  Printf.sprintf "%s|%s|%d" frozen.verdict states frozen.uncovered

let expected_of name =
  let path = Filename.concat (corpus_dir name) "expected.json" in
  let json = Yojson.Safe.from_file path in
  match json with
  | `Assoc fields -> (
      let text name =
        match List.assoc_opt name fields with
        | Some (`String value) -> value
        | _ -> failwith (Printf.sprintf "the expectation %s has no %s" name name)
      in
      let states =
        match List.assoc_opt "states" fields with
        | Some (`List items) ->
            List.map
              (fun item ->
                match item with
                | `List [ `String id; `String state ] -> (id, state)
                | _ -> failwith "an expectation state is malformed")
              items
        | _ -> failwith "the expectation states are not a list"
      in
      let uncovered =
        match List.assoc_opt "uncovered" fields with
        | Some (`Int count) -> count
        | _ -> failwith "the expectation uncovered is not a number"
      in
      { verdict = text "verdict"; states; uncovered })
  | _ -> failwith "an expectation is not an object"

let compare_expectation produced want = canonical want = canonical produced

let matches name produced = compare_expectation produced (expected_of name)

let run_corpus () =
  List.iter
    (fun name ->
      with_work (fun work ->
          let dir = copy_fixture name work in
          let produced = read_frozen dir in
          if not (matches name produced) then
            failwith
              (Printf.sprintf "the corpus project %s produced %s, expected %s" name
                 (canonical produced) (canonical (expected_of name)));
          Printf.printf "corpus %s: %s\n" name (canonical produced)))
    [ "p-green"; "p-mixed"; "p-empty" ]

(* The negative control of the corpus itself: a doctored expectation must be
   rejected by the same comparison that reads the honest ones. *)
let tampered_expectation_is_rejected () =
  with_work (fun work ->
      let dir = copy_fixture "p-green" work in
      let produced = read_frozen dir in
      if not (matches "p-green" produced) then
        failwith "the comparison rejected the honest expectation";
      let doctored = { verdict = "red"; states = []; uncovered = 7 } in
      if compare_expectation produced doctored then
        failwith "the comparison accepted a doctored expectation";
      Printf.printf "corpus: a doctored expectation is rejected\n")

let () =
  run_corpus ();
  tampered_expectation_is_rejected ();
  print_endline "golden-corpus: PASS"
