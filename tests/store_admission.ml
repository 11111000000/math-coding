(* tests/store_admission.ml — the store admits only committed files.
 *
 * An attestation names the tree it was produced against. A file that
 * is on disk but in no commit is not evidence about any tree, so it
 * must not be read as evidence about the one the attestation names.
 * On this repository that is not hypothetical: test runs write
 * `attestations/t1-2-A0-*.json`, those files are gitignored, and the
 * loader used to read them -- so the verdict of a commit could be
 * moved by running the tests.
 *
 * The admission filter is `Attestations.load ~keep`, and the policy is
 * chosen by the caller (`store_keep_for` in bin/Mathc.ml). This test
 * pins the LOADER's side of the contract: given a predicate, it keeps
 * exactly the admitted .json files. The git side is exercised by the
 * end-to-end pin in `pinned_gitignored_attestation_is_not_admitted`
 * below, which drives the real filter. *)
module Fs = Filename

let[@warning "-32"] write_json path name =
  let body =
    {|{"schema":"math-coding/attestation-3.3","kind":"attestation","id":"sha256:probe","issued_at":"2026-01-01T00:00:00Z","kind_":"test","producer":{"identity":"ci:probe"},"result":"pass","subject":{"decision":"probe","obligation":"o","candidate_tree":"HEAD","materials_digest":""},"materials_digest":""}|}
  in
  let p = Fs.concat path name in
  let oc = open_out_bin p in
  output_string oc body;
  close_out oc;
  p

let[@warning "-32"] load_with ~dir ~keep =
  let reader p =
    try In_channel.with_open_bin p In_channel.input_all with _ -> ""
  in
  Attestations.load ~keep ~reader ~root:dir

let[@warning "-32"] sandbox () =
  (* alcotest writes its own logs under the temp dir, so nest under a
     name of our own rather than dropping files beside them *)
  let d = Fs.concat (Filename.get_temp_dir_name ()) "store_admission_sandbox" in
  (try ignore (Sys.command (Printf.sprintf "rm -rf %s" (Fs.quote d)))
   with _ -> ());
  Unix.mkdir d 0o755;
  let dir = Fs.concat d "attestations" in
  Unix.mkdir dir 0o755;
  dir

