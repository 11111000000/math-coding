open Domain

type measurement = {
  project : string;
  claims : int;
  uncovered : int;
  caught : int;
  stale : int;
  protocol_seconds : float;
  control_seconds : float;
  cut : bool;
}

type costs = {
  human_minutes : float;
  agent_tokens : int;
  person_minute_cost : float;
  machine_second_cost : float;
  token_cost : float;
  defect_cost : float option;
}

let absolute path =
  if Filename.is_relative path then Filename.concat (Sys.getcwd ()) path else path

let method_binary () =
  match Sys.getenv_opt "MATHC" with
  | Some path -> absolute path
  | None ->
      let directory = Filename.dirname Sys.argv.(0) in
      let candidates =
        List.map absolute
          [ Filename.concat directory "mathc"; Filename.concat directory "mathc.exe";
            Filename.concat directory "../bin/mathc"; Filename.concat directory "../bin/mathc.exe" ]
      in
      match List.find_opt Sys.file_exists candidates with Some path -> path | None -> "mathc"

let field name json =
  match json with `Assoc pairs -> List.assoc_opt name pairs | _ -> None

let int_field name json = match field name json with Some (`Int value) -> value | _ -> 0

let states_field json = match field "states" json with Some (`List states) -> states | _ -> []

let count_uncovered json = match field "uncovered" json with Some (`List files) -> List.length files | _ -> 0

let count_state wanted json =
  List.length
    (List.filter
       (fun state ->
         match state with
         | `Assoc pairs -> (match List.assoc_opt "state" pairs with Some (`String value) -> value = wanted | _ -> false)
         | _ -> false)
       (states_field json))

let rec commands = function
  | Verifier command -> [ command ]
  | Review _ -> []
  | All requirements | Any requirements -> List.concat_map commands requirements

(* A measurement is a measurement only when every arm of it finished. An arm
   that was cut off at the limit says nothing about the cost of the work, and a
   limit reported as a number would be a number about the tool, not about the
   method. *)
let cut_off elapsed limit = elapsed >= limit -. 0.5

let measure ?limit root =
  let binary = method_binary () in
  let project_root = absolute root in
  match Project.load_spec root with
  | Error error -> prerr_endline error; None
  | Ok spec ->
      (* The limit of the protocol arm is derived from the limits of the
         protocol itself, so a legitimate run is never cut short. *)
      let limit =
        match limit with Some value -> value | None -> Commands.protocol_timeout (List.length spec.claims)
      in
      let started = Unix.gettimeofday () in
      ignore (Process.run ~timeout:limit ~root (Printf.sprintf "%s --root %s run" (Filename.quote binary) (Filename.quote project_root)));
      let protocol_seconds = Unix.gettimeofday () -. started in
      let cut = ref (cut_off protocol_seconds limit) in
      let mapped = Process.run ~timeout:30.0 ~root (Printf.sprintf "%s --root %s map --json" (Filename.quote binary) (Filename.quote project_root)) in
      if mapped.truncated then (
        prerr_endline "stand: mathc map output was truncated";
        None)
      else
      match Yojson.Safe.from_string mapped.stdout with
      | exception Yojson.Json_error error -> prerr_endline error; None
      | json -> (
          let control_seconds =
            List.fold_left
              (fun total claim ->
                (* The price arm runs the command the protocol runs: the same
                   check, inside the environment the claim declares, or the one
                   of the specification when the claim declares none, and under
                   the same time limit. A price arm that runs the check outside
                   that environment measures cheaper work than the protocol
                   does, and the difference is then reported as the overhead of
                   the method - the method looks cheaper than it is, and the
                   criterion of the cost is decided by a wrong denominator. *)
                let environment = effective_environment spec claim in
                List.fold_left
                  (fun total command ->
                    let started = Unix.gettimeofday () in
                    ignore (Process.run ~timeout:Commands.verifier_timeout ~root (Commands.command_in_environment environment command));
                    let elapsed = Unix.gettimeofday () -. started in
                    if cut_off elapsed Commands.verifier_timeout then cut := true;
                    total +. elapsed)
                  total (List.concat_map commands claim.requirements))
              0.0 spec.claims
          in
          Some {
            project = root;
            claims = int_field "claims" json;
            uncovered = count_uncovered json;
            caught = count_state "refuted" json;
            stale = count_state "outdated" json + count_state "inconclusive" json;
            protocol_seconds;
            control_seconds;
            cut = !cut;
          })

