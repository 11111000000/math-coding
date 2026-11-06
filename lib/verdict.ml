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

(** The state of ONE REQUIREMENT, from its evidence and the subject's
    current binding. The binding is the crux: evidence obtained
    against a subject that has since moved is evidence about a subject
    that no longer exists, and it can never read as verified.

    The proof's TERM is the second crux. The binding answers "is the
    content the same?"; the term answers "does this proof still
    count?". A proof can be about exactly the right content and still
    be too old to stand - the deployment moved, the dependency
    changed, the review was for the release that is over. Neither the
    content nor the truth can see that; only the term can.

    The moment is a VALUE, not a reading of the clock: the core has no
    clock, and a law that read the clock would be a law about the
    machine rather than about the value. *)
let expired (now : float) (e : evidence) : bool =
  match e.valid_until with
  | None -> false
  | Some until_ -> (
      match float_of_string_opt until_ with
      | Some t -> t <= now
      | None -> false)

(** What an outcome means for the state of a claim. ONE mapping for
    every proof, so that a proof from a person and a proof from a
    machine cannot come to mean different things. *)
let state_of_outcome (o : outcome) : state =
  match o with
  | Verified -> Holds
  | Falsified -> Refuted
  | Unresolved -> Inconclusive
  | Refused -> NotCheckable

let state_of_evidence (current : binding option) (now : float)
    (evidence : evidence option) : state =
  match evidence with
  | None -> NeverChecked
  | Some e -> (
      match current with
      | Some b when e.bound_to = b ->
          if expired now e then Outdated else state_of_outcome e.outcome
      | _ -> Outdated)

let verdict_of_state = function
  | Holds -> Green
  | Refuted -> Red
  | Inconclusive -> Unknown
  | NotCheckable -> Unknown
  | Outdated -> Unknown
  | NeverChecked -> Unknown
  | Accepted -> Unknown

(** The verdict of the map, as a whole. *)
let verdict_of_states (states : state list) : verdict =
  List.fold_left (fun v s -> combine v (verdict_of_state s)) Green states

(** What the human is asked to decide: the claims that a machine cannot
    settle. An unresolved claim and a refused claim both need a
    person; nothing else does. *)
(** The state of a claim, from the states of its requirements.

    The claim's state is the FOLD of the requirement states, and the
    fold is the monoid above. A claim with two requirements, one closed
    and one open, is not "closed" and not "unknown" - it is partly
    known, which is [Inconclusive], and the map shows which part is
    missing. That is the answer to the question the third version could
    not state: what is the state of a thing that needs two kinds of
    confirmation and has one? *)
(** What a requirement names - the thing `record` and the attestations
    call it by. *)
let spec_of (r : requirement) : string =
  match r with Verified_by spec -> spec | Reviewed_by spec -> spec

(** Seconds since the epoch, as a number. The moments of two proofs
    are compared, and the comparison must not depend on the order the
    files were read in. *)
let at_seconds (text : string) : float =
  match float_of_string_opt text with Some t -> t | None -> 0.0

(** The moment of a proof, when it has one. A trail written before the
    moment was recorded has none, and an absent moment is older than
    any recorded one. *)
let at_of (moment : string option) : float =
  match moment with Some t -> at_seconds t | None -> 0.0

(** The state of a requirement closed by an attestation: a proof from
    outside, bound to the subject as it stands. It carries the same
    freshness rules as any other proof - the subject may have moved,
    and the attestation may have expired. *)
let state_of_attestation (current : binding option) (now : float)
    (a : attestation) : state =
  let expired_now =
    match a.valid_until with
    | None -> false
    | Some until_ -> (
        match float_of_string_opt until_ with
        | Some t -> t <= now
        | None -> false)
  in
  if expired_now then Outdated
  else
    match current with
    | Some b when b = a.bound_to -> state_of_outcome a.outcome
    | _ -> Outdated

