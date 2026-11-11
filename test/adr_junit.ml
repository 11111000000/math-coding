open Helpers

let madr = {|
---
status: accepted
---
# Use an expiring waiver

## Context and problem statement

The risk has an owner.

## Decision outcome

Waiver expires and has a recovery action.

### Consequences

- old evidence is not promoted
- reviews are re-evaluated
|}

let junit = {|<testsuite name="sample" tests="2" failures="1" errors="0" skipped="0">
  <testcase classname="a" name="ok"/>
  <testcase classname="a" name="bad"><failure message="no"/></testcase>
</testsuite>|}

let () =
  with_repo (fun root ->
      write root "docs/adr/0001-waiver.md" madr;
      let before = Git.digest_of_file (Filename.concat root "docs/adr/0001-waiver.md") in
      let result = run root "import-adr docs/adr/0001-waiver.md" in
      check "ADR import succeeds" (result.code = 0);
      check "ADR import has source digest" (contains result.stdout "digest");
      check "ADR import does not activate" (contains result.stdout "\"requirements\": []");
      let after = Git.digest_of_file (Filename.concat root "docs/adr/0001-waiver.md") in
      check "ADR file is unchanged" (before = after);
      write root "report.xml" junit;
      let report = run root "import-junit report.xml" in
      check "JUnit import succeeds" (report.code = 0);
      check "JUnit counts are exact" (contains report.stdout "\"test_count\": 2" && contains report.stdout "\"failure_count\": 1");
      check "JUnit failure message is preserved" (contains report.stdout "no");
      let sources = run root "adopt" in
      check "adopt is read-only and detects ADR" (contains sources.stdout "madr" && contains sources.stdout "read-only");
      print_endline "adr-junit: PASS")
