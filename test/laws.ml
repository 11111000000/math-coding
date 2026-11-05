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

(* --- the claims the control needs ---------------------------------- *)

let sample_claim =
  {
    id = "sample";
    subject = { text = "a sample subject"; scope = [ "lib/" ] };
    check = "true";
    falsifier = "the sample stops holding";
    register = Fact;
  }

let sample_evidence outcome bound_to =
  { claim = sample_claim; outcome; bound_to; reason = None }

(* --- the proof ------------------------------------------------------ *)

let check_laws_hold () =
  (* The whole domain, not a sample of it. *)
  assert (laws_hold ());

  (* Each law, instantiated with the real implementation. *)
  assert (law_vacancy_is_green aggregate);
  assert (law_outdated_is_never_verified state_of (sample_evidence Verified "old")
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
  assert (state_of (Some "digest-of-today") (Some outdated) = Outdated);
  assert
    (state_outdated_as_verified (Some "digest-of-today") (Some outdated)
    = Holds);
  assert
    (not
      (law_outdated_is_never_verified state_outdated_as_verified outdated
         (Some "digest-of-today")));

  (* Vacancy. *)
  assert (not (law_vacancy_is_green aggregate_not_vacant))

let () =
  check_laws_hold ();
  check_negative_controls ();
  print_endline "laws: PASS"
