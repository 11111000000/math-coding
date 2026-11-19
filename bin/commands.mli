val init : string -> int
val goal : string -> string -> string list -> string -> string -> int
val add : string -> string -> string -> string list -> string -> string -> Domain.requirement list -> string -> string -> int
val run : ?changed:bool -> string -> bool -> int
val map : string -> bool -> int
val next : string -> int
val context : string -> int
val waive : string -> string -> string -> string -> int -> string -> int
val record : string -> string -> string -> string -> string -> int option -> string option -> int
val install : string -> int
val authorize : string -> string -> string -> int
val re_evaluate : string -> int
val review_source : string -> string -> string -> string -> int
val version : unit -> int

(* A declared environment is a prefix for the whole command. The measurer
   compares the full protocol with the same commands, so it has to run them in
   the same environment. *)
val command_in_environment : string option -> string -> string

(* The time a check is allowed to take. The protocol and the price arm of the
   measurer share one limit, so the measurer cannot cut short a check that the
   protocol lets finish. *)
val verifier_timeout : float

(* The time a negative control is allowed to take. *)
val control_timeout : float

(* The time the whole protocol run of a specification may take. It is derived
   from the limits above, so the measurer never cuts a legitimate run short. *)
val protocol_timeout : int -> float
