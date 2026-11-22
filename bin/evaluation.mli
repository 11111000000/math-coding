open Domain

(* The state of every claim together with what the journal could not say. *)
type evaluated_state = {
  id : string;
  state : state;
  changed : bool;
  reason : Verdict.reason;
  (* The digest of the subject as it is now; missing when the subject cannot
     be digested. *)
  materials : string option;
  (* The branches that no evidence settles yet, with the state each of them
     stands in: what still has to close for the claim to hold. *)
  open_branches : (requirement * state) list;
}

type evaluation = { states : evaluated_state list; damaged : Trail.damage list }

(* The claims a partial run has work for, and the ones it leaves alone. *)
type selection = {
  to_execute : claim list;
  current : claim list;
  settled : claim list;
  human : claim list;
  blind : claim list;
}

(* The environment of the project: the operating system and the lock file of
   the toolchain. The binary is not part of it. *)
val environment : string -> environment

(* The tool that writes the records down: the binary itself. An unknown tool
   (an empty fingerprint) is not a changed tool. *)
val tool : unit -> tool

val source_changed : string -> claim -> bool

(* The requirements of a claim that the method evaluates. *)
val requirements_of_claim : claim -> requirement list

(* The reviews a claim waits for. *)
val reviews_of_claim : claim -> requirement list

val evaluate : string -> spec -> (evaluation, string) result
val states : string -> spec -> ((string * state) list, string) result
val uncovered : string -> spec -> (string list, string) result
val selection : string -> spec -> (selection, string) result
val selection_words : selection -> string
val blind_words : selection -> string option
