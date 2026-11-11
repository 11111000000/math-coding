open Domain

val valid_path : string -> bool
val parse_string : string -> (spec, string) result
val to_json : spec -> Yojson.Safe.t
val claim_to_json : claim -> Yojson.Safe.t
val claim_of_json : Yojson.Safe.t -> (claim, string) result
val requirement_to_json : requirement -> Yojson.Safe.t
val requirement_of_json : Yojson.Safe.t -> (requirement, string) result
val source_to_json : source_ref -> Yojson.Safe.t
val waiver_to_json : waiver -> Yojson.Safe.t
