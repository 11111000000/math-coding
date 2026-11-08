(* The paths, and their boundaries.

   A claim is about a place in the tree, so the paths it names have to
   mean what they say. The failure mode is quiet: "library/" is not
   inside "lib/", but a comparison on the letters alone says it is,
   and the claim binds to the wrong files. Nothing would look wrong.

   THE NEGATIVE CONTROL. Each case below is one that a comparison on
   letters alone gets wrong. A path check that cannot fail is a check
   that has already failed, silently, somewhere else. *)

open Git

let check_boundaries () =
  (* A directory contains itself, and its contents. *)
  assert (path_contains ~dir:"lib/" ~path:"lib/");
  assert (path_contains ~dir:"lib" ~path:"lib");
  assert (path_contains ~dir:"lib/" ~path:"lib/verdict.ml");
  assert (path_contains ~dir:"lib" ~path:"lib/verdict.ml");
  assert (path_contains ~dir:"lib/" ~path:"lib/deep/nested/file.ml");

  (* And a directory does not contain its siblings, however similar
     the names. This is the case a letter-wise comparison gets
     wrong. *)
  assert (not (path_contains ~dir:"lib/" ~path:"library/"));
  assert (not (path_contains ~dir:"lib" ~path:"library/x.ml"));
  assert (not (path_contains ~dir:"test/" ~path:"tests/x.ml"));
  assert (not (path_contains ~dir:"bin/" ~path:"binaries/x.ml"));

  (* Nor its parent, nor a file that merely starts with the same
     letters. *)
  assert (not (path_contains ~dir:"lib/" ~path:"lib.ml"));
  assert (not (path_contains ~dir:"lib/" ~path:"other/lib/x.ml"));

  (* A file can be inside a scope that names it. *)
  assert (path_contains ~dir:"spec.json" ~path:"spec.json")

let () =
  check_boundaries ();
  print_endline "paths: PASS"
