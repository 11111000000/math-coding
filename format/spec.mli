open Domain

val valid_path : string -> bool

(* The version of the format the codec reads and writes. *)
val version : int

val parse_string : string -> (spec, string) result

(* The same reader, for a document that is already parsed. *)
val parse_json : Yojson.Safe.t -> (spec, string) result

(* The version of a specification, read without reading the rest of it. *)
val version_of_string : string -> (int, string) result
val version_of_json : Yojson.Safe.t -> (int, string) result

val to_json : spec -> Yojson.Safe.t
val claim_to_json : claim -> Yojson.Safe.t
val claim_of_json : Yojson.Safe.t -> (claim, string) result
val requirement_to_json : requirement -> Yojson.Safe.t
val requirement_of_json : Yojson.Safe.t -> (requirement, string) result
val source_to_json : source_ref -> Yojson.Safe.t
(* The rule of a declared environment: a non-empty single line, at most 512 characters. *)
val environment_value : string -> Yojson.Safe.t -> (string, string) result
val waiver_to_json : waiver -> Yojson.Safe.t
val waiver_of_json : Yojson.Safe.t -> (waiver, string) result
