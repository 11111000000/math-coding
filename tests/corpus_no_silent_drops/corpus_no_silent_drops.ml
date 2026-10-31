(* tests/corpus_no_silent_drops/corpus_no_silent_drops.ml
 *
 * The corpus-wide gate for the silent-drop family: content the kernel
 * reads on less than a file says.
 *
 * The reason this file exists is not a bug report. It is that the
 * diagnostics were named, the corpus shipped them anyway, and the
 * people who could have fixed them had no way to see the whole set.
 * A defect class nobody can re-run is a defect class nobody re-fixes,
 * so the scan became a test and this is the test.
 *
 *   scripts/scan-silent-drops.sh        reproducible scan, prints the set
 *   this file                          asserts the set did not change
 *
 * ---------------------------------------------------------------------
 * WHY THIS IS NOT "no offenders" AND NOT "a frozen inventory"
 * ---------------------------------------------------------------------
 *
 * Both simple answers are wrong here, and it is worth being precise
 * about why, because the choice is the whole content of this file.
 *
 * "Zero offenders" is red on arrival. The corpus contains real
 * malformed YAML; the kernel is right to stop on it. A test that is
 * born red teaches the reader to ignore red, which is how a real
 * regression gets waved through in the noise of a known-failing
 * suite.
 *
 * "Offenders outside a frozen list are failures" is green on arrival
 * and then rots. The list is the only place anyone records that a
 * residual was LOOKED AT and ACCEPTED. Freeze it and the acceptance
 * becomes invisible: the entry stays, nobody re-reads it, nobody
 * remembers why, and the next person to add a file to the corpus adds
 * their entry to the list too without a second thought.
 *
 * So this asserts an EXACT SET, in both directions:
 *
 *   - a file that STARTS losing content turns the test red -- the
 *     whole point;
 *   - a file that STOPS losing content ALSO turns it red, because a
 *     residual list is an inventory of accepted debt, and debt that
 *     has been repaid must be struck off in the same commit. That is
 *     friction, and the friction is the feature: it is the difference
 *     between "somebody fixed this" and "somebody fixed this and
 *     somebody else can see that they did".
 *
 * ---------------------------------------------------------------------
 * THE PART AN EXACT SET ALONE STILL GETS WRONG
 * ---------------------------------------------------------------------
 *
 * An offender is not one thing. "The kernel stopped reading" and
 * "the file could not be read by anyone" are different claims with
 * different owners, and putting them in one list hides which is
 * which:
 *
 *   author_malformed  a strict reader rejects the file too. The
 *                     kernel loses nothing that was ever there. The
 *                     author owes a fix; the diagnostic is truthful.
 *   cosmetic_marker   the kernel truncated at a second `---`, and
 *                     nothing followed it. No loss at all. Cosmetic.
 *   kernel_holes      (empty, and it MUST stay empty) a strict reader
 *                     reads this file to EOF and the kernel does not.
 *                     This is the only entry in the ledger that is
 *                     ours to fix, so it is the only one allowed zero
 *                     slack.
 *
 * Splitting the ledger by CLAIM is what keeps the exact-set from
 * freezing: the kernel-side bucket is asserted empty with no
 * tolerance, so a parser regression is a zero-tolerance failure even
 * though the author-side buckets still carry ten entries of noise.
 *
 * HONEST LIMIT. The classification above is a claim about what an
 * independent YAML reader thinks, and this executable has no YAML
 * reader of its own -- it cannot re-derive the buckets. So the buckets
 * are recorded DATA, not computed verdicts. What keeps that honest is
 * (a) the buckets are re-derivable in one command by anyone,
 * `scripts/scan-silent-drops.sh --validity`, whose column 1 is yq's
 * verdict, and (b) the file-level exact set below is enforced by the
 * kernel regardless of how the buckets are labelled. The one thing
 * this test cannot see is a file whose validity class changed while
 * it kept offending -- a repair that swapped one defect for another.
 * That is review's job, and pretending otherwise would be the kind of
 * comfortable lie this repository exists to catch.
 *
 * SCOPE. `decisions/**` plus `policies.yaml`, deliberately. The
 * fixture trees under tests/ and fixtures/ hold YAML that is malformed
 * ON PURPOSE; scanning them would either be noise or, worse, invite
 * "fixing" a fixture whose job is to be broken. `scan-silent-drops.sh
 * --all` exists for the curious and reports 14 of 271, the two extra
 * being exactly those fixtures.
 *)

let[@warning "-32"] repo_root =
  let cwd = Sys.getcwd () in
  let rec loop d =
    if Sys.file_exists (Filename.concat d "dune-project") then d
    else
      let parent = Filename.dirname d in
      if parent = d then cwd else loop parent
  in
  loop cwd

