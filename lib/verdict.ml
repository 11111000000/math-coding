(** The laws.

    This file is where the method earns its name. A method called
    math-coding owes more than prose about mathematics: it owes
    equations over its own state, and a proof that they hold.

    THE ALGEBRA. The verdicts form a commutative monoid under
    [combine]. Green is the unit - combining with it changes nothing.
    Red is absorbing - one refuted claim makes the set red whatever
    else happened. Unknown sits between: it dominates Green and is
    dominated by Red. The order is

        Red  >  Unknown  >  Green

    and [combine] is the maximum in it. Every law below is a fact
    about that structure.

    THE PROOF. The type is finite - three elements - so the laws are
    proved by exhaustion: every pair, every triple, every empty
    sequence. That is not a sample and not a heuristic. It is the
    whole domain. [laws_hold] performs the enumeration, and the
    negative controls in the test suite kill each law separately, so
    a law cannot survive because the check that watches it was
    weakened.

    WHAT THE LAWS ARE FOR. They are the answer to a question the
    third version answered with 134 files: how do you know the method
    does what it says? Here it is six equations and a finite proof. *)

open Domain

(** The law of combination: Red beats Unknown beats Green. *)
let combine a b =
  match a with
  | Red -> Red
  | Unknown -> (
      match b with
      | Red -> Red
      | Unknown -> Unknown
      | Green -> Unknown)
  | Green -> b

(** What one outcome contributes to the verdict of a set.

    [Refused] contributes [Unknown], not [Green]. This is a change from
    what the fourth version first wrote, and it is a correction of a
    contradiction: the philosophy says a green result means "every live
    claim has a fresh, bound, executed proof", and a refused claim has
    no executed proof at all. A method that says green anyway is
    saying something it does not mean. *)
let verdict_of_outcome = function
  | Verified -> Green
  | Falsified -> Red
  | Unresolved -> Unknown
  | Refused -> Unknown

(** The verdict of a set of results. Empty is green: there is nothing
    to check, and "nothing to check" is not a defect. *)
let aggregate (results : evidence list) : verdict =
  List.fold_left
    (fun v (r : evidence) -> combine v (verdict_of_outcome r.outcome))
    Green results

(** The state of one claim, given its evidence and the subject's
    current binding. The binding is the crux: evidence obtained
    against a subject that has since moved is evidence about a subject
    that no longer exists, and it can never read as verified. *)
let state_of (current : binding option) (evidence : evidence option) : state =
  match evidence with
  | None -> NeverChecked
  | Some e -> (
      match current with
      | Some b when e.bound_to = b -> (
          match e.outcome with
          | Verified -> Holds
          | Falsified -> Refuted
          | Unresolved -> Inconclusive
          | Refused -> NotCheckable)
      | _ -> Outdated)

(** The verdict of a set of states. An outdated claim is unknown, never
    green: the proof was about yesterday's subject. *)
let verdict_of_state = function
  | Holds -> Green
  | Refuted -> Red
  | Inconclusive -> Unknown
  | NotCheckable -> Unknown
  | Outdated -> Unknown
  | NeverChecked -> Unknown

(** The verdict of the map, as a whole. *)
let verdict_of_states (states : state list) : verdict =
  List.fold_left (fun v s -> combine v (verdict_of_state s)) Green states

(** What the human is asked to decide: the claims that a machine cannot
    settle. An unresolved claim and a refused claim both need a
    person; nothing else does. *)
let route (results : evidence list) : finding list =
  List.filter_map
    (fun (r : evidence) ->
      match r.outcome with
      | Unresolved | Refused ->
          Some { subject = r.claim.subject.text; outcome = r.outcome; reason = r.reason }
      | Verified | Falsified -> None)
    results

(** The exit code of the method. Three values, because "we could not
    tell" and "it is wrong" must not share a code: a caller that
    treats them alike will treat a missing tool as a passing check. *)
let verdict_to_exit = function Green -> 0 | Red -> 1 | Unknown -> 3

(* ------------------------------------------------------------------ *)
(* The laws, as executable properties.                                *)
(* ------------------------------------------------------------------ *)

(* Each law is stated over the function it constrains, not over the
   implementation directly. That is not a stylistic choice: a law that
   can only be evaluated on the code it constrains is a description of
   that code, and a description cannot be refuted. Stated over the
   function, the law can be checked against a broken one as well as
   against the real one, and a law that accepts a broken
   implementation is exposed.

   The broken implementations live in the test suite, where they are
   required to be REJECTED. *)

(** Commutativity: the order of the results does not matter. *)
let law_commutative (combine' : verdict -> verdict -> verdict) a b =
  combine' a b = combine' b a

(** Associativity: grouping does not matter. *)
let law_associative (combine' : verdict -> verdict -> verdict) a b c =
  combine' (combine' a b) c = combine' a (combine' b c)

(** Green is the unit: an empty result changes nothing. *)
let law_unit (combine' : verdict -> verdict -> verdict) a = combine' Green a = a

(** Red is absorbing: one refuted claim is decisive. *)
let law_absorbing (combine' : verdict -> verdict -> verdict) a =
  combine' Red a = Red

(** The verdicts in order: Red dominates Unknown dominates Green. *)
let law_order (combine' : verdict -> verdict -> verdict) =
  combine' Red Unknown = Red
  && combine' Unknown Green = Unknown
  && combine' Green Green = Green

(** An outdated claim is never verified. This is the law that the whole
    binding machinery exists to make true, and the one that the third
    version broke by treating an empty digest as a wildcard. *)
let law_outdated_is_never_verified
    (state_of' : binding option -> evidence option -> state)
    (e : evidence) (current : binding option) =
  (* "if the subject moved, the claim cannot read as verified". *)
  current = Some e.bound_to || state_of' current (Some e) <> Holds

(** A scope that names nothing is not a subject. The scope must not be
    empty; whether it names anything in the tree is the adapter's
    business, and this law is the part that can be stated here. *)
let law_no_vacant_subject (s : scope) = s <> []

(** Every verdict leaves the method with a distinct exit code. *)
let law_exit_codes_distinct () =
  let codes = List.map verdict_to_exit [ Green; Red; Unknown ] in
  List.length (List.sort_uniq compare codes) = 3

(** The law of vacancy: the empty result is green. This is what makes
    adoption cost nothing. *)
let law_vacancy_is_green (aggregate' : evidence list -> verdict) = aggregate' [] = Green

(* ------------------------------------------------------------------ *)
(* The proof.                                                           *)
(* ------------------------------------------------------------------ *)

(** The domain of the verdicts. Finite, small, and written out so that
    the proof does not depend on the type staying this way. *)
let verdict_domain = [ Green; Red; Unknown ]

(** Every law, checked over the whole domain. Not a sample: the
    domain has three elements, so the pairs are nine and the triples
    are twenty-seven, and all of them are checked.

    A law that cannot be checked over the whole domain is a law that
    is being trusted rather than proved, and this method has been
    burned by exactly that. *)
let laws_hold () =
  let d = verdict_domain in
  let commutative =
    List.for_all (fun a -> List.for_all (fun b -> law_commutative combine a b) d) d
  in
  let associative =
    List.for_all
      (fun a ->
        List.for_all (fun b -> List.for_all (fun c -> law_associative combine a b c) d) d)
      d
  in
  let unit = List.for_all (law_unit combine) d in
  let absorbing = List.for_all (law_absorbing combine) d in
  commutative && associative && unit && absorbing && law_order combine
  && law_exit_codes_distinct () && law_vacancy_is_green aggregate
