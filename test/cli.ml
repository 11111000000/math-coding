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
      expect root "init" 0;
      check "empty project is vacant" ((run root "map").code = 3);
      add_and_run root;
      let map = run root "map" in
      check "valid evidence is green" (map.code = 0 && contains map.stdout "green" && contains map.stdout "holds");
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
      let exact = Isolated_run.with_copy root (fun copy ->
        let staged = Process.run ~root:copy "git diff --cached --name-only" in
        not (Sys.file_exists (Filename.concat copy "removed.txt")) && contains staged.stdout "subject.txt") in
      check "the snapshot contains new files and excludes deleted files" exact;
      expect root "add exact-copy \"the control sees only current files\" subject.txt \"a deleted file is still visible\" fact --requirement \"verifier:test ! -e removed.txt && grep -q expected subject.txt\" --control \"printf broken > subject.txt\"" 0;
      expect root "run" 0;
      check "the live deletion is untouched" (not (Sys.file_exists (Filename.concat root "removed.txt")));
      print_endline "isolated-snapshot: PASS")

let () =
  let root = Sys.getcwd () in
  check "a signal-like exit is an infrastructure error"
    ((Process.run ~root "exit 137").outcome = Infrastructure_error);
  check "a timeout is an infrastructure error"
    ((Process.run ~timeout:0.05 ~root "sleep 1").outcome = Infrastructure_error);
  print_endline "process-outcomes: PASS"
