(* tests/attestation_anchor.ml — pin the unanchored share of the store.
 *
 * `subject.candidate_tree` is what makes an attestation falsifiable: it
 * names the tree the observation was made against. Until
 * `candidate-tree-resolves-to-a-commit` it was a hardcoded literal in
 * the write path, and the whole committed corpus inherited that:
 * 749 files carry `HEAD`, 16 carry a branch name, and 0 carry a commit
 * SHA. A symbolic ref resolves to whatever the reader's HEAD is, so
 * none of those 765 observations can be reproduced or refuted. They
 * are DECLARATIONS, not anchored observations.
 *
 * That corpus cannot be retrofitted. An attestation's `id` is the
 * sha256 of its body, and `candidate_tree` is inside the body, so
 * rewriting the field would mint a new id for an observation nobody
 * re-ran -- manufacturing evidence for something that did not happen,
 * which is strictly worse than leaving it declared. So the corpus
 * stays as it is, and the honest move is to make the debt VISIBLE and
 * non-growing:
 *
 *   - `unanchored_count_does_not_grow` pins the number of tracked
 *     attestations whose `candidate_tree` is not a full object id.
 *     It may only ever go DOWN, as new anchored attestations are
 *     written alongside the old ones. It may never go up.
 *
 *   - `every_tracked_attestation_parses` pins that the whole tracked
 *     store still loads, so forward-only edits elsewhere cannot make
 *     the corpus unreadable.
 *
 * Only TRACKED files are counted. Test runs write gitignored
 * `attestations/t1-2-A0-*.json` into the store (see
 * `store_admission.ml` for why the loader filters those out), and
 * counting them would make this test depend on whether the suite had
 * been run. `git ls-files` is the same admission rule the kernel
 * applies at runtime, so the two cannot drift apart silently. *)

let[@warning "-32"] project_root =
  let cwd = Sys.getcwd () in
  let rec loop d =
    if Sys.file_exists (Filename.concat d "dune-project") then d
    else
      let parent = Filename.dirname d in
      if parent = d then d else loop parent
  in
  loop cwd

(* The count this test exists to hold still. Recorded 2026-10-23 by
 * walking `git ls-files attestations`: 765 tracked files, 0 anchored,
 * 765 unanchored, 0 unparseable. The 16 non-`HEAD` entries are branch
 * names (7 x feat/multi-policy-hierarchy-2026-10, 5 x
 * feat/mcp-server-stub-2026-10, 4 x fix/d8-coarse-diagnostics-2026-10),
 * which are pointers in exactly the same way. *)
let[@warning "-32"] pinned_unanchored = 765

let[@warning "-32"] is_full_object_id s =
  let n = String.length s in
  (n = 40 || n = 64)
  && String.for_all (function '0' .. '9' | 'a' .. 'f' -> true | _ -> false) s

(* `git ls-files attestations` -- the same tracked-files rule the
 * loader's `store_keep_for` enforces, so the corpus this test counts
 * is the corpus the gate reads. *)
let[@warning "-32"] tracked_attestations () =
  let out = Filename.temp_file "mc_lsfiles_att_" ".txt" in
  Fun.protect
    ~finally:(fun () -> try Sys.remove out with _ -> ())
    (fun () ->
      let cmd =
        Printf.sprintf "git -C %s ls-files -z -- attestations > %s"
          (Filename.quote project_root)
          (Filename.quote out)
      in
      if Sys.command cmd <> 0 then Alcotest.fail "git ls-files failed";
      let raw =
        try In_channel.with_open_bin out In_channel.input_all with _ -> ""
      in
      raw
      |> String.split_on_char '\000'
      |> List.filter (fun s -> s <> "")
      |> List.sort String.compare)

(* Parse ONE tracked attestation through the production loader
   (`Attestations.read_one`, the same function `Attestations.load`
   calls per file). Using the real decoder rather than a private
   parser is the point: "all 765 still parse" has to be a statement
   about the code that actually reads the store, not about a
   lookalike in the test. `None` covers both a malformed document and
   one missing the fields the schema requires -- for this assertion
   the two are the same fact. *)
let[@warning "-32"] candidate_tree_of path =
  let reader p =
    try In_channel.with_open_bin p In_channel.input_all with _ -> ""
  in
  match Attestations.read_one reader path with
  | Some a -> Ok a.Domain.candidate_tree
  | None -> Error "the loader admitted no attestation from this file"

let[@warning "-32"] unanchored_count_does_not_grow () =
  let files = tracked_attestations () in
  Alcotest.(check bool)
    "the committed store is not empty -- the pin would be vacuous if it were"
    true
    (List.length files > 0);
  let unanchored =
    List.filter
      (fun f ->
        let full = Filename.concat project_root f in
        match candidate_tree_of full with
        | Ok v -> not (is_full_object_id v)
        | Error _ -> true)
      files
  in
  Alcotest.(check int)
    (Printf.sprintf
       "tracked attestations whose candidate_tree is not a full object id \
        (pinned at %d; may only decrease as anchored attestations are added)"
       pinned_unanchored)
    pinned_unanchored (List.length unanchored)

let[@warning "-32"] every_tracked_attestation_parses () =
  let files = tracked_attestations () in
  let bad =
    List.filter_map
      (fun f ->
        let full = Filename.concat project_root f in
        match candidate_tree_of full with Ok _ -> None | Error _ -> Some f)
      files
  in
  Alcotest.(check (list string)) "every tracked attestation still parses" [] bad

let () =
  Alcotest.run "attestation_anchor"
    [
      ( "corpus",
        [
          Alcotest.test_case "unanchored_count_does_not_grow" `Quick
            unanchored_count_does_not_grow;
          Alcotest.test_case "every_tracked_attestation_parses" `Quick
            every_tracked_attestation_parses;
        ] );
    ]
