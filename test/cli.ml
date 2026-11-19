open Domain
open Helpers

let expect = Helpers.expect

(* The map explains every state it reports. *)
let state_of_text = function
  | "holds" -> Some Holds
  | "refuted" -> Some Refuted
  | "inconclusive" -> Some Inconclusive
  | "not-checkable" -> Some NotCheckable
  | "outdated" -> Some Outdated
  | "never-checked" -> Some NeverChecked
  | "waived" -> Some Waived
  | _ -> None

let states_of json =
  match field "states" json with Some (`List items) -> items | _ -> []

let text_field name item =
  match field name item with Some (`String value) -> value | _ -> ""

let bool_field name item =
  match field name item with Some (`Bool value) -> value | _ -> false

(* The journal of evidence is a JSONL file: every record is one line. *)
let trail_records root =
  let path = Filename.concat root ".math/v5/evidence.jsonl" in
  if not (Sys.file_exists path) then []
  else String.split_on_char '\n' (Io.read_file path) |> List.filter (fun line -> line <> "")

let state_of_map map id =
  List.map (fun item -> (text_field "id" item, text_field "state" item)) (states_of map)
  |> List.assoc id

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
      let map_text = run root "map" in
      check "run shows the same map as the map command"
        (map_text.code = 0 && contains proof.stdout map_text.stdout);
      let proof_json = run root "run --json" in
      let proof_map = Yojson.Safe.from_string proof_json.stdout in
      check "structured run output is actionable"
        (proof_json.code = 0
        && not (contains proof_json.stdout "negative control proven")
        && field "verdict" proof_map = Some (`String "green")
        && field "exit" proof_map = Some (`Int 0)
        &&
        match field "next" proof_map with
        | Some (`String next) -> contains next "nothing to do"
        | _ -> false);
      check "structured run binds fresh evidence" ((run root "map").code = 0);
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
      let doctor = run root "doctor" in
      check "the doctor tells the tool apart from the state of the evidence"
        (doctor.code = 0
        && contains doctor.stdout "the evidence trail is whole"
        && contains doctor.stdout "the evidence is fresh for"
        && contains doctor.stdout "every negative control of the last run reaches the subject");
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
      (* A damaged record does not take the project with it: the records that
         can be read still stand, the damage is named, and the run repairs the
         journal and keeps the damaged original beside it. *)
      let damaged = run root "map" in
      check "a damaged evidence trail does not kill the project"
        (damaged.code = 3 && contains damaged.stdout "damaged records"
        && contains damaged.stdout "the evidence trail is not whole"
        && not (contains damaged.stderr "evidence trail"));
      let damaged_doctor = run root "doctor" in
      check "the doctor names a trail that is not whole"
        (contains damaged_doctor.stdout "the evidence trail is not whole");
      let repaired = run root "run" in
      check "run repairs the journal and says what it did"
        (contains repaired.stdout "the evidence trail had 1 record(s) that could not be read"
        && contains repaired.stdout "the damaged original is kept at");
      let kept =
        Sys.readdir (Filename.concat root ".math/v5")
        |> Array.to_list
        |> List.filter (fun name -> String.starts_with ~prefix:"evidence.damaged." name)
      in
      check "the damaged original is kept beside the journal"
        (kept <> []
        && contains (Io.read_file (Filename.concat (Filename.concat root ".math/v5") (List.hd kept))) "not-json");
      let healed = run root "map" in
      check "the repaired journal is whole"
        (not (contains healed.stdout "damaged records")
        && contains healed.stdout "never-checked");
      write root ".math/v5/evidence.jsonl" "not-json\n";
      let corrupted_json = run root "run --json" in
      check "structured run keeps the repair notice out of the json"
        (corrupted_json.code = 3
        && contains corrupted_json.stderr "the evidence trail had"
        && (match Yojson.Safe.from_string corrupted_json.stdout with
            | exception Yojson.Json_error _ -> false
            | _ -> true));
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
      let changed_map = Yojson.Safe.from_string (run root "map --json").stdout in
      check "a changed source is outdated for the reason source-changed"
        (List.for_all
           (fun item -> text_field "reason" item = "source-changed"
              && bool_field "source_changed" item)
           (states_of changed_map));
      let changed_run = run root "run" in
      check "run routes a changed source to review"
        (changed_run.code = 3 && contains changed_run.stdout "outdated"
        && contains changed_run.stdout "source changed"
        && contains changed_run.stdout "next: review the changed source of sourced");
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
      let weak = run root "run" in
      check "an ineffective control is routed as unknown"
        (weak.code = 3 && contains weak.stdout "verdict: unknown"
        && contains weak.stdout "weak-control" && contains weak.stdout "inconclusive"
        && contains weak.stdout "next: check the claim weak-control"
        && not (contains weak.stdout "verdict: green"));
      check "an ineffective control cannot hold" (contains (run root "map").stdout "inconclusive");
      check "an ineffective control leaves the live tree alone" (Io.read_file (Filename.concat root "subject.txt") = "expected\n");
      print_endline "control-reach: PASS")

