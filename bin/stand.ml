(** The measurement stand.

    The method's own claim about its usefulness is a ratio: the defects
    it caught, over the cost it took. The third version measured that
    on five external projects and then REFUSED to publish the number,
    because the harness that produced it could not be reproduced. That
    refusal was honest and it cost the method its only measurement.

    So the stand is part of the delivery, not a tool for later. It
    runs the protocol over projects that are not this one and reports
    what it can actually measure.

    WHAT IT MEASURES, AND WHAT IT CANNOT.

    It measures: the wall-clock cost of running the checks, the size
    of the covered surface, the size of the uncovered surface, and the
    number of claims the protocol found to be untrue, undetermined, or
    moved. Those are facts about a run, and they are reproducible
    because the stand is the harness.

    It cannot measure: how many defects a human would have found
    anyway, and how many tokens the agent spent. The first needs a
    control arm - the same project without the protocol - and the
    second needs the agent, not the method. The stand says so rather
    than producing a number it cannot stand behind.

    THE RATIO THE GOAL ASKS FOR IS NOT YET MEASURABLE HERE, and the
    stand does not pretend otherwise. What it produces is the
    denominator and the numerator's raw material, on more than one
    project, so that the claim in GOAL.md can be tested rather than
    asserted. *)

let read_file path =
  let channel = open_in path in
  let content = In_channel.input_all channel in
  close_in channel;
  content

(** Run a command and return how long it took, in seconds. *)
let timed (command : string) : float * int =
  let start = Unix.gettimeofday () in
  let code = Sys.command command in
  (Unix.gettimeofday () -. start, code)

(** The method's own binary. The stand sits beside it, and an adopter
    does not have it in the project: the method is a tool the project
    uses, not a file the project carries. *)
let method_binary () =
  match Sys.getenv_opt "MATHC" with
  | Some p -> p
  | None -> Filename.concat (Filename.dirname Sys.argv.(0)) "mathc.exe"

(** The claims of a project, read from its standing specification. The
    control arm needs them: it runs the project's own commands, and the
    protocol is what is being left out. *)
let claims_of (root : string) : Domain.claim list =
  let path = Filename.concat root "spec.json" in
  if not (Sys.file_exists path) then []
  else
    match Yojson.Safe.from_string (read_file path) with
    | json -> (
        match Spec.parse_spec json with
        | Ok spec -> spec.Domain.claims
        | Error _ -> [])
    | exception Yojson.Json_error _ -> []