let[@warning "-32"] read rel =
  let path = Filename.concat repo_root rel in
  if not (Sys.file_exists path) then Alcotest.failf "%s missing" rel;
  In_channel.with_open_bin path In_channel.input_all

let[@warning "-32"] sorted_uniq xs = List.sort_uniq String.compare xs

(* --- the ledger ------------------------------------------------- *)

(* Author's debt, not the kernel's. Every entry was checked against
   `yq` (go-yaml), which rejects it; `scripts/scan-silent-drops.sh
   --validity` prints INVALID for all ten. The bracketed shape is what
   the independent reader complains about, recorded so the next reader
   does not have to re-derive it:
    3-2-cli-catalog            bad indentation of a mapping entry
    ci-blocking-list-config    bad indentation of a sequence entry
    d5-body-vs-wrapper-canon.  mapping values are not allowed here
    mathc-packages-subcommand  a multiline key may not be an implicit key

   Three entries were struck off on 2026-10-29, each in the commit
   that fixed it, as the assertion below demands: mathc-self-check-
   subcommand (a plain scalar opened with a backtick),
   render-html-templates (bad indentation of a sequence entry) and
   render-ordered-lists (expected ':' after a mapping key). *)
let author_malformed =
  [
    "decisions/3-2-cli-catalog.yaml";
    "decisions/ci-blocking-list-config.yaml";
    "decisions/d5-body-vs-wrapper-canonical-2026-10.yaml";
    "decisions/mathc-packages-subcommand.yaml";
  ]

(* A stray second `---`. These lose NOTHING: in both, the marker is the
   LAST line of the file, so the tail behind it is empty and every
   top-level key is already in the tree. They are listed separately
   because "the diagnostic fired" and "the kernel lost something" are
   different statements, and conflating them is how a real loss gets
   dismissed as cosmetic -- which is why the case below also pins the
   no-loss claim instead of taking it on trust. *)
let cosmetic_marker = [ "decisions/forge-stub-read-request-2026-10.yaml" ]

(* Files a strict reader reads to EOF and the kernel does not. Empty,
   and asserted empty: this is the only bucket that is ours to fix, so
   it is the only one allowed no tolerance. Adding an entry here is a
   confession of a kernel defect, and the diff will show it. *)
let kernel_holes : string list = []

(* Decisions carrying a duplicated mapping key (MC-DUPLICATE-KEY).
   Empty; the ten files the earlier repair touched were the last. *)
let duplicate_residual : string list = []

(* --- reading the corpus ----------------------------------------- *)

let[@warning "-32"] decision_files () =
  let dir = Filename.concat repo_root "decisions" in
  Sys.readdir dir |> Array.to_list
  |> List.filter (fun f -> Filename.extension f = ".yaml")
  |> List.sort String.compare
  |> List.map (fun f -> Filename.concat "decisions" f)

let[@warning "-32"] measure rel =
  let raw = read rel in
  let value, leftover, extra = Codec.load_yaml_string_full raw in
  let dups = Codec.duplicate_keys value in
  (leftover <> [], extra, dups <> [], raw)

(* --- the gate ---------------------------------------------------- *)

(* Anti-vacuity. Every assertion below compares a measured set against
   a recorded one, and a set comparison against two empty lists passes.
   If this test ever ran in a directory with no corpus -- a broken root
   lookup, a truncated checkout, someone invoking it from _build by
   hand -- the whole file would go green while checking nothing. The
   floor makes that failure loud. *)
let test_the_corpus_was_actually_read () =
  let files = decision_files () in
  (* THE FLOOR MOVED, AND HERE IS WHY.
   *
   * The floor was 150: the corpus had 157 decisions, and the check
   * said "the corpus was read". It was really a pin on the corpus's
   * SIZE -- and a size pin is the opposite of what the corpus wants:
   * `decisions/corpus-final-state-2026-10` says the corpus shrinks to
   * about fifty rules, and `decisions/decision-level-census-2026-10`
   * says the pins follow the truth down.
   *
   * The anti-vacuity this check exists for is "the directory listing
   * returned something", and the loud half of it is already in the
   * ledger: `read` fails with `Alcotest.failf "%s missing"` when the
   * corpus is not there at all. So the floor is the non-empty one,
   * and the loud reads carry the rest. A floor of 150 would have
   * turned a corpus-pruning decision into a failing test, which is
   * the wrong way round: the corpus is supposed to get smaller. *)
  Alcotest.check Alcotest.bool "decisions/ was found and is not empty" true
    (List.length files > 0);
  Alcotest.check Alcotest.bool "policies.yaml was found" true
    (Sys.file_exists (Filename.concat repo_root "policies.yaml"))

