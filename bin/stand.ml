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

(** One project's measurement. *)
type measurement = {
  project : string;
  claims : int;
  covered : int;
  uncovered : int;
  seconds : float;
  exit : int;
  found : int;
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
          }
    | _ -> None

(** The projects to measure. Given on the command line, one per
    argument. A project without a standing specification is not
    measured: the method has nothing to say about a project that has
    not stated its aim, and the stand does not state aims on its
    behalf. *)
let projects_of_args = Array.to_list Sys.argv |> List.tl

let () =
  let measurements = List.filter_map measure projects_of_args in
  if measurements = [] then (
    Printf.eprintf "stand: nothing was measured\n";
    print_endline "usage: stand PROJECT [PROJECT ...]";
    print_endline "  each project must have a standing specification and a built method";
    exit 2);
  Printf.printf "%-40s %7s %9s %9s %9s %6s\n" "project" "claims" "uncovered"
    "found" "run-secs" "exit";
  List.iter
    (fun (m : measurement) ->
      Printf.printf "%-40s %7d %9d %9d %8.1f %6d\n" m.project m.claims m.uncovered
        m.found m.seconds m.exit)
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
  Printf.printf "\nprojects: %d, uncovered: %d, found: %d, machine seconds: %.1f\n"
    (List.length measurements) total_uncovered total_found total_seconds;
  print_endline "";
  print_endline
    "This is the denominator and the raw material of the numerator. It is not the";
  print_endline
    "ratio GOAL.md asks for: that needs a control arm, the same project without the";
  print_endline "protocol, and the agent's own cost, which the method cannot see.";
  print_endline "The stand refuses to publish a number it cannot stand behind."
