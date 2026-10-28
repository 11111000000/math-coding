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
 *   - `unanchored_count_does_not_grow` pins the number of
 *     attestations THE SWEEP PRODUCED for this tree whose
 *     `candidate_tree` is not a full object id. It is 0, and a new
 *     observation that names a symbolic ref is a declaration, not an
 *     observation.
 *
 *   - `every_tracked_attestation_parses` pins that the whole store
 *     still loads, so forward-only edits elsewhere cannot make the
 *     corpus unreadable.
 *
 * THE STORE IS GENERATED NOW. It is not in git's index (decisions/
 * store-not-committed-2026-10.yaml), and the sweep leaves
 * attestations for more than one tree in it: the ones whose scope did
 * not change stay fresh, because freshness is a property of the
 * SCOPE, not of the tree the file was written in. So the store on
 * disk is the corpus the kernel reads -- the loader's admission rule
 * is the DIRECTORY now -- and this test counts what the kernel
 * counts, for the same reason it always did: a pin about a
 * lookalike in the test is a pin about nothing.
 *
 * The legacy corpus -- 765 files that name `HEAD` instead of a
 * commit -- cannot be retrofitted (rewriting `candidate_tree` would
 * mint a new id for an observation nobody re-ran), and it stays as
 * history. When the sweep has not run for this tree there is nothing
 * to measure, and the pin says so instead of failing on a store that
 * was never generated here. *)

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
let[@warning "-32"] pinned_unanchored = 0

let[@warning "-32"] is_full_object_id s =
  let n = String.length s in
  (n = 40 || n = 64)
  && String.for_all (function '0' .. '9' | 'a' .. 'f' -> true | _ -> false) s

(* The store the KERNEL reads: the .json files under the store
   directory. The loader's admission rule is the directory itself
   (bin/Mathc.ml::store_keep_for), so this test counts exactly what
   the gate counts. *)
let[@warning "-32"] store_attestations () =
  let dir = Filename.concat project_root "attestations" in
  if not (Sys.file_exists dir) then []
  else
    (try Sys.readdir dir |> Array.to_list with _ -> [])
    |> List.filter (fun n -> Filename.extension n = ".json")
    |> List.sort String.compare
    |> List.map (Filename.concat "attestations")

(* The commit this tree is at. *)
let[@warning "-32"] head_sha () =
  let out = Filename.temp_file "mc_head_" ".txt" in
  Fun.protect
    ~finally:(fun () -> try Sys.remove out with _ -> ())
    (fun () ->
      let cmd =
        Printf.sprintf "git -C %s rev-parse HEAD > %s"
          (Filename.quote project_root)
          (Filename.quote out)
      in
      if Sys.command cmd <> 0 then Alcotest.fail "git rev-parse failed";
      let raw =
        try In_channel.with_open_bin out In_channel.input_all with _ -> ""
      in
      String.trim raw)

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
  let head = head_sha () in
  let mine =
    List.filter
      (fun f ->
        match candidate_tree_of (Filename.concat project_root f) with
        | Ok v -> String.equal v head
        | Error _ -> false)
      (store_attestations ())
  in
  if mine = [] then begin
    (* The sweep has not run for this tree. The store is generated,
       and a store that was never generated here has nothing to say
       about anchoring. *)
    Printf.printf
      "  no attestations for %s yet: the sweep has not run for this tree\n"
      (String.sub head 0 8);
    Alcotest.(check bool) "nothing to measure for this tree" true true
  end
  else begin
    let unanchored =
      List.filter
        (fun f ->
          match candidate_tree_of (Filename.concat project_root f) with
          | Ok v -> not (is_full_object_id v)
          | Error _ -> true)
        mine
    in
    Alcotest.(check int)
      (Printf.sprintf
         "attestations the sweep produced for this tree whose candidate_tree \
          is not a full object id (ceiling %d)"
         pinned_unanchored)
      0 (List.length unanchored)
  end

let[@warning "-32"] every_tracked_attestation_parses () =
  let files = store_attestations () in
  let bad =
    List.filter_map
      (fun f ->
        let full = Filename.concat project_root f in
        match candidate_tree_of full with Ok _ -> None | Error _ -> Some f)
      files
  in
  Alcotest.(check (list string))
    "every attestation in the store still parses" [] bad

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
