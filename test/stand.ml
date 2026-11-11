open Helpers

let () =
  with_repo (fun root ->
      ignore (run root "init");
      ignore (run root "goal \"measure\" subject.txt owner");
      write root "subject.txt" "expected\n";
      expect root "add sample \"measure\" subject.txt \"not expected\" fact --requirement \"verifier:true\"" 0;
      let stand = Filename.concat (Filename.dirname Sys.executable_name) "../bin/stand.exe" in
      let help = Process.run ~root (Filename.quote stand ^ " --help") in
      check "stand help explains its inputs" (help.code = 0 && contains help.stdout "--human-minutes");
      let result = Process.run ~root (Printf.sprintf "%s %s --human-minutes 1 --agent-tokens 100 --person-minute-cost 1 --machine-second-cost 0.1 --token-cost 0.01 --defect-cost 100" (Filename.quote stand) (Filename.quote root)) in
      check "stand runs against installed mathc" (result.code = 0);
      check "stand reports the criterion boundary" (contains result.stdout "criterion: not computable - no defect was caught");
      print_endline "stand: PASS")
