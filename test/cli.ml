open Domain
open Helpers

let expect = Helpers.expect

let add_and_run root =
  expect root "goal \"the subject is expected\" subject.txt owner" 0;
  write root "subject.txt" "expected\n";
  expect root "add sample \"the subject is expected\" subject.txt \"not expected\" fact --requirement \"verifier:grep -q expected subject.txt\" --control \"printf broken > subject.txt\"" 0;
  expect root "run" 0

let () =
  with_repo (fun root ->
      let help = run root "--help" in
      check "help is available before project setup"
        (help.code = 0 && contains help.stdout "review-source" && contains help.stdout "./install.sh");
      let add_help = run root "help add" in
      check "command help names valid registers"
        (add_help.code = 0 && contains add_help.stdout "fact, hypothesis, judgment or unknown");
      expect root "help unknown-command" 2;
      let empty = run root "map" in
      check "empty project is vacant" (empty.code = 3 && contains empty.stderr "project root");
      expect root "init" 0;
      add_and_run root;
      let map = run root "map" in
      check "valid evidence is green" (map.code = 0 && contains map.stdout "green" && contains map.stdout "holds");
      let proof = run root "run" in
      check "run states that the negative control was proven"
        (proof.code = 0 && contains proof.stdout "negative control proven");
      let next_before = Io.read_file (Filename.concat root "subject.txt") in
      expect root "next" 0;
      check "next is read-only" (Io.read_file (Filename.concat root "subject.txt") = next_before);
      write root "subject.txt" "changed\n";
      let outdated = run root "map" in
      check "content change invalidates evidence" (outdated.code = 3 && contains outdated.stdout "outdated");
      expect root "waive sample --by owner --reason temporary --valid-for 1 --recovery rerun" 0;
      let waived_map = run root "map" in
      check "waiver remains unknown" (waived_map.code = 3 && contains waived_map.stdout "waived");
      expect root "install" 0;
      let first = Io.read_file (Filename.concat root "AGENTS.md") in
      expect root "install" 0;
      let second = Io.read_file (Filename.concat root "AGENTS.md") in
      check "install is idempotent" (first = second);
      check "generated agent page is outside uncovered subject scope"
        (contains (run root "map").stdout "uncovered: 0 file(s)");
      expect root "doctor" 0;
      print_endline "cli: PASS")

let () =
  with_repo (fun root ->
      expect root "init" 0;
      expect root "goal \"only subject\" subject.txt owner" 0;
      write root "subject.txt" "expected\n";
      write root "outside.txt" "outside\n";
      expect root "add mixed \"outside scope\" subject.txt,outside.txt \"accepted\" fact --requirement \"verifier:true\"" 2;
      expect root "map --unknown-option" 2;
      expect root "waive sample --by owner --reason reason --valid-for nope --recovery rerun" 2;
      expect root "add reviewed \"human review\" subject.txt \"review refutes it\" fact --requirement \"review:owner\"" 0;
      expect root "record reviewed owner --by owner --outcome invented" 2;
      expect root "record reviewed owner --by owner --outcome pass --valid-for -1" 2;
      write root ".math/v5/evidence.jsonl" "not-json\n";
      let corrupted = run root "map" in
      check "a malformed evidence trail is a readable error"
        (corrupted.code = 3 && contains corrupted.stderr "evidence trail");
      print_endline "cli-boundary: PASS")

