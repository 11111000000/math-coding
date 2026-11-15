open Helpers

(* The development shell greets its user on stdout. That is harmless for a
   person and fatal for a machine: `nix develop -c mathc map --json` must
   print nothing but the map, otherwise every consumer of the machine
   interface has to guess where the JSON starts. The notice belongs to
   stderr, and this test keeps it there. *)

let () =
  (* The binary lives in the build tree; the repository root is where the
     flake lives, so the shell has to be entered there. `nix develop -c`
     takes the command as separate words, so the arguments of the method
     go through a shell of their own. *)
  let root = in_repo "." in
  let inner =
    Printf.sprintf "%s --root %s map --json"
      (Filename.quote (binary ())) (Filename.quote root)
  in
  let command = Printf.sprintf "nix develop -c sh -c %s" (Filename.quote inner) in
  let result = Process.run ~timeout:300.0 ~root command in
  check "the map through the development shell runs" (result.code = 0 || result.code = 3);
  check "the development shell keeps stdout free of prose"
    (not (contains result.stdout "math-coding 5 dev shell"));
  check "the development shell keeps stdout free of any prose"
    (not (contains result.stdout "dune:"));
  check "the map through the development shell is still a map"
    (contains result.stdout "\"schema_version\"");
  check "the notice still reaches the person on stderr"
    (contains result.stderr "math-coding 5 dev shell");
  print_endline "shell-output: PASS"
