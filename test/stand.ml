open Domain
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
      let negative = Process.run ~root (Printf.sprintf "%s %s --human-minutes -1 --agent-tokens -1 --person-minute-cost -1 --machine-second-cost -1 --token-cost -1 --defect-cost -1" (Filename.quote stand) (Filename.quote root)) in
      check "negative costs are rejected" (negative.code = 2 && contains negative.stderr "cost parameters must be finite and nonnegative");
      let unknown = Process.run ~root (Filename.quote stand ^ " --unknown-option") in
      check "unknown options are rejected" (unknown.code = 2 && contains unknown.stderr "unknown option");
      print_endline "stand: PASS")

(* The price arm measures what the checks cost when they are run directly, with
   no protocol around them. It has to run the very command the protocol runs:
   the same check, inside the same environment. A price arm that runs the check
   outside the environment the claim declares measures cheaper work than the
   protocol does, and the difference is then reported as the overhead of the
   method - the method looks cheaper than it is, and the criterion of the cost
   is decided by a wrong denominator. *)
let probe marker =
  Printf.sprintf
    "test \"$MATHC_STAND_ENV\" = inside && echo inside >> %s; grep -q expected subject.txt"
    marker

let claim_with_environment id environment command =
  { id; text = "the subject is expected"; scope = [ "subject.txt" ];
    source = None; kind = Acceptance; phase = Pre_merge; owner = None; review_on = [];
    requirements = [ Verifier command ];
    falsifier = "the subject is not expected"; register = Fact;
    control = None; waiver = None; environment }

let written_lines path =
  if not (Sys.file_exists path) then 0
  else
    Io.read_file path
    |> String.split_on_char '\n'
    |> List.filter (fun line -> String.trim line <> "")
    |> List.length

let () =
  with_repo (fun root ->
      ignore (run root "init");
      write root "subject.txt" "expected\n";
      (* One claim declares its own environment, the other declares none. *)
      let spec =
        { goal = Some { text = "the price arm runs the same work as the protocol";
                        scope = [ "subject.txt" ]; by = "owner"; at = 1; reason = None };
          claims = [ claim_with_environment "own" (Some "env MATHC_STAND_ENV=inside") (probe "marker-own");
                     claim_with_environment "bare" None (probe "marker-bare") ];
          environment = None }
      in
      write root "spec.json" (Yojson.Safe.pretty_to_string (Spec.to_json spec));
      let stand = Filename.concat (Filename.dirname Sys.executable_name) "../bin/stand.exe" in
      let result = Process.run ~root (Printf.sprintf "%s %s" (Filename.quote stand) (Filename.quote root)) in
      check "stand measures the project" (result.code = 0);
      (* The protocol runs the check of the claim once in the tree; the price arm
         has to run it once more, inside the very same environment. *)
      check "the price arm runs the check inside the environment of the claim"
        (written_lines (Filename.concat root "marker-own") = 2);
      (* A claim without an environment runs the check as it is declared. The
         price arm must not invent one, so the marker stays empty. *)
      check "the price arm does not invent an environment where none is declared"
        (written_lines (Filename.concat root "marker-bare") = 0);
      print_endline "stand-price-arm: PASS")

(* A measurement is a measurement only when every arm of it finished. An arm
   that was cut off at the limit says nothing about the cost of the work, and a
   limit reported as a number would be a number about the tool, not about the
   method. *)
