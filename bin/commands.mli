val init : string -> int
val goal : string -> string -> string list -> string -> string -> int
val add : string -> string -> string -> string list -> string -> string -> Domain.requirement list -> string -> string -> int
val run : string -> bool -> int
val map : string -> bool -> int
val next : string -> int
val context : string -> int
val waive : string -> string -> string -> string -> int -> string -> int
val record : string -> string -> string -> string -> string -> int option -> string option -> int
val install : string -> int
val doctor : string -> int
val authorize : string -> string -> string -> int
val re_evaluate : string -> int
val review_source : string -> string -> string -> string -> int
val version : unit -> int

(* A declared environment is a prefix for the whole command. The measurer
   compares the full protocol with the same commands, so it has to run them in
   the same environment. *)
val command_in_environment : string option -> string -> string
