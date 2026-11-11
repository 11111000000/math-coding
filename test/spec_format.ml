open Domain
open Helpers

let expect_error label = function Ok _ -> failwith label | Error _ -> ()

let update name change json =
  match json with
  | `Assoc fields ->
      `Assoc (List.map (fun (key, value) -> if key = name then key, change value else key, value) fields)
  | _ -> json

let () =
  let spec = { goal = Some { text = "aim"; scope = [ "subject.txt" ]; by = "owner"; at = 1; reason = None }; claims = [ claim ] } in
  let text = Yojson.Safe.pretty_to_string (Spec.to_json spec) in
  (match Spec.parse_string text with
   | Ok parsed -> check "roundtrip preserves claim" (List.length parsed.claims = 1 && (List.hd parsed.claims).id = claim.id)
   | Error error -> failwith error);
  expect_error "unknown top-level field is rejected" (Spec.parse_string "{\"schema_version\":5,\"goal\":null,\"claims\":[],\"extra\":true}");
  expect_error "duplicate field is rejected" (Spec.parse_string "{\"schema_version\":5,\"schema_version\":5,\"goal\":null,\"claims\":[]}");
  expect_error "bad nested requirement is rejected" (Spec.parse_string "{\"schema_version\":5,\"goal\":null,\"claims\":[{\"id\":\"x\",\"text\":\"x\",\"scope\":[],\"requirements\":[{\"kind\":\"verifier\",\"spec\":1}],\"falsifier\":\"x\",\"register\":\"fact\"}]}");
  expect_error "bad goal is rejected" (Spec.parse_string "{\"schema_version\":5,\"goal\":1,\"claims\":[]}");
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
  print_endline "spec-format: PASS"
