(* The proof of the laws, and the proof that the proof has teeth.

   THE PROOF. The verdict type has three elements, so the laws of
   combination are checked over the whole domain: nine pairs, twenty-seven
   triples, and the empty sequence. Not a sample - the whole thing.

   THE NEGATIVE CONTROL. A law that cannot fail is a comment, and a
   proof that cannot fail is worse than no proof: it is a thing that
   looks like evidence. So every law below is instantiated with a
   BROKEN version of the function it constrains, and the law is
   required to REJECT it. A law that accepted its own counterexample
   would fail this file.

   This is why the laws in the library are stated over a function
   rather than over the implementation: only then can a broken
   implementation be offered to them at all.

   These controls run in every build. The library was additionally
   mutated by hand - each law broken in the source, the suite watched
   to see it go red, and the source restored. Both directions are
   needed: the copy proves the law discriminates, the hand mutation
   proves the library is the thing the law talks about. *)

open Domain
open Verdict

(* --- the broken versions, one per law ------------------------------- *)

(* Commutative, but not: the right argument wins. *)
let combine_right_biased a b =
  match a with Red -> Red | Unknown -> b | Green -> b

(* Associative, but not. Subtraction on the three verdicts is the
   standard counterexample: (a - b) - c differs from a - (b - c). *)
let rank = function Green -> 0 | Unknown -> 1 | Red -> 2
let unrank = function 0 -> Green | 1 -> Unknown | _ -> Red
let combine_subtractive a b = unrank ((rank a - rank b + 3) mod 3)

(* Green is no longer the unit: combining with it can change the other. *)
let combine_not_unit a b =
  match a with Green -> (match b with Red -> Red | _ -> Green) | _ -> combine a b

(* Red is no longer absorbing. *)
let combine_not_absorbing a b = match a with Red -> b | _ -> combine a b

(* An outdated claim reads as verified - the bug the binding exists to
   stop. *)
let state_outdated_as_verified (_current : binding option) (_now : float)
    (_e : evidence option) = Holds

(* The empty result is no longer green: adoption would cost something
   before it had measured anything. *)
let aggregate_not_vacant (_results : evidence list) = Unknown

