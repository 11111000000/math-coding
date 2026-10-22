(* tests/counters_drift.ml
 *
 * Structural drift guard for PACKAGES.md and ROADMAP.md.
 *
 * PACKAGES.md and ROADMAP.md MUST NOT carry per-checkout live
 * numbers (attestation count, cram-file count, active-decision
 * count, subcommand count, etc.) in their counter blocks — every
 * such number drifts the moment a sibling session lands an
 * `attestations/*.json`, `decisions/*.yaml`, or `tests/cli/*.t`
 * commit. The only authoritative source of those numbers is
 * `mathc counters --format=json` (see
 * `decisions/mathc-counters-subcommand-2026-10`); the docs
 * reference it as the single source of truth and MUST NOT
 * re-state any of those counts in prose.
 *
 * The drift is enforced structurally:
 *   1. PACKAGES.md and ROADMAP.md each contain the literal
 *      phrase `mathc counters` near the live-counter block.
 *   2. PACKAGES.md and ROADMAP.md do NOT carry the brittle
 *      bolded-attestation-count pattern `**<number> files**`
 *      that the prior equality check used to anchor on. The
 *      narrow scope catches a regression to the old contract
 *      without false-positives on historical `X cram files
 *      under <commit>` or `X subcommands` style prose.
 *
 * Adding a new `attestations/tmp-drift-probe.json` (or any
 * other `attestations/*.json`, `decisions/*.yaml`, or
 * `tests/cli/*.t`) MUST NOT break this test, because the test
 * does not read any on-disk count. This is the
 * class-of-failure fix; the prior equality-based contract
 * (see `decisions/enable-counters-drift-test-2026-10`) was
 * structurally incompatible with parallel-session commits and
 * broke the day a sibling session added two attestation files
 * (commit ce3e26e). The replacement contract — prose points at
 * the SoT, the SoT is the SoT — is drift-proof by
 * construction. *)

let[@warning "-32"] project_root () =
  let cwd = Sys.getcwd () in
  let rec find d =
    if Sys.file_exists (Filename.concat d "dune-project") then d
    else
      let parent = Filename.dirname d in
      if parent = d then cwd else find parent
  in
  find cwd

let[@warning "-32"] in_repo name = Filename.concat (project_root ()) name

let[@warning "-32"] read_file path =
  try In_channel.with_open_bin path In_channel.input_all with _ -> ""

let[@warning "-32"] substring ~needle ~haystack =
  let nlen = String.length needle in
  let hlen = String.length haystack in
  let rec loop i =
    if i + nlen > hlen then false
    else if String.sub haystack i nlen = needle then true
    else loop (i + 1)
  in
  loop 0

(* Narrow scope on purpose: only the bolded-attestation-count
   pattern that the original test was failing on. Wider patterns
   (`X cram files in`, `X active decisions`, etc.) catch
   historical commentary inside `PACKAGES.md`'s changelog and
   `decisions/*.yaml` records, which are anchored to a specific
   commit ref and are out of scope for this drift detector. *)
let[@warning "-32"] bolded_attestation_count_pat =
  Str.regexp "\\*\\*[0-9][0-9,]* files\\*\\*"

let[@warning "-32"] has_bolded_attestation_count haystack =
  try
    ignore (Str.search_forward bolded_attestation_count_pat haystack 0);
    true
  with Not_found -> false

(* For a useful diagnostic on failure, build a short snippet
   showing the offending substring and its line number. *)
let[@warning "-32"] bolded_match_diagnostic haystack =
  match Str.search_forward bolded_attestation_count_pat haystack 0 with
  | exception Not_found -> "<no match>"
  | _ ->
      let matched = Str.matched_string haystack in
      let pos = Str.match_end () in
      (* Approximate the line: count '\n' in haystack up to the
         match end position. *)
      let line =
        let rec loop i n =
          if i >= pos then n + 1
          else
            let c =
              if i < String.length haystack then haystack.[i] else '\000'
            in
            loop (i + 1) (if c = '\n' then n + 1 else n)
        in
        loop 0 0
      in
      Printf.sprintf "line %d: %S" line matched

let[@warning "-32"] check_no_drift () =
  let pkg = read_file (in_repo "PACKAGES.md") in
  let road = read_file (in_repo "ROADMAP.md") in
  Alcotest.(check bool)
    "PACKAGES.md references `mathc counters`" true
    (substring ~needle:"mathc counters" ~haystack:pkg);
  Alcotest.(check bool)
    "ROADMAP.md references `mathc counters`" true
    (substring ~needle:"mathc counters" ~haystack:road);
  Alcotest.(check bool)
    (Printf.sprintf "PACKAGES.md does not carry bolded attestation count (%s)"
       (bolded_match_diagnostic pkg))
    false
    (has_bolded_attestation_count pkg);
  Alcotest.(check bool)
    (Printf.sprintf "ROADMAP.md does not carry bolded attestation count (%s)"
       (bolded_match_diagnostic road))
    false
    (has_bolded_attestation_count road)

let () =
  Alcotest.run "counters drift"
    [
      ( "docs reference mathc counters",
        [ Alcotest.test_case "no drift" `Quick check_no_drift ] );
    ]
