(* The doctor looks at the state of the project and at the state of its
   evidence. The repository can be in order and the evidence stale; the tool can
   be in place while the page for agents says nothing about it. The doctor tells
   the two apart: an error is something that has to be fixed, a note is
   something the owner has to know. *)

open Domain

(* The latest record of every claim and requirement: an old record says nothing
   about the last run. On the same timestamp the later record of the journal
   wins. *)
let latest_records (records : evidence list) =
  List.fold_left
    (fun acc (record : evidence) ->
      let key = (record.claim_id, record.requirement) in
      match List.assoc_opt key acc with
      | Some previous when previous.issued_at > record.issued_at -> acc
      | _ -> (key, record) :: List.remove_assoc key acc)
    [] records

let doctor root =
  let broken = ref 0 in
  let report ok message = if not ok then incr broken; Printf.printf "  %s %s\n" (if ok then "ok" else "wrong") message in
  let note message = Printf.printf "  note %s\n" message in
  report (Git.is_repository root) "this is a git repository";
  report (Sys.file_exists (Filename.concat root "spec.json")) "the standing specification is there";
  let spec =
    match Project.load_spec root with
    | Ok spec -> spec
    | Error error -> report false ("the standing specification is readable: " ^ error); exit 1
  in
  report (spec.goal <> None) "the aim is stated";
  (match Policy.check root with Ok () -> report true "protected transitions are authorized" | Error _ -> report false "protected transitions are authorized");
  let page = Filename.concat root "AGENTS.md" in
  if not (Sys.file_exists page) then report false "there is no page for agents: mathc install"
  else (
    let text = Io.read_file page in
    report (Agent_page.contains text Agent_page.block_begin && Agent_page.contains text Agent_page.block_end) "the page has a math-coding block";
    let expected = Agent_page.with_block text (Agent_page.block_begin ^ "\n" ^ Agent_page.entry_page spec ^ Agent_page.block_end ^ "\n") in
    report (expected = text) "the page is current";
    List.iter (fun verb -> report (Agent_page.contains text verb) ("the page names " ^ verb)) Agent_page.usage_verbs);
  (* The state of the evidence, not only the shape of the repository. The tool
     can be in place and the evidence stale; the doctor has to tell the two
     apart, and it has to name what is wrong with the evidence. *)
  (match Project.evaluate root spec with
   | Error error -> report false ("the evidence can be read: " ^ error)
   | Ok evaluation ->
       report true "the evidence trail can be read";
       (match evaluation.damaged with
        | [] -> note "the evidence trail is whole"
        | damages ->
            report false
              (Printf.sprintf "the evidence trail is not whole: %d record(s) cannot be read (%s)"
                 (List.length damages) (Project.damage_words damages)));
       let states = List.map (fun (item : Project.evaluated_state) -> item.state) evaluation.states in
       let count state = List.length (List.filter (fun value -> value = state) states) in
       note
         (Printf.sprintf "the evidence is fresh for %d of %d claim(s) (%d outdated, %d never checked, %d inconclusive)"
            (count Holds) (List.length states) (count Outdated) (count NeverChecked) (count Inconclusive));
       (match Project.uncovered root spec with
        | Error error -> report false ("the coverage of the aim can be read: " ^ error)
        | Ok files ->
            if files = [] then note "every file inside the aim is covered by a claim"
            else note (Printf.sprintf "%d file(s) inside the aim are covered by no claim" (List.length files)));
       (match Trail.read root with
        | Error error -> report false ("the evidence trail can be read: " ^ error)
        | Ok journal ->
            let latest = latest_records journal.Trail.records in
            let nothing =
              List.length (List.filter (fun (_, (record : evidence)) -> record.control_reach = Some "nothing") latest)
            in
            if nothing = 0 then note "every negative control of the last run reaches the subject"
            else report false (Printf.sprintf "%d negative control(s) of the last run reach nothing" nothing));
       (* The price of the last run. It is not evidence and it does not change
          the verdict; it is the number that tells an owner which check to look
          at first. *)
       (match Run_log.read root with
        | Error error -> note ("the price of the last run can be read: " ^ error)
        | Ok runs -> (
            match List.rev runs with
            | [] -> note "no run of this project has been priced yet"
            | (last : Run_log.run_record) :: _ ->
                note
                  (Printf.sprintf "the last run spent %.1f s of machine time in %d claim(s)"
                     last.machine_seconds last.executed))));
  if !broken = 0 then 0 else 1