let () =
  with_repo (fun root ->
      expect root "init" 0;
      expect root "goal \"cover the stated area\" subject.txt,extra.txt owner" 0;
      write root "subject.txt" "expected\n";
      write root "extra.txt" "unexamined\n";
      expect root "add covered \"the subject is expected\" subject.txt \"not expected\" fact --requirement \"verifier:grep -q expected subject.txt\" --control \"printf broken > subject.txt\"" 0;
      let result = run root "run" in
      check "run keeps green separate from uncovered work"
        (result.code = 0 && contains result.stdout "verdict: green"
        && contains result.stdout "uncovered: 1 file(s)"
        && contains result.stdout "  extra.txt"
        && contains result.stdout "next: inspect uncovered file extra.txt"
        && not (contains result.stdout "uncovered: 0 file(s)"));
      print_endline "run-uncovered: PASS")

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
      let judged_json = run root "run --json" in
      check "structured run stays quiet for a human review"
        (judged_json.code = 3
        && not (contains judged_json.stdout "review by")
        && field "verdict" (Yojson.Safe.from_string judged_json.stdout) = Some (`String "unknown"));
      expect root "record judged owner --by owner --outcome pass" 0;
      expect root "map" 0;
      print_endline "judgment-register: PASS")

(* The next action has to be an action that can close the claim. The run
   refuses a human review by definition, so a claim that waits for a review is
   not closed by re-running the checks: the hint names the record. *)
let () =
  with_repo (fun root ->
      expect root "init" 0;
      expect root "goal \"a human decision settles the claim\" subject.txt owner" 0;
      write root "subject.txt" "expected\n";
      expect root "add judged \"the subject is expected\" subject.txt \"not expected\" judgment --requirement \"review:owner\"" 0;
      let waiting = run root "next" in
      check "a claim that waits for a human names the record command"
        (contains waiting.stdout "mathc record judged owner --by WHO --outcome OUTCOME"
        && not (contains waiting.stdout "re-run the checks"));
      expect root "record judged owner --by owner --outcome pass" 0;
      check "a recorded review settles the claim"
        (contains (run root "map").stdout "holds"
        && contains (run root "next").stdout "nothing to do");
      write root "subject.txt" "changed\n";
      let stale = run root "next" in
      check "a stale human claim names the record command and not the checks"
        (contains stale.stdout "the evidence of judged is stale (materials-changed)"
        && contains stale.stdout "mathc record judged owner --by WHO --outcome OUTCOME"
        && not (contains stale.stdout "re-run the checks"));
      print_endline "next-names-the-human-review: PASS")

(* A claim that asks for both a machine check and a human review waits for the
   check first: the run takes the machine branch, and the review is what the
   map names when the check already holds. *)
let () =
  with_repo (fun root ->
      expect root "init" 0;
      write root "subject.txt" "expected\n";
      let goal = Some { text = "a check and a human settle the claim"; scope = [ "subject.txt" ];
                        by = "owner"; at = 1; reason = None } in
      let both = { claim with id = "both";
                   requirements = [ Verifier "grep -q expected subject.txt";
                                    Review { authority = "owner"; minimum_independence = External } ];
                   control = Some "printf broken > subject.txt" } in
      write root "spec.json"
        (Yojson.Safe.pretty_to_string (Spec.to_json { goal; claims = [ both ]; environment = None }));
      (* The run settles the machine branch. The review stays open, so the
         verdict is unknown and the map names the record. *)
      expect root "run" 3;
      let waiting = run root "next" in
      check "an open review is named when the machine check already holds"
        (contains waiting.stdout "mathc record both owner --by WHO --outcome OUTCOME"
        && not (contains waiting.stdout "re-run the checks"));
      expect root "record both owner --by owner --outcome pass" 0;
      check "the recorded review settles the claim"
        (contains (run root "map").stdout "holds");
      print_endline "next-names-the-open-review: PASS")

(* A record is an external attestation. It answers the requirement as the
   claim declares it, so a claim that asks for a weaker independence is closed
   by the same command; a claim without a review requirement refuses it. *)
let () =
  with_repo (fun root ->
      expect root "init" 0;
      write root "subject.txt" "expected\n";
      let goal = Some { text = "a human decision settles the claim"; scope = [ "subject.txt" ];
                        by = "owner"; at = 1; reason = None } in
      let judged = { claim with id = "judged"; register = Judgment; control = None;
                     requirements = [ Review { authority = "owner"; minimum_independence = Self_attested } ] } in
      let nested = { claim with id = "nested"; register = Judgment; control = None;
                     requirements = [ All [ Review { authority = "owner"; minimum_independence = External } ] ] } in
      write root "spec.json"
        (Yojson.Safe.pretty_to_string (Spec.to_json { goal; claims = [ judged; nested ]; environment = None }));
      expect root "record absent owner --by owner --outcome pass" 2;
      expect root "record judged owner --by owner --outcome pass" 0;
      expect root "record nested owner --by owner --outcome pass" 0;
      let map = Yojson.Safe.from_string (run root "map --json").stdout in
      check "a record answers the requirement as the claim declares it"
        (state_of_map map "judged" = "holds");
      check "a record answers a review inside the tree of the requirements"
        (state_of_map map "nested" = "holds");
      print_endline "record-answers-the-declared-requirement: PASS")

let () =
  with_repo (fun root ->
      expect root "init" 0;
      expect root "goal \"one passing alternative is enough\" subject.txt owner" 0;
      write root "subject.txt" "expected\n";
      let alternative = { claim with requirements = [ Any [ Verifier "grep -q expected subject.txt"; Verifier "printf second > second.txt && false" ] ] } in
      let spec = { goal = Some { text = "one passing alternative is enough"; scope = [ "subject.txt" ]; by = "owner"; at = 1; reason = None }; claims = [ alternative ]; environment = None } in
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
      let spec = { goal = Some { text = "every required branch must pass"; scope = [ "subject.txt" ]; by = "owner"; at = 1; reason = None }; claims = [ required ]; environment = None } in
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
      let spec = { goal = Some { text = "a later refutation must be observed"; scope = [ "subject.txt" ]; by = "owner"; at = 1; reason = None }; claims = [ required ]; environment = None } in
      write root "spec.json" (Yojson.Safe.pretty_to_string (Spec.to_json spec));
      let refused = run root "run" in
      check "All preserves a refutation after an inconclusive branch"
        (contains (run root "map").stdout "refuted");
      check "run routes a refutation without reporting green"
        (refused.code = 1 && contains refused.stdout "verdict: red"
        && contains refused.stdout "sample" && contains refused.stdout "refuted"
        && contains refused.stdout "next: the claim sample is refuted"
        && not (contains refused.stdout "verdict: green")
        && not (contains refused.stdout "nothing to do"));
      let refused_json = run root "run --json" in
      let refused_map = Yojson.Safe.from_string refused_json.stdout in
      check "structured run reports a refutation without progress lines"
        (refused_json.code = 1 && field "verdict" refused_map = Some (`String "red")
        && field "exit" refused_map = Some (`Int 1)
        && not (contains refused_json.stdout "sample: fail"));
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
      let spec = { goal = Some { text = "a refutation ends required evaluation"; scope = [ "subject.txt" ]; by = "owner"; at = 1; reason = None }; claims = [ required ]; environment = None } in
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

let () =
  with_repo (fun root ->
      expect root "init" 0;
      expect root "goal \"the map explains every state\" subject.txt owner" 0;
      write root "subject.txt" "expected\n";
      expect root "add sample \"the subject is expected\" subject.txt \"not expected\" fact --requirement \"verifier:grep -q expected subject.txt\" --control \"printf broken > subject.txt\"" 0;
      expect root "run" 0;
      let map = Yojson.Safe.from_string (run root "map --json").stdout in
      let states = states_of map in
      check "the map reports a reason for every claim" (List.length states = 1);
      check "a fresh claim holds for the reason current"
        (text_field "state" (List.hd states) = "holds"
        && text_field "reason" (List.hd states) = "current");
      check "every reported reason belongs to the closed vocabulary"
        (List.for_all
           (fun item -> Verdict.reason_of_string (text_field "reason" item) <> None)
           states);
      check "every reported reason explains the state it stands for"
        (List.for_all
           (fun item ->
             match state_of_text (text_field "state" item) with
             | Some state ->
                 (match Verdict.reason_of_string (text_field "reason" item) with
                  | Some reason -> Verdict.explains reason state
                  | None -> false)
             | None -> false)
           states);
      check "the human map prints the reason next to the state"
        (contains (run root "map").stdout "holds (current)");
      write root "subject.txt" "changed\n";
      let stale = Yojson.Safe.from_string (run root "map --json").stdout in
      check "a changed subject is outdated for the reason materials-changed"
        (text_field "state" (List.hd (states_of stale)) = "outdated"
        && text_field "reason" (List.hd (states_of stale)) = "materials-changed");
      check "the next action names the stale reason"
        (contains (run root "next").stdout
           "the evidence of sample is stale (materials-changed), re-run the checks");
      check "a machine check is never sent to a human record"
        (not (contains (run root "next").stdout "mathc record"));
      print_endline "map-reason: PASS")

let () =
  with_repo (fun root ->
      expect root "init" 0;
      expect root "goal \"a check that cannot start stays unknown\" subject.txt owner" 0;
      write root "subject.txt" "expected\n";
      expect root "add missing \"the program exists\" subject.txt \"the program is absent\" fact --requirement \"verifier:mathc-no-such-program\"" 0;
      expect root "run" 3;
      let map = Yojson.Safe.from_string (run root "map --json").stdout in
      let states = states_of map in
      check "a check that did not start is inconclusive for the reason not-run"
        (text_field "state" (List.hd states) = "inconclusive"
        && text_field "reason" (List.hd states) = "not-run");
      check "the next action says the check could not start"
        (contains (run root "next").stdout "the check for missing could not start");
      print_endline "map-reason-not-run: PASS")

(* A declared environment is the prefix of the whole command. *)
let () =
  with_repo (fun root ->
      expect root "init" 0;
      expect root "goal \"the checks run inside the declared environment\" subject.txt owner" 0;
      write root "subject.txt" "expected\n";
      let inside = "test \"$MATHC_TEST_ENV\" = inside" in
      let verifier = { claim with
        id = "verifier-side";
        requirements = [ Verifier (inside ^ " && grep -q expected subject.txt") ];
        control = Some "printf broken > subject.txt" } in
      let control = { claim with
        id = "control-side";
        requirements = [ Verifier "grep -q expected subject.txt" ];
        control = Some (inside ^ " && printf broken > subject.txt") } in
      let goal = Some { text = "the checks run inside the declared environment";
                        scope = [ "subject.txt" ]; by = "owner"; at = 1; reason = None } in
      let spec = { goal; claims = [ verifier; control ]; environment = Some "env MATHC_TEST_ENV=inside" } in
      write root "spec.json" (Yojson.Safe.pretty_to_string (Spec.to_json spec));
      expect root "run" 0;
      let map = Yojson.Safe.from_string (run root "map --json").stdout in
      check "the declared environment runs the check and the control"
        (field "verdict" map = Some (`String "green"));
      check "the environment survives the codec"
        (match Spec.parse_string (Io.read_file (Filename.concat root "spec.json")) with
         | Ok parsed -> parsed.environment = Some "env MATHC_TEST_ENV=inside"
         | Error error -> failwith error);
      write root "spec.json" (Yojson.Safe.pretty_to_string (Spec.to_json { spec with environment = None }));
      expect root "run" 1;
      let plain = Yojson.Safe.from_string (run root "map --json").stdout in
      let state_of id =
        List.map (fun item -> (text_field "id" item, text_field "state" item)) (states_of plain)
        |> List.assoc id
      in
      check "without the environment the check cannot pass"
        (state_of "verifier-side" = "refuted");
      check "without the environment the control cannot reach the subject"
        (state_of "control-side" = "inconclusive");
      print_endline "declared-environment: PASS")

