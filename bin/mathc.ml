(** The method's binary.

    Seven verbs, and each of them is one move of the protocol. The
    command line is the whole interface: an agent runs one command and
    gets the next step, not a report to interpret.

    WHERE THE FRICTION IS, AND WHERE IT IS NOT.

    Reading the state must be cheap. `map`, `route` and `next` are one
    command each and they never fail on a project that has not adopted
    the method: an empty project is green, and the map of an empty
    project says so.

    The friction is in the three places where agents make mistakes.
    `add` refuses a claim it cannot bind or cannot refute. `run` never
    turns a check that did not run into a check that passed. `close`
    refuses a wave whose verdicts did not change, because a wave that
    changes nothing is a wave that did not happen. *)

let project_root = ref "."

let set_root r = project_root := r

let root () = !project_root

let read_file path =
  let channel = open_in path in
  let content = In_channel.input_all channel in
  close_in channel;
  content

(* ------------------------------------------------------------------ *)
(* The standing specification and the trail.                            *)
(* ------------------------------------------------------------------ *)

let spec_path () = Filename.concat (root ()) "spec.json"

let load_spec () : Domain.claim list =
  let path = spec_path () in
  if not (Sys.file_exists path) then []
  else
    match Spec.parse_spec_string (read_file path) with
    | Ok claims -> claims
    | Error e ->
        Printf.eprintf "mathc: the standing specification is not readable: %s\n"
          (Spec.result_of (Error e));
        exit 2

(** The newest evidence for each claim. The trail may hold many runs of
    the same claim; the last one is the one that counts. *)
let latest_evidence (claims : Domain.claim list) : Domain.evidence list =
  let ids = List.map (fun (c : Domain.claim) -> c.id) claims in
  let trail = Trail.read (root ()) in
  List.fold_left
    (fun (acc : Domain.evidence list) (e : Domain.evidence) ->
      let id = e.claim.id in
      if List.mem id ids then
        List.filter (fun (x : Domain.evidence) -> x.claim.id <> id) acc @ [ e ]
      else acc)
    [] trail

(** The current digest of a claim's subject, if the scope names
    anything. *)
let binding_of (claim : Domain.claim) : Domain.binding option =
  Git.digest_of_scope (root ()) claim.subject.scope

(** The state of every claim, computed. *)
let states_of (claims : Domain.claim list) : (string * Domain.state) list =
  let evidence = latest_evidence claims in
  List.map
    (fun (claim : Domain.claim) ->
      let e = List.find_opt (fun (x : Domain.evidence) -> x.claim.id = claim.id) evidence in
      (claim.id, Verdict.state_of (binding_of claim) e))
    claims

(* ------------------------------------------------------------------ *)
(* The verbs.                                                           *)
(* ------------------------------------------------------------------ *)

(** map: the standing specification of the project, computed. What is
    claimed, what is known, what is not covered. *)
let verb_map () =
  let claims = load_spec () in
  let states = states_of claims in
  let files = Git.tracked_files (root ()) in
  let uncovered = Git.uncovered claims files in
  let verdict = Verdict.verdict_of_states (List.map snd states) in
  Printf.printf "verdict: %s (exit %d)\n"
    (match verdict with Domain.Green -> "green" | Domain.Red -> "red" | Domain.Unknown -> "unknown")
    (Verdict.verdict_to_exit verdict);
  Printf.printf "claims: %d\n" (List.length claims);
  List.iter
    (fun (id, state) ->
      Printf.printf "  %-24s %s\n" id
        (match state with
        | Domain.Holds -> "holds"
        | Domain.Refuted -> "refuted"
        | Domain.Inconclusive -> "inconclusive"
        | Domain.NotCheckable -> "not checkable"
        | Domain.Outdated -> "outdated"
        | Domain.NeverChecked -> "never checked"))
    states;
  Printf.printf "uncovered: %d tracked file(s) no claim covers\n" (List.length uncovered);
  List.iter (fun f -> Printf.printf "  %s\n" f) uncovered;
  Verdict.verdict_to_exit verdict

(** route: what needs a person, and why. *)
let verb_route () =
  let claims = load_spec () in
  let evidence = latest_evidence claims in
  let findings = Verdict.route evidence in
  if findings = [] then print_endline "nothing needs a person"
  else
    List.iter
      (fun (f : Domain.finding) ->
        Printf.printf "%s: %s%s\n" f.subject
          (match f.outcome with
          | Domain.Unresolved -> "unresolved"
          | Domain.Refused -> "refused"
          | _ -> "?")
          (match f.reason with
          | Some r -> " (" ^ r ^ ")"
          | None -> ""))
      findings;
  0

(** run: execute the checks, bind the results to the subject as it
    stands, and write them to the trail. *)
