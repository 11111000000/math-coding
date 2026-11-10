(** The laws.

    This file is where the method earns its name. A method called
    math-coding owes more than prose about mathematics: it owes
    equations over its own state, and a proof that they hold.

    THE ALGEBRA. The verdicts form a commutative monoid under
    [combine]. Green is the unit, Red is absorbing, and Unknown sits
    between: it dominates Green and is dominated by Red. The order is

        Red  >  Unknown  >  Green

    and [combine] is the maximum in it.

    THE PROOF. The type is finite - three elements - so the laws are
    proved by exhaustion: every pair, every triple, every empty
    sequence. Not a sample and not a heuristic: it is the whole domain.
    The enumeration lives in the test suite, where the negative
    controls kill each law separately, so a law cannot survive because
    the check that watches it was weakened. *)

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

    [Refused] contributes [Unknown], not [Green]: the philosophy says a
    green result means "every live claim has a fresh, bound, executed
    proof", and a refused claim has no executed proof at all. *)
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
    current binding. Evidence obtained against a subject that has since
    moved is evidence about a subject that no longer exists.

    The proof's TERM is the second crux. The binding answers "is the
    content the same?"; the term answers "does this proof still
    count?". A proof can be about exactly the right content and still
    be too old to stand - the deployment moved, the dependency
    changed. Neither the content nor the truth can see that.

    The moment is a VALUE, not a reading of the clock: the core has no
    clock, and a law that read the clock would be a law about the
    machine rather than about the value. *)
let expired (now : float) (valid_until : string option) : bool =
  match valid_until with
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

(** What one proof says about the state of a requirement.

    A proof that says "yes" is a proof only if the same check was shown
    able to say "no" on the same subject. [e.control] carries what the
    check said when the negative control was applied: [Some Falsified]
    means it BIT, and only that is a proof. A proof with no control, or
    with one that did not bite, is a proof that a command exited zero -
    a fact about the command and not about the subject.

    THIS IS THE CARRIER OF A16, and it was not one before: the core
    never read the control, and the map reported a DECLARED control as
    a control that had bitten. *)
let state_of_evidence (current : binding option) (now : float)
    (evidence : evidence option) : state =
  match evidence with
  | None -> NeverChecked
  | Some e -> (
      match current with
      | Some b when e.bound_to = b ->
          if expired now e.valid_until then Outdated
          else if e.outcome = Verified && e.control <> Some Falsified then
            (* The check said yes and was never shown able to say no:
               not established, and not refuted either - nobody has
               shown it false. *)
            Inconclusive
          else state_of_outcome e.outcome
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
    settle. *)
(** The state of a claim, from the states of its requirements. A claim
    with two requirements, one closed and one open, is not "closed" and
    not "unknown" - it is partly known, which is [Inconclusive], and
    the map shows which part is missing. *)
(** What a requirement names - the thing `record` and the attestations
    call it by. *)
let spec_of (r : requirement) : string =
  match r with Verified_by spec -> spec | Reviewed_by spec -> spec

(** The moment of a proof, as seconds since the epoch. The moments of two
    proofs are compared, and the comparison must not depend on the order
    the files were read in. An absent moment is older than any recorded
    one. *)
let at_of (moment : string option) : float =
  match moment with
  | Some t -> (match float_of_string_opt t with Some v -> v | None -> 0.0)
  | None -> 0.0

(** The state of a requirement closed by an attestation: a proof from
    outside, bound to the subject as it stands. It carries the same
    freshness rules as any other proof. *)
let state_of_attestation (current : binding option) (now : float)
    (a : attestation) : state =
  if expired now a.valid_until then Outdated
  else if a.standing then
    (* A standing word is not about a version of the subject, so the
       subject moving does not expire it. The TERM still does. *)
    state_of_outcome a.outcome
  else
    match current with
    | Some b when b = a.bound_to -> state_of_outcome a.outcome
    | _ -> Outdated

let state_of_requirements (claim : claim) (current : binding option) (now : float)
    (evidence : evidence list) : state =
  (* WHICH KIND OF PROOF MAY CLOSE WHICH KIND OF REQUIREMENT. The hole
     was open in both directions. A VERIFIER requirement names a
     procedure the method could have run itself, so a word from outside
     cannot stand in for it. A REVIEW requirement names a person, and a
     person's word is what it asks for. The exception is a JUDGMENT: it
     has no procedure, the machine is not allowed to decide it, and the
     attestation is the only thing that can close it. *)
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
             | Some (_prev : evidence) -> Some e
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
                 if at_of (Some a.at) >= at_of (Some prev.at) then Some a else Some prev
             | None -> Some a)
           None
    in
    match r with
    | Verified_by _ ->
        if claim.register = Judgment then
          (match latest_attestation with
          | Some a -> state_of_attestation current now a
          | None -> NotCheckable)
        else state_of_evidence current now latest
    | Reviewed_by _ -> (
        match latest_attestation with
        | Some a -> state_of_attestation current now a
        | None -> state_of_evidence current now latest)
  in
  let states = List.map for_requirement claim.requirements in
  (* The refinement of the fold. The fold answers "is anything
     refuted, and is everything known"; the states say WHICH kind of
     not-knowing it is, because the human acts differently in each
     case: nobody looked, we looked and the subject moved, we looked
     and could not tell, or the machine is not the one to decide. *)
  (* THE EMPTY SET IS ITS OWN STATE. [List.for_all f []] is true in
     OCaml, so a claim with no requirements used to fall into the
     HOLDS branch above and read as proven: the project went green with
     no proof of anything. The branch that named the empty case was
     there, and it was DEAD CODE, because it came after the branch
     that swallowed it. *)
  if states = [] then NeverChecked
  else if List.exists (fun s -> s = Refuted) states then Refuted
  else if List.exists (fun s -> s = NotCheckable) states then NotCheckable
  else if List.for_all (fun s -> s = Holds) states then Holds
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