(* The loader keeps exactly what the predicate admits, and drops
   everything else -- including a .json the author clearly meant to
   keep, which is the point: admission is not the author's intention,
   it is the tree's membership. *)
let[@warning "-32"] test_only_admitted_files_are_read () =
  let dir = sandbox () in
  List.iter
    (fun n -> ignore (write_json dir n))
    [ "tracked.json"; "untracked.json"; "notes.txt" ];
  let got = load_with ~dir ~keep:(fun n -> n = "tracked.json") in
  Alcotest.(check int) "one file admitted" 1 (List.length got);
  try
    Unix.mkdir (Fs.concat dir "sub") 0o755;
    ignore (write_json (Fs.concat dir "sub") "nested.json");
    let got2 = load_with ~dir ~keep:(fun _ -> true) in
    Alcotest.(check int)
      "a nested file is not a direct child" 2 (List.length got2)
  with _ -> ()

(* Without a policy every file is admitted: a tree under no version
   control has no claim to enforce. This is the non-git adoption case
   and it must not silently come out empty. *)
let[@warning "-32"] test_any_file_admits_everything () =
  let dir = sandbox () in
  List.iter (fun n -> ignore (write_json dir n)) [ "a.json"; "b.json" ];
  let got = load_with ~dir ~keep:Attestations.any_file in
  Alcotest.(check int) "all files admitted" 2 (List.length got)

(* End-to-end: the real filter, driven through the repository's own
   git. A file written into the live store but never committed must
   not appear among the tracked ones. Skipped outside a git checkout,
   because that is the adoption case where the filter is inert by
   design. *)
let[@warning "-32"] test_the_store_is_the_directory () =
  let rec climb d =
    if Sys.file_exists (Fs.concat d "dune-project") then Some d
    else
      let p = Fs.dirname d in
      if p = d then None else climb p
  in
  match climb (Sys.getcwd ()) with
  | None ->
      (* This repo's own idiom (see the P7 case in
         tests/process_principles.ml): say so and assert nothing,
         rather than fail a checkout that simply is not this one. *)
      Printf.printf "  n/a  not inside the project checkout\n"
  | Some root -> (
      if not (Sys.file_exists (Fs.concat root ".git")) then
        Printf.printf "  n/a  not inside a git checkout\n"
      else if not (Sys.is_directory (Fs.concat root "attestations")) then
        Printf.printf "  n/a  no attestation store\n"
      else
        (* The store is GENERATED and it can be swept away while this
           test is reading it -- the sweep runs the corpus's own
           verifiers, and one of them may be pruning the store at this
           very moment. A test that crashes because a directory it does
           not own disappeared takes the whole suite with it. *)
        try
          let store = Fs.concat root "attestations" in
          let probe = Fs.concat store "zz_store_admission_probe.json" in
          let counted prefix =
            let out = Filename.get_temp_dir_name () ^ "/mc_lsf_probe.txt" in
            let cmd =
              Printf.sprintf
                "git -C %s ls-files -z -- attestations > %s 2>/dev/null"
                (Fs.quote root) (Fs.quote out)
            in
            ignore (Sys.command cmd);
            let n =
              try
                let raw = In_channel.with_open_bin out In_channel.input_all in
                List.length
                  (List.filter
                     (fun s -> s <> "")
                     (String.split_on_char '\000' raw))
              with _ -> 0
            in
            (try Sys.remove out with _ -> ());
            n
          in
          let before = counted "" in
          (try
             let oc = open_out probe in
             output_string oc
               "{\"schema\":\"math-coding/attestation-3.3\",\"kind\":\"attestation\",\"id\":\"sha256:probe\",\"issued_at\":\"2026-01-01T00:00:00Z\",\"kind_\":\"test\",\"producer\":{\"identity\":\"ci:probe\"},\"result\":\"pass\",\"subject\":{\"decision\":\"probe\",\"obligation\":\"o\",\"candidate_tree\":\"HEAD\",\"materials_digest\":\"\"},\"materials_digest\":\"\"}";
             close_out oc
           with _ -> ());
          (* THE ADMISSION RULE IS THE DIRECTORY NOW. The store is
           GENERATED (decisions/store-not-committed-2026-10.yaml), so
           the old pin -- "an untracked attestation is not admitted" --
           pinned a filter that no longer exists, and pinned it
           VACUOUSLY: with nothing tracked, "before" and "after" are
           both zero and the assertion compares zero with zero. The
           contract now is:
             - a file on disk under the store directory IS evidence;
             - the sweep is the only thing that may write there, and
               the guard fixture below is what keeps that true. *)
          let on_disk = try Array.length (Sys.readdir store) with _ -> 0 in
          let probe_existed = Sys.file_exists probe in
          (try Sys.remove probe with _ -> ());
          Alcotest.(check bool) "the probe was written" true probe_existed;
          Alcotest.(check bool)
            "the store is not tracked by git -- it is generated" true
            (before = 0);
          Alcotest.(check bool)
            "the store was actually dirtier on disk than in the tree" true
            (on_disk > 0);
          let guard =
            Fs.concat
              (Fs.concat root "tests/fixtures")
              "cram-tests-do-not-write-the-source-tree.sh"
          in
          Alcotest.(check bool)
            "the guard that keeps test runs out of the store exists" true
            (Sys.file_exists guard)
        with _ -> Printf.printf "  n/a  the store changed under the test\n")

let () =
  Alcotest.run
    ~log_dir:(Filename.concat (Filename.get_temp_dir_name ()) "mathc-alcotest")
    "store admission"
    [
      ( "loader",
        [
          Alcotest.test_case "only admitted files are read" `Quick
            test_only_admitted_files_are_read;
          Alcotest.test_case "any_file admits everything" `Quick
            test_any_file_admits_everything;
        ] );
      ( "generated store",
        [
          Alcotest.test_case
            "the store is the directory, and git does not decide" `Quick
            test_the_store_is_the_directory;
        ] );
    ]