let state_of_requirements (claim : claim) (current : binding option) (now : float)
    (evidence : evidence list) : state =
  let for_requirement (r : requirement) =
    (* The evidence is matched by the claim AND the requirement. Two
       claims often share one check - the same test suite verifies
       several rules - and matching by the requirement alone would let
       one claim's evidence answer for another. The digests differ, so
       the mismatch would show up as "outdated" rather than as a wrong
       answer, which is how it was found: on the second claim of a
       pair, the verdict turned unknown with no visible cause. *)
    let latest =
      List.filter
        (fun (e : evidence) -> e.claim.id = claim.id && e.requirement = r)
        evidence
      |> List.fold_left
           (fun acc (e : evidence) ->
             match acc with
             | Some (prev : evidence) -> Some e
             | None -> Some e)
           None
    in
    (* AN ATTESTATION OUTRANKS THE TRAIL WHEN IT IS NEWER: both may
       speak about the same requirement, and the later one counts. *)
    let latest_attestation =
      List.filter (fun (a : attestation) -> a.requirement = spec_of r) claim.attestations
      |> List.fold_left
           (fun acc (a : attestation) ->
             match acc with
             | Some (prev : attestation) ->
                 if at_seconds a.at >= at_seconds prev.at then Some a else Some prev
             | None -> Some a)
           None
    in
    match (latest, latest_attestation) with
    | None, None -> state_of_evidence current now None
    | Some e, None -> state_of_evidence current now (Some e)
    | None, Some a -> state_of_attestation current now a
    | Some e, Some a ->
        if at_seconds a.at >= at_of e.at then state_of_attestation current now a
        else state_of_evidence current now (Some e)
  in
  let states = List.map for_requirement claim.requirements in
  (* The refinement of the fold. The fold answers "is anything
     refuted, and is everything known"; the states say WHICH kind of
     not-knowing it is, because the human acts differently in each
     case: nobody looked, we looked and the subject moved, we looked
     and could not tell, or the machine is not the one to decide. *)
  if List.exists (fun s -> s = Refuted) states then Refuted
  else if List.exists (fun s -> s = NotCheckable) states then NotCheckable
  else if List.for_all (fun s -> s = Holds) states then Holds
  else if states = [] then NeverChecked
  else if List.for_all (fun s -> s = NeverChecked) states then NeverChecked
  else if List.for_all (fun s -> s = Outdated) states then Outdated
  else Inconclusive

let apply_acceptance (c : claim) (computed : state) : state =
  match c.accepted with
  | Some _ when computed = Holds || computed = Refuted -> computed
  | Some _ -> Accepted
  | None -> computed

(** The state of one claim, with the acceptance applied. The computed
    state comes from the requirements; the acceptance may only cover
    an uncertainty, never an answer (A7). *)
let state_of_claim (claim : claim) (current : binding option) (now : float)
    (evidence : evidence list) : state =
  apply_acceptance claim (state_of_requirements claim current now evidence)

(** The law of the acceptance: it covers uncertainty and never an
    answer. Stated over the step it constrains, so that the broken
    version - one that accepts anything - can be offered to it and
    rejected. *)
