open Helpers

let () =
  with_repo (fun root ->
      write root "policy.json" "{\"protected_paths\":[\"subject.txt\"],\"authorized_by\":\"owner\"}\n";
      ignore (run root "init");
      write root "subject.txt" "expected\n";
      expect root "run" 1;
      expect root "authorize --by owner --reason reviewed" 0;
      expect root "run" 3;
      expect root "authorize --by stranger --reason reviewed" 2;
      let evaluated = run root "re-evaluate" in
      check "re-evaluation returns data" (contains evaluated.stdout "needs_re_evaluation");
      write root "policy.json" "{\n";
      let broken = run root "doctor" in
      check "malformed policy is a readable error" (broken.code = 1 && contains broken.stdout "protected transitions");
      let outside = Io.temp_dir "mathc-policy-outside" in
      Fun.protect ~finally:(fun () -> Io.remove_tree outside) (fun () ->
        match Git.uncovered outside [] ~goal_scope:[ "." ] with
        | Error _ -> ()
        | Ok _ -> failwith "repository errors must not become empty coverage");
      print_endline "policy: PASS")