(* A judgment may be verified after all. The whole point of the
   register is that what should be true about meaning is not the
   machine's to decide. *)
let apply_register_lets_judgments_through (_r : register) (o : outcome) = o

(* A judgment may be refuted after all. A failed procedure is a fact
   about the procedure, not about what should be true about meaning. *)
let apply_register_refutes_judgments (_r : register) (o : outcome) = o

(* Uncertainty is free. Then "I do not know" is cheaper than checking,
   and the method stops being worth anything. *)
let cost_of_outcome_free (_o : outcome) = 0

(* An acceptance covers everything, including a finding. Then a person
   can bury a refuted claim by accepting it, which is the opposite of
   what an acceptance is for. *)
let apply_acceptance_accepts_anything (_c : claim) (_s : state) = Accepted

(* A scope that names nothing is accepted as a subject. Then a claim
   about nothing could be declared, bound and run - the door the third
   version's wildcard came through. *)
let scope_never_empty (_s : scope) = true

(* A proof whose term is over still reads as verified. Then a proof
   nobody may rely on any more keeps a claim standing - and the
   binding cannot catch it, because the content is exactly the same. *)
let state_ignoring_the_term (_current : binding option) (_now : float)
    (_e : evidence option) = Holds

(* A proof that says "yes" is taken as a proof, whether or not the same
   check was ever shown able to say "no". This is what the method did
   before A16 had a carrier: the control was read by nobody, so a
   claim with no control at all read exactly like a claim whose
   control had bitten - and the map said "proven able to fail" about a
   control that had never run. *)
let state_ignoring_the_control (current : binding option) (now : float)
    (e : evidence option) =
  match e with
  | Some x -> (
      match current with
      | Some b when x.bound_to = b ->
          if Verdict.expired now x.valid_until then Outdated
          else Verdict.state_of_outcome x.outcome
      | _ -> Outdated)
  | None -> NeverChecked

(* A claim with no requirements reads as proven. The fold of an empty
   list is HOLDS, because [List.for_all] over nothing is true, and the
   project went green with no proof of anything. *)
let state_of_requirements_folding_empty_to_holds (c : claim) (current : binding option)
    (now : float) (evidence : evidence list) =
  if c.requirements = [] then Holds
  else Verdict.state_of_requirements c current now evidence

(* A word from outside closes a procedure: the method could have run
   that command itself, and it cannot tell a word from a proof. *)
let state_of_requirements_letting_a_word_close (c : claim) (current : binding option)
    (now : float) (evidence : evidence list) =
  if c.attestations <> [] then Holds
  else Verdict.state_of_requirements c current now evidence

(* --- the claims the control needs ---------------------------------- *)

let sample_claim =
  {
    id = "sample";
    subject = { text = "a sample subject"; scope = [ "lib/" ] };
    requirements = [ Domain.Verified_by "true" ];
    falsifier = "the sample stops holding";
    register = Fact;
    accepted = None; attestations = []; control = None;
  }

let sample_evidence outcome bound_to =
  { claim = sample_claim; requirement = Domain.Verified_by "true"; outcome; bound_to; producer = "the method"; reason = None; at_commit = None; at = None; valid_until = None; control = None }

(* The same proof, with what the negative control said about it. A
   proof that says "yes" and a control that BIT are different facts
   about the same check, and only the second makes the first a proof. *)
let sample_evidence_with_control outcome control =
  { (sample_evidence outcome "digest") with control }

(* The domain of the verdicts, written out so that the proof does not
   depend on the type staying this way. It lives HERE and not in the
   core: the core holds the laws, and the proof is the check's job. The
   core has a ceiling on its size, and the answer to "the core outgrew
   its ceiling" is to move code out of the core, not to move the
   ceiling. *)
let verdict_domain = [ Green; Red; Unknown ]

(* Every law, checked over the whole domain. Not a sample: the domain
   has three elements, so the pairs are nine and the triples are
   twenty-seven, and all of them are checked.

   A law that cannot be checked over the whole domain is a law that is
   being trusted rather than proved, and this method has been burned by
   exactly that. *)
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
    List.for_all (fun o -> law_only_answers_are_free cost_of_outcome) outcomes
  in
  (* THE LAWS THAT NEED A CLAIM AND A PROOF. The verdict algebra is
     proved over its whole domain; these are proved over the claims
     and the evidence they speak about, and they are the ones that had
     no carrier at all - the control was read by nobody, and the empty
     requirement set was swallowed by a branch above. *)
  let control_law =
    (* A proof that says yes, with a control that bit: it holds. *)
    law_verified_needs_a_biting_control Verdict.state_of_evidence
      (sample_evidence_with_control Verified (Some Falsified))
    (* A proof that says yes, with no control at all, or with one that
       did not bite: it does not. *)
    && law_verified_needs_a_biting_control Verdict.state_of_evidence
         (sample_evidence_with_control Verified None)
    && law_verified_needs_a_biting_control Verdict.state_of_evidence
         (sample_evidence_with_control Verified (Some Unresolved))
  in
  let kinds_law =
    law_an_unestablished_claim_is_not_holding Verdict.state_of_requirements
      { sample_claim with requirements = [] }
    && law_an_unestablished_claim_is_not_holding Verdict.state_of_requirements
         sample_claim
    && law_an_unestablished_claim_is_not_holding Verdict.state_of_requirements
         { sample_claim with register = Judgment }
  in
  commutative && associative && unit && absorbing && law_order combine
  && law_exit_codes_distinct () && law_vacancy_is_green aggregate && judgment
  && price && control_law && kinds_law

(* --- the proof ------------------------------------------------------ *)

let check_laws_hold () =
  (* The whole domain, not a sample of it. *)
  assert (laws_hold ());

  (* Each law, instantiated with the real implementation. *)
  assert (law_vacancy_is_green aggregate);
  assert (law_judgment_is_never_verified apply_register Judgment Verified);
  assert (law_only_answers_are_free cost_of_outcome);
  assert (law_outdated_is_never_verified Verdict.state_of_evidence (sample_evidence Verified "old")
           (Some "new"))

let check_negative_controls () =
  (* Each law must REJECT the broken version of the function it
     constrains. If any of these accepts, the law is not a law. *)

  (* Commutativity. The broken version is right-biased, so Red on the
     left and Unknown on the right must disagree with the reverse. *)
  assert (
    not
      (List.for_all
         (fun a ->
           List.for_all
             (fun b -> law_commutative combine_right_biased a b)
             verdict_domain)
         verdict_domain));

  (* Associativity. The broken version subtracts, so
     ((Green Green) Unknown) and (Green (Green Unknown)) differ. *)
  assert (
    not
      (List.for_all
         (fun a ->
           List.for_all
             (fun b ->
               List.for_all
                 (fun c -> law_associative combine_subtractive a b c)
                 verdict_domain)
             verdict_domain)
         verdict_domain));

  (* The unit. *)
  assert (
    not
      (List.for_all (fun a -> law_unit combine_not_unit a) verdict_domain));

  (* The absorbing element. *)
  assert (
    not
      (List.for_all (fun a -> law_absorbing combine_not_absorbing a) verdict_domain));

  (* The order. *)
  assert (not (law_order combine_subtractive));

  (* An outdated claim is never verified. The evidence below is bound to
     a subject that has since moved, and the broken state function calls
     it verified anyway - so the law rejects that function. *)
  let outdated = sample_evidence Verified "digest-of-yesterday" in
  assert (Verdict.state_of_evidence (Some "digest-of-today") 0.0 (Some outdated) = Outdated);
  assert
    (state_outdated_as_verified (Some "digest-of-today") 0.0 (Some outdated)
    = Holds);
  assert
    (not
      (law_outdated_is_never_verified state_outdated_as_verified outdated
         (Some "digest-of-today")));

  (* Vacancy. *)
  assert (not (law_vacancy_is_green aggregate_not_vacant));

  (* The register. A judgment whose check says yes must not read as
     verified; the broken version lets it through. *)
  assert (law_judgment_is_never_verified apply_register Judgment Verified);
  assert
    (not
      (law_judgment_is_never_verified apply_register_lets_judgments_through Judgment
         Verified));
  (* And a fact whose check says yes is verified - the rule must not
     swallow the cases it should not touch. *)
  assert (law_judgment_is_never_verified apply_register Fact Verified);

  (* A judgment is not refuted either: a failed procedure is a fact
     about the procedure. *)
  assert (law_judgment_is_never_verified apply_register Judgment Falsified);
  assert
    (not
      (law_judgment_is_never_verified apply_register_refutes_judgments Judgment
         Falsified));
  (* But a gap in the evidence stays a gap, whoever owns the claim. *)
  assert (law_judgment_is_never_verified apply_register Judgment Unresolved);

  (* The price of uncertainty. Only an answer is free. *)
  assert (law_only_answers_are_free cost_of_outcome);
  assert (not (law_only_answers_are_free cost_of_outcome_free));

  (* The acceptance covers uncertainty and never an answer. *)
  let accepted_claim = { sample_claim with accepted = Some ("a person", "reason") } in
  let refuted = Verdict.state_of_evidence (Some "digest") 0.0 (Some (sample_evidence Falsified "digest")) in
  assert (refuted = Domain.Refuted);
  assert
    (law_acceptance_never_changes_an_answer Verdict.apply_acceptance accepted_claim
       refuted);
  assert
    (not
      (law_acceptance_never_changes_an_answer apply_acceptance_accepts_anything
         accepted_claim refuted));
  (* And it does cover an uncertainty. *)
  let unknown =
    Verdict.state_of_evidence (Some "digest") 0.0 (Some (sample_evidence Unresolved "digest"))
  in
  assert (unknown = Domain.Inconclusive);
  assert
    (law_acceptance_never_changes_an_answer Verdict.apply_acceptance accepted_claim
       unknown);

  (* A scope that names nothing is not a subject. This law was in the
     core from the start and had NO control: it was stated as a bare
     predicate over a scope, so no broken implementation could be
     offered to it, and nothing ever tried to break it. A law with no
     counterexample offered to it is a description of the code, not a
     law about it. The law is now stated over the function that
     decides, like every other one. *)
  assert (law_no_vacant_subject (fun _ -> true) [ "lib/" ]);
  assert (law_no_vacant_subject (fun _ -> false) []);
  assert (not (law_no_vacant_subject scope_never_empty []));

  (* The law of the budget. A plan is free, an uncertainty is priced,
     and an answer is free - and the law has to reject all three ways
     of getting it wrong.

     The broken ones are named here because a law that cannot be
     offered a counterexample is a description of the code. *)
  let covers_nothing _ = false in
  let covers_something _ = true in
  (* The real implementation: a plan about code that is not there yet
     costs nothing, and the same claim costs one once there is code. *)
  assert
    (law_the_budget_prices_uncertainty cost_of_claim covers_nothing sample_claim
       NeverChecked);
  assert
    (law_the_budget_prices_uncertainty cost_of_claim covers_something sample_claim
       NeverChecked);
  assert
    (law_the_budget_prices_uncertainty cost_of_claim covers_something sample_claim
       Holds);
  (* A budget that charges plans makes every promise expensive before
     there is anything to check. *)
  assert
    (not
       (law_the_budget_prices_uncertainty (fun ~covers:_ _ _ -> 1) covers_nothing sample_claim
          NeverChecked));
  (* A budget that charges nothing makes "I do not know" free, which is
     the thing the budget exists to prevent. *)
  assert
    (not
       (law_the_budget_prices_uncertainty (fun ~covers:_ _ _ -> 0) covers_something sample_claim
          NeverChecked));
  (* A budget that charges answers is no budget at all. *)
  assert
    (not
       (law_the_budget_prices_uncertainty (fun ~covers:_ _ _ -> 1) covers_something sample_claim
          Holds));

  (* The term of a proof. A proof whose term is over cannot read as
     verified - even when the content is exactly the one it was
     produced against, which is the case the binding cannot see. *)
  let dated =
    { (sample_evidence_with_control Verified (Some Falsified)) with valid_until = Some "100" }
  in
  (* Before the term, it holds. *)
  assert (Verdict.state_of_evidence (Some "digest") 50.0 (Some dated) = Domain.Holds);
  (* After the term, it does not - and it does not read as anything
     else either: the proof simply stops counting. *)
  assert (Verdict.state_of_evidence (Some "digest") 150.0 (Some dated) = Domain.Outdated);
  (* The law accepts the real function... *)
  assert (law_expired_is_never_verified Verdict.state_of_evidence dated (Some "digest"));
  (* ...and REJECTS the broken one, which ignores the term. *)
  assert
    (not
       (law_expired_is_never_verified state_ignoring_the_term dated (Some "digest")));

  (* THE CONTROL. A proof that says "yes" is a proof only if the same
     check was shown able to say "no" on the same subject. This is the
     carrier of A16, and it had none: the control was read by nobody,
     the CLI rewrote the outcome imperatively, and the map reported a
     DECLARED control as a control that had bitten. *)
  let biting = sample_evidence_with_control Verified (Some Falsified) in
  let unchecked = sample_evidence_with_control Verified None in
  let unbiting = sample_evidence_with_control Verified (Some Unresolved) in
  (* The law accepts the real function... *)
  assert (law_verified_needs_a_biting_control Verdict.state_of_evidence biting);
  assert (law_verified_needs_a_biting_control Verdict.state_of_evidence unchecked);
  assert (law_verified_needs_a_biting_control Verdict.state_of_evidence unbiting);
  (* ...and REJECTS the broken one, which reads the outcome and ignores
     the control: that is the implementation the method had. *)
  assert
    (not (law_verified_needs_a_biting_control state_ignoring_the_control unchecked));
  (* And the real function says so: a proof with no control is not
     established, and a proof with a control that bit is. *)
  assert (Verdict.state_of_evidence (Some "digest") 0.0 (Some biting) = Domain.Holds);
  assert (Verdict.state_of_evidence (Some "digest") 0.0 (Some unchecked) = Domain.Inconclusive);
  assert (Verdict.state_of_evidence (Some "digest") 0.0 (Some unbiting) = Domain.Inconclusive);

  (* THE KINDS OF PROOF. A claim with no requirement has nothing to
     close; a claim with a procedure is not closed by a word; a
     judgment is nobody's but a person's. *)
  let empty = { sample_claim with requirements = [] } in
  let judgment = { sample_claim with register = Judgment } in
  (* The law accepts the real function... *)
  assert (law_an_unestablished_claim_is_not_holding Verdict.state_of_requirements empty);
  assert (law_an_unestablished_claim_is_not_holding Verdict.state_of_requirements sample_claim);
  assert (law_an_unestablished_claim_is_not_holding Verdict.state_of_requirements judgment);
  (* ...and REJECTS the broken ones: the empty fold that reads as
     proven, and the one that lets a word close a procedure. *)
  assert
    (not
       (law_an_unestablished_claim_is_not_holding
          state_of_requirements_folding_empty_to_holds empty));
  assert
    (not
       (law_an_unestablished_claim_is_not_holding
          state_of_requirements_letting_a_word_close
          { sample_claim with attestations = [ { requirement = "true"; who = "me"; outcome = Verified; reason = None; bound_to = "digest"; at = "1"; valid_until = None } ] }))

(** Two claims often share one check - the same test suite verifies
    several rules - and their evidence must not answer for each other.
    The bug this pins was found by running the method, not by reading
    it: the second claim of a pair turned unknown with no visible
    cause, because the evidence of one was matched to the other by
    the requirement alone. *)
let check_evidence_does_not_crosstalk () =
  let shared = Domain.Verified_by "the same command" in
  let other = { sample_claim with id = "another"; subject = { text = "another"; scope = [ "lib/" ] } } in
  let claim_a = { sample_claim with id = "a"; requirements = [ shared ] } in
  let claim_b = { other with requirements = [ shared ] } in
  let digest_a = "digest-a" and digest_b = "digest-b" in
  let ev_a =
    { claim = claim_a; requirement = shared; outcome = Verified; bound_to = digest_a; producer = "the method"; reason = None; at_commit = None; at = None; valid_until = None; control = Some Falsified }
  in
  let ev_b =
    { claim = claim_b; requirement = shared; outcome = Falsified; bound_to = digest_b; producer = "the method"; reason = None; at_commit = None; at = None; valid_until = None; control = None }
  in
  let evidence = [ ev_a; ev_b ] in
  (* Each claim sees only its own evidence. *)
  assert (Verdict.state_of_requirements claim_a (Some digest_a) 0.0 evidence = Domain.Holds);
  assert (Verdict.state_of_requirements claim_b (Some digest_b) 0.0 evidence = Domain.Refuted);
  (* And a claim whose subject moved sees neither as its own. *)
  assert (Verdict.state_of_requirements claim_a (Some "moved") 0.0 evidence = Domain.Outdated)

let () =
  check_laws_hold ();
  check_negative_controls ();
  check_evidence_does_not_crosstalk ();
  print_endline "laws: PASS"