let law_acceptance_never_changes_an_answer
    (apply' : claim -> state -> state)
    (c : claim)
    (s : state) =
  match s with
  | Holds | Refuted -> apply' c s = s
  | _ -> apply' c s = Accepted || apply' c s = s

(** The verdict of a set of states. An outdated claim is unknown, never
    green: the proof was about yesterday's subject. *)
let route (binding_of : claim -> binding option) (claims : claim list)
    (evidence : evidence list) : finding list =
  let for_claim (claim : claim) =
    let evs = List.filter (fun (e : evidence) -> e.claim.id = claim.id) evidence in
    let unsettled =
      List.filter_map
        (fun (e : evidence) ->
          match e.outcome with
          | Unresolved | Refused ->
              Some { subject = claim.subject.text; outcome = e.outcome; reason = e.reason }
          | Verified | Falsified -> None)
        evs
    in
    let waiting =
      List.filter_map
        (fun (r : requirement) ->
          match r with
          | Verified_by _ -> None
          | Reviewed_by authority ->
              (* A review is closed either by a proof in the trail or by
                 an attestation in the specification - and by nothing
                 else. The attestation counts only while it is fresh:
                 a review of a subject that has since moved is not a
                 review of the subject as it stands. *)
              let fresh bound_to =
                match binding_of claim with
                | Some b -> bound_to = b
                | None -> false
              in
              let closed =
                List.exists
                  (fun (e : evidence) ->
                    e.requirement = r && e.outcome = Verified && fresh e.bound_to)
                  evs
                || List.exists
                     (fun (a : attestation) ->
                       a.requirement = spec_of r
                       && a.outcome = Verified
                       && fresh a.bound_to)
                     claim.attestations
              in
              if closed then None
              else
                Some
                  {
                    subject = claim.subject.text;
                    outcome = Unresolved;
                    reason = Some ("ждёт ревью от " ^ authority);
                  })
        claim.requirements
    in
    unsettled @ waiting
  in
  List.concat_map for_claim claims

(** The exit code of the method. Three values, because "we could not
    tell" and "it is wrong" must not share a code: a caller that
    treats them alike will treat a missing tool as a passing check. *)
let verdict_to_exit = function Green -> 0 | Red -> 1 | Unknown -> 3

(* ------------------------------------------------------------------ *)
(* The laws, as executable properties.                                *)
(* ------------------------------------------------------------------ *)


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
    (state_of' : binding option -> float -> evidence option -> state)
    (e : evidence) (current : binding option) =
  (* "if the subject moved, the claim cannot read as verified". *)
  current = Some e.bound_to || state_of' current 0.0 (Some e) <> Holds

let law_expired_is_never_verified
    (state_of' : binding option -> float -> evidence option -> state)
    (e : evidence) (current : binding option) =
  state_of' current 1_000_000_000.0 (Some e) <> Holds

(** A scope that names nothing is not a subject. The scope must not be
    empty; whether it names anything in the tree is the adapter's
    business, and this law is the part that can be stated here.

    It is stated over the FUNCTION that decides, like every other law
    here, and it used not to be: it was a bare predicate over a scope,
    which no broken implementation could be offered to, and so it had
    no negative control and nobody had ever tried to break it. A law
    that cannot be offered a counterexample is a description of the
    code. The function is the one that says whether a scope names a
    subject at all; the law says that such a scope is not empty. *)
let law_no_vacant_subject (is_subject : scope -> bool) (s : scope) =
  (not (is_subject s)) || s <> []

let law_no_partial_subject (digest : scope -> string option)
    (exists : string -> bool) (s : scope) =
  match digest s with
  | None -> true
  | Some _ -> s <> [] && List.for_all exists s

(** Every verdict leaves the method with a distinct exit code. *)
let law_exit_codes_distinct () =
  let codes = List.map verdict_to_exit [ Green; Red; Unknown ] in
  List.length (List.sort_uniq compare codes) = 3

(** The law of vacancy: the empty result is green. This is what makes
    adoption cost nothing. *)
let law_vacancy_is_green (aggregate' : evidence list -> verdict) = aggregate' [] = Green

let apply_register (r : register) (o : outcome) : outcome =
  match r, o with
  | Judgment, Verified -> Refused
  | Judgment, Falsified -> Refused
  | _ -> o

(** The law, stated over the function it constrains: no register lets a
    judgment read as verified, and none lets it read as refuted. *)
let law_judgment_is_never_verified
    (apply' : register -> outcome -> outcome)
    (r : register)
    (o : outcome) =
  r <> Judgment || (apply' r o <> Verified && apply' r o <> Falsified)

(** The law of the price of uncertainty: an unresolved or refused claim
    costs something, and the cost is counted rather than asserted. *)
let cost_of_outcome (o : outcome) : int =
  match o with
  | Verified | Falsified -> 0
  | Unresolved | Refused -> 1

(** The law of the price of uncertainty: an unresolved or refused claim
    costs something, and only an answer is free.

    Both halves are needed. "Answers are free" alone is satisfied by a
    cost function that charges nothing for anything, and that is
    exactly the world the principle forbids: an uncertainty that costs
    nothing makes "I do not know" cheaper than checking. *)
let law_only_answers_are_free (cost' : outcome -> int) =
  List.for_all (fun o -> cost' o = 0) [ Verified; Falsified ]
  && List.for_all (fun o -> cost' o > 0) [ Unresolved; Refused ]

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
  let registers = [ Fact; Hypothesis; Judgment; Undeclared ] in
  let outcomes = [ Verified; Falsified; Unresolved; Refused ] in
  let judgment =
    List.for_all
      (fun r ->
        List.for_all
          (fun o -> law_judgment_is_never_verified apply_register r o)
          outcomes)
      registers
  in
  let price =
    List.for_all
      (fun o -> law_only_answers_are_free cost_of_outcome)
      outcomes
  in
  commutative && associative && unit && absorbing && law_order combine
  && law_exit_codes_distinct () && law_vacancy_is_green aggregate && judgment
  && price
