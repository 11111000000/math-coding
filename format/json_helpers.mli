val object_ : string -> string list -> Yojson.Safe.t -> ((string * Yojson.Safe.t) list, string) result
val string : string -> (string * Yojson.Safe.t) list -> (string, string) result
val string_opt : string -> (string * Yojson.Safe.t) list -> (string option, string) result
val string_list : string -> (string * Yojson.Safe.t) list -> (string list, string) result
val int : string -> (string * Yojson.Safe.t) list -> (int, string) result
val int_opt : string -> (string * Yojson.Safe.t) list -> (int option, string) result
val json_string : string -> Yojson.Safe.t
val json_string_opt : string option -> Yojson.Safe.t
val json_strings : string list -> Yojson.Safe.t
