open Domain

(* The moment an observation is made. *)
val now : unit -> int

(* The time a check is allowed to take. The protocol and the price arm of the
   measurer share one limit, so the measurer cannot cut short a check that the
   protocol lets finish. *)
val verifier_timeout : float

(* The time a negative control is allowed to take. *)
val control_timeout : float

(* The time the whole protocol run of a specification may take. It is derived
   from the limits above, so the measurer never cuts a legitimate run short. *)
val protocol_timeout : int -> float

(* A declared environment is a prefix for the whole command. The measurer
   compares the full protocol with the same commands, so it has to run them in
   the same environment. *)
val command_in_environment : string option -> string -> string

(* The observation a check produces, bound to the subject it was made against. *)
val evidence_for :
  ?files:string list -> string -> claim -> requirement -> string -> outcome -> string option -> evidence

(* The execution of one branch of a claim. *)
val execute_requirement :
  ?files:string list -> ?quiet:bool -> environment:string option ->
  string -> claim -> (evidence -> unit) -> requirement -> outcome
