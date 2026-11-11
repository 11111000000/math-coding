open Domain

val combine : verdict -> verdict -> verdict
val verdict_of_state : state -> verdict
val verdict_of_states : state list -> verdict
val state_of_evidence : now:int -> ?materials:string -> claim -> requirement -> evidence option -> state
val state_of_attestation : now:int -> ?materials:string -> claim -> requirement -> evidence option -> state
val state_of_claim : now:int -> ?materials:string -> claim -> evidence list -> state
val cost_of_outcome : outcome -> int
