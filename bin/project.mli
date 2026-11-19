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
  (* The digest of the subject as it is now; missing when the subject cannot
     be digested. *)
  materials : string option;
  (* The branches that no evidence settles yet, with the state each of them
     stands in: what still has to close for the claim to hold. *)
  open_branches : (requirement * state) list;
}

type evaluation = { states : evaluated_state list; damaged : Trail.damage list }

(* The claims a partial run has work for, and the ones it leaves alone. *)
type selection = {
  to_execute : claim list;
  current : claim list;
  settled : claim list;
  human : claim list;
  blind : claim list;
}

(* The path of the standing specification of the project. *)
val spec_path : string -> string

val load_spec : string -> (spec, string) result
val save_spec : string -> spec -> unit
val states : string -> spec -> ((string * state) list, string) result
val environment : string -> environment
val source_changed : string -> claim -> bool
val uncovered : string -> spec -> (string list, string) result
val reviews_of_claim : claim -> requirement list
val evaluate : string -> spec -> (evaluation, string) result
val selection : string -> spec -> (selection, string) result
val selection_words : selection -> string
val blind_words : selection -> string option
val damage_words : Trail.damage list -> string
val next_text : string -> spec -> (string, string) result
val map_output : string -> spec -> (map_output, string) result
val map_json : string -> spec -> (Yojson.Safe.t, string) result
