open Domain

type map_output = {
  json : Yojson.Safe.t;
  text : string;
  exit_code : int;
}

(* The state of every claim together with what the journal could not say. *)
type evaluated_state = {
  id : string;
  state : state;
  changed : bool;
  reason : Verdict.reason;
  (* The branches that no evidence settles yet: what still has to close for
     the claim to hold. *)
  open_branches : requirement list;
}

type evaluation = { states : evaluated_state list; damaged : Trail.damage list }

val load_spec : string -> (spec, string) result
val save_spec : string -> spec -> unit
val states : string -> spec -> ((string * state) list, string) result
val environment : string -> environment
val source_changed : string -> claim -> bool
val uncovered : string -> spec -> (string list, string) result
val evaluate : string -> spec -> (evaluation, string) result
val damage_words : Trail.damage list -> string
val next_text : string -> spec -> (string, string) result
val map_output : string -> spec -> (map_output, string) result
val map_json : string -> spec -> (Yojson.Safe.t, string) result
