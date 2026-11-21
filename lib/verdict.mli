open Domain

(* The reason names the cause of a state. *)
type reason =
  | Why_current | Why_never_checked | Why_source_changed | Why_materials_changed
  | Why_definition_changed | Why_verifier_changed | Why_environment_changed | Why_expired
  | Why_not_run | Why_inconclusive | Why_infrastructure_error | Why_refuted | Why_waived
  | Why_tool_changed

val reason_to_string : reason -> string
val reason_of_string : string -> reason option
val reason_to_words : reason -> string

(* The token of every reason. The table is the closed vocabulary of the map:
   it is exhaustive, so the two directions cannot drift apart. *)
val reason_tokens : (string * reason) list

(* A reason explains the states it can be the cause of. *)
val explains : reason -> state -> bool

(* The order the reasons are read in: the first one that explains the state is
   the reason of that state. *)
val priority : reason list

val combine : verdict -> verdict -> verdict
val verdict_of_state : state -> verdict
val verdict_of_states : state list -> verdict

(* The state of a claim and the reason of that state. The reason names the
   cause of the state and never changes it. The tool is the one that reads the
   map: when it is not the tool that produced the record, the reason says so
   and the state stays the same. *)
val explain_evidence :
  now:int -> ?materials:string -> ?environment:environment -> ?tool:tool ->
  claim -> requirement -> evidence option -> state * reason
val explain_attestation :
  now:int -> ?materials:string -> ?environment:environment -> ?tool:tool ->
  claim -> requirement -> evidence option -> state * reason
val explain_claim :
  now:int -> ?materials:string -> ?environment:environment -> ?tool:tool -> ?requirements:requirement list ->
  claim -> evidence list -> state * reason

(* The review branches of a requirement. A judgment takes only its review
   branches: a machine check cannot settle a human decision. *)
val judgment_requirements : requirement -> requirement option

(* The last record for a requirement, by time of issue and then by position. *)
val latest : claim -> requirement -> evidence list -> evidence option

val state_of_evidence : now:int -> ?materials:string -> ?environment:environment -> ?tool:tool -> claim -> requirement -> evidence option -> state
val state_of_attestation : now:int -> ?materials:string -> ?environment:environment -> ?tool:tool -> claim -> requirement -> evidence option -> state
val state_of_claim : now:int -> ?materials:string -> ?environment:environment -> ?tool:tool -> claim -> evidence list -> state
val cost_of_outcome : outcome -> int
