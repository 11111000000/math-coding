(* The subject is whole or it is not.

   THE DEFECT THIS PINS. The adapter used to hash the paths of a scope
   that it could resolve and drop the ones it could not. A scope of one
   real directory and one path that is not in the tree therefore
   produced a digest, and a claim on it came out verified, holds and
   green - and the part of the subject that was missing was invisible.
   The method exists to catch exactly this, so the method's own adapter
   must not have it.

   THE NEGATIVE CONTROL. The broken adapter is written out here, in
   full, and the law is required to REJECT it. A test that only checks
   the fixed adapter cannot tell a check from a description: it would
   pass just as well against the broken one. The control is what makes
   the test a check.

   THE REPOSITORY ITSELF IS NOT THE SUBJECT. The test builds a small
   git repository in a temporary directory, because a test that ran
   against the method's own tree would pass or fail with the method's
   own commits, and its failure would say nothing about the adapter. *)

open Domain
open Verdict

let run (cmd : string) =
  let code = Sys.command cmd in
  if code <> 0 then
    failwith (Printf.sprintf "the test's own setup failed: %s (exit %d)" cmd code)

(** A temporary directory holding a git repository with one committed
    file. The file is what a scope can name; the other path a scope can
    name is one that is not there. *)
let with_repository (f : string -> unit) =
  let path = Filename.temp_file "mathc-scope" ".dir" in
  Sys.remove path;
  Unix.mkdir path 0o755;
  let root = path in
  run (Printf.sprintf "git -C %s init -q ." (Filename.quote root));
  let file = Filename.concat root "subject.txt" in
  let channel = open_out file in
  output_string channel "the subject\n";
  close_out channel;
  run (Printf.sprintf "git -C %s add -A ." (Filename.quote root));
  run
    (Printf.sprintf
       "git -C %s -c user.email=test@example -c user.name=test commit -qm init ."
       (Filename.quote root));
  (try f root with e ->
     (* The directory is left in place when the test fails: a test that
        cleans up after itself destroys the evidence of what went
        wrong. *)
     raise e)

let exists root path = Git.object_id root path <> None

(* The broken adapter: the one this fix replaces. It hashes the paths it
   found and drops the ones it did not, so a subject with a hole in it
   gets a digest of the part that is there. *)
let digest_keeping_only_what_it_finds (root : string) (scope : Domain.scope) =
  let lines =
    List.filter_map
      (fun prefix ->
        match Git.object_id root prefix with
        | None -> None
        | Some oid -> Some (prefix ^ " " ^ oid))
      scope
  in
  if lines = [] then None
  else Some (Git.hash_content root (String.concat "\n" (List.sort compare lines) ^ "\n"))

let check_the_subject_is_whole () =
  with_repository (fun root ->
      let whole = [ "subject.txt" ] in
      let holed = [ "subject.txt"; "missing/" ] in
      (* The whole subject has a digest and exists. *)
      assert (Git.digest_of_scope root whole <> None);
      assert (Git.scope_exists root whole);
      (* The holed one has none: not even a digest of the part that IS
         there, because a digest of half a subject says nothing about
         the other half. *)
      assert (Git.digest_of_scope root holed = None);
      assert (not (Git.scope_exists root holed));
      (* And the empty scope names nothing at all. *)
      assert (Git.digest_of_scope root [] = None);
      assert (not (Git.scope_exists root [])))

let check_the_negative_control () =
  with_repository (fun root ->
      let whole = [ "subject.txt" ] in
      let holed = [ "subject.txt"; "missing/" ] in
      (* The law accepts the fixed adapter. *)
      assert (law_no_partial_subject (Git.digest_of_scope root) (exists root) whole);
      (* And it REJECTS the broken one: the broken adapter produces a
         digest for a subject with a hole in it, and the law says such a
         subject has no digest. *)
      assert
        (not
           (law_no_partial_subject (digest_keeping_only_what_it_finds root) (exists root)
              holed));
      (* The broken adapter really does produce that digest - otherwise
         the control would pass for the wrong reason, and a control that
         passes for the wrong reason is a comment. *)
      assert (digest_keeping_only_what_it_finds root holed <> None);
      (* And the broken adapter is wrong about the whole subject too: it
         agrees with the fixed one there, which is why the control has
         to be about the holed one. *)
      assert
        (law_no_partial_subject (digest_keeping_only_what_it_finds root) (exists root)
           whole))

let () =
  check_the_subject_is_whole ();
  check_the_negative_control ();
  print_endline "adapter-scope: PASS"
