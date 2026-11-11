open Domain

val load_spec : string -> (spec, string) result
val save_spec : string -> spec -> unit
val states : string -> spec -> ((string * state) list, string) result
val environment : string -> environment
val source_changed : string -> claim -> bool
val uncovered : string -> spec -> (string list, string) result
val next_text : string -> spec -> (string, string) result
val map_json : string -> spec -> (Yojson.Safe.t, string) result
