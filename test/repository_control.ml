open Helpers

let () =
  let scope = [ "lib/"; "format/"; "bin/"; "test/repository_lints.ml" ] in
  (match Isolated_run.with_copy (in_repo "") (fun root ->
      let before = Git.digest_of_scope root ~scope in
      let mutation = Process.run ~root "printf 'let broken = 0\\n' > lib/without_interface.ml" in
      check "the lint control executes" (mutation.code = 0);
      let after = Git.digest_of_scope root ~scope in
      check "the lint control reaches its subject" (before <> after);
      let result = Process.run ~timeout:90.0 ~root "dune build --root . test/repository_lints.exe && _build/default/test/repository_lints.exe" in
      if result.code <> 2 then Printf.eprintf "unexpected lint result %d\n%s%s" result.code result.stdout result.stderr;
      check "a module without an interface is rejected" (result.code = 2)) with
  | Ok () -> ()
  | Error error -> failwith error);
  print_endline "repository-control: PASS"

let () =
  let scope = [ "lib/" ] in
  (match Isolated_run.with_copy (in_repo "") (fun root ->
      let before = Git.digest_of_scope root ~scope in
      let mutation =
        Process.run ~root
          "printf 'val x : int\\n' > lib/long_module.mli && printf 'let x = 0\\n' > lib/long_module.ml && for i in $(seq 1 300); do printf 'let v%d = %d\\n' $i $i >> lib/long_module.ml; done"
      in
      check "the size control executes" (mutation.code = 0);
      let after = Git.digest_of_scope root ~scope in
      check "the size control reaches its subject" (before <> after);
      let result = Process.run ~timeout:90.0 ~root "dune build --root . test/repository_lints.exe && _build/default/test/repository_lints.exe" in
      if result.code <> 2 then Printf.eprintf "unexpected lint result %d\n%s%s" result.code result.stdout result.stderr;
      check "a module that outgrows the core is rejected" (result.code = 2)) with
  | Ok () -> ()
  | Error error -> failwith error);
  print_endline "repository-size-control: PASS"
