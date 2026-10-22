(* tests/path_config_test.ml — minimal coverage for lib/path_config.ml.
 *
 * The resolver is pure (env-var + two filesystem checks), so the
 * tests construct tmpdirs and assert the four-tuple of (env-var,
 * default-exists, fallback-exists) → resolved value. The
 * "synthesize default" branch (neither exists) is the new code
 * path added in ux-3-minimal-pollution-2026-10; without it,
 * `mathc init` on a fresh directory would land at the legacy
 * `decisions/` instead of `.math-coding/decisions/`.
 *
 * Why this lives in tests/ and not lib/path_config.ml's own
 * unit test: OCAML_BEST_PRACTICES §10.1 splits the test suite
 * into one executable per file under tests/. A self-test inside
 * the library would violate the rule. *)

let ( let* ) = Option.bind

let with_tmpdir (f : string -> 'a) : 'a =
  let name =
    Filename.concat "/tmp"
      (Printf.sprintf "path-config-test-%d-%d" (Unix.getpid ())
         (Unix.gettimeofday () |> int_of_float))
  in
  Unix.mkdir name 0o755;
  Fun.protect
    (fun () -> f name)
    ~finally:(fun () ->
      let rec rm p =
        try
          if Sys.is_directory p then
            Sys.readdir p |> Array.iter (fun n -> rm (Filename.concat p n));
          Unix.rmdir p
        with _ -> ()
      in
      rm name)

let touch path =
  let oc = open_out path in
  output_string oc "n";
  close_out oc

let with_envvar var value f =
  let prev = Sys.getenv_opt var in
  Unix.putenv var value;
  Fun.protect
    ~finally:(fun () ->
      match prev with Some p -> Unix.putenv var p | None -> Unix.putenv var "")
    f

let test_env_var_wins () =
  with_tmpdir (fun tmp ->
      let default_path = Filename.concat tmp "default" in
      let legacy_path = Filename.concat tmp "legacy" in
      Unix.mkdir default_path 0o755;
      Unix.mkdir legacy_path 0o755;
      with_envvar "MATH_CODING_DECISIONS_DIR" "user-override" (fun () ->
          let v =
            Path_config.resolve_with "MATH_CODING_DECISIONS_DIR"
              ~default:default_path ~fallback:legacy_path ()
          in
          Alcotest.(check string) "env-var wins" "user-override" v))

let test_default_wins_when_default_exists () =
  with_tmpdir (fun tmp ->
      let default_path = Filename.concat tmp "default" in
      let legacy_path = Filename.concat tmp "legacy" in
      Unix.mkdir default_path 0o755;
      Unix.mkdir legacy_path 0o755;
      Unix.putenv "MATH_CODING_DECISIONS_DIR" "";
      let v =
        Path_config.resolve_with "MATH_CODING_DECISIONS_DIR"
          ~layout:Path_config.New ~default:default_path ~fallback:legacy_path ()
      in
      Alcotest.(check string) "default wins over legacy" default_path v)

let test_legacy_wins_when_only_legacy_exists () =
  with_tmpdir (fun tmp ->
      let default_path = Filename.concat tmp "default" in
      let legacy_path = Filename.concat tmp "legacy" in
      Unix.mkdir legacy_path 0o755;
      Unix.putenv "MATH_CODING_DECISIONS_DIR" "";
      let v =
        Path_config.resolve_with "MATH_CODING_DECISIONS_DIR"
          ~layout:Path_config.Legacy ~default:default_path ~fallback:legacy_path
          ()
      in
      Alcotest.(check string) "legacy when only legacy exists" legacy_path v)

let test_default_synthesises_when_neither_exists () =
  with_tmpdir (fun tmp ->
      let default_path = Filename.concat tmp "default" in
      let legacy_path = Filename.concat tmp "legacy" in
      Unix.putenv "MATH_CODING_DECISIONS_DIR" "";
      let v =
        Path_config.resolve_with "MATH_CODING_DECISIONS_DIR"
          ~layout:Path_config.New ~default:default_path ~fallback:legacy_path ()
      in
      Alcotest.(check string)
        "synthesise default for fresh projects" default_path v)

let test_public_api_returns_expected_default () =
  with_tmpdir (fun tmp ->
      let cwd = Sys.getcwd () in
      Sys.chdir tmp;
      Fun.protect
        ~finally:(fun () -> Sys.chdir cwd)
        (fun () ->
          let v = Path_config.resolve_decisions_dir () in
          Alcotest.(check string)
            "default is .math-coding/decisions" ".math-coding/decisions" v))

(* --- layout coherence + root-awareness --------------------------- *)
(* Added by `kernel-fixes-found-bugs-2026-10@1`. Two defects the old
   tests could not see because they passed synthetic paths:

   (1) the three resolvers asked three independent questions, so a
       directory holding `decisions/` but no `decisions/decision.yaml`
       resolved decisions to the legacy path and the policy to the
       new default — half a project in each layout. `layout_of` now
       decides once per project.
   (2) the existence checks ran against the process cwd, so
       `mathc init /srv/app` inherited the caller's layout. `?root`
       makes the question "about the project being operated on". *)

let test_layout_of_fresh_is_new () =
  with_tmpdir (fun tmp ->
      let l = Path_config.layout_of ~root:tmp () in
      Alcotest.(check bool)
        "fresh dir is the new layout" true (l = Path_config.New))

let test_layout_of_legacy_artifacts () =
  with_tmpdir (fun tmp ->
      Unix.mkdir (Filename.concat tmp "decisions") 0o755;
      let l = Path_config.layout_of ~root:tmp () in
      Alcotest.(check bool)
        "decisions/ alone is a legacy tree" true (l = Path_config.Legacy))

let test_layout_new_wins_over_legacy () =
  with_tmpdir (fun tmp ->
      Unix.mkdir (Filename.concat tmp "decisions") 0o755;
      Unix.mkdir (Filename.concat tmp ".math-coding") 0o755;
      let l = Path_config.layout_of ~root:tmp () in
      Alcotest.(check bool)
        ".math-coding/ wins (forward path)" true (l = Path_config.New))

let test_root_scopes_the_question () =
  with_tmpdir (fun outer ->
      let project = Filename.concat outer "srv-app" in
      Unix.mkdir project 0o755;
      Unix.mkdir (Filename.concat project "decisions") 0o755;
      let cwd = Sys.getcwd () in
      Sys.chdir outer;
      Fun.protect
        ~finally:(fun () -> Sys.chdir cwd)
        (fun () ->
          let without_root = Path_config.resolve_decisions_dir () in
          let with_root = Path_config.resolve_decisions_dir ~root:project () in
          Alcotest.(check string)
            "cwd-relative answer ignores the target project"
            ".math-coding/decisions" without_root;
          Alcotest.(check string)
            "?root asks about the target project" "decisions" with_root))

let test_layout_coherence_across_three_paths () =
  with_tmpdir (fun tmp ->
      Unix.mkdir (Filename.concat tmp "decisions") 0o755;
      Unix.putenv "MATH_CODING_DECISIONS_DIR" "";
      Unix.putenv "MATH_CODING_ATTESTATIONS_DIR" "";
      Unix.putenv "MATH_CODING_POLICY" "";
      let dec = Path_config.resolve_decisions_dir ~root:tmp () in
      let att = Path_config.resolve_attestations_dir ~root:tmp () in
      let pol = Path_config.resolve_policy_path ~root:tmp () in
      Alcotest.(check string) "decisions: legacy" "decisions" dec;
      Alcotest.(check string) "attestations: legacy" "attestations" att;
      Alcotest.(check string) "policy: legacy" "decisions/decision.yaml" pol)

let () =
  Unix.putenv "MATH_CODING_DECISIONS_DIR" "";
  Alcotest.run
    ~log_dir:(Filename.concat (Filename.get_temp_dir_name ()) "mathc-alcotest")
    "path_config"
    [
      ( "resolver",
        [
          Alcotest.test_case "env-var wins" `Quick test_env_var_wins;
          Alcotest.test_case "default wins when default exists" `Quick
            test_default_wins_when_default_exists;
          Alcotest.test_case "legacy wins when only legacy exists" `Quick
            test_legacy_wins_when_only_legacy_exists;
          Alcotest.test_case "default synthesises when neither exists" `Quick
            test_default_synthesises_when_neither_exists;
          Alcotest.test_case "public API returns .math-coding/decisions" `Quick
            test_public_api_returns_expected_default;
        ] );
      ( "layout coherence",
        [
          Alcotest.test_case "fresh dir is the new layout" `Quick
            test_layout_of_fresh_is_new;
          Alcotest.test_case "decisions/ alone is a legacy tree" `Quick
            test_layout_of_legacy_artifacts;
          Alcotest.test_case ".math-coding/ wins over decisions/" `Quick
            test_layout_new_wins_over_legacy;
          Alcotest.test_case "?root scopes the question" `Quick
            test_root_scopes_the_question;
          Alcotest.test_case "three paths agree on one layout" `Quick
            test_layout_coherence_across_three_paths;
        ] );
    ]
