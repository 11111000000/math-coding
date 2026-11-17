open Domain

val expired : now:int -> int option -> bool

type defect =
  | Fresh
  | Materials_changed
  | Definition_changed
  | Verifier_changed
  | Environment_changed
  | Not_applicable

(* The environment binds the execution of a check, not the decision of a human.
   A review requirement is not bound to the environment; a claim that asks for
   a machine check is. *)
val binds_environment : requirement -> bool

val defect :
  ?materials:string -> ?environment:environment -> ?binds_environment:bool -> claim -> evidence -> defect
val requirement_fresh : ?materials:string -> ?environment:environment -> claim -> requirement -> evidence -> bool
val matches : ?materials:string -> ?environment:environment -> claim -> requirement -> evidence -> bool