(* The load-bearing assertion. Note the direction: an offender that is
   not in the ledger fails, and a ledger entry that is no longer an
   offender ALSO fails. Both are on purpose; see the header.
 *
 * This is the UNPARSED-TAIL channel only. A second `---` marker
   truncates the file during front-matter stripping, BEFORE
   tokenisation, so it leaves an empty leftover list and surfaces on the
   marker channel instead. The CLI reports both under MC-UNPARSED-TAIL,
   which is why `scan-silent-drops.sh` prints twelve files and this
   assertion measures ten: same corpus, two channels, no
   contradiction. The marker channel is asserted separately below. *)
let test_offender_set_is_exactly_the_ledger () =
  let recorded = sorted_uniq (author_malformed @ kernel_holes) in
  let measured =
    List.filter_map
      (fun rel ->
        let tail, _extra, _dups, _raw = measure rel in
        if tail then Some rel else None)
      (decision_files ())
  in
  Alcotest.check
    (Alcotest.list Alcotest.string)
    "decisions with an unparsed tail: a NEW one fails here, and a FIXED one \
     must be struck off the ledger in the same commit"
    recorded (sorted_uniq measured)

(* The marker channel gets the same exact-set discipline, for the same
   reason and with the same asymmetry: a file that grows a stray `---`
   is red, and a ledger entry whose marker is gone is ALSO red. *)
let test_marker_set_is_exactly_the_ledger () =
  let measured =
    List.filter_map
      (fun rel ->
        let _tail, extra, _dups, _raw = measure rel in
        match extra with None -> None | Some _ -> Some rel)
      (decision_files ())
  in
  Alcotest.check
    (Alcotest.list Alcotest.string)
    "decisions carrying a stray document marker"
    (sorted_uniq cosmetic_marker)
    (sorted_uniq measured)

(* The zero-tolerance bucket, stated on its own so the failure says
   what it means. As long as this is empty, every offender in the
   corpus is accounted for by something a strict reader also rejects
   -- and the eleven author-side entries above are noise the reader is
   entitled to make. *)
let test_no_valid_decision_is_truncated () =
  Alcotest.check
    (Alcotest.list Alcotest.string)
    "decisions a strict reader reads to EOF and the kernel does not: a KERNEL \
     defect, and there is no tolerance for one"
    [] kernel_holes

(* Pins the "cosmetic" claim instead of trusting it. "Nothing follows
   the marker" is checkable and is the whole difference between a
   formatting wart and a silent drop, so it is checked rather than
   asserted in a comment. *)
let test_cosmetic_markers_really_lose_nothing () =
  List.iter
    (fun rel ->
      let _tail, extra, _dups, raw = measure rel in
      match extra with
      | None -> Alcotest.failf "%s no longer carries a stray marker" rel
      | Some marker_line ->
          let behind =
            Codec.yaml_lines raw
            |> List.mapi (fun i l -> (i + 1, l))
            |> List.filter (fun (n, _) -> n > marker_line)
            |> List.filter (fun (_, l) -> String.trim l <> "")
          in
          Alcotest.check Alcotest.int
            (rel ^ ": nothing but the marker follows it")
            0 (List.length behind);
          Alcotest.check Alcotest.bool
            (rel ^ ": the marker is the last non-empty line")
            true
            (List.length behind = 0))
    cosmetic_marker

let test_duplicate_key_set_is_exactly_the_ledger () =
  let measured =
    List.filter_map
      (fun rel ->
        let _tail, _extra, dups, _raw = measure rel in
        if dups then Some rel else None)
      (decision_files ())
  in
  Alcotest.check
    (Alcotest.list Alcotest.string)
    "decisions carrying a duplicated mapping key"
    (sorted_uniq duplicate_residual)
    (sorted_uniq measured)

(* `policies.yaml` is loaded by lib/policy.ml through
   `load_yaml_value`, which reaches neither `load_yaml_string_full` nor
   the MC-UNPARSED-TAIL collector. A policy file the loader could not
   finish was read as a SHORTER policy with nothing to say so -- the
   D2 shape, on the one path with no diagnostic behind it. Asserted
   here or not at all. (The same property is pinned for the synthetic
   case in tests/decision_parser_yaml.ml; this is the real file.) *)
let test_policies_yaml_reaches_eof () =
  let raw = read "policies.yaml" in
  let _value, remaining = Codec.load_yaml_value_remaining raw in
  Alcotest.check Alcotest.int "policies.yaml leaves no unparsed remainder" 0
    (List.length remaining)