(* A claim may declare its own environment. It covers the check and its
   negative control, and a claim without one inherits the environment of the
   specification. *)
let () =
  with_repo (fun root ->
      expect root "init" 0;
      expect root "goal \"the checks run inside their declared environment\" subject.txt owner" 0;
      write root "subject.txt" "expected\n";
      let own = { claim with
        id = "own";
        requirements = [ Verifier "test \"$MATHC_TEST_ENV\" = inside && grep -q expected subject.txt" ];
        control = Some "test \"$MATHC_TEST_ENV\" = inside && printf broken > subject.txt";
        environment = Some "env MATHC_TEST_ENV=inside" } in
      let inherited = { claim with
        id = "inherited";
        requirements = [ Verifier "test \"$MATHC_TEST_ENV\" = outside && grep -q expected subject.txt" ];
        control = Some "test \"$MATHC_TEST_ENV\" = outside && printf broken > subject.txt" } in
      let goal = Some { text = "the checks run inside their declared environment";
                        scope = [ "subject.txt" ]; by = "owner"; at = 1; reason = None } in
      let spec = { goal; claims = [ own; inherited ]; environment = Some "env MATHC_TEST_ENV=outside" } in
      write root "spec.json" (Yojson.Safe.pretty_to_string (Spec.to_json spec));
      expect root "run" 0;
      let map = Yojson.Safe.from_string (run root "map --json").stdout in
      check "a claim runs inside its own environment" (state_of_map map "own" = "holds");
      check "a claim without an environment inherits the one of the specification"
        (state_of_map map "inherited" = "holds");
      (* The environment of a claim is applied, not ignored: a wrong one fails the
         check and its control. *)
      let wrong = { own with environment = Some "env MATHC_TEST_ENV=wrong" } in
      write root "spec.json" (Yojson.Safe.pretty_to_string (Spec.to_json { spec with claims = [ wrong; inherited ] }));
      expect root "run" 1;
      let wrong_map = Yojson.Safe.from_string (run root "map --json").stdout in
      check "a claim with a wrong environment is refuted" (state_of_map wrong_map "own" = "refuted");
      check "the other claim keeps its own environment" (state_of_map wrong_map "inherited" = "holds");
      (* A garbage environment of a claim is refused before anything is run. *)
      let garbage =
        `Assoc [ "schema_version", `Int 5; "goal", `Null; "environment", `Null;
                 "claims", `List [ `Assoc [ "id", `String "own"; "text", `String "text"; "scope", `List [];
                                           "requirements", `List []; "falsifier", `String "x";
                                           "register", `String "fact"; "environment", `String "" ] ] ] in
      write root "spec.json" (Yojson.Safe.pretty_to_string garbage);
      let refused = run root "map" in
      check "an empty environment of a claim is refused"
        (refused.code = 3 && contains refused.stderr "claim.environment");
      print_endline "claim-environment: PASS")

(* The journal receives every observation as soon as it is made. The second
   claim reads the journal of the first one while the run is still working. *)
let () =
  with_repo (fun root ->
      expect root "init" 0;
      expect root "goal \"the journal grows while the run works\" subject.txt owner" 0;
      write root "subject.txt" "expected\n";
      let first = { claim with id = "first";
                    requirements = [ Verifier "grep -q expected subject.txt" ];
                    control = Some "printf broken > subject.txt" } in
      let second = { claim with id = "second";
                     requirements = [ Verifier "grep -q '\"claim_id\":\"first\"' .math/v5/evidence.jsonl && grep -q expected subject.txt" ];
                     control = Some "printf broken > subject.txt" } in
      let goal = Some { text = "the journal grows while the run works";
                        scope = [ "subject.txt" ]; by = "owner"; at = 1; reason = None } in
      write root "spec.json"
        (Yojson.Safe.pretty_to_string (Spec.to_json { goal; claims = [ first; second ]; environment = None }));
      expect root "run" 0;
      let map = Yojson.Safe.from_string (run root "map --json").stdout in
      check "the first claim is proven" (state_of_map map "first" = "holds");
      check "the second claim sees the journal of the first one" (state_of_map map "second" = "holds");
      check "the journal holds one record per claim"
        (List.length (trail_records root) = 2);
      print_endline "journal-grows: PASS")

(* A repeated run does not make the journal ambiguous: the last observation of
   a claim and requirement is the one that counts. *)
let () =
  with_repo (fun root ->
      expect root "init" 0;
      expect root "goal \"the last observation counts\" subject.txt owner" 0;
      write root "subject.txt" "broken\n";
      expect root "add sample \"the subject is expected\" subject.txt \"not expected\" fact --requirement \"verifier:grep -q expected subject.txt\" --control \"printf broken > subject.txt\"" 0;
      expect root "run" 1;
      check "the first observation refutes the claim"
        (state_of_map (Yojson.Safe.from_string (run root "map --json").stdout) "sample" = "refuted");
      write root "subject.txt" "expected\n";
      expect root "run" 0;
      let map = Yojson.Safe.from_string (run root "map --json").stdout in
      check "the last observation decides the state" (state_of_map map "sample" = "holds");
      check "the journal keeps both observations and no duplicates"
        (List.length (trail_records root) = 2);
      print_endline "journal-last-observation: PASS")

(* An interrupted run keeps everything it has already proven. *)
let () =
  with_repo (fun root ->
      expect root "init" 0;
      expect root "goal \"an interrupted run keeps its evidence\" subject.txt owner" 0;
      write root "subject.txt" "expected\n";
      let first = { claim with id = "first";
                    requirements = [ Verifier "grep -q expected subject.txt" ];
                    control = Some "printf broken > subject.txt" } in
      let second = { claim with id = "second";
                     requirements = [ Verifier "sleep 30" ]; control = None } in
      let goal = Some { text = "an interrupted run keeps its evidence";
                        scope = [ "subject.txt" ]; by = "owner"; at = 1; reason = None } in
      write root "spec.json"
        (Yojson.Safe.pretty_to_string (Spec.to_json { goal; claims = [ first; second ]; environment = None }));
      let silent = Unix.openfile "/dev/null" [ Unix.O_WRONLY ] 0o666 in
      let pid = Unix.create_process (binary ()) [| binary (); "--root"; root; "run" |]
          Unix.stdin silent silent in
      Unix.close silent;
      let recorded line = List.exists (fun record -> contains record line) (trail_records root) in
      let deadline = Unix.gettimeofday () +. 60.0 in
      while not (recorded "\"claim_id\":\"first\"") && Unix.gettimeofday () < deadline do
        Unix.sleepf 0.1
      done;
      check "the finished claim is in the journal before the run ends" (recorded "\"claim_id\":\"first\"");
      Unix.kill pid Sys.sigterm;
      let _, status = Unix.waitpid [] pid in
      check "the interrupted run hands over the map instead of vanishing"
        (status = Unix.WEXITED 4);
      check "the interrupted run keeps the observation of the finished claim"
        (recorded "\"claim_id\":\"first\"");
      check "the interrupted run leaves no record of the unfinished claim"
        (not (recorded "\"claim_id\":\"second\""));
      let map = Yojson.Safe.from_string (run root "map --json").stdout in
      check "the map shows the finished claim as holds" (state_of_map map "first" = "holds");
      check "the map shows the unfinished claim as never checked"
        (state_of_map map "second" = "never-checked");
      print_endline "interrupted-run: PASS")

(* A partial run executes the claims whose evidence no longer holds and leaves
   the rest alone. The rule is the rule of freshness the map uses. *)
let () =
  with_repo (fun root ->
      expect root "init" 0;
      expect root "goal \"the subject is expected\" subject.txt,other.txt owner" 0;
      write root "subject.txt" "expected\n";
      write root "other.txt" "other\n";
      expect root "add sample \"the subject is expected\" subject.txt \"not expected\" fact --requirement \"verifier:grep -q expected subject.txt\" --control \"printf broken > subject.txt\"" 0;
      expect root "add other \"the other is expected\" other.txt \"not expected\" fact --requirement \"verifier:grep -q other other.txt\" --control \"printf broken > other.txt\"" 0;
      expect root "run" 0;
      let records_of id =
        trail_records root |> List.filter (fun record -> contains record ("\"claim_id\":\"" ^ id ^ "\""))
      in
      let sample_before = List.length (records_of "sample") in
      write root "other.txt" "changed\n";
      let partial = run root "run --changed" in
      check "a partial run says how much it executed"
        (contains partial.stdout "partial run: 1 of 2 claim(s) executed");
      check "a partial run leaves the current claim alone"
        (contains partial.stdout "sample                       holds (current)");
      check "a partial run does not rewrite the evidence of the current claim"
        (List.length (records_of "sample") = sample_before);
      check "a partial run executes the claim whose materials changed"
        (List.length (records_of "other") = 2);
      let json = run root "run --changed --json" in
      check "a partial run keeps the json clean"
        (contains json.stderr "partial run:"
        && (match Yojson.Safe.from_string json.stdout with
            | exception Yojson.Json_error _ -> false
            | _ -> true));
      print_endline "partial-run: PASS")

(* A claim the run cannot see is executed anyway: the method does not skip a
   claim it cannot see, and the map does not stay green for it. *)
let () =
  with_repo (fun root ->
      expect root "init" 0;
      expect root "goal \"the subject is expected\" subject.txt owner" 0;
      write root "subject.txt" "expected\n";
      expect root "add sample \"the subject is expected\" subject.txt \"not expected\" fact --requirement \"verifier:grep -q expected subject.txt\" --control \"printf broken > subject.txt\"" 0;
      expect root "run" 0;
      Sys.rename (Filename.concat root "subject.txt") (Filename.concat root "gone.txt");
      let partial = run root "run --changed" in
      check "a partial run executes the claim it cannot see"
        (contains partial.stdout "the subject of 1 claim(s) cannot be seen"
        && contains partial.stdout "the subject is not whole or does not exist");
      let map = run root "map" in
      check "a claim without a subject is not green"
        (map.code = 3 && contains map.stdout "inconclusive");
      print_endline "partial-run-blind: PASS")

(* The price of a run: the machine time is named in the report of the run and
   kept in the journal of runs. A record of the journal that cannot be read
   does not take the price of the other runs with it. *)
let () =
  with_repo (fun root ->
      expect root "init" 0;
      expect root "goal \"the subject is expected\" subject.txt owner" 0;
      write root "subject.txt" "expected\n";
      expect root "add sample \"the subject is expected\" subject.txt \"not expected\" fact --requirement \"verifier:grep -q expected subject.txt\" --control \"printf broken > subject.txt\"" 0;
      let report = run root "run" in
      check "the report names the price of the run"
        (contains report.stdout "machine time:");
      check "the report names the claim that was slow"
        (contains report.stdout "sample");
      let journal = Filename.concat root ".math/v5/runs.jsonl" in
      check "the journal of runs exists" (Sys.file_exists journal);
      let lines =
        String.split_on_char '\n' (Io.read_file journal) |> List.filter (fun line -> line <> "")
      in
      check "the journal of runs keeps one record of the run"
        (List.length lines = 1);
      let record = Yojson.Safe.from_string (List.hd lines) in
      check "the record names the machine time of the run"
        (match field "machine_seconds" record with
         | Some (`Float seconds) -> seconds >= 0.0
         | Some (`Int seconds) -> seconds >= 0
         | _ -> false);
      check "the record names the claim it measured"
        (match field "durations" record with
         | Some (`List [ item ]) -> (
             match item with
             | `Assoc pairs -> (
                 match List.assoc_opt "claim_id" pairs with
                 | Some (`String id) -> id = "sample"
                 | _ -> false)
             | _ -> false)
         | _ -> false);
      (* A record that cannot be read does not take the price of the other runs
         with it. *)
      write root ".math/v5/runs.jsonl"
        ("{\"schema_version\": 4, \"started_at\": 0}\n" ^ String.concat "\n" lines ^ "\n");
      let doctor = run root "doctor" in
      check "the doctor still names the price of the last run"
        (contains doctor.stdout "of machine time in 1 claim(s)");
      print_endline "run-price: PASS")