let parse_costs args =
  let value name =
    List.find_map (fun (key, value) -> if key = name then Some value else None) args
  in
  let float name = Option.bind (value name) float_of_string_opt in
  let int name = Option.bind (value name) int_of_string_opt in
  let cost_keys = [ "--human-minutes"; "--agent-tokens"; "--person-minute-cost";
                    "--machine-second-cost"; "--token-cost"; "--defect-cost" ] in
  let has_cost_input = List.exists (fun (key, _) -> List.mem key cost_keys) args in
  match float "--human-minutes", int "--agent-tokens", float "--person-minute-cost",
        float "--machine-second-cost", float "--token-cost" with
  | Some human_minutes, Some agent_tokens, Some person_minute_cost, Some machine_second_cost, Some token_cost ->
      let values = [ human_minutes; person_minute_cost; machine_second_cost; token_cost ] in
      let defect_cost = float "--defect-cost" in
      if agent_tokens < 0 || List.exists (fun value -> value < 0.0 || value = infinity) values
         || Option.exists (fun value -> value < 0.0 || value = infinity) defect_cost then
        Error "cost parameters must be finite and nonnegative"
      else if List.exists (fun value -> value <> value) values
         || Option.exists (fun value -> value <> value) defect_cost then
        Error "cost parameters must not be NaN"
      else
        Ok (Some { human_minutes; agent_tokens; person_minute_cost; machine_second_cost; token_cost;
                   defect_cost })
  | _ when has_cost_input -> Error "all five base cost parameters are required and must be numbers"
  | _ -> Ok None

let parse_limit args =
  let value = List.find_map (fun (key, value) -> if key = "--timeout" then Some value else None) args in
  match value with
  | None -> Ok None
  | Some text -> (
      match float_of_string_opt text with
      | Some seconds when seconds > 0.0 && seconds < infinity && seconds = seconds -> Ok (Some seconds)
      | _ -> Error "--timeout must be a positive number of seconds")

let rec parse_args = function
  | [] -> []
  | "--human-minutes" :: value :: rest -> ("--human-minutes", value) :: parse_args rest
  | "--agent-tokens" :: value :: rest -> ("--agent-tokens", value) :: parse_args rest
  | "--person-minute-cost" :: value :: rest -> ("--person-minute-cost", value) :: parse_args rest
  | "--machine-second-cost" :: value :: rest -> ("--machine-second-cost", value) :: parse_args rest
  | "--token-cost" :: value :: rest -> ("--token-cost", value) :: parse_args rest
  | "--defect-cost" :: value :: rest -> ("--defect-cost", value) :: parse_args rest
  | "--timeout" :: value :: rest -> ("--timeout", value) :: parse_args rest
  | option :: _ when String.length option > 0 && option.[0] = '-' ->
      failwith ("unknown option: " ^ option)
  | project :: rest -> ("project", project) :: parse_args rest

let usage () =
  print_endline {|usage: mathc-stand PROJECT [PROJECT ...] [COST OPTIONS] [MEASUREMENT OPTIONS]

Measure the math-coding protocol against direct verifier execution.

Columns:
  claims     declared obligations
  uncovered  files inside the aim that no claim covers
  caught     refuted claims
  stale      outdated or inconclusive claims
  protocol   seconds for mathc run
  price-arm  seconds for direct verifier reruns in the declared environment
  overhead   protocol seconds minus price-arm seconds

Cost options:
  --human-minutes N          human time spent on the work
  --agent-tokens N           tokens spent by agents
  --person-minute-cost N     monetary cost of one human minute
  --machine-second-cost N    monetary cost of one machine second
  --token-cost N             monetary cost of one agent token
  --defect-cost N            monetary value of one caught defect

Measurement options:
  --timeout SECONDS          limit of the protocol arm; the default is derived
                             from the limits of the protocol itself, so a
                             legitimate run is never cut short

Example:
  mathc-stand /path/to/project \
    --human-minutes 30 --agent-tokens 10000 \
    --person-minute-cost 1 --machine-second-cost 0.01 --token-cost 0.0001 \
    --defect-cost 100

The ratio is computed only when all five base cost options are supplied.
The criterion additionally requires --defect-cost and at least one caught defect.
An arm that was cut off at the limit is reported and the ratio is not computed:
a limit is not a measurement.|}

