open Domain

val expired : now:int -> int option -> bool
val current : ?materials:string -> ?environment:environment -> claim -> evidence -> bool
val requirement_fresh : ?materials:string -> ?environment:environment -> claim -> requirement -> evidence -> bool
val matches : ?materials:string -> ?environment:environment -> claim -> requirement -> evidence -> bool
