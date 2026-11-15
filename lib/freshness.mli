open Domain

val expired : now:int -> int option -> bool

type defect =
  | Fresh
  | Materials_changed
  | Definition_changed
  | Verifier_changed
  | Environment_changed
  | Not_applicable

val defect : ?materials:string -> ?environment:environment -> claim -> evidence -> defect
val requirement_fresh : ?materials:string -> ?environment:environment -> claim -> requirement -> evidence -> bool
val matches : ?materials:string -> ?environment:environment -> claim -> requirement -> evidence -> bool
