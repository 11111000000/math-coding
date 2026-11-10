
open Domain

type error = { field : string; problem : string }

let error field problem = { field; problem }
let ( let* ) r f = match r with Ok v -> f v | Error e -> Error e

let message_of (e : error) : string =
  Printf.sprintf "%s: %s" (if e.field = "" then "spec" else e.field) e.problem

let result_of = function
  | Ok v -> v
  | Error e -> failwith (message_of e)

let read_object ~what (json : Yojson.Safe.t) ~(fields : string list) :
    ((string * Yojson.Safe.t) list, error) result =
  match json with
  | `Assoc pairs -> (
      let unknown =
        List.filter_map (fun (k, _) -> if List.mem k fields then None else Some k) pairs
      in
      match unknown with
      | k :: _ ->
          Error
            (error what
               (Printf.sprintf "unknown field %S; the fields are %s" k
                  (String.concat ", " (List.sort compare fields))))
      | [] -> Ok pairs)
  | _ -> Error (error what "expected an object")

let require_string ~what name (pairs : (string * Yojson.Safe.t) list) =
  match List.assoc_opt name pairs with
  | Some (`String s) when s <> "" -> Ok s
  | Some (`String _) -> Error (error (what ^ "." ^ name) "must not be empty")
  | Some _ -> Error (error (what ^ "." ^ name) "expected a string")
  | None -> Error (error (what ^ "." ^ name) "is required")

let require_string_list ~what name (pairs : (string * Yojson.Safe.t) list) =
  match List.assoc_opt name pairs with
  | Some (`List items) ->
      let rec strings acc = function
        | [] -> Ok (List.rev acc)
        | `String s :: rest -> strings (s :: acc) rest
        | _ -> Error (error (what ^ "." ^ name) "expected a list of strings")
      in
      strings [] items
  | Some _ -> Error (error (what ^ "." ^ name) "expected a list of strings")
  | None -> Error (error (what ^ "." ^ name) "is required")

let require_register ~what name (pairs : (string * Yojson.Safe.t) list) =
  match List.assoc_opt name pairs with
  | Some (`String "fact") -> Ok Fact
  | Some (`String "hypothesis") -> Ok Hypothesis
  | Some (`String "judgment") -> Ok Judgment
  | Some (`String "unknown") -> Ok Undeclared
  | Some (`String other) ->
      Error
        (error (what ^ "." ^ name)
           (Printf.sprintf "expected fact, hypothesis, judgment or unknown; got %S" other))
  | Some _ -> Error (error (what ^ "." ^ name) "expected a string")
  | None -> Error (error (what ^ "." ^ name) "is required")

