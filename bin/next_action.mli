open Domain

(* The next action: exactly one, in words a reader can act on. *)

(* The command that records a human review of a claim. *)
val record_command : string -> string -> string

(* The human action that can close the claim, when no check can. *)
val human_action : Evaluation.evaluated_state -> string option

(* The checks that can close the claim, and the checks that refuted it. *)
val open_checks : Evaluation.evaluated_state -> string list
val refuting_checks : Evaluation.evaluated_state -> string list
val checks_words : Evaluation.evaluated_state -> string

val next_of_refutation : Evaluation.evaluated_state -> string
val next_of_reason : Evaluation.evaluated_state -> string

(* What the journal could not say, in words a human can act on. *)
val damage_words : Trail.damage list -> string

(* The one next action over the states of the claims. *)
val next_of_states :
  Evaluation.evaluated_state list -> string list -> Trail.damage list ->
  high_risk:Evaluation.evaluated_state list -> claim_excess:int -> string
