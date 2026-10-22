(* tests/counters_reference.ml — conditional counters-drift guard.
 *
 * WHY THIS EXISTS ALONGSIDE tests/counters_drift.ml
 * --------------------------------------------------
 * `counters_drift.ml` asserts a STRUCTURAL contract: PACKAGES.md
 * and ROADMAP.md point at `mathc counters` (the single source of
 * truth) and do not carry the bolded `**<N> files**` pattern that
 * an earlier generation of the docs used. That contract is worth
 * keeping, and this test keeps it too — but on its own it cannot
 * fail on drift. Its rule matches ONE literal shape of one stale
 * number; a doc that says "34 subcommands total" in plain prose is
 * invisible to it. The name promises more than the rule delivers.
 *
 * This test implements the rule the name promises, in a form that
 * does not reintroduce the tax that got the original test
 * disabled (`decisions/disable-counters-drift-test-2026-10@1`:
 * every `attestations/*.json` commit turned the equality check
 * red). The conditional is the whole trick:
 *
 *   - a doc that states NO live count is checked only for the
 *     SoT reference (zero cost, forever — adding an attestation
 *     changes nothing);
 *   - a doc that DOES state a live count for a countable fact is
 *     checked for EQUALITY with the live count. The author opted
 *     into the number, so the author owns keeping it true.
 *
 * Two exemptions keep historical prose out of the equality rule,
 * and both were calibrated against the actual corpus rather than
 * guessed (see `decisions/self-check-waiver-verdict-coherence-
 * 2026-10.yaml`, obligation `counters-reference-no-false-
 * positives`):
 *
 *   1. Dated paragraphs are snapshots. PACKAGES.md's counter
 *      block reads "Last updated at: HEAD `3c64970` (2026-10-14):
 *      ... 857 attestations ... 67 cram files". Those numbers are
 *      a claim about that commit, not about today, and they are
 *      verifiable against that commit. A backticked hex sha, an
 *      ISO date, the word `Previous`, `HEAD`, or a `v3.x` version
 *      marker in the paragraph exempts every claim in it.
 *   2. Table rows are their own paragraphs. Without this, one
 *      dated row would exempt the whole table.
 *
 * What is deliberately NOT in scope: "N obligations" and bare
 * "N files". In this corpus those overwhelmingly denote a single
 * decision's own obligations or a specific past cycle's file
 * count ("audit-0.0.21-fixes ... by generating 27 attestations"),
 * not a repository total. Matching them would produce false
 * positives on correct, stable prose — the failure mode that
 * made the previous detector useless.
 *
 * LIVE VALUES come from `Sys.readdir` in-process. No subprocess,
 * no fork, no pipe: the earlier incarnation of this test hung
 * `dune test` in dune's parallel-alcotest harness by shelling out
 * to `mathc counters --format=json`, which is exactly why it was
 * disabled. The mapping used here is the one
 * `decisions/enable-counters-drift-test-2026-10` assumed and this
 * file now verifies: `attestations/*.json` ->
 * `attestations.live_store`, `decisions/*.yaml` ->
 * `decisions.total`, `tests/cli/*.t` -> `tests.cram_count`. *)

open Alcotest

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

(* --- live counts ------------------------------------------------- *)

let[@warning "-32"] count_suffix dir suffix =
  if not (Sys.file_exists dir) then 0
  else if not (Sys.is_directory dir) then 0
  else
    try
      Sys.readdir dir |> Array.to_list
      |> List.filter (fun f -> Filename.check_suffix f suffix)
      |> List.length
    with _ -> 0

(* `decisions.total` in `mathc counters` counts every `.yaml` in
   `decisions/`, meta aggregators included (`do_counters`'s
   `enumerate_decisions` returns the full list and subtracts the
   meta files only for `.active`). Match `total`. *)
let[@warning "-32"] live_decision_files () =
  count_suffix (in_repo "decisions") ".yaml"

let[@warning "-32"] live_attestations () =
  count_suffix (in_repo "attestations") ".json"

let[@warning "-32"] live_cram_files () = count_suffix (in_repo "tests/cli") ".t"

(* Dispatcher shape, same parse as `bin/Mathc.ml::subcommand_names`:
   a trimmed line of the form `| "name" -> do_handler`. Counting
   those lines counts the subcommands the CLI actually dispatches,
   which is the number a doc claims when it says "N subcommands". *)