(** The law of A16, over the function that decides it: a proof that
    says "yes" establishes nothing unless the same check was shown able
    to say "no" on the same subject.

    The broken version - one that reads the outcome and ignores the
    control - is offered to this law in the test suite and rejected. *)
let law_verified_needs_a_biting_control
    (state_of' : binding option -> float -> evidence option -> state)
    (e : evidence) =
  if e.outcome <> Verified then true
  else if e.control = Some Falsified then true
  else state_of' (Some e.bound_to) 0.0 (Some e) <> Holds

(** The law of the empty requirement set, and of the kinds of proof.

    Three obligations over the same function, so they are one law: a
    claim is not established unless it can be. A claim with NO
    requirement has nothing to close and was never checked - the broken
    version, which folds an empty list to HOLDS and so made the
    project green with no proof of anything, is offered to this law and
    rejected. A claim with a PROCEDURE and no machine proof is not
    established whatever words it carries: the method could have run
    that procedure itself, and it cannot tell a word from a proof. A
    JUDGMENT with nobody's word is not established either: what should
    be true about meaning is not the machine's to decide. *)
(** The law of the standing word: a fact that is not about a version
    of the code is not expired by the code moving. The aim belongs to a
    person, and that does not stop being true because a file changed.
    The broken version - one that expires a standing word whenever the
    subject moves - is offered to this law and rejected. *)
let law_a_standing_word_survives_the_subject
    (state_of' : binding option -> float -> attestation -> state)
    (a : attestation) =
  not a.standing
  || (state_of' (Some "moved") 0.0 a <> Outdated
     && state_of' (Some "moved") 0.0 a = state_of' None 0.0 a)

let law_an_unestablished_claim_is_not_holding
    (state_of' : claim -> binding option -> float -> evidence list -> state)
    (c : claim) =
  if c.requirements = [] then state_of' c None 0.0 [] = NeverChecked
  else
    let has_procedure =
      List.exists
        (fun (r : requirement) -> match r with Verified_by _ -> true | _ -> false)
        c.requirements
    in
    if has_procedure && c.register <> Judgment then
      state_of' c (Some "digest") 0.0 [] <> Holds
    else if c.register = Judgment && c.attestations = [] then
      state_of' c (Some "digest") 0.0 [] <> Holds
    else true

(** A scope that names nothing is not a subject. Whether it names
    anything in the tree is the adapter's business; this is the part
    that can be stated here. It is stated over the FUNCTION that
    decides, so that a broken implementation can be offered to it: a
    law that cannot be offered a counterexample is a description. *)
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

(** What one outcome costs: an unresolved or refused claim costs one. *)
let cost_of_outcome (o : outcome) : int =
  match o with
  | Verified | Falsified -> 0
  | Unresolved | Refused -> 1

(** The law of the price of uncertainty: an unresolved or refused claim
    costs something, and only an answer is free. Both halves are
    needed. "Answers are free" alone is satisfied by a
    cost function that charges nothing for anything, and that is
    exactly the world the principle forbids: an uncertainty that costs
    nothing makes "I do not know" cheaper than checking. *)
let law_only_answers_are_free (cost' : outcome -> int) =
  List.for_all (fun o -> cost' o = 0) [ Verified; Falsified ]
  && List.for_all (fun o -> cost' o > 0) [ Unresolved; Refused ]

(** The uncertainty a claim costs. A plan is not an uncertainty: a
    promise about code that is not there yet is work to do, and it is
    resolved by writing the code. So it costs nothing, until there is
    code. Whether code exists is not the core's business - the core
    does not see the tree - so the coverage comes from outside. *)
let cost_of_claim ~covers (c : claim) (s : state) : int =
  match s with
  | Holds | Refuted | Accepted -> 0
  | _ -> if covers c then 1 else 0

(** The law of the budget, stated over the function that decides, so that
    a broken one - one that charges plans, or one that charges nothing -
    can be offered to it and rejected. *)
let law_the_budget_prices_uncertainty
    (cost : covers:(claim -> bool) -> claim -> state -> int)
    (covers : claim -> bool) (c : claim) (s : state) =
  let answered = s = Holds || s = Refuted || s = Accepted in
  if answered then cost ~covers c s = 0
  else if covers c then cost ~covers c s = 1
  else cost ~covers c s = 0