(* A run that is stopped says so and hands over the map over what was
   observed. An empty report after a stopped run is a lie: the reader cannot
   tell a run that proved nothing from a run that was never finished. *)
let () =
  with_repo (fun root ->
      expect root "init" 0;
      expect root "goal \"the subject is expected\" subject.txt owner" 0;
      write root "subject.txt" "expected\n";
      expect root "add sample \"the subject is expected\" subject.txt \"not expected\" fact --requirement \"verifier:grep -q expected subject.txt\" --control \"printf broken > subject.txt\"" 0;
      let stopped = run root "run --limit 0" in
      check "a stopped run says that it was stopped"
        (contains stopped.stdout "the run was stopped after 0 of 1 claim(s)");
      check "a stopped run hands over the map over what was observed"
        (contains stopped.stdout "never-checked");
      check "a stopped run does not pass the gate" (stopped.code = 4);
      let journal = Filename.concat root ".math/v5/runs.jsonl" in
      let lines =
        String.split_on_char '\n' (Io.read_file journal) |> List.filter (fun line -> line <> "")
      in
      let record = Yojson.Safe.from_string (List.hd lines) in
      check "the journal of runs keeps the stop"
        (match field "stopped" record with Some (`Bool true) -> true | _ -> false);
      check "the journal of runs keeps the reason of the stop"
        (match field "stop_reason" record with
         | Some (`String reason) -> contains reason "the limit of the run"
         | _ -> false);
      (* A run that finishes is not a stopped run. *)
      let finished = run root "run" in
      check "a run that finishes does not say that it was stopped"
        (not (contains finished.stdout "the run was stopped"));
      check "a run that finished gives the verdict of the map" (finished.code = 0);
      print_endline "stopped-run: PASS")