let[@warning "-32"] live_subcommands () =
  let text = read_file (in_repo "bin/Mathc.ml") in
  let lines = String.split_on_char '\n' text in
  let starts_with ~needle s =
    let n = String.length needle and l = String.length s in
    l >= n
    &&
    let rec loop i =
      i >= n || (String.get s i = String.get needle i && loop (i + 1))
    in
    loop 0
  in
  List.fold_left
    (fun acc line ->
      let t = String.trim line in
      if
        String.length t > 6
        && starts_with ~needle:"| \"" t
        &&
        let rest = String.sub t 3 (String.length t - 3) in
        let rec arrow i =
          i + 6 <= String.length rest
          && ((String.sub rest i 3 = "-> " && String.sub rest (i + 3) 3 = "do_")
             || arrow (i + 1))
        in
        arrow 0
      then acc + 1
      else acc)
    0 lines

(* --- text scanning (no Str: hand-rolled so the patterns stay
 *     readable and the test needs no extra library) --------------- *)

let[@warning "-32"] find_all haystack needle =
  let hlen = String.length haystack and nlen = String.length needle in
  let rec loop i acc =
    if i + nlen > hlen then List.rev acc
    else if String.sub haystack i nlen = needle then loop (i + 1) (i :: acc)
    else loop (i + 1) acc
  in
  if nlen = 0 then [] else loop 0 []

let[@warning "-32"] is_digit c = c >= '0' && c <= '9'

let[@warning "-32"] is_hex c =
  is_digit c || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')

(* A paragraph is dated if it carries a backticked hex sha of 7+
   chars, an ISO date, or one of the release markers the docs use
   for their snapshot blocks. *)
let[@warning "-32"] contains_at haystack needle from =
  let n = String.length needle and h = String.length haystack in
  let rec loop i =
    if i < 0 || i + n > h then None
    else if String.sub haystack i n = needle then Some i
    else loop (i - 1)
  in
  loop (min from (h - n))

let[@warning "-32"] paragraph_has_iso_date paragraph =
  let h = String.length paragraph in
  let rec loop i =
    if i + 10 > h then false
    else if
      String.sub paragraph i 4 = "20"
      && paragraph.[i + 4] = '-'
      && is_digit paragraph.[i + 5]
      && paragraph.[i + 7] = '-'
      && is_digit paragraph.[i + 8]
    then true
    else loop (i + 1)
  in
  loop 0

let[@warning "-32"] paragraph_has_sha paragraph =
  let h = String.length paragraph in
  List.exists
    (fun i ->
      i + 9 <= h
      && paragraph.[i] = '`'
      && is_hex paragraph.[i + 1]
      &&
      let rec run j n =
        if j < h && is_hex paragraph.[j] then run (j + 1) (n + 1) else n >= 7
      in
      run (i + 1) 0)
    (List.init h (fun i -> i))

let[@warning "-32"] paragraph_is_dated paragraph =
  let lowered = String.lowercase_ascii paragraph in
  let contains needle =
    List.length (find_all lowered (String.lowercase_ascii needle)) > 0
  in
  paragraph_has_sha paragraph
  || paragraph_has_iso_date paragraph
  || contains "previous" || contains "last updated at" || contains "head"
  || (contains "v3." && contains "20")

(* Clauses are delimited by a sentence end, a newline, a semicolon,
   an em dash, or a slash-separated counter list. A claim is
   "live-scoped" when its own clause says the number is a total or
   a current state; "by generating 27 attestations" is not. *)
let[@warning "-32"] delimiters = [ ". "; "\n"; ";"; " — "; " / " ]

let[@warning "-32"] first_from haystack needle from =
  let n = String.length needle and h = String.length haystack in
  let rec loop i =
    if i < 0 || i + n > h then None
    else if String.sub haystack i n = needle then Some i
    else loop (i + 1)
  in
  loop from

let[@warning "-32"] clause_around paragraph index =
  let h = String.length paragraph in
  let starts =
    List.filter_map (fun d -> contains_at paragraph d (index - 1)) delimiters
  in
  let ends =
    List.filter_map (fun d -> first_from paragraph d index) delimiters
  in
  let lo = List.fold_left (fun acc i -> max acc (i + 1)) 0 starts in
  let hi = match ends with [] -> h | l -> List.fold_left min h l in
  if hi <= lo then paragraph else String.sub paragraph lo (hi - lo)

let[@warning "-32"] qualifiers =
  [
    "total";
    "live";
    "currently";
    "on disk";
    "in the repo";
    "in this repository";
    "there are";
    "overall";
    "now ";
  ]

let[@warning "-32"] clause_is_live_scoped clause =
  let lowered = String.lowercase_ascii clause in
  List.exists (fun q -> List.length (find_all lowered q) > 0) qualifiers

(* --- the check --------------------------------------------------- *)