let require_requirements ~what (pairs : (string * Yojson.Safe.t) list) =
  match List.assoc_opt "requirements" pairs with
  | Some (`List items) ->
      let rec go acc = function
        | [] -> Ok (List.rev acc)
        | `Assoc fields :: rest ->
            let* kind = require_string ~what "kind" fields in
            let* spec = require_string ~what "spec" fields in
            (match kind with
            | "verifier" -> go (Verified_by spec :: acc) rest
            | "review" -> go (Reviewed_by spec :: acc) rest
            | _ ->
                Error
                  (error (what ^ ".requirements.kind")
                     (Printf.sprintf "expected verifier or review; got %S" kind)))
        | _ :: rest ->
            Error (error (what ^ ".requirements") "expected a list of objects")
      in
      go [] items
  | Some _ -> Error (error (what ^ ".requirements") "expected a list")
  | None -> Error (error (what ^ ".requirements") "is required")

let require_outcome ~what (fields : (string * Yojson.Safe.t) list) =
  let* outcome = require_string ~what "outcome" fields in
  match outcome with
  | "verified" -> Ok Verified
  | "falsified" -> Ok Falsified
  | "unresolved" -> Ok Unresolved
  | "refused" -> Ok Refused
  | other ->
      Error
        (error (what ^ ".attestations.outcome")
           (Printf.sprintf "expected verified, falsified, unresolved or refused; got %S" other))
(* The [standing] flag is optional: an old attestation is not standing. *)
let require_attestations ~what (pairs : (string * Yojson.Safe.t) list) =
  match List.assoc_opt "attestations" pairs with
  | None -> Ok []
  | Some (`List items) ->
      let rec go acc = function
        | [] -> Ok (List.rev acc)
        | `Assoc fields :: rest -> (
            let* requirement = require_string ~what "requirement" fields in
            let* who = require_string ~what "who" fields in
            let* outcome = require_outcome ~what fields in
            let* bound_to = require_string ~what "bound_to" fields in
            let* at = require_string ~what "at" fields in
            let text name =
              match List.assoc_opt name fields with
              | Some (`String t) -> Some t
              | _ -> None
            in
            let flag name =
              match List.assoc_opt name fields with Some (`Bool b) -> b | _ -> false
            in
            go
              ({ requirement; who; outcome; reason = text "reason"; bound_to; at;
                 valid_until = text "valid_until"; standing = flag "standing" }
               :: acc)
              rest)
        | _ -> Error (error (what ^ ".attestations") "expected a list of objects")
      in
      go [] items
  | Some _ -> Error (error (what ^ ".attestations") "expected a list")

let parse_claim (json : Yojson.Safe.t) : (claim, error) result =
  let what = "claim" in
  match
    read_object ~what json
      ~fields:
        [ "id"; "subject"; "scope"; "requirements"; "falsifier"; "register";
          "accepted"; "attestations"; "control" ]
  with
  | Error e -> Error e
  | Ok pairs ->
      let* id = require_string ~what "id" pairs in
      let* text = require_string ~what "subject" pairs in
      let* scope = require_string_list ~what "scope" pairs in
      let* requirements = require_requirements ~what pairs in
      let* falsifier = require_string ~what "falsifier" pairs in
      let* register = require_register ~what "register" pairs in
      let* accepted =
        match List.assoc_opt "accepted" pairs with
        | None -> Ok None
        | Some (`Null) -> Ok None
        | Some (`Assoc fields) -> (
            let* by = require_string ~what "by" fields in
            let* reason = require_string ~what "reason" fields in
            Ok (Some (by, reason)))
        | Some _ -> Error (error (what ^ ".accepted") "expected an object or null")
      in
      let* attestations = require_attestations ~what pairs in
      let* control =
        match List.assoc_opt "control" pairs with
        | None -> Ok None
        | Some (`String c) when c <> "" -> Ok (Some c)
        | Some (`String _) -> Ok None
        | Some `Null -> Ok None
        | Some _ -> Error (error (what ^ ".control") "expected a command")
      in
      if scope = [] then
        Error
          (error (what ^ ".scope")
             "must not be empty: a claim about nothing is not a claim")
      else
        Ok
          {
            id;
            subject = { text; scope };
            requirements;
            falsifier;
            register;
            accepted;
            attestations;
            control;
          }

let parse_goal (json : Yojson.Safe.t) : (goal, error) result =
  let what = "goal" in
  match read_object ~what json ~fields:[ "text"; "scope"; "by"; "at" ] with
  | Error e -> Error e
  | Ok pairs ->
      let* text = require_string ~what "text" pairs in
      let* scope = require_string_list ~what "scope" pairs in
      let* by = require_string ~what "by" pairs in
      let* at = require_string ~what "at" pairs in
      if scope = [] then
        Error
          (error (what ^ ".scope")
             "must not be empty: an aim about nothing aims at nothing")
      else Ok { text; scope; by; at }

let parse_spec (json : Yojson.Safe.t) : (spec, error) result =
  match
    read_object ~what:"spec" json
      ~fields:[ "goal"; "uncertainty_budget"; "claims"; "closed_waves" ]
  with
  | Error e -> Error e
  | Ok pairs -> (
      let* goal =
        match List.assoc_opt "goal" pairs with
        | None -> Ok None
        | Some (`Null) -> Ok None
        | Some json ->
            let* g = parse_goal json in
            Ok (Some g)
      in
      let* budget =
        match List.assoc_opt "uncertainty_budget" pairs with
        | Some (`Int n) when n >= 0 -> Ok n
        | Some (`Int n) ->
            Error
              (error "spec.uncertainty_budget"
                 (Printf.sprintf "must not be negative; got %d" n))
        | Some _ -> Error (error "spec.uncertainty_budget" "expected an integer")
        | None ->
            Error
              (error "spec.uncertainty_budget"
                 "is required: an uncertainty nobody priced is free, and a free uncertainty is why \"I do not know\" would be cheaper than checking")
      in
      let* closed_waves =
        match List.assoc_opt "closed_waves" pairs with
        | None -> Ok []
        | Some (`List items) ->
            let rec go acc = function
              | [] -> Ok (List.rev acc)
              | `String s :: rest -> go (s :: acc) rest
              | _ -> Error (error "spec.closed_waves" "expected a list of strings")
            in
            go [] items
        | Some _ -> Error (error "spec.closed_waves" "expected a list")
      in
      match List.assoc_opt "claims" pairs with
      | Some (`List items) ->
          let rec claims acc = function
            | [] -> Ok (List.rev acc)
            | item :: rest -> (
                match parse_claim item with
                | Ok c -> claims (c :: acc) rest
                | Error e -> Error e)
          in
          let* cs = claims [] items in
          Ok { goal; budget; claims = cs; closed_waves }
      | Some _ -> Error (error "spec.claims" "expected a list")
      | None -> Error (error "spec.claims" "is required"))

let parse_spec_string (text : string) : (spec, error) result =
  match Yojson.Safe.from_string text with
  | json -> parse_spec json
  | exception Yojson.Json_error msg -> Error (error "spec" msg)

let spec_to_json (s : spec) : Yojson.Safe.t =
  `Assoc
    [ ( "goal",
        match s.goal with
        | None -> `Null
        | Some g ->
            `Assoc
              [ ("text", `String g.text);
                ("scope", `List (List.map (fun p -> `String p) g.scope));
                ("by", `String g.by);
                ("at", `String g.at) ] );
      ("uncertainty_budget", `Int s.budget);
      ("closed_waves", `List (List.map (fun w -> `String w) s.closed_waves));
      ( "claims",
        `List
          (List.map
             (fun (c : claim) ->
               `Assoc
                 [ ("id", `String c.id);
                   ("subject", `String c.subject.text);
                   ( "scope",
                     `List (List.map (fun p -> `String p) c.subject.scope) );
                   ( "requirements",
                     `List
                       (List.map
                          (fun (r : requirement) ->
                            match r with
                            | Verified_by spec ->
                                `Assoc [ ("kind", `String "verifier"); ("spec", `String spec) ]
                            | Reviewed_by spec ->
                                `Assoc [ ("kind", `String "review"); ("spec", `String spec) ])
                          c.requirements) );
                   ("falsifier", `String c.falsifier);
                   ( "register",
                     `String
                       (match c.register with
                       | Fact -> "fact"
                       | Hypothesis -> "hypothesis"
                       | Judgment -> "judgment"
                       | Undeclared -> "unknown") );
                   ( "accepted",
                     match c.accepted with
                     | None -> `Null
                     | Some (by, reason) ->
                         `Assoc [ ("by", `String by); ("reason", `String reason) ] );
                   ( "control",
                     match c.control with
                     | None -> `Null
                     | Some cmd -> `String cmd );
                   ( "attestations",
                     `List
                       (List.map
                          (fun (a : Domain.attestation) ->
                            `Assoc
                              [
                                ("requirement", `String a.requirement);
                                ("who", `String a.who);
                                ( "outcome",
                                  `String
                                    (match a.outcome with
                                    | Domain.Verified -> "verified"
                                    | Domain.Falsified -> "falsified"
                                    | Domain.Unresolved -> "unresolved"
                                    | Domain.Refused -> "refused") );
                                ( "reason",
                                  match a.reason with
                                  | Some r -> `String r
                                  | None -> `Null );
                                ("bound_to", `String a.bound_to);
                                ("at", `String a.at);
                                ("standing", `Bool a.standing);
                                ( "valid_until",
                                  match a.valid_until with
                                  | Some t -> `String t
                                  | None -> `Null );
                              ])
                          c.attestations) ) ])
             s.claims) )]

let state_of_name (text : string) : Domain.state option =
  match text with
  | "holds" -> Some Domain.Holds
  | "refuted" -> Some Domain.Refuted
  | "inconclusive" -> Some Domain.Inconclusive
  | "not checkable" -> Some Domain.NotCheckable
  | "outdated" -> Some Domain.Outdated
  | "never checked" -> Some Domain.NeverChecked
  | "accepted by a person" -> Some Domain.Accepted
  | _ -> None

let require_commitment ~what (pairs : (string * Yojson.Safe.t) list) =
  match List.assoc_opt "commitment" pairs with
  | Some (`List items) ->
      let rec go acc = function
        | [] -> Ok (List.rev acc)
        | `Assoc fields :: rest -> (
            let* claim = require_string ~what "claim" fields in
            let* state = require_string ~what "state" fields in
            match state_of_name state with
            | Some s -> go ({ claim; state = s } :: acc) rest
            | None ->
                Error
                  (error (what ^ ".commitment.state")
                     (Printf.sprintf "expected a state of a claim; got %S" state)))
        | _ -> Error (error (what ^ ".commitment") "expected a list of objects")
      in
      go [] items
  | Some _ -> Error (error (what ^ ".commitment") "expected a list")
  | None -> Error (error (what ^ ".commitment") "is required")

let parse_wave (json : Yojson.Safe.t) : (wave, error) result =
  let what = "wave" in
  match
    read_object ~what json
      ~fields:
        [ "id"; "title"; "intent"; "touches"; "checks"; "claims"; "commitment";
          "objection"; "refuted_by" ]
  with
  | Error e -> Error e
  | Ok pairs ->
      let* id = require_string ~what "id" pairs in
      let* title = require_string ~what "title" pairs in
      let* intent = require_string ~what "intent" pairs in
      let* touches = require_string_list ~what "touches" pairs in
      let* checks = require_string_list ~what "checks" pairs in
      let* claims = require_string_list ~what "claims" pairs in
      let* commitment = require_commitment ~what pairs in
      let* objection = require_string ~what "objection" pairs in
      let* refuted_by = require_string ~what "refuted_by" pairs in
      Ok
        {
          id;
          title;
          intent;
          touches;
          checks;
          claims;
          commitment;
          objection;
          refuted_by;
        }

let parse_wave_string (text : string) : (wave, error) result =
  match Yojson.Safe.from_string text with
  | json -> parse_wave json
  | exception Yojson.Json_error msg -> Error (error "wave" msg)
