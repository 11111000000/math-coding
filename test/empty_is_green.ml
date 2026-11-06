(* The emptiness check.

   WHAT IT PROVES. A project with no claims is green, and says so
   instead of failing or reporting the absence as a gap. This is the
   rule that makes adoption trivial: a repository that has not yet
   adopted the method can run it and get an honest answer, so the first
   use costs nothing.

   THE NEGATIVE CONTROL. A check that cannot fail proves nothing, so
   this test also asserts the opposite cases: a falsified claim is
   red, an unresolved one is unknown, and a refusal does not turn the
   set green. Without those assertions, a broken aggregate that always
   returned Green would pass this file.

   THE NEGATIVE CONTROL, AND THE CORRECTION. A refusal used to count
   as green here. It does not any more, and the reason is the
   philosophy's own words: a green result means every live claim has a
   fresh, bound, executed proof, and a refused claim has no executed
   proof at all. The test below pins the corrected behaviour, so the
   contradiction cannot come back quietly.

   THE NEGATIVE CONTROL IS THE WHOLE POINT: it is the difference
   between a check and a comment. *)

open Domain
open Verdict

let claim subject =
  {
    id = "sample";
    subject = { text = subject; scope = [ "lib/" ] };
    requirements = [ Domain.Verified_by "true" ];
    falsifier = "the sample stops holding";
    register = Fact;
    accepted = None;
  }

let checked subject outcome =
  { claim = claim subject; requirement = Domain.Verified_by "true"; outcome; bound_to = "digest"; producer = "the method"; reason = None }

let check_empty_is_green () =
  (* The rule under test. *)
  assert (aggregate [] = Green);
  assert (verdict_to_exit (aggregate []) = 0);
  assert (route [] = []);

  (* The negative control: the same aggregate on claims that are not
     empty. If any of these is Green, the aggregate is broken. *)
  assert (aggregate [ checked "a" Falsified ] = Red);
  assert (aggregate [ checked "a" Unresolved ] = Unknown);
  assert (aggregate [ checked "a" Verified ] = Green);

  (* A refusal is a legitimate result: it is not a failure, and it
     reaches the human. But it is not a proof either, so it cannot make
     the set green. *)
  assert (aggregate [ checked "a" Refused ] = Unknown);
  assert (List.length (route [ checked "a" Refused ]) = 1);

  (* Severity is ordered: one falsified claim among verified ones is
     still red, and one unresolved among verified ones is still
     unknown. *)
  assert
    (aggregate [ checked "a" Verified; checked "b" Falsified ] = Red);
  assert
    (aggregate [ checked "a" Verified; checked "b" Unresolved ] = Unknown);

  (* Exit codes are distinct: "wrong" and "we could not tell" must not
     share a code. *)
  assert (verdict_to_exit Green = 0);
  assert (verdict_to_exit Red = 1);
  assert (verdict_to_exit Unknown = 3)

let () =
  check_empty_is_green ();
  print_endline "empty-is-green: PASS"
