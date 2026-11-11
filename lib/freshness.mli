open Domain

val expired : now:int -> int option -> bool
val current : ?materials:string -> claim -> evidence -> bool
val requirement_fresh : claim -> requirement -> evidence -> bool
val matches : claim -> requirement -> evidence -> bool
