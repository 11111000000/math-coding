(* The emptiness check.

   WHAT IT PROVES. A project with no claims is green, and says so
   instead of failing or reporting the absence as a gap. This is the
   rule that makes adoption trivial: a repository that has not yet
   adopted the method can run it and get an honest answer, so the first
   use costs nothing.

   THE NEGATIVE CONTROL. A check that cannot fail proves nothing, so
   this test also asserts the opposite cases: a falsified claim is
   red, an unresolved one is unknown, and a refusal does not turn the
   set red. Without those assertions, a broken aggregate that always
   returned Green would pass this file.

   The negative control is the whole point: it is the difference
   between a check and a comment. *)

let claim subject = { Verdict.subject; check = "a check that could fail"; falsifier = "its own failure" }

let checked subject outcome = { Verdict.claim = claim subject; outcome }

let check_empty_is_green () =
  (* The rule under test. *)
  assert (Verdict.aggregate [] = Verdict.Green);
  assert (Verdict.verdict_to_exit (Verdict.aggregate []) = 0);
  assert (Verdict.route [] = []);

  (* The negative control: the same aggregate on claims that are not
     empty. If any of these is Green, the aggregate is broken. *)
  assert (Verdict.aggregate [ checked "a" Verdict.Falsified ] = Verdict.Red);
  assert (Verdict.aggregate [ checked "a" Verdict.Unresolved ] = Verdict.Unknown);
  assert (Verdict.aggregate [ checked "a" Verdict.Verified ] = Verdict.Green);

  (* A refusal is a legitimate outcome: it does not turn the set red,
     and it does reach the human. *)
  assert (Verdict.aggregate [ checked "a" Verdict.Refused ] = Verdict.Green);
  assert (List.length (Verdict.route [ checked "a" Verdict.Refused ]) = 1);

  (* Severity is ordered: one falsified claim among verified ones is
     still red, and one unresolved among verified ones is still
     unknown. *)
  assert
    (Verdict.aggregate [ checked "a" Verdict.Verified; checked "b" Verdict.Falsified ]
    = Verdict.Red);
  assert
    (Verdict.aggregate [ checked "a" Verdict.Verified; checked "b" Verdict.Unresolved ]
    = Verdict.Unknown);

  (* Exit codes are distinct: "wrong" and "we could not tell" must not
     share a code. *)
  assert (Verdict.verdict_to_exit Verdict.Green = 0);
  assert (Verdict.verdict_to_exit Verdict.Red = 1);
  assert (Verdict.verdict_to_exit Verdict.Unknown = 3)

let () =
  check_empty_is_green ();
  print_endline "empty-is-green: PASS"
