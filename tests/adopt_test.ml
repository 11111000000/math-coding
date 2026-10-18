(* tests/adopt_test.ml
 *
 * Tests for `lib/adopt/detect.ml` — the brownfield detection
 * logic for the future `mathc adopt` subcommand (Phase 3).
 *
 * The detection is pure: directory markers (docs/arc42/,
 * docs/adr/, adr/) determine which convention is present.
 * Each test case creates a fresh tmpdir, sets up the marker
 * dirs, calls `Detect.detect` / `Detect.classify`, and asserts
 * the right output. *)

let ( let* ) = Option.bind

let with_tmpdir (f : string -> 'a) : 'a =
  (* Use a unique tmpdir under /tmp. We pass the absolute
   * path to the test function; nested paths are constructed
   * via Filename.concat (no chdir). The bwrap sandbox may
   * restrict chdir, so we work entirely in absolute paths. *)
  let base = "/tmp" in
  let name =
    Filename.concat base
      (Printf.sprintf "adopt-test-%d-%d" (Unix.getpid ())
         (Unix.gettimeofday () |> int_of_float))
  in
  Unix.mkdir name 0o755;
  Fun.protect
    (fun () -> f name)
    ~finally:(fun () ->
      let rec rm p =
        try
          if Sys.is_directory p then begin
            Array.iter (fun n -> rm (Filename.concat p n)) (Sys.readdir p);
            Unix.rmdir p
          end
          else Sys.remove p
        with _ -> ()
      in
      try rm name with _ -> ())

let touch_dir (root : string) (sub : string) : unit =
  (* The bwrap sandbox used by `dune test` may restrict
   * nested mkdir even though the parent exists. Use
   * `mkdir -p` via Sys.command to get shell-level recursive
   * creation. The bwrap allows exec of common utils. *)
  let _ =
    Sys.command
      (Printf.sprintf "mkdir -p %s" (Filename.quote (Filename.concat root sub)))
  in
  ()

let touch_file (root : string) (sub : string) (body : string) : unit =
  let path = Filename.concat root sub in
  let oc = open_out path in
  output_string oc body;
  close_out oc

let touch_file (root : string) (sub : string) (body : string) : unit =
  let path = Filename.concat root sub in
  let oc = open_out path in
  output_string oc body;
  close_out oc

let int_of_brownfield = function
  | Detect.Empty -> 0
  | Detect.Arc42 -> 1
  | Detect.Madr -> 2
  | Detect.AdrTools -> 3
  | Detect.Mixed_Arc42_Madr -> 4
  | Detect.Mixed_Arc42_AdrTools -> 5
  | Detect.Mixed_Madr_AdrTools -> 6
  | Detect.Mixed_All_Three -> 7

let string_of_brownfield = function
  | Detect.Empty -> "Empty"
  | Detect.Arc42 -> "Arc42"
  | Detect.Madr -> "Madr"
  | Detect.AdrTools -> "AdrTools"
  | Detect.Mixed_Arc42_Madr -> "Mixed_Arc42_Madr"
  | Detect.Mixed_Arc42_AdrTools -> "Mixed_Arc42_AdrTools"
  | Detect.Mixed_Madr_AdrTools -> "Mixed_Madr_AdrTools"
  | Detect.Mixed_All_Three -> "Mixed_All_Three"

let _ = string_of_brownfield (* silence unused warning *)

let test_detect_empty () =
  with_tmpdir (fun root ->
      let r = Detect.detect root in
      Alcotest.(check bool) "arc42 false" false r.arc42;
      Alcotest.(check bool) "madr false" false r.madr;
      Alcotest.(check bool) "adr_tools false" false r.adr_tools;
      Alcotest.(check int)
        "classify Empty" 0
        (int_of_brownfield (Detect.classify r)))

let test_detect_arc42_only () =
  with_tmpdir (fun root ->
      touch_dir root "docs/arc42";
      let r = Detect.detect root in
      Alcotest.(check bool) "arc42 true" true r.arc42;
      Alcotest.(check int)
        "classify Arc42" 1
        (int_of_brownfield (Detect.classify r)))

let test_detect_madr_only () =
  with_tmpdir (fun root ->
      touch_dir root "docs/adr";
      touch_file root "docs/adr/0001-test.md" "# test\n";
      let r = Detect.detect root in
      Alcotest.(check bool) "madr true" true r.madr;
      Alcotest.(check int)
        "classify Madr" 2
        (int_of_brownfield (Detect.classify r)))

let test_detect_adr_tools_only () =
  with_tmpdir (fun root ->
      touch_dir root "adr";
      touch_file root "adr/0001-test.md" "# test\n";
      let r = Detect.detect root in
      Alcotest.(check bool) "adr_tools true" true r.adr_tools;
      Alcotest.(check int)
        "classify AdrTools" 3
        (int_of_brownfield (Detect.classify r)))

let test_detect_mixed_arc42_madr () =
  with_tmpdir (fun root ->
      touch_dir root "docs/arc42";
      touch_dir root "docs/adr";
      let r = Detect.detect root in
      Alcotest.(check int)
        "classify Mixed_Arc42_Madr" 4
        (int_of_brownfield (Detect.classify r)))

let test_detect_mixed_all_three () =
  with_tmpdir (fun root ->
      touch_dir root "docs/arc42";
      touch_dir root "docs/adr";
      touch_dir root "adr";
      let r = Detect.detect root in
      Alcotest.(check int)
        "classify Mixed_All_Three" 7
        (int_of_brownfield (Detect.classify r)))

let test_madr_files () =
  with_tmpdir (fun root ->
      touch_dir root "docs/adr";
      touch_file root "docs/adr/0001-foo.md" "foo";
      touch_file root "docs/adr/0002-bar.md" "bar";
      touch_file root "docs/adr/0003-baz.txt" "ignored";
      Alcotest.(check (list string))
        "madr_files returns *.md sorted"
        [ "0001-foo.md"; "0002-bar.md" ]
        (Detect.madr_files root))

let test_madr_files_empty () =
  with_tmpdir (fun root ->
      Alcotest.(check (list string)) "empty" [] (Detect.madr_files root))

let test_adrtools_files () =
  with_tmpdir (fun root ->
      touch_dir root "adr";
      touch_file root "adr/0001-foo.md" "foo";
      Alcotest.(check (list string))
        "adrtools_files returns *.md sorted" [ "0001-foo.md" ]
        (Detect.adrtools_files root))

let () =
  let open Alcotest in
  run "Detect"
    [
      ("detect empty", [ test_case "detects empty" `Quick test_detect_empty ]);
      ( "detect arc42 only",
        [ test_case "arc42 only" `Quick test_detect_arc42_only ] );
      ( "detect madr only",
        [ test_case "madr only" `Quick test_detect_madr_only ] );
      ( "detect adr-tools",
        [ test_case "adr-tools only" `Quick test_detect_adr_tools_only ] );
      ( "mixed arc42+madr",
        [ test_case "arc42 + madr" `Quick test_detect_mixed_arc42_madr ] );
      ( "mixed all three",
        [ test_case "all three" `Quick test_detect_mixed_all_three ] );
      ("madr_files", [ test_case "lists .md files" `Quick test_madr_files ]);
      ("madr_files empty", [ test_case "empty" `Quick test_madr_files_empty ]);
      ( "adrtools_files",
        [ test_case "lists .md files" `Quick test_adrtools_files ] );
    ]
