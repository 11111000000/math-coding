open Domain

(* The reason names the cause of a state. *)
type reason =
  | Why_current | Why_never_checked | Why_source_changed | Why_materials_changed
  | Why_definition_changed | Why_verifier_changed | Why_environment_changed | Why_expired
  | Why_not_run | Why_inconclusive | Why_infrastructure_error | Why_refuted | Why_waived
  | Why_not_checkable

val reason_to_string : reason -> string
val reason_of_string : string -> reason option
val reason_to_words : reason -> string

(* A reason explains the states it can be the cause of. *)
val explains : reason -> state -> bool

val combine : verdict -> verdict -> verdict
val verdict_of_state : state -> verdict
val verdict_of_states : state list -> verdict

(* The state of a claim and the reason of that state. The reason names the
   cause of the state and never changes it. *)
val explain_evidence :
  now:int -> ?materials:string -> ?environment:environment -> claim -> requirement -> evidence option -> state * reason
val explain_attestation :
  now:int -> ?materials:string -> ?environment:environment -> claim -> requirement -> evidence option -> state * reason
val explain_claim :
  now:int -> ?materials:string -> ?environment:environment -> ?requirements:requirement list ->
  claim -> evidence list -> state * reason

(* The review branches of a requirement. A judgment takes only its review
   branches: a machine check cannot settle a human decision. *)
val judgment_requirements : requirement -> requirement option

(* The last record for a requirement, by time of issue and then by position. *)
val latest : claim -> requirement -> evidence list -> evidence option

val state_of_evidence : now:int -> ?materials:string -> ?environment:environment -> claim -> requirement -> evidence option -> state
val state_of_attestation : now:int -> ?materials:string -> ?environment:environment -> claim -> requirement -> evidence option -> state
val state_of_claim : now:int -> ?materials:string -> ?environment:environment -> claim -> evidence list -> state
val cost_of_outcome : outcome -> int
