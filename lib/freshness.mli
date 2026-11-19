open Domain

val expired : now:int -> int option -> bool

type defect =
  | Fresh
  | Materials_changed
  | Definition_changed
  | Verifier_changed
  | Environment_changed
  | Not_applicable

(* The environment and the materials bind the execution of a check, not the
   decision of a human. *)
val binds_machine : requirement -> bool

val defect :
  ?materials:string -> ?environment:environment -> ?binds_machine:bool -> claim -> evidence -> defect
val requirement_fresh : ?materials:string -> ?environment:environment -> claim -> requirement -> evidence -> bool
