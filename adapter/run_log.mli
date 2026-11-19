open Domain

(* The price of one claim: what the machine spent on it, and the claim it was
   spent on. *)
type priced_claim = { claim_id : string; cost : execution_log }

(* The price of one run: what it cost and how many claims it touched. *)
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

val path : string -> string
val to_json : run_record -> Yojson.Safe.t
val of_json : Yojson.Safe.t -> (run_record, string) result
val append : string -> run_record -> unit

(* The runs that can be read. A record that cannot be read is skipped, not
   fatal: the price of the other runs must not disappear with it. *)
val read : string -> (run_record list, string) result
