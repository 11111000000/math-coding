open Domain
open Json_helpers

(* The log of what a run cost. It is not evidence: the evidence trail says
   what was proved, this says what the machine spent. The price of a run is
   lost when the terminal closes, and the price is what tells a consumer which
   check to look at first.

   The cost of a claim is the domain's own observation of execution; the run
   journal only says which claim the observation belongs to. One model of
   "what the machine spent", not two.

   The codec lives here, beside the file it writes, because the format library
   has no room for another module and the strict predicates of that library
   are what make a record readable or not. The record carries its own
   schema_version: a record of another version is not read and does not
   become a fallback. *)

(* The price of one claim: what the machine spent on it. *)
type priced_claim = { claim_id : string; cost : execution_log }

type run_record = {
  started_at : int;
  finished_at : int;
  (* The wall-clock time of the run. *)
  wall_seconds : float;
  (* The machine time of the checks: what the run spent proving. *)
  machine_seconds : float;
  claims : int;
  executed : int;
  stopped : bool;
  durations : priced_claim list;
}

let path root = Filename.concat root ".math/v5/runs.jsonl"

let scale_to_string = function
  | Wall_clock_seconds -> "wall_clock_seconds"
  | Tokens -> "tokens"
  | Steps -> "steps"

let scale_of_string = function
  | "wall_clock_seconds" -> Some Wall_clock_seconds
  | "tokens" -> Some Tokens
  | "steps" -> Some Steps
  | _ -> None

let float_of_json name pairs =
  match List.assoc_opt name pairs with
  | Some (`Float value) -> Ok value
  | Some _ -> Error (name ^ " must be a number")
  | None -> Error (name ^ " is required")

let priced_to_json (priced : priced_claim) =
  let cost = priced.cost in
  `Assoc
    [ "claim_id", `String priced.claim_id;
      "scale", `String (scale_to_string cost.scale);
      "value", `Float cost.value;
      "observed_at", `Int cost.observed_at;
      "observed_by", `String cost.observed_by ]

let to_json (run : run_record) =
  `Assoc
    [ "schema_version", `Int 5;
      "started_at", `Int run.started_at;
      "finished_at", `Int run.finished_at;
      "wall_seconds", `Float run.wall_seconds;
      "machine_seconds", `Float run.machine_seconds;
      "claims", `Int run.claims;
      "executed", `Int run.executed;
      "stopped", `Bool run.stopped;
      "durations", `List (List.map priced_to_json run.durations) ]

let priced_of_json json =
  match object_ "price"
          [ "claim_id"; "scale"; "value"; "observed_at"; "observed_by" ] json with
  | Error error -> Error error
  | Ok pairs -> (
      match string "claim_id" pairs, string "scale" pairs, float_of_json "value" pairs,
            int "observed_at" pairs, string "observed_by" pairs with
      | Ok claim_id, Ok scale, Ok value, Ok observed_at, Ok observed_by -> (
          match scale_of_string scale with
          | Some scale -> Ok { claim_id; cost = { scale; value; observed_at; observed_by } }
          | None -> Error ("unknown scale " ^ scale))
      | Error error, _, _, _, _ | _, Error error, _, _, _ | _, _, Error error, _, _
      | _, _, _, Error error, _ | _, _, _, _, Error error -> Error error)

let of_json json =
  match object_ "run"
          [ "schema_version"; "started_at"; "finished_at"; "wall_seconds"; "machine_seconds";
            "claims"; "executed"; "stopped"; "durations" ] json with
  | Error error -> Error error
  | Ok pairs -> (
      match int "schema_version" pairs with
      | Error error -> Error error
      | Ok version ->
          if version <> 5 then Error ("unsupported run log schema_version " ^ string_of_int version)
          else
            match
              int "started_at" pairs, int "finished_at" pairs, float_of_json "wall_seconds" pairs,
              float_of_json "machine_seconds" pairs, int "claims" pairs, int "executed" pairs,
              bool "stopped" pairs
            with
            | Ok started_at, Ok finished_at, Ok wall_seconds, Ok machine_seconds, Ok claims, Ok executed, Ok stopped ->
                (match List.assoc_opt "durations" pairs with
                 | Some (`List items) ->
                     let rec convert acc = function
                       | [] -> Ok (List.rev acc)
                       | item :: rest -> (
                           match priced_of_json item with
                           | Ok priced -> convert (priced :: acc) rest
                           | Error error -> Error error)
                     in
                     (match convert [] items with
                      | Error error -> Error error
                      | Ok durations ->
                          Ok { started_at; finished_at; wall_seconds; machine_seconds; claims; executed;
                               stopped; durations })
                 | Some _ -> Error "durations must be a list"
                 | None -> Error "durations is required")
            | Error error, _, _, _, _, _, _ | _, Error error, _, _, _, _, _
            | _, _, Error error, _, _, _, _ | _, _, _, Error error, _, _, _
            | _, _, _, _, Error error, _, _ | _, _, _, _, _, Error error, _
            | _, _, _, _, _, _, Error error -> Error error)

let append root (run : run_record) =
  let file = path root in
  Io.mkdir_p (Filename.dirname file);
  let channel = open_out_gen [ Open_append; Open_creat; Open_wronly ] 0o600 file in
  output_string channel (Yojson.Safe.to_string (to_json run));
  output_char channel '\n';
  close_out channel

(* The runs that can be read. A record that cannot be read is skipped, not
   fatal: the price of the other runs must not disappear with it. *)
let read root =
  let file = path root in
  if not (Sys.file_exists file) then Ok []
  else
    try
      let rec lines channel acc =
        match input_line channel with
        | line -> lines channel (line :: acc)
        | exception End_of_file -> close_in channel; Ok (List.rev acc)
      in
      match lines (open_in file) [] with
      | Error error -> Error error
      | Ok values ->
          let rec convert runs = function
            | [] -> Ok (List.rev runs)
            | line :: rest ->
                if String.trim line = "" then convert runs rest
                else
                  match Yojson.Safe.from_string line with
                  | exception Yojson.Json_error _ -> convert runs rest
                  | json -> (
                      match of_json json with
                      | Ok run -> convert (run :: runs) rest
                      | Error _ -> convert runs rest)
          in
          convert [] values
    with Sys_error error -> Error ("run log: " ^ error)
