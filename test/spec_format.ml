(* The format, and the proof that it is strict.

   A format that silently ignores what it does not understand is a
   format that lets an agent believe it did something it did not. The
   strictness is therefore the whole point, and it is checked here
   against what it must reject.

   THE NEGATIVE CONTROL. Every rejection below is a case the parser
   must refuse. A parser that accepts an unknown field, or a claim
   about nothing, is a parser that will happily accept a claim with no
   subject and no falsifier - and a claim with no subject cannot be
   bound to anything, so its evidence could be bound to anything at
   all. That is the hole the third version fell into, and it starts
   here, at the door. *)

open Domain

(** The source tree. Dune runs the test from the build directory, and
    the build directory is always named [_build], so the source tree is
    its parent. The test needs it because the specification it must
    check is not copied into the build directory - and a check that
    quietly finds nothing is a comment: this file used to look for
    [spec.json] in the working directory, where it never is, so the
    check that "the method can see its own project" never ran at all. *)
let[@warning "-32"] source_root () =
  let rec loop d =
    if Filename.basename d = "_build" then Filename.dirname d
    else
      let parent = Filename.dirname d in
      if parent = d then d else loop parent
  in
  loop (Sys.getcwd ())

let[@warning "-32"] in_repo rel = Filename.concat (source_root ()) rel

let expect_error (label : string) (result : ('a, Spec.error) result) =
  match result with
  | Ok _ ->
      Printf.eprintf "the format accepted %s\n" label;
      exit 1
  | Error _ -> ()

let check_strictness () =
  (* An unknown field is an error, not silence. *)
  expect_error "a claim with an unknown field"
    (Spec.parse_claim
       (`Assoc
          [ ("id", `String "c");
            ("subject", `String "s");
            ("scope", `List [ `String "lib/" ]);
            ("check", `String "true");
            ("falsifier", `String "f");
            ("register", `String "fact");
            ("notes", `String "an extra field") ]));

  (* A missing field is an error. *)
  expect_error "a claim without a falsifier"
    (Spec.parse_claim
       (`Assoc
          [ ("id", `String "c");
            ("subject", `String "s");
            ("scope", `List [ `String "lib/" ]);
            ("check", `String "true");
            ("register", `String "fact") ]));

  (* A claim about nothing is not a claim. This is the door the third
     version's hole came through: an empty scope yields an empty
     digest, and an empty digest was a wildcard for freshness, so the
     only attestation that could pass was the one carrying no
     evidence. *)
  expect_error "a claim with an empty scope"
    (Spec.parse_claim
       (`Assoc
          [ ("id", `String "c");
            ("subject", `String "s");
            ("scope", `List []);
            ("check", `String "true");
            ("falsifier", `String "f");
            ("register", `String "fact") ]));

  (* An empty check is a promise with no procedure. *)
  expect_error "a claim with an empty check"
    (Spec.parse_claim
       (`Assoc
          [ ("id", `String "c");
            ("subject", `String "s");
            ("scope", `List [ `String "lib/" ]);
            ("check", `String "");
            ("falsifier", `String "f");
            ("register", `String "fact") ]));

  (* An unknown register is an error: a claim that does not say what
     kind of claim it is cannot be asked for the right evidence. *)
  expect_error "a claim with an unknown register"
    (Spec.parse_claim
       (`Assoc
          [ ("id", `String "c");
            ("subject", `String "s");
            ("scope", `List [ `String "lib/" ]);
            ("check", `String "true");
            ("falsifier", `String "f");
            ("register", `String "vibes") ]));

  (* Malformed JSON is an error, not a crash. *)
  expect_error "malformed JSON" (Spec.parse_spec_string "{ this is not json")

let check_the_good_cases () =
  (* The format this repository uses must parse. If it does not, the
     method cannot see its own project. The file is read from the
     SOURCE tree: the build directory does not carry it, and a check
     that finds no file passes vacuously. *)
  let path = in_repo "spec.json" in
  if not (Sys.file_exists path) then (
    Printf.eprintf "the repository has no specification at %s\n" path;
    exit 1)
  else
    let text = In_channel.with_open_bin path In_channel.input_all in
    match Spec.parse_spec_string text with
    | Error e ->
        Printf.eprintf "spec.json does not parse: %s\n" (Spec.message_of e);
        exit 1
    | Ok spec ->
        assert (List.length spec.Domain.claims > 0);
        List.iter
          (fun (c : claim) ->
            assert (c.id <> "");
            assert (c.subject.text <> "");
            assert (c.subject.scope <> []);
            assert (c.requirements <> []);
            assert (c.falsifier <> ""))
          spec.Domain.claims

(** The wave carries the dialectic of the plan. A plan that cannot state
    the objection against itself has not thought, so the fields are
    required - and the wave is where the dialectic lives, not on every
    claim. *)
let check_wave_dialectic () =
  let wave fields =
    `Assoc
      (("id", `String "w")
      :: ("title", `String "t")
      :: ("intent", `String "why this unit of work")
      :: ("touches", `List [ `String "lib/" ])
      :: ("checks", `List [ `String "true" ])
      :: ("claims", `List [ `String "c" ])
      :: ( "commitment",
          `List [ `Assoc [ ("claim", `String "c"); ("state", `String "holds") ] ] )
      :: fields)
  in
  let complete =
    [ ("objection", `String "the strongest objection");
      ("refuted_by", `String "what would refute it") ]
  in
  (* Without the objection, the wave is not a wave. *)
  expect_error "a wave without an objection" (Spec.parse_wave (wave [ ("refuted_by", `String "x") ]));
  expect_error "a wave without what would refute it"
    (Spec.parse_wave (wave [ ("objection", `String "x") ]));
  (* And it parses when both are there. *)
  match Spec.parse_wave (wave complete) with
  | Error e ->
      Printf.eprintf "a complete wave does not parse: %s\n" (Spec.message_of e);
      exit 1
  | Ok w ->
      assert (w.objection = "the strongest objection");
      assert (w.refuted_by = "what would refute it")

(** Every wave of THIS repository's plan carries the dialectic. The
    dialectic lives on the plan, not on every claim, so the waves of the
    method's own plan are where it is checked - and they are read from
    the source tree, because a check that looks in the build directory
    finds no waves and passes vacuously. *)
let check_the_waves_of_this_repository () =
  let dir = in_repo "waves" in
  if not (Sys.file_exists dir) then (
    Printf.eprintf "the repository has no waves at %s\n" dir;
    exit 1)
  else
    let files =
      Sys.readdir dir |> Array.to_list
      |> List.filter (fun name -> Filename.check_suffix name ".json")
      |> List.sort compare
    in
    assert (files <> []);
    List.iter
      (fun name ->
        let path = Filename.concat dir name in
        let text = In_channel.with_open_bin path In_channel.input_all in
        match Spec.parse_wave_string text with
        | Error e ->
            Printf.eprintf "the wave %s does not parse: %s\n" name
              (Spec.message_of e);
            exit 1
        | Ok w ->
            assert (w.objection <> "");
            assert (w.refuted_by <> ""))
      files

let () =
  check_strictness ();
  check_the_good_cases ();
  check_the_waves_of_this_repository ();
  check_wave_dialectic ();
  print_endline "spec-format: PASS"
