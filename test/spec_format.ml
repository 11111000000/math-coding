open Domain
open Helpers

let expect_error label = function Ok _ -> failwith label | Error _ -> ()

let update name change json =
  match json with
  | `Assoc fields ->
      `Assoc (List.map (fun (key, value) -> if key = name then key, change value else key, value) fields)
  | _ -> json

let () =
  let spec = { goal = Some { text = "aim"; scope = [ "subject.txt" ]; by = "owner"; at = 1; reason = None }; claims = [ claim ]; environment = None } in
  let text = Yojson.Safe.pretty_to_string (Spec.to_json spec) in
  (match Spec.parse_string text with
   | Ok parsed -> check "roundtrip preserves claim" (List.length parsed.claims = 1 && (List.hd parsed.claims).id = claim.id)
   | Error error -> failwith error);
  expect_error "unknown top-level field is rejected" (Spec.parse_string "{\"schema_version\":5,\"goal\":null,\"claims\":[],\"extra\":true}");
  expect_error "duplicate field is rejected" (Spec.parse_string "{\"schema_version\":5,\"schema_version\":5,\"goal\":null,\"claims\":[]}");
  expect_error "bad nested requirement is rejected" (Spec.parse_string "{\"schema_version\":5,\"goal\":null,\"claims\":[{\"id\":\"x\",\"text\":\"x\",\"scope\":[],\"requirements\":[{\"kind\":\"verifier\",\"spec\":1}],\"falsifier\":\"x\",\"register\":\"fact\"}]}");
  expect_error "bad goal is rejected" (Spec.parse_string "{\"schema_version\":5,\"goal\":1,\"claims\":[]}");
  expect_error "goal timestamp must be an integer"
    (Spec.parse_string "{\"schema_version\":5,\"goal\":{\"text\":\"aim\",\"scope\":[],\"by\":\"owner\",\"at\":\"1\",\"reason\":null},\"claims\":[]}");
  expect_error "an empty scope path is rejected"
    (Spec.claim_of_json (`Assoc [ "id", `String "x"; "text", `String "x"; "scope", `List [ `String "" ];
                                   "requirements", `List []; "falsifier", `String "x"; "register", `String "fact" ]));
  check "directory scopes retain their trailing slash" (Spec.valid_path "lib/");
  check "internal empty path segments are rejected" (not (Spec.valid_path "lib//broken"));
  expect_error "traversal scope is rejected"
    (Spec.claim_of_json (`Assoc [ "id", `String "x"; "text", `String "x"; "scope", `List [ `String "../outside" ];
                                   "requirements", `List []; "falsifier", `String "x"; "register", `String "fact" ]));
  expect_error "traversal source is rejected"
    (Spec.claim_of_json (`Assoc [ "id", `String "x"; "text", `String "x"; "scope", `List [];
                                   "source", `Assoc [ "kind", `String "madr"; "path", `String "../outside";
                                                     "section", `Null; "digest", `String "abc"; "review", `Null ];
                                   "requirements", `List []; "falsifier", `String "x"; "register", `String "fact" ]));
  let any = `Assoc [ "any", `List [ `Assoc [ "kind", `String "verifier"; "spec", `String "true" ] ] ] in
  (match Spec.requirement_of_json any with
   | Ok (Any [ Verifier "true" ]) -> ()
   | _ -> failwith "acceptance.any was not preserved");
  let draft = `Assoc [ "id", `String "adr"; "text", `String "draft"; "scope", `List [];
                       "requirements", `List []; "falsifier", `String ""; "register", `String "unknown" ] in
  (match Spec.claim_of_json draft with
   | Ok claim -> check "ADR draft roundtrip accepts undecided fields" (claim.falsifier = "" && claim.requirements = [])
   | Error error -> failwith error);
  let invalid_owner = match draft with `Assoc fields -> `Assoc (fields @ [ "owner", `Int 1 ]) | value -> value in
  expect_error "an optional field has a strict type" (Spec.claim_of_json invalid_owner);
  expect_error "schema version is not a string" (Spec.parse_string "{\"schema_version\":\"5\",\"goal\":null,\"claims\":[]}");
  expect_error "review independence is not silently downgraded"
    (Spec.requirement_of_json (`Assoc [ "kind", `String "review"; "spec", `String "owner";
                                        "minimum_independence", `String "invented" ]));
  expect_error "verifier and acceptance.any cannot be combined"
    (Spec.requirement_of_json (`Assoc [ "kind", `String "verifier"; "spec", `String "true";
                                        "any", `List [] ]));
  let sourced_claim = { claim with source = Some {
    kind = Madr; path = "docs/adr/0001.md"; section = None; digest = "new";
    review = Some { by = "owner"; reason = "reviewed change"; at = 2; previous_digest = "old" } } } in
  let encoded_claim = Spec.claim_to_json sourced_claim in
  (match Spec.claim_of_json encoded_claim with
   | Ok parsed ->
       (match parsed.source with
        | Some { review = Some review; _ } ->
            check "source review survives the codec"
              (review.by = "owner" && review.reason = "reviewed change" && review.previous_digest = "old")
        | _ -> failwith "source review was lost")
   | Error error -> failwith error);
  expect_error "source review has a strict nested shape"
    (Spec.claim_of_json (update "source" (update "review" (fun _ -> `String "approved")) encoded_claim));
  let encoded = Evidence.to_json (evidence claim) in
  (match Evidence.of_json encoded with
   | Ok parsed -> check "valid evidence roundtrip is preserved" (parsed.claim_id = claim.id)
   | Error error -> failwith error);
  expect_error "a malformed evidence expiry is rejected" (Evidence.of_json (update "valid_until" (fun _ -> `String "never") encoded));
  expect_error "legacy evidence cannot become current by relabelling"
    (Evidence.of_json (update "schema_version" (fun _ -> `Int 4) encoded));
  expect_error "unknown nested evidence fields are rejected"
    (Evidence.of_json (update "environment" (function `Assoc fields -> `Assoc (fields @ [ "extra", `Bool true ]) | value -> value) encoded));
  expect_error "producer.run has a strict optional type"
    (Evidence.of_json (update "producer" (update "run" (fun _ -> `Int 1)) encoded));
  (* The declared environment is optional and additive. *)
  (match Spec.parse_string "{\"schema_version\":5,\"goal\":null,\"claims\":[]}" with
   | Ok parsed -> check "the environment is optional" (parsed.environment = None)
   | Error error -> failwith error);
  (match Spec.parse_string "{\"schema_version\":5,\"goal\":null,\"claims\":[],\"environment\":\"nix develop -c\"}" with
   | Ok parsed -> check "a declared environment is accepted" (parsed.environment = Some "nix develop -c")
   | Error error -> failwith error);
  (match Spec.parse_string
     (Printf.sprintf "{\"schema_version\":5,\"goal\":null,\"claims\":[],\"environment\":\"%s\"}"
        (String.make 512 'x'))
   with
   | Ok parsed -> check "an environment of the allowed length is accepted" (parsed.environment <> None)
   | Error error -> failwith error);
  let with_environment value =
    Spec.parse_string (Printf.sprintf "{\"schema_version\":5,\"goal\":null,\"claims\":[],\"environment\":%s}" value)
  in
  expect_error "an empty environment is rejected" (with_environment "\"\"");
  expect_error "a line break in the environment is rejected" (with_environment "\"nix develop\\nc\"");
  expect_error "a carriage return in the environment is rejected" (with_environment "\"nix develop\\rc\"");
  expect_error "an environment that is not a string is rejected" (with_environment "5");
  expect_error "an environment that is a list is rejected" (with_environment "[]");
  expect_error "an overlong environment is rejected"
    (with_environment (Printf.sprintf "\"%s\"" (String.make 513 'x')));
  (match Spec.parse_string (Yojson.Safe.pretty_to_string (Spec.to_json { spec with environment = Some "nix develop -c" })) with
   | Ok parsed -> check "the environment survives the codec" (parsed.environment = Some "nix develop -c")
   | Error error -> failwith error);
  (match Spec.parse_string (Yojson.Safe.pretty_to_string (Spec.to_json spec)) with
   | Ok parsed -> check "a specification without an environment keeps it absent" (parsed.environment = None)
   | Error error -> failwith error);
  (* A claim may declare its own environment. The rule is the rule of the
     specification: a non-empty single line of at most 512 characters. *)
  let claim_with_environment value =
    `Assoc [ "id", `String "x"; "text", `String "x"; "scope", `List [];
             "requirements", `List [ `Assoc [ "kind", `String "verifier"; "spec", `String "true" ] ];
             "falsifier", `String "x"; "register", `String "fact"; "environment", value ]
  in
  (match Spec.claim_of_json (claim_with_environment (`String "nix develop -c")) with
   | Ok parsed -> check "a claim may declare its own environment" (parsed.environment = Some "nix develop -c")
   | Error error -> failwith error);
  (match Spec.claim_of_json (claim_with_environment (`Null)) with
   | Ok parsed -> check "a claim without a declared environment keeps it absent" (parsed.environment = None)
   | Error error -> failwith error);
  (match Spec.claim_of_json
     (`Assoc [ "id", `String "x"; "text", `String "x"; "scope", `List [];
               "requirements", `List [ `Assoc [ "kind", `String "verifier"; "spec", `String "true" ] ];
               "falsifier", `String "x"; "register", `String "fact" ]) with
   | Ok parsed -> check "a claim without the field is still accepted" (parsed.environment = None)
   | Error error -> failwith error);
  expect_error "an empty claim environment is rejected" (Spec.claim_of_json (claim_with_environment (`String "")));
  expect_error "a line break in the claim environment is rejected"
    (Spec.claim_of_json (claim_with_environment (`String "nix develop\nc")));
  expect_error "a carriage return in the claim environment is rejected"
    (Spec.claim_of_json (claim_with_environment (`String "nix develop\rc")));
  expect_error "a claim environment that is not a string is rejected"
    (Spec.claim_of_json (claim_with_environment (`Int 5)));
  expect_error "a claim environment that is a list is rejected"
    (Spec.claim_of_json (claim_with_environment (`List [])));
  expect_error "an overlong claim environment is rejected"
    (Spec.claim_of_json (claim_with_environment (`String (String.make 513 'x'))));
  (match Spec.claim_of_json (claim_with_environment (`String (String.make 512 'x'))) with
   | Ok parsed -> check "a claim environment of the allowed length is accepted" (parsed.environment <> None)
   | Error error -> failwith error);
  (* A claim without the field stays absent in the written specification, so an
     existing specification is not broken by the new field. *)
  check "a claim without an environment does not add the field"
    (match Spec.claim_to_json claim with
     | `Assoc fields -> not (List.mem_assoc "environment" fields)
     | _ -> false);
  let own = { claim with environment = Some "nix develop -c" } in
  (match Spec.parse_string (Yojson.Safe.pretty_to_string (Spec.to_json { spec with claims = [ own ] })) with
   | Ok parsed ->
       check "the environment of a claim survives the codec"
         (List.length parsed.claims = 1 && (List.hd parsed.claims).environment = Some "nix develop -c")
   | Error error -> failwith error);
  (match Spec.parse_string (Yojson.Safe.pretty_to_string (Spec.to_json { spec with claims = [ claim ] })) with
   | Ok parsed ->
       check "a claim without an environment keeps it absent after the codec"
         (List.length parsed.claims = 1 && (List.hd parsed.claims).environment = None)
   | Error error -> failwith error);
  print_endline "spec-format: PASS"