let verb_run () =
  let claims = load_spec () in
  if claims = [] then (
    print_endline "nothing to run: the standing specification is empty";
    0)
  else
    let results =
      List.map
        (fun (claim : Domain.claim) ->
          match binding_of claim with
          | None ->
              Printf.printf
                "%s: no digest - the scope names nothing, so nothing can be bound\n"
                claim.id;
              (claim, Domain.Unresolved, None, None)
          | Some binding ->
              let outcome, reason = Exec.run_check claim.check in
              Printf.printf "%s: %s\n" claim.id
                (match outcome with
                | Domain.Verified -> "verified"
                | Domain.Falsified -> "falsified"
                | Domain.Unresolved -> "unresolved"
                | Domain.Refused -> "refused");
              (claim, outcome, Some binding, reason))
        claims
    in
    List.iter
      (fun (claim, outcome, binding, reason) ->
        match binding with
        | None -> ()
        | Some binding ->
            Trail.append (root ()) { claim; outcome; bound_to = binding; reason })
      results;
    let states = states_of claims in
    Verdict.verdict_to_exit (Verdict.verdict_of_states (List.map snd states))

(** next: the next work. Not a list to choose from - one item. *)
let verb_next () =
  let claims = load_spec () in
  let states = states_of claims in
  let files = Git.tracked_files (root ()) in
  let uncovered = Git.uncovered claims files in
  let needs_check =
    List.filter_map
      (fun (id, state) ->
        match state with
        | Domain.NeverChecked | Domain.Outdated | Domain.Inconclusive -> Some id
        | _ -> None)
      states
  in
  match (needs_check, uncovered) with
  | id :: _, _ ->
      Printf.printf "next: check the claim %s - it is not known now\n" id;
      0
  | [], first :: _ ->
      Printf.printf "next: nothing is unverified; %d tracked file(s) are uncovered, starting with %s\n"
        (List.length uncovered) first;
      0
  | [], [] ->
      print_endline "next: nothing to do - every claim is known and everything is covered";
      0

(** close: close a wave or a claim. A wave that changes no verdict is
    not closed; it is left open with the reason. *)
let verb_close id =
  let path = Filename.concat (root ()) (Filename.concat "waves" (id ^ ".json")) in
  if not (Sys.file_exists path) then (
    Printf.eprintf "mathc: no wave %S\n" id;
    2)
  else
    match Spec.parse_wave_string (read_file path) with
    | Error e ->
        Printf.eprintf "mathc: the wave is not readable: %s\n" (Spec.result_of (Error e));
        2
    | Ok wave -> (
        let claims = load_spec () in
        let before = states_of claims in
        List.iter
          (fun check -> ignore (Exec.run_check check))
          wave.checks;
        let after = states_of claims in
        let changed =
          List.filter
            (fun (id, state) ->
              let before_state = List.assoc_opt id before in
              before_state <> Some state)
            after
        in
        if changed = [] then (
          Printf.eprintf "mathc: wave %s changed no verdict, and is therefore not closed\n" wave.id;
          1)
        else (
          Printf.printf "wave %s closed; changed:\n" wave.id;
          List.iter (fun (id, state) -> Printf.printf "  %s -> %s\n" id (match state with Domain.Holds -> "holds" | Domain.Refuted -> "refuted" | Domain.Inconclusive -> "inconclusive" | Domain.NotCheckable -> "not checkable" | Domain.Outdated -> "outdated" | Domain.NeverChecked -> "never checked")) changed;
          0))

(* ------------------------------------------------------------------ *)

let usage () =
  print_endline "mathc - the protocol of math-coding";
  print_endline "";
  print_endline "  mathc map               the standing specification: claims, states, uncovered";
  print_endline "  mathc route             what needs a person, and why";
  print_endline "  mathc run                execute the checks, bind the results, write the trail";
  print_endline "  mathc next               the next work, one item";
  print_endline "  mathc close WAVE         close a wave whose verdicts changed";
  print_endline "";
  print_endline "  --root DIR               the project (default: the working directory)"

let () =
  let root_flag = ref "" in
  let args = Array.to_list Sys.argv |> List.tl in
  let rec take_root acc = function
    | "--root" :: dir :: rest -> root_flag := dir; take_root acc rest
    | "--root" :: [] ->
        Printf.eprintf "mathc: --root needs a directory\n";
        exit 2
    | rest -> (acc, rest)
  in
  let positional, rest = take_root [] args in
  ignore rest;
  if !root_flag <> "" then set_root !root_flag;
  match positional with
  | [] | [ "--help" ] | [ "-h" ] ->
      usage ();
      exit 0
  | verb :: _ -> (
      let code =
        match verb with
        | "map" -> verb_map ()
        | "route" -> verb_route ()
        | "run" -> verb_run ()
        | "next" -> verb_next ()
        | "close" -> (
            match positional with
            | _ :: id :: _ -> verb_close id
            | _ ->
                Printf.eprintf "mathc: close needs a wave id\n";
                2)
        | other ->
            Printf.eprintf "mathc: unknown verb %S\n" other;
            usage ();
            2
      in
      exit code)
