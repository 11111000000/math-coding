open Domain

val check : string -> bool -> unit
val contains : string -> string -> bool
val with_repo : (string -> 'a) -> 'a
val write : string -> string -> string -> unit
val binary : unit -> string
val expect : string -> string -> int -> unit
val run : string -> string -> Process.result
val claim : claim
val evidence : claim -> evidence
val field : string -> Yojson.Safe.t -> Yojson.Safe.t option
val in_repo : string -> string
