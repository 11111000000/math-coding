(* tests/ci_blocking_list_test.ml — verifies decisions/ci-blocking-list-config.yaml
   obligations `blocking-cis-default-preserved` and
   `blocking-cis-reads-env-var`. The test exercises
   `Attestations.blocking_cis ()` under three env-var
   configurations: unset, set with a single CI, set with
   multiple CIs. The default branch falls back to the
   historical `blocking_cis_default`.

   The test is intentionally written against a single
   module to avoid coupling with the rest of the kernel;
   it imports only `Attestations`. *)

let[@warning "-32"] strip_newline s =
  let len = String.length s in
  if len > 0 && s.[len - 1] = '\n' then String.sub s 0 (len - 1) else s

let[@warning "-32"] assert_equal ~msg actual expected =
  if actual <> expected then
    Alcotest.failf "%s: expected %S, got %S" msg expected actual
  else ()

let[@warning "-32"] default_when_unset () =
  Unix.putenv "MATH_CODING_BLOCKING_CIS" "";
  let cis = Attestations.blocking_cis () in
  assert_equal ~msg:"default list when env unset" (String.concat "," cis)
    "payments-ci,orders-ci,integration-ci"

let[@warning "-32"] override_single () =
  Unix.putenv "MATH_CODING_BLOCKING_CIS" "ci-bot";
  let cis = Attestations.blocking_cis () in
  assert_equal ~msg:"single override" (String.concat "," cis) "ci-bot"

let[@warning "-32"] override_multiple () =
  Unix.putenv "MATH_CODING_BLOCKING_CIS" "ci-bot,security-bot,docs-bot";
  let cis = Attestations.blocking_cis () in
  assert_equal ~msg:"multiple override" (String.concat "," cis)
    "ci-bot,security-bot,docs-bot"

let[@warning "-32"] override_whitespace_tolerant () =
  Unix.putenv "MATH_CODING_BLOCKING_CIS" " ci-bot , security-bot ";
  let cis = Attestations.blocking_cis () in
  assert_equal ~msg:"whitespace tolerant" (String.concat "," cis)
    "ci-bot,security-bot"

let[@warning "-32"] override_empty_falls_back () =
  Unix.putenv "MATH_CODING_BLOCKING_CIS" ",,,";
  let cis = Attestations.blocking_cis () in
  assert_equal ~msg:"empty entries fall back to default" (String.concat "," cis)
    "payments-ci,orders-ci,integration-ci"

let () =
  let open Alcotest in
  run "ci_blocking_list"
    [
      ( "ci_blocking_list",
        [
          test_case "default when env unset" `Quick default_when_unset;
          test_case "single override" `Quick override_single;
          test_case "multiple override" `Quick override_multiple;
          test_case "whitespace tolerant" `Quick override_whitespace_tolerant;
          test_case "empty entries fall back" `Quick override_empty_falls_back;
        ] );
    ]