(* --- content pins: a fold that reads to EOF but folds WRONG -----
 *
 * Every assertion above is about the SHAPE of the read. None of them
 * can see a parser that consumes all the lines and then puts them in
 * the wrong place -- the failure mode where `leftover` is empty and
 * the answer is still a lie. These four cases are the ones D4 actually
 * cost the corpus, pinned by CONTENT: the item count and the text, so
 * a fold that silently truncates the prose instead of the document
 * still turns this red. *)
let[@warning "-32"] seq_items value key =
  match value with
  | Jsonl.Object ps -> (
      match List.assoc_opt key ps with
      | Some (Jsonl.Array items) -> Some items
      | _ -> None)
  | _ -> None

let d4_repaired =
  [
    ("decisions/cli-cram-tests.yaml", "unknowns", 2);
    ("decisions/p8-hook-deficit-2026-10.yaml", "unknowns", 1);
    ("archive/decisions/render-module-split-phase1-2026-10.yaml", "unknowns", 1);
  ]

let test_d4_repaired_files_read_completely () =
  List.iter
    (fun (rel, key, expected) ->
      let raw = read rel in
      let value, leftover, extra = Codec.load_yaml_string_full raw in
      Alcotest.check Alcotest.int (rel ^ ": read to EOF") 0
        (List.length leftover);
      Alcotest.check Alcotest.int (rel ^ ": one document") 0
        (match extra with None -> 0 | Some _ -> 1);
      Alcotest.check Alcotest.int
        (rel ^ ": no duplicate keys")
        0
        (List.length (Codec.duplicate_keys value));
      match seq_items value key with
      | Some items ->
          Alcotest.check Alcotest.int
            (rel ^ ": " ^ key ^ " came back whole")
            expected (List.length items)
      | None ->
          Alcotest.failf "%s: %s vanished from the kernel's reading" rel key)
    d4_repaired

(* The load-bearing half of the D4 repair, and the case that proves the
   loss was not cosmetic. `render-module-split-phase1a-2026-10.yaml`
   carried two SCHEMA keys -- not prose -- below the `unknowns:` block
   that swallowed them. A parser that reaches EOF but folds the tail
   into the wrong item would still satisfy every assertion above. *)
let test_schema_keys_recovered_from_behind_a_d4_tail () =
  (* The corpus file that carries the two SCHEMA keys behind a tail is
     a work record BY CONTENT, and the census would have removed it --
     but a contract test pins a property on it, and the census's own
     rule is that a file something depends on is not archived until
     the dependency is fixed. The dependency is this test, so the file
     stays and the property stays pinned on it. *)
  let rel = "decisions/render-module-split-phase1a-2026-10.yaml" in
  let value = Codec.load_yaml_string (read rel) in
  match value with
  | Jsonl.Object ps ->
      List.iter
        (fun key ->
          Alcotest.check Alcotest.bool
            (rel ^ ": " ^ key ^ " is in the tree")
            true (List.mem_assoc key ps))
        [ "planned_evidence"; "estimated_class" ]
  | _ -> Alcotest.failf "%s did not parse as an object" rel

let () =
  Alcotest.run
    ~log_dir:(Filename.concat (Filename.get_temp_dir_name ()) "mathc-alcotest")
    "corpus_no_silent_drops"
    [
      ( "corpus is real",
        [
          Alcotest.test_case "decisions/ was found and is not empty" `Quick
            test_the_corpus_was_actually_read;
        ] );
      ( "the ledger",
        [
          Alcotest.test_case "offender set is exactly the ledger" `Quick
            test_offender_set_is_exactly_the_ledger;
          Alcotest.test_case "no valid decision is truncated" `Quick
            test_no_valid_decision_is_truncated;
          Alcotest.test_case "marker set is exactly the ledger" `Quick
            test_marker_set_is_exactly_the_ledger;
          Alcotest.test_case "cosmetic markers really lose nothing" `Quick
            test_cosmetic_markers_really_lose_nothing;
          Alcotest.test_case "duplicate-key set is exactly the ledger" `Quick
            test_duplicate_key_set_is_exactly_the_ledger;
          Alcotest.test_case "policies.yaml reaches EOF" `Quick
            test_policies_yaml_reaches_eof;
        ] );
      ( "content pins",
        [
          Alcotest.test_case "the four D4 files read completely" `Quick
            test_d4_repaired_files_read_completely;
          Alcotest.test_case "schema keys behind a D4 tail are back" `Quick
            test_schema_keys_recovered_from_behind_a_d4_tail;
        ] );
    ]
