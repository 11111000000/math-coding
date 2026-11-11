open Domain
open Json_helpers

let ( let* ) result next = match result with Ok value -> next value | Error error -> Error error

let environment_to_json (environment : environment) =
  `Assoc [ "class", json_string environment.class_; "fingerprint", json_string environment.fingerprint ]

let producer_to_json producer =
  `Assoc [ "class", json_string producer.class_;
          "identity", json_string producer.identity;
          "run", json_string_opt producer.run ]

let to_json evidence =
  `Assoc [ "schema_version", `Int 5;
          "claim_id", json_string evidence.claim_id;
          "requirement", Spec.requirement_to_json evidence.requirement;
          "candidate_tree", json_string evidence.candidate_tree;
          "materials_digest", json_string evidence.materials_digest;
          "definition_digest", json_string evidence.definition_digest;
          "verifier_digest", json_string evidence.verifier_digest;
          "environment", environment_to_json evidence.environment;
          "producer", producer_to_json evidence.producer;
          "independence", json_string (independence_to_string evidence.independence);
          "outcome", json_string (outcome_to_string evidence.outcome);
          "issued_at", `Int evidence.issued_at;
          "valid_until", (match evidence.valid_until with None -> `Null | Some value -> `Int value);
          "evidence_ref", json_string_opt evidence.evidence_ref;
          "control_reach", json_string_opt evidence.control_reach ]

let of_json json =
  let* pairs = object_ "evidence" [ "schema_version"; "claim_id"; "requirement"; "candidate_tree";
      "materials_digest"; "definition_digest"; "verifier_digest"; "environment"; "producer";
      "independence"; "outcome"; "issued_at"; "valid_until"; "evidence_ref"; "control_reach" ] json in
  let* version = int "schema_version" pairs in
  let* () = if version = 5 then Ok () else Error ("unsupported evidence schema_version " ^ string_of_int version) in
  let* claim_id = string "claim_id" pairs in
  let* requirement =
    match List.assoc_opt "requirement" pairs with
    | Some json -> Spec.requirement_of_json json
    | None -> Error "requirement is required"
  in
  let* candidate_tree = string "candidate_tree" pairs in
  let* materials_digest = string "materials_digest" pairs in
  let* definition_digest = string "definition_digest" pairs in
  let* verifier_digest = string "verifier_digest" pairs in
  let* environment =
    match List.assoc_opt "environment" pairs with
    | Some json ->
        let* fields = object_ "environment" [ "class"; "fingerprint" ] json in
        let* class_ = string "class" fields in
        let* fingerprint = string "fingerprint" fields in
        Ok { class_; fingerprint }
    | None -> Error "environment is required"
  in
  let* producer =
    match List.assoc_opt "producer" pairs with
    | Some json ->
        let* fields = object_ "producer" [ "class"; "identity"; "run" ] json in
        let* class_ = string "class" fields in
        let* identity = string "identity" fields in
        let* run = string_opt "run" fields in
        Ok { class_; identity; run }
    | None -> Error "producer is required"
  in
  let* independence_name = string "independence" pairs in
  let* independence =
    match independence_of_string independence_name with
    | Some value -> Ok value
    | None -> Error ("independence: unsupported " ^ independence_name)
  in
  let* outcome_name = string "outcome" pairs in
  let* outcome = match outcome_of_string outcome_name with Some value -> Ok value | None -> Error ("outcome: unsupported " ^ outcome_name) in
  let* issued_at = int "issued_at" pairs in
  let* valid_until = int_opt "valid_until" pairs in
  let* evidence_ref = string_opt "evidence_ref" pairs in
  let* control_reach = string_opt "control_reach" pairs in
  Ok { claim_id; requirement; candidate_tree; materials_digest; definition_digest;
       verifier_digest; environment; producer; independence; outcome; issued_at;
       valid_until; evidence_ref; control_reach }
