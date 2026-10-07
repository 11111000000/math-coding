(* tests/supersession_check.ml
 *
 * I7 supersession order check (constitution invariant 7):
 *   "supersedes MUST be irreflexive and acyclic."
 *
 * For each decision in `decisions/*.yaml`, walk every decision
 * and assert that:
 *   (a) a decision does NOT list itself in its `supersedes:`
 *       array (irreflexivity);
 *   (b) the supersedes graph has no cycles (acyclicity).
 *
 * The kernel's parser does not currently enforce I7 (Agent 1's
 * audit: I7 invariant "SCAFFOLD-only" at HEAD `3db08e5`). This
 * test executable closes the project-state gap. New commits that
 * introduce a self-supersession or a cycle must either fix the
 * decision file or add a kernel check first. *)

let[@warning "-32"] project_root () =
  let cwd = Sys.getcwd () in
  let rec find d =
    if Sys.file_exists (Filename.concat d "dune-project") then d
    else
      let parent = Filename.dirname d in
      if parent = d then cwd else find parent
  in
  find cwd

(* Parse just the `id` and `supersedes` fields from a YAML
   decision file. Returns None if the file cannot be loaded,
   id is missing, or the file is in the meta-aggregator list. *)
let[@warning "-32"] parse_id_and_super raw =
  let yaml = try Codec.load_yaml_string raw with _ -> Jsonl.Object [] in
  let yaml_obj = match yaml with Jsonl.Object ps -> ps | _ -> [] in
  let id =
    match Schema.take_string yaml_obj "id" with Some s -> s | None -> ""
  in
  let supersedes =
    match Schema.take_object yaml_obj "relations" with
    | Some rps -> (
        match Schema.take_array rps "supersedes" with
        | Some xs ->
            List.filter_map
              (fun x -> match x with Jsonl.String s -> Some s | _ -> None)
              xs
        | None -> [])
    | None -> []
  in
  if id = "" then None else Some (id, supersedes)

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
  List.filter_map
    (fun fname ->
      let path = Filename.concat decisions_dir fname in
      let raw =
        try In_channel.with_open_bin path In_channel.input_all with _ -> ""
      in
      parse_id_and_super raw)
    files

let[@warning "-32"] test_no_self_supersession () =
  let root = project_root () in
  let entries = walk root in
  let self_refs = List.filter (fun (id, ss) -> List.mem id ss) entries in
  let n = List.length self_refs in
  if n > 0 then begin
    Printf.printf "DEBUG: %d self-supersession(s):\n%!" n;
    List.iter (fun (id, _) -> Printf.printf "  %s\n%!" id) self_refs
  end;
  Alcotest.(check int)
    "no decision lists itself in supersedes (I7 irreflexivity)" 0 n

(* DFS to detect cycles. *)
let[@warning "-32"] has_cycle entries =
  let succ =
    let tbl = Hashtbl.create 32 in
    List.iter (fun (id, ss) -> Hashtbl.add tbl id ss) entries;
    fun id -> try Hashtbl.find tbl id with Not_found -> []
  in
  let visited = Hashtbl.create 32 in
  let stack = Hashtbl.create 32 in
  let rec dfs node =
    if Hashtbl.mem stack node then true
    else if Hashtbl.mem visited node then false
    else begin
      Hashtbl.add visited node true;
      Hashtbl.add stack node true;
      let cycle = List.exists dfs (succ node) in
      Hashtbl.remove stack node;
      cycle
    end
  in
  List.exists (fun (id, _) -> dfs id) entries

let[@warning "-32"] test_no_supersession_cycle () =
  let root = project_root () in
  let entries = walk root in
  if has_cycle entries then begin
    Printf.printf "DEBUG: supersession cycle detected\n%!";
    List.iter
      (fun (id, ss) ->
        Printf.printf "  %s -> [%s]\n%!" id (String.concat "; " ss))
      entries
  end;
  Alcotest.(check bool)
    "no supersession cycle exists (I7 acyclicity)" false (has_cycle entries)

let () =
  Alcotest.run "supersession order (I7)"
    [
      ( "no self-supersession",
        [ Alcotest.test_case "irreflexive" `Quick test_no_self_supersession ] );
      ( "no cycle",
        [ Alcotest.test_case "acyclic" `Quick test_no_supersession_cycle ] );
    ]