(* A live claim is `N <noun>`: walk back from the noun over spaces
   and pick up the digits (with thousands separators) that precede
   it. Returns None when the noun is not preceded by a number, which
   is the common case (`attestations/` mentions, table headers). *)
let[@warning "-32"] number_before paragraph noun_start =
  let rec back i =
    if i < 0 then None
    else
      let c = paragraph.[i] in
      if c = ' ' || c = '\t' then back (i - 1)
      else if is_digit c || c = ',' then
        let rec digits j =
          if j < 0 then Some (j + 1, i + 1)
          else if is_digit paragraph.[j] || paragraph.[j] = ',' then
            digits (j - 1)
          else Some (j + 1, i + 1)
        in
        digits i
      else None
  in
  back (noun_start - 1)

let[@warning "-32"] parse_count s =
  let digits =
    String.to_seq s |> Seq.filter (fun c -> c <> ',') |> String.of_seq
  in
  int_of_string_opt digits

(* Paragraphs: blank line OR markdown table row starts a new one. *)
let[@warning "-32"] paragraphs text =
  let lines = String.split_on_char '\n' text in
  let is_row l =
    String.length l > 0 && (String.get l 0 = '|' || String.get l 0 = ' ')
  in
  let rec loop acc cur = function
    | [] ->
        if cur = [] then List.rev acc
        else List.rev (String.concat "\n" cur :: acc)
    | l :: rest ->
        if String.trim l = "" then loop (String.concat "\n" cur :: acc) [] rest
        else if is_row l && cur <> [] then
          loop
            (String.concat "\n" cur :: String.concat "\n" [ l ] :: acc)
            [] rest
        else loop acc (l :: cur) rest
  in
  List.filter (fun p -> String.trim p <> "") (loop [] [] lines)

type fact = { noun : string; live : int; counter_path : string }

let[@warning "-32"] facts () =
  [
    {
      noun = "attestation";
      live = live_attestations ();
      counter_path = "attestations.live_store";
    };
    {
      noun = "decision files";
      live = live_decision_files ();
      counter_path = "decisions.total";
    };
    {
      noun = "cram files";
      live = live_cram_files ();
      counter_path = "tests.cram_count";
    };
    {
      noun = "subcommands";
      live = live_subcommands ();
      counter_path = "cli.subcommand_count";
    };
  ]

(* Every live-scoped, undated `N <noun>` claim in `text`, reported as
   the numbers the doc asserts. Two docs and four nouns is a
   handful of matches; the scan is linear and the whole test runs
   in well under a millisecond. *)
let[@warning "-32"] live_claims text fact =
  List.concat_map
    (fun paragraph ->
      if paragraph_is_dated paragraph then []
      else
        List.concat_map
          (fun noun_start ->
            match number_before paragraph noun_start with
            | None -> []
            | Some (ds, de) -> (
                let claimed = parse_count (String.sub paragraph ds (de - ds)) in
                let clause = clause_around paragraph noun_start in
                match claimed with
                | Some n when clause_is_live_scoped clause ->
                    [ (n, String.trim clause) ]
                | _ -> []))
          (find_all paragraph fact.noun))
    (paragraphs text)

let[@warning "-32"] docs = [ "PACKAGES.md"; "ROADMAP.md" ]

let[@warning "-32"] check_reference path =
  let text = read_file (in_repo path) in
  check bool
    (Printf.sprintf "%s points at `mathc counters` as the SoT" path)
    true
    (List.length (find_all text "mathc counters") > 0)

let[@warning "-32"] check_fact path fact =
  let text = read_file (in_repo path) in
  List.iter
    (fun (claimed, clause) ->
      check int
        (Printf.sprintf
           "%s: %S is the live %s (`mathc counters` -> %s); state the count, \
            date it, or point at the SoT instead"
           path clause fact.noun fact.counter_path)
        fact.live claimed)
    (live_claims text fact)

let () =
  let facts = facts () in
  let cases =
    List.concat_map
      (fun path ->
        [
          ( Printf.sprintf "%s names the source of truth" path,
            [
              ( Printf.sprintf "%s points at `mathc counters`" path,
                `Quick,
                fun () -> check_reference path );
            ] );
          ( Printf.sprintf "%s states live counts correctly" path,
            List.map
              (fun fact ->
                ( Printf.sprintf "%s: %s" path fact.noun,
                  `Quick,
                  fun () -> check_fact path fact ))
              facts );
        ])
      docs
  in
  run
    ~log_dir:(Filename.concat (Filename.get_temp_dir_name ()) "mathc-alcotest")
    "counters reference" cases
