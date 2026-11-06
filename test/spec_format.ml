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
     method cannot see its own project. *)
  let path = "spec.json" in
  if Sys.file_exists path then
    let text = In_channel.with_open_bin path In_channel.input_all in
    match Spec.parse_spec_string text with
    | Error e ->
        Printf.eprintf "spec.json does not parse: %s\n" (Spec.result_of (Error e));
        exit 1
    | Ok spec ->
        assert (List.length spec.Domain.claims > 0);
        List.iter
          (fun (c : claim) ->
            assert (c.id <> "");
            assert (c.subject.text <> "");
            assert (c.subject.scope <> []);
            assert (c.check <> "");
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
      :: ("touches", `List [ `String "lib/" ])
      :: ("checks", `List [ `String "true" ])
      :: ("claims", `List [ `String "c" ])
      :: ("verdicts_changed", `List [ `String "c" ])
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
      Printf.eprintf "a complete wave does not parse: %s\n" (Spec.result_of (Error e));
      exit 1
  | Ok w ->
      assert (w.objection = "the strongest objection");
      assert (w.refuted_by = "what would refute it")

let () =
  check_strictness ();
  check_the_good_cases ();
  check_wave_dialectic ();
  print_endline "spec-format: PASS"
