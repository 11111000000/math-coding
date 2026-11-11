open Helpers

let () =
  let scope = [ "lib/"; "format/"; "bin/"; "test/repository_lints.ml" ] in
  Isolated_run.with_copy (in_repo "") (fun root ->
      let before = Git.digest_of_scope root ~scope in
      let mutation = Process.run ~root "printf 'let broken = 0\\n' > lib/without_interface.ml" in
      check "the lint control executes" (mutation.code = 0);
      let after = Git.digest_of_scope root ~scope in
      check "the lint control reaches its subject" (before <> after);
      let result = Process.run ~timeout:90.0 ~root "dune build --root . test/repository_lints.exe && _build/default/test/repository_lints.exe" in
      if result.code <> 2 then Printf.eprintf "unexpected lint result %d\n%s%s" result.code result.stdout result.stderr;
      check "a module without an interface is rejected" (result.code = 2));
  print_endline "repository-control: PASS"