let () =
  with_repo (fun root ->
      expect root "init" 0;
      expect root "goal \"keep the ADR obligation current\" subject.txt,docs/adr owner" 0;
      write root "subject.txt" "expected\n";
      let adr = "# 0001. Expected subject\n\n## Decision Outcome\n\nThe subject is expected.\n" in
      write root "docs/adr/0001.md" adr;
      expect root "add sourced \"the ADR requires an expected subject\" subject.txt \"the ADR is not implemented\" fact --requirement \"verifier:grep -q expected subject.txt\" --control \"printf broken > subject.txt\" --source docs/adr/0001.md" 0;
      (match Spec.parse_string (Io.read_file (Filename.concat root "spec.json")) with
       | Error error -> failwith error
       | Ok { claims = [ claim ]; _ } ->
           (match claim.source with
            | Some source ->
                check "source digest is bound" (source.digest = Domain.digest_string adr);
                check "source path is retained" (source.path = "docs/adr/0001.md")
            | None -> failwith "the claim lost its source")
       | Ok _ -> failwith "unexpected claims");
      check "ADR import is read-only" (Io.read_file (Filename.concat root "docs/adr/0001.md") = adr);
      expect root "run" 0;
      expect root "map" 0;
      write root "docs/adr/0001.md" (adr ^ "\nA later decision changes the obligation.\n");
      let map = run root "map" in
      check "source change invalidates the green verdict"
        (map.code = 3 && contains map.stdout "outdated" && contains map.stdout "source changed");
      let pending = run root "re-evaluate" in
      check "source change requires re-evaluation" (pending.code = 0 && contains pending.stdout "sourced");
      check "next names the source-review command" (contains (run root "next").stdout "review-source");
      expect root "review-source sourced --by stranger --reason reviewed" 2;
      expect root "review-source sourced --by owner --reason \"reviewed the changed ADR\"" 0;
      let rebound = run root "map" in
      check "source review never skips fresh verification"
        (rebound.code = 3 && contains rebound.stdout "outdated" && not (contains rebound.stdout "source changed"));
      let changed_adr = adr ^ "\nA later decision changes the obligation.\n" in
      (match Spec.parse_string (Io.read_file (Filename.concat root "spec.json")) with
       | Error error -> failwith error
       | Ok { claims = [ claim ]; _ } ->
           (match claim.source with
            | Some { review = Some review; digest; _ } ->
                check "source review records the previous digest" (review.previous_digest = Domain.digest_string adr);
                check "source review records the new digest" (digest = Domain.digest_string changed_adr);
                check "source review records the owner and reason"
                  (review.by = "owner" && review.reason = "reviewed the changed ADR")
            | _ -> failwith "source review was not retained")
       | Ok _ -> failwith "unexpected claims");
      check "source review does not rewrite the ADR" (Io.read_file (Filename.concat root "docs/adr/0001.md") = changed_adr);
      expect root "run" 0;
      expect root "map" 0;
      expect root "review-source sourced --by owner --reason redundant" 2;
      expect root "add traversal \"outside source\" subject.txt \"outside source\" fact --requirement \"verifier:true\" --source ../outside.md" 2;
      expect root "add outside-scope \"outside scope\" ../outside.txt \"outside scope\" fact --requirement \"verifier:true\"" 2;
      Unix.symlink (Filename.concat root "docs/adr/0001.md") (Filename.concat root "link.md");
      expect root "add linked \"symlink source\" subject.txt \"symlink source\" fact --requirement \"verifier:true\" --source link.md" 2;
      print_endline "source-re-evaluation: PASS")

let () =
  with_repo (fun root ->
      expect root "init" 0;
      expect root "goal \"the control must reach the subject\" subject.txt owner" 0;
      write root "subject.txt" "expected\n";
      expect root "add weak-control \"the subject is expected\" subject.txt \"not expected\" fact --requirement \"verifier:grep -q expected subject.txt\" --control \"true\"" 0;
      expect root "run" 3;
      check "an ineffective control cannot hold" (contains (run root "map").stdout "inconclusive");
      check "an ineffective control leaves the live tree alone" (Io.read_file (Filename.concat root "subject.txt") = "expected\n");
      print_endline "control-reach: PASS")

let () =
  with_repo (fun root ->
      write root "removed.txt" "old implementation\n";
      ignore (Process.run ~root "git add removed.txt && git -c user.name=Test -c user.email=test@example.invalid commit -qm baseline");
      expect root "init" 0;
      expect root "goal \"the control mirrors the live tree\" subject.txt owner" 0;
      write root "subject.txt" "expected\n";
      Unix.unlink (Filename.concat root "removed.txt");
      let exact =
        match Isolated_run.with_copy root (fun copy ->
          let staged = Process.run ~root:copy "git diff --cached --name-only" in
          not (Sys.file_exists (Filename.concat copy "removed.txt")) && contains staged.stdout "subject.txt") with
        | Ok value -> value
        | Error error -> failwith error
      in
      check "the snapshot contains new files and excludes deleted files" exact;
      expect root "add exact-copy \"the control sees only current files\" subject.txt \"a deleted file is still visible\" fact --requirement \"verifier:test ! -e removed.txt && grep -q expected subject.txt\" --control \"printf broken > subject.txt\"" 0;
      expect root "run" 0;
      check "the live deletion is untouched" (not (Sys.file_exists (Filename.concat root "removed.txt")));
      print_endline "isolated-snapshot: PASS")

let () =
  with_repo (fun root ->
      write root "subject.sh" "#!/bin/sh\nif [ \"$1\" = expected ]; then printf 'expected\\n'; else exit 1; fi\n";
      write root "verify.sh" "#!/bin/sh\n./subject.sh expected\n";
      Unix.chmod (Filename.concat root "subject.sh") 0o755;
      Unix.chmod (Filename.concat root "verify.sh") 0o755;
      expect root "init" 0;
      expect root "goal \"the executable subject is preserved\" subject.sh,verify.sh owner" 0;
      expect root "add executable \"the executable subject works\" subject.sh,verify.sh \"the subject fails\" fact --requirement \"verifier:sh verify.sh\" --control \"sed -i 's/expected/broken/g' subject.sh\"" 0;
      expect root "run" 0;
      expect root "map" 0;
      Unix.chmod (Filename.concat root "subject.sh") 0o644;
      let changed_mode = run root "map" in
      check "a mode change invalidates evidence" (changed_mode.code = 3 && contains changed_mode.stdout "outdated");
      Unix.chmod (Filename.concat root "subject.sh") 0o755;
      expect root "map" 0;
      print_endline "executable-snapshot: PASS")

