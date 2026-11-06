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
let state_outdated_as_verified (_current : binding option) (_e : evidence option) =
  Holds

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

(* --- the claims the control needs ---------------------------------- *)

let sample_claim =
  {
    id = "sample";
    subject = { text = "a sample subject"; scope = [ "lib/" ] };
    requirements = [ Domain.Verified_by "true" ];
    falsifier = "the sample stops holding";
    register = Fact;
    accepted = None;
  }

let sample_evidence outcome bound_to =
  { claim = sample_claim; requirement = Domain.Verified_by "true"; outcome; bound_to; producer = "the method"; reason = None }

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
  assert (Verdict.state_of_evidence (Some "digest-of-today") (Some outdated) = Outdated);
  assert
    (state_outdated_as_verified (Some "digest-of-today") (Some outdated)
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
  let refuted = Verdict.state_of_evidence (Some "digest") (Some (sample_evidence Falsified "digest")) in
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
    Verdict.state_of_evidence (Some "digest") (Some (sample_evidence Unresolved "digest"))
  in
  assert (unknown = Domain.Inconclusive);
  assert
    (law_acceptance_never_changes_an_answer Verdict.apply_acceptance accepted_claim
       unknown)

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
    { claim = claim_a; requirement = shared; outcome = Verified; bound_to = digest_a; producer = "the method"; reason = None }
  in
  let ev_b =
    { claim = claim_b; requirement = shared; outcome = Falsified; bound_to = digest_b; producer = "the method"; reason = None }
  in
  let evidence = [ ev_a; ev_b ] in
  (* Each claim sees only its own evidence. *)
  assert (Verdict.state_of_requirements claim_a (Some digest_a) evidence = Domain.Holds);
  assert (Verdict.state_of_requirements claim_b (Some digest_b) evidence = Domain.Refuted);
  (* And a claim whose subject moved sees neither as its own. *)
  assert (Verdict.state_of_requirements claim_a (Some "moved") evidence = Domain.Outdated)

let () =
  check_laws_hold ();
  check_negative_controls ();
  check_evidence_does_not_crosstalk ();
  print_endline "laws: PASS"