let () =
  let arguments = Array.to_list Sys.argv |> List.tl in
  if List.exists (fun argument -> argument = "--help" || argument = "-h") arguments then (
    usage ();
    exit 0);
  let options =
    match parse_args arguments with
    | exception Failure message -> Printf.eprintf "stand: %s\n" message; exit 2
    | options -> options
  in
  let projects = List.filter_map (fun (key, value) -> if key = "project" then Some value else None) options in
  if projects = [] then (
    Printf.eprintf "stand: nothing was measured\nusage: stand PROJECT [PROJECT ...]\n";
    exit 2);
  let limit =
    match parse_limit options with
    | Error message -> Printf.eprintf "stand: %s\n" message; exit 2
    | Ok limit -> limit
  in
  let measurements = List.filter_map (measure ?limit) projects in
  if measurements = [] then (
    Printf.eprintf "stand: nothing was measured\n";
    exit 2);
  Printf.printf "%-30s %6s %9s %7s %6s %9s %9s %8s\n" "project" "claims" "uncovered" "caught" "stale" "protocol" "price-arm" "overhead";
  List.iter
    (fun measurement ->
      Printf.printf "%-30s %6d %9d %7d %6d %9.1f %9.1f %8.1f\n"
        measurement.project measurement.claims measurement.uncovered measurement.caught
        measurement.stale measurement.protocol_seconds measurement.control_seconds
        (measurement.protocol_seconds -. measurement.control_seconds))
    measurements;
  List.iter
    (fun measurement ->
      if measurement.cut then
        Printf.printf "note: the measurement of %s is not a measurement - an arm was cut off at the limit\n"
          measurement.project)
    measurements;
  let total field =
    List.fold_left (fun total measurement -> total +. field measurement) 0.0 measurements
  in
  let caught = List.fold_left (fun total measurement -> total + measurement.caught) 0 measurements in
  Printf.printf "\nprojects: %d, uncovered: %.0f, caught: %d, needs work: %.0f\n"
    (List.length measurements) (total (fun m -> float_of_int m.uncovered)) caught
    (total (fun m -> float_of_int m.stale));
  Printf.printf "protocol seconds: %.1f, price-arm seconds: %.1f, overhead: %.1f\n"
    (total (fun m -> m.protocol_seconds)) (total (fun m -> m.control_seconds))
    (total (fun m -> m.protocol_seconds -. m.control_seconds));
  match parse_costs options with
  | Error message ->
      Printf.eprintf "stand: %s\n" message;
      exit 2
  | Ok None ->
      print_endline "ratio: not computed. Declare human minutes, tokens and their prices."
  | Ok (Some costs) ->
      if List.exists (fun measurement -> measurement.cut) measurements then
        print_endline "ratio: not computed. An arm was cut off at the limit."
      else (
        let denominator =
          costs.human_minutes *. costs.person_minute_cost
          +. total (fun m -> m.protocol_seconds) *. costs.machine_second_cost
          +. float_of_int costs.agent_tokens *. costs.token_cost
        in
        if denominator <= 0.0 then print_endline "ratio: not computable - the denominator is zero"
        else (
          Printf.printf "cost: %.4f; defects caught per unit of cost: %.4f\n" denominator (float_of_int caught /. denominator);
          match costs.defect_cost with
          | None -> print_endline "criterion: not computed. Declare --defect-cost."
          | Some _ when caught = 0 -> print_endline "criterion: not computable - no defect was caught"
          | Some price ->
              let per_defect = denominator /. float_of_int caught in
              Printf.printf "criterion: the method cost %.4f per defect; the defect was worth %.4f; %s\n"
                per_defect price (if per_defect <= price then "the criterion holds" else "the criterion does not hold")))
