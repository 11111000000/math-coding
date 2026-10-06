(* tests/identity_uniqueness.ml
 *
 * I4 Identity uniqueness check (constitution invariant 4):
 *   "Identity: (kind, id, revision) MUST be globally unique."
 *
 * For every decision in `decisions/*.yaml`, extract the
 * (kind, id, revision) triple. Assert that no two files share
 * the same triple. Two decisions may share the same `id` if
 * their `revision` differs (one supersedes the other); that is
 * the legal case.
 *
 * What this catches:
 *   - Two decisions with the same (kind, id, revision) — a
 *     silent merge conflict that human reviewers may not spot
 *   - Decisions committed without bumping `revision` after a
 *     body edit (a separate concern, not enforced here)
 *
 * Mirrors the test-architecture pattern in
 * tests/fixture_coverage.ml: read YAML, walk the
 * decisions/ directory, classify each entry. The pre-commit
 * hook does NOT cover this; the I4 invariant has been
 * SCAFFOLD-only in the spec↔code audit (per Agent 2's
 * previous analysis). This executable closes that gap at
 * project-state level. *)

let[@warning "-32"] project_root () =
  let cwd = Sys.getcwd () in
  let rec find d =
    if Sys.file_exists (Filename.concat d "dune-project") then d
    else
      let parent = Filename.dirname d in
      if parent = d then cwd else find parent
  in
  find cwd

let[@warning "-32"] walk root =
  let decisions_dir = Filename.concat root "decisions" in
  let files =
    Sys.readdir decisions_dir |> Array.to_list
    |> List.filter (fun n ->
        Filename.extension n = ".yaml" || Filename.extension n = ".yml")
    |> List.filter (fun n ->
        not
          (List.mem (Filename.basename n)
             [
               "decision.yaml";
               "obligations.yaml";
               "obligation-count-reconcile.yaml";
             ]))
  in
  List.concat_map
    (fun fname ->
      let path = Filename.concat decisions_dir fname in
      let raw = In_channel.with_open_bin path In_channel.input_all in
      let yaml = try Codec.load_yaml_string raw with _ -> Jsonl.Object [] in
      let yaml_obj = match yaml with Jsonl.Object ps -> ps | _ -> [] in
      let id =
        match Schema.take_string yaml_obj "id" with Some s -> s | None -> ""
      in
      let rev =
        match Schema.take_string yaml_obj "revision" with
        | Some r -> r
        | None -> "1" (* legacy decisions without explicit rev *)
      in
      if id = "" then [] else [ (id, rev, fname) ])
    files

let[@warning "-32"] test_no_duplicate_identity () =
  let root = project_root () in
  let entries = walk root in
  let total = List.length entries in
  (* Group by (id, revision). *)
  let groups =
    List.fold_left
      (fun acc (id, rev, fname) ->
        let key = (id, rev) in
        let prev =
          match List.assoc_opt key acc with Some xs -> xs | None -> []
        in
        (key, fname :: prev) :: List.remove_assoc key acc)
      [] entries
  in
  let dupes = List.filter (fun (_, fs) -> List.length fs > 1) groups in
  let n_dupes = List.length dupes in
  if n_dupes > 0 then begin
    Printf.printf "DEBUG: %d duplicate (id, revision) pairs:\n%!" n_dupes;
    List.iter
      (fun ((id, rev), fs) ->
        Printf.printf "  %s@%s: %s\n%!" id rev (String.concat ", " fs))
      dupes
  end;
  Alcotest.(check int)
    (Printf.sprintf
       "every (id, revision) is unique (walked %d decisions, found %d \
        duplicates)"
       total n_dupes)
    0 n_dupes

let () =
  Alcotest.run "identity uniqueness (I4)"
    [
      ( "(id, revision) globally unique",
        [ Alcotest.test_case "no duplicates" `Quick test_no_duplicate_identity ]
      );
    ]
