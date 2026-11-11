open Domain

val to_json : evidence -> Yojson.Safe.t
val of_json : Yojson.Safe.t -> (evidence, string) result
