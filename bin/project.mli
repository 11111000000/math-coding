open Domain

type map_output = {
  json : Yojson.Safe.t;
  text : string;
  exit_code : int;
}

(* The path of the standing specification of the project. *)
val spec_path : string -> string

(* The specification of the project. A project of the previous version of the
   format is refused with the instruction to migrate it. *)
val load_spec : string -> (spec, string) result

val save_spec : string -> spec -> unit

(* The area of the aim: the paths the aim declares. *)
val goal_scope_words : spec -> string

(* The one next action over what the journal holds now. *)
val next_text : string -> spec -> (string, string) result

(* The map: the verdict, the states, the tool that reads them and the next
   action. *)
val map_output : string -> spec -> (map_output, string) result
val map_json : string -> spec -> (Yojson.Safe.t, string) result