let () =
  with_repo (fun root ->
      ignore (run root "init");
      write root "subject.txt" "expected\n";
      let spec =
        { goal = Some { text = "the arms of the measurement have to finish";
                        scope = [ "subject.txt" ]; by = "owner"; at = 1; reason = None };
          claims = [ claim_with_environment "slow" None "sleep 3; grep -q expected subject.txt" ];
          environment = None }
      in
      write root "spec.json" (Yojson.Safe.pretty_to_string (Spec.to_json spec));
      let stand = Filename.concat (Filename.dirname Sys.executable_name) "../bin/stand.exe" in
      let cut =
        Process.run ~root (Printf.sprintf "%s %s --timeout 1" (Filename.quote stand) (Filename.quote root))
      in
      check "a cut off arm is reported" (cut.code = 0 && contains cut.stdout "an arm was cut off at the limit");
      let ratio =
        Process.run ~root
          (Printf.sprintf
             "%s %s --timeout 1 --human-minutes 1 --agent-tokens 100 --person-minute-cost 1 --machine-second-cost 0.1 --token-cost 0.01 --defect-cost 100"
             (Filename.quote stand) (Filename.quote root))
      in
      check "the ratio is not computed from a cut off measurement"
        (contains ratio.stdout "ratio: not computed. An arm was cut off at the limit.");
      let zero = Process.run ~root (Printf.sprintf "%s %s --timeout 0" (Filename.quote stand) (Filename.quote root)) in
      check "a zero timeout is rejected"
        (zero.code = 2 && contains zero.stderr "--timeout must be a positive number of seconds");
      let text = Process.run ~root (Printf.sprintf "%s %s --timeout abc" (Filename.quote stand) (Filename.quote root)) in
      check "a non numeric timeout is rejected"
        (text.code = 2 && contains text.stderr "--timeout must be a positive number of seconds");
      print_endline "stand-cut-off: PASS")

(* The price arm has to do the same work the protocol does. A claim with
   alternatives stops at the first confirmed one: a price arm that measures all
   of them is charged for work the protocol never did, and the difference
   between the arms is then not the overhead of the method. *)
let alternatives id first second =
  { id; text = "the subject is expected"; scope = [ "subject.txt" ];
    source = None; kind = Acceptance; phase = Pre_merge; owner = None; review_on = [];
    requirements = [ Any [ Verifier first; Verifier second ] ];
    falsifier = "the subject is not expected"; register = Fact;
    control = Some "printf broken > subject.txt"; waiver = None; environment = None }

let measure_with_costs root =
  let stand = Filename.concat (Filename.dirname Sys.executable_name) "../bin/stand.exe" in
  Process.run ~root
    (Printf.sprintf
       "%s %s --human-minutes 1 --agent-tokens 100 --person-minute-cost 1 --machine-second-cost 0.1 --token-cost 0.01 --defect-cost 100"
       (Filename.quote stand) (Filename.quote root))

let () =
  with_repo (fun root ->
      ignore (run root "init");
      write root "subject.txt" "expected\n";
      let spec =
        { goal = Some { text = "the arms have to do the same work";
                        scope = [ "subject.txt" ]; by = "owner"; at = 1; reason = None };
          claims = [ alternatives "one"
                       "echo first >> marker-first; grep -q expected subject.txt"
                       "echo second >> marker-second; grep -q expected subject.txt" ];
          environment = None }
      in
      write root "spec.json" (Yojson.Safe.pretty_to_string (Spec.to_json spec));
      let result = measure_with_costs root in
      check "the arms did the same work" (result.code = 0 && not (contains result.stdout "did different work"));
      (* The protocol confirms the first alternative and stops; the price arm
         stops there as well, so the second alternative is run by neither. *)
      check "the second alternative is not measured"
        (written_lines (Filename.concat root "marker-second") = 0);
      check "the first alternative is measured by both arms"
        (written_lines (Filename.concat root "marker-first") = 2);
      check "the ratio is computed over the same work"
        (contains result.stdout "cost:");
      print_endline "stand-same-work: PASS")

(* The two arms can still drift apart: a check that does not give the same
   answer twice is measured differently by the protocol and by the price arm.
   The measurement then says so instead of reporting a difference that is not
   the overhead of the method. *)
let () =
  with_repo (fun root ->
      ignore (run root "init");
      write root "subject.txt" "expected\n";
      let spec =
        { goal = Some { text = "the arms have to do the same work";
                        scope = [ "subject.txt" ]; by = "owner"; at = 1; reason = None };
          claims = [ alternatives "one"
                       "test ! -f marker-flaky && touch marker-flaky"
                       "echo second >> marker-second; grep -q expected subject.txt" ];
          environment = None }
      in
      write root "spec.json" (Yojson.Safe.pretty_to_string (Spec.to_json spec));
      let result = measure_with_costs root in
      check "the measurement is declared not a measurement"
        (contains result.stdout "the protocol and the price arm did different work");
      check "the ratio is not computed over different work"
        (contains result.stdout "ratio: not computed. The protocol and the price arm did different work.");
      print_endline "stand-different-work: PASS")
