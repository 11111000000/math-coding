open Domain

(* The version of the format of the record. *)
val version : int

val to_json : evidence -> Yojson.Safe.t
val of_json : Yojson.Safe.t -> (evidence, string) result