(** One project's measurement. *)
type measurement = {
  project : string;
  claims : int;
  covered : int;
  uncovered : int;
  seconds : float;
  exit : int;
  found : int;
  (* The control arm: the same checks, run directly, without the
     protocol. The difference between the two is what the protocol
     costs and what it adds. *)
  control_seconds : float;
  control_failed : int;
}

(** Read the map of a project, as the method wrote it. The map is JSON
    because the stand is a program and the map is its input. *)
let read_map (root : string) : (string * Yojson.Safe.t) option =
  let path = Filename.concat root "spec.json" in
  if not (Sys.file_exists path) then None
  else
    match Yojson.Safe.from_string (read_file path) with
    | _ -> None

(** The map of a project, computed by the method itself. The stand
    does not count anything the method does not already count: a
    second counter would be a second truth. *)
let measure (root : string) : measurement option =
  let map_bin = method_binary () in
  if not (Sys.file_exists map_bin) then None
  else
    (* The cost of the method is the CHECKS, not the map: the map is
       computed from what the checks produced, and it is cheap. So the
       timed thing is the run. *)
    let seconds, exit =
      timed (Printf.sprintf "%s --root %s run" (Filename.quote map_bin) (Filename.quote root))
    in
    (* The method's own map, read back as data. *)
    let out = Filename.temp_file "stand-map" ".json" in
    let cmd =
      Printf.sprintf "%s --root %s map --json > %s 2>/dev/null"
        (Filename.quote map_bin) (Filename.quote root) (Filename.quote out)
    in
    ignore (Sys.command cmd);
    let json =
      try Some (Yojson.Safe.from_string (read_file out)) with Yojson.Json_error _ -> None
    in
    Sys.remove out;
    (* The control arm. The claims' checks are the project's own
       commands, so the control runs them directly - no binding, no
       map, no route, no budget. What it cannot say is what nobody
       looked at, what went stale, and what the machine must not
       decide; the difference between the arms is exactly the yield
       of the protocol, and the difference in seconds is its price. *)
    let control_seconds, control_failed =
      match json with
      | None -> (0.0, 0)
      | Some _ ->
          let claims = claims_of root in
          List.fold_left
            (fun (total, failed) (claim : Domain.claim) ->
              List.fold_left
                (fun (total, failed) (r : Domain.requirement) ->
                  match r with
                  | Domain.Reviewed_by _ -> (total, failed)
                  | Domain.Verified_by command ->
                      let started = Unix.gettimeofday () in
                      let code =
                        Sys.command
                          (Printf.sprintf "cd %s && %s" (Filename.quote root) command)
                      in
                      (total +. (Unix.gettimeofday () -. started),
                       if code = 0 then failed else failed + 1))
                (total, failed) claim.Domain.requirements)
            (0.0, 0) claims
    in
    match json with
    | Some (`Assoc fields) ->
        let get name = List.assoc_opt name fields in
        let int_of name = match get name with Some (`Int n) -> n | _ -> 0 in
        let found =
          match get "states" with
          | Some (`List states) ->
              List.length
                (List.filter
                   (fun s ->
                     match s with
                     | `Assoc kv ->
                         (match List.assoc_opt "state" kv with
                         | Some (`String st) ->
                             st = "refuted" || st = "inconclusive" || st = "outdated"
                         | _ -> false)
                     | _ -> false)
                   states)
          | _ -> 0
        in
        Some
          {
            project = root;
            claims = int_of "claims";
            covered = int_of "claims";
            uncovered = int_of "uncovered";
            seconds;
            exit;
            found;
            control_seconds;
            control_failed;
          }
    | _ -> None

(** The costs the method cannot see.

    The ratio GOAL.md asks for has three terms in its denominator: a
    person's minutes, the machine's seconds, and the agent's tokens.
    The stand measures the second. The first and the third are facts
    about people, and a method that guessed them would be publishing a
    number it invented - which is the thing the third version refused
    to do and was right to refuse.

    So they are declared. The person who ran the adoption says how long
    it took them and how many tokens the agent spent, and the stand
    divides. Until they are declared, the stand prints the denominator
    it knows and no ratio. *)
type declared_costs = {
  human_minutes : float;
  agent_tokens : int;
  (* The weights. The criterion in GOAL.md divides the defects caught
     by "the minutes of a person plus the seconds of a machine plus the
     tokens of an agent" - three quantities in three different units,
     and a sum of them is not a quantity. The weights are what make
     them commensurable, and they are a fact about the world, not
     about the method, so they are declared with the costs. *)
  person_minute_cost : float;
  machine_second_cost : float;
  token_cost : float;
}

let declared_costs = ref None

(** The projects to measure. Given on the command line, one per
    argument. A project without a standing specification is not
    measured: the method has nothing to say about a project that has
    not stated its aim, and the stand does not state aims on its
    behalf. *)
(** The command line: project paths, and the costs the stand cannot
    measure on its own. *)
let parse_args (args : string list) : string list * declared_costs option =
  let projects = ref [] in
  let minutes = ref None in
  let tokens = ref None in
  let person_minute_cost = ref None in
  let machine_second_cost = ref None in
  let token_cost = ref None in
  let rec loop = function
    | [] -> ()
    | "--human-minutes" :: v :: rest ->
        minutes := float_of_string_opt v;
        loop rest
    | "--agent-tokens" :: v :: rest ->
        tokens := int_of_string_opt v;
        loop rest
    | "--person-minute-cost" :: v :: rest ->
        person_minute_cost := float_of_string_opt v;
        loop rest
    | "--machine-second-cost" :: v :: rest ->
        machine_second_cost := float_of_string_opt v;
        loop rest
    | "--token-cost" :: v :: rest ->
        token_cost := float_of_string_opt v;
        loop rest
    | ( "--human-minutes"
      | "--agent-tokens"
      | "--person-minute-cost"
      | "--machine-second-cost"
      | "--token-cost" )
      :: [] ->
        Printf.eprintf "stand: that option needs a number\n";
        exit 2
    | p :: rest ->
        projects := p :: !projects;
        loop rest
  in
  loop args;
  ( List.rev !projects,
    match
      ( !minutes,
        !tokens,
        !person_minute_cost,
        !machine_second_cost,
        !token_cost )
    with
    | Some m, Some t, Some pm, Some ms, Some tk ->
        Some
          {
            human_minutes = m;
            agent_tokens = t;
            person_minute_cost = pm;
            machine_second_cost = ms;
            token_cost = tk;
          }
    | _ -> None )

let () =
  let projects, costs = parse_args (Array.to_list Sys.argv |> List.tl) in
  declared_costs := costs;
  let measurements = List.filter_map measure projects in
  if measurements = [] then (
    Printf.eprintf "stand: nothing was measured\n";
    print_endline "usage: stand PROJECT [PROJECT ...]";
    print_endline "  each project must have a standing specification and a built method";
    exit 2);
  Printf.printf "%-34s %6s %9s %6s %9s %9s %8s\n" "project" "claims" "uncovered"
    "found" "protocol" "control" "overhead";
  List.iter
    (fun (m : measurement) ->
      Printf.printf "%-34s %6d %9d %6d %9.1f %9.1f %8.1f\n" m.project m.claims
        m.uncovered m.found m.seconds m.control_seconds
        (m.seconds -. m.control_seconds))
    measurements;
  let total_uncovered =
    List.fold_left (fun n (m : measurement) -> n + m.uncovered) 0 measurements
  in
  let total_found =
    List.fold_left (fun n (m : measurement) -> n + m.found) 0 measurements
  in
  let total_seconds =
    List.fold_left (fun t (m : measurement) -> t +. m.seconds) 0.0 measurements
  in
  let total_control =
    List.fold_left (fun t (m : measurement) -> t +. m.control_seconds) 0.0 measurements
  in
  Printf.printf
    "\nprojects: %d, uncovered: %d, found: %d\nprotocol seconds: %.1f, control seconds: %.1f, overhead: %.1f\n"
    (List.length measurements) total_uncovered total_found total_seconds total_control
    (total_seconds -. total_control);
  print_endline "";
  print_endline
    "The control arm is the same checks, run directly, without the protocol. The";
  print_endline
    "overhead is what the protocol costs; the uncovered count and the found count are";
  print_endline "what it adds. What it does not settle is the human question: whether";
  print_endline
    "a person working without the protocol would have found the same things, and how";
  print_endline "long that would have taken. That needs a human control arm.";
  print_endline "";
  match !declared_costs with
  | Some costs ->
      let denominator =
        (costs.human_minutes *. costs.person_minute_cost)
        +. (total_seconds *. costs.machine_second_cost)
        +. (float_of_int costs.agent_tokens *. costs.token_cost)
      in
      Printf.printf
        "declared: %.0f person-minutes at %.2f, %.1f machine-seconds at %.4f, %d agent tokens at %.6f\n"
        costs.human_minutes costs.person_minute_cost total_seconds
        costs.machine_second_cost costs.agent_tokens costs.token_cost;
      if denominator <= 0.0 then
        print_endline "ratio: not computable - the denominator is zero"
      else
        Printf.printf "cost: %.4f; ratio (defects caught per unit of cost): %.4f\n"
          denominator (float_of_int total_found /. denominator)
  | None ->
      print_endline "ratio: not computed. The person-minutes and the agent's tokens are";
      print_endline
        "facts about people, and the stand does not guess them. Declare them with";
      print_endline
        "  --human-minutes N --agent-tokens N --person-minute-cost N";
      print_endline
        "  --machine-second-cost N --token-cost N   (one unit of cost for all three)" 