let () =
  with_repo (fun root ->
      write root "flake.lock" "{\"nodes\":{}}\n";
      expect root "init" 0;
      expect root "goal \"environment must stay bound\" subject.txt owner" 0;
      write root "subject.txt" "expected\n";
      expect root "add sample \"the subject is expected\" subject.txt \"not expected\" fact --requirement \"verifier:grep -q expected subject.txt\" --control \"printf broken > subject.txt\"" 0;
      expect root "run" 0;
      write root "flake.lock" "{\"nodes\":{\"changed\":true}}\n";
      let changed = run root "map" in
      check "changed nonempty environment invalidates evidence"
        (changed.code = 3 && contains changed.stdout "outdated");
      print_endline "environment-freshness: PASS")

let () =
  with_repo (fun root ->
      expect root "init" 0;
      expect root "goal \"a judgment needs human evaluation\" subject.txt owner" 0;
      write root "subject.txt" "expected\n";
      expect root "add subjective \"subjective quality is excellent\" subject.txt \"a human reviewer disagrees\" judgment --requirement \"verifier:grep -q expected subject.txt\"" 2;
      expect root "add invalid \"invalid register\" subject.txt \"invalid register\" fax --requirement \"verifier:true\"" 2;
      expect root "add judged \"subjective quality is excellent\" subject.txt \"a human reviewer disagrees\" judgment --requirement \"review:owner\"" 0;
      expect root "map" 3;
      expect root "record judged owner --by owner --outcome pass" 0;
      expect root "map" 0;
      print_endline "judgment-register: PASS")

let () =
  with_repo (fun root ->
      expect root "init" 0;
      expect root "goal \"one passing alternative is enough\" subject.txt owner" 0;
      write root "subject.txt" "expected\n";
      let alternative = { claim with requirements = [ Any [ Verifier "grep -q expected subject.txt"; Verifier "printf second > second.txt && false" ] ] } in
      let spec = { goal = Some { text = "one passing alternative is enough"; scope = [ "subject.txt" ]; by = "owner"; at = 1; reason = None }; claims = [ alternative ] } in
      write root "spec.json" (Yojson.Safe.pretty_to_string (Spec.to_json spec));
      expect root "run" 0;
      check "Any stops after the first passing alternative" (not (Sys.file_exists (Filename.concat root "second.txt")));
      print_endline "any-short-circuit: PASS")

let () =
  with_repo (fun root ->
      expect root "init" 0;
      expect root "goal \"every required branch must pass\" subject.txt owner" 0;
      write root "subject.txt" "expected\n";
      let required = { claim with requirements = [ All [
        Verifier "grep -q expected subject.txt";
        Verifier "test \"$(cat subject.txt)\" = expected";
      ] ] } in
      let spec = { goal = Some { text = "every required branch must pass"; scope = [ "subject.txt" ]; by = "owner"; at = 1; reason = None }; claims = [ required ] } in
      write root "spec.json" (Yojson.Safe.pretty_to_string (Spec.to_json spec));
      expect root "run" 0;
      check "All accepts fresh passing branches" (contains (run root "map").stdout "holds");
      print_endline "all-accepting: PASS")

let () =
  with_repo (fun root ->
      expect root "init" 0;
      expect root "goal \"a later refutation must be observed\" subject.txt owner" 0;
      write root "subject.txt" "expected\n";
      let required = { claim with requirements = [ All [
        Verifier "exit 2";
        Verifier "printf second > second.txt && false";
      ] ] } in
      let spec = { goal = Some { text = "a later refutation must be observed"; scope = [ "subject.txt" ]; by = "owner"; at = 1; reason = None }; claims = [ required ] } in
      write root "spec.json" (Yojson.Safe.pretty_to_string (Spec.to_json spec));
      expect root "run" 1;
      check "All preserves a refutation after an inconclusive branch"
        (contains (run root "map").stdout "refuted");
      check "All executes the later refuting branch" (Sys.file_exists (Filename.concat root "second.txt"));
      print_endline "all-late-refutation: PASS")

let () =
  with_repo (fun root ->
      expect root "init" 0;
      expect root "goal \"a refutation ends required evaluation\" subject.txt owner" 0;
      write root "subject.txt" "expected\n";
      let required = { claim with requirements = [ All [
        Verifier "false";
        Verifier "printf second > second.txt && true";
      ] ] } in
      let spec = { goal = Some { text = "a refutation ends required evaluation"; scope = [ "subject.txt" ]; by = "owner"; at = 1; reason = None }; claims = [ required ] } in
      write root "spec.json" (Yojson.Safe.pretty_to_string (Spec.to_json spec));
      expect root "run" 1;
      check "All stops after a refutation" (not (Sys.file_exists (Filename.concat root "second.txt")));
      print_endline "all-refusal-short-circuit: PASS")

let () =
  let root = Sys.getcwd () in
  check "a signal-like exit is an infrastructure error"
    ((Process.run ~root "exit 137").outcome = Infrastructure_error);
  check "a timeout is an infrastructure error"
    ((Process.run ~timeout:0.05 ~root "sleep 1").outcome = Infrastructure_error);
  check "large output is marked truncated"
    (Process.run ~root "python3 -c 'print(\"x\" * 1048577)'").truncated;
  print_endline "process-outcomes: PASS"
