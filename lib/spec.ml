(** The formats, and the only place they are read.

    A format is read by a library, never by a parser of our own. The
    third version wrote its own YAML reader and lost data in ways
    nobody noticed for months; the rule against hand-written parsers
    came out of that loss, and this file is the rule being kept.

    The two formats are the standing specification of a project and the
    wave. Both are strict: an unknown field is an error, not silence.
    A format that silently ignores what it does not understand is a
    format that lets an agent believe it did something it did not.

    The shapes are chosen so that a translation into a formal modelling
    language is a mapping and not a rewrite. A claim, a scope of paths,
    an evidence, a verdict: four entities and three relations. That is
    all a temporal model of this method needs. *)

open Domain

(** A parse failure, with the reason a human can act on. *)
type error = { field : string; problem : string }

let error field problem = { field; problem }

(* Sequencing for results. Reading a format is a sequence of
   requirements, and the first failure is the one worth reporting. *)
let ( let* ) r f = match r with Ok v -> f v | Error e -> Error e

let result_of = function
  | Ok v -> v
  | Error e ->
      failwith
        (Printf.sprintf "%s: %s" (if e.field = "" then "spec" else e.field) e.problem)

(* ------------------------------------------------------------------ *)
(* Strict object reading.                                              *)
(* ------------------------------------------------------------------ *)

(** Read an object with exactly the given fields. An unknown field is
    an error: the whole point of a strict format is that a typo is
    loud. A format that silently ignores what it does not understand is
    a format that lets an agent believe it did something it did not. *)
let read_object ~what (json : Yojson.Safe.t) ~(fields : string list) :
    ((string * Yojson.Safe.t) list, error) result =
  match json with
  | `Assoc pairs -> (
      let unknown =
        List.filter_map
          (fun (k, _) -> if List.mem k fields then None else Some k)
          pairs
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

(* ------------------------------------------------------------------ *)
(* The standing specification.                                          *)
(* ------------------------------------------------------------------ *)

(** Parse one claim. Every field is required, and the scope must not be
    empty: a claim about nothing is not a claim. Whether the scope
    names anything in the tree is the adapter's business - see
    [Verdict.law_no_vacant_subject] and the rule the adapter enforces
    on top of it. *)
let parse_claim (json : Yojson.Safe.t) : (claim, error) result =
  let what = "claim" in
  match
    read_object ~what json
      ~fields:[ "id"; "subject"; "scope"; "check"; "falsifier"; "register"; "accepted" ]
  with
  | Error e -> Error e
  | Ok pairs ->
      let* id = require_string ~what "id" pairs in
      let* text = require_string ~what "subject" pairs in
      let* scope = require_string_list ~what "scope" pairs in
      let* check = require_string ~what "check" pairs in
      let* falsifier = require_string ~what "falsifier" pairs in
      let* register = require_register ~what "register" pairs in
      let* accepted =
        match List.assoc_opt "accepted" pairs with
        | None -> Ok None
        | Some (`Null) -> Ok None
        | Some (`Assoc fields) -> (
            let* by = require_string ~what "accepted.by" fields in
            let* reason = require_string ~what "accepted.reason" fields in
            Ok (Some (by, reason)))
        | Some _ -> Error (error (what ^ ".accepted") "expected an object or null")
      in
      if scope = [] then
        Error
          (error (what ^ ".scope")
             "must not be empty: a claim about nothing is not a claim")
      else Ok { id; subject = { text; scope }; check; falsifier; register; accepted }

(** Parse the aim. It is optional in the file - a project that has not
    stated one yet is a project the method accepts claims from
    nowhere, and [mathc add] is where that is refused. *)
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

(** Parse the standing specification: the aim, the price of uncertainty
    the project agreed to pay, and the claims.

    The budget is required. A budget nobody declared is not finite, and
    an uncertainty that costs nothing makes "I do not know" cheaper
    than checking - which is the free escalation the principle exists
    to stop. *)
let parse_spec (json : Yojson.Safe.t) : (spec, error) result =
  match
    read_object ~what:"spec" json
      ~fields:[ "goal"; "uncertainty_budget"; "claims" ]
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
          Ok { goal; budget; claims = cs }
      | Some _ -> Error (error "spec.claims" "expected a list")
      | None -> Error (error "spec.claims" "is required"))

let parse_spec_string (text : string) : (spec, error) result =
  match Yojson.Safe.from_string text with
  | json -> parse_spec json
  | exception Yojson.Json_error msg -> Error (error "spec" msg)

(** Write the specification back. The file is machine-managed: it is
    read and written by the method, and the aim and the claims are
    data in it. *)
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
      ( "claims",
        `List
          (List.map
             (fun (c : claim) ->
               `Assoc
                 [ ("id", `String c.id);
                   ("subject", `String c.subject.text);
                   ( "scope",
                     `List (List.map (fun p -> `String p) c.subject.scope) );
                   ("check", `String c.check);
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
                         `Assoc [ ("by", `String by); ("reason", `String reason) ] ) ])
             s.claims) )]

(* ------------------------------------------------------------------ *)
(* The wave.                                                            *)
(* ------------------------------------------------------------------ *)

(** Parse a wave: a finished, green slice of work. *)
let parse_wave (json : Yojson.Safe.t) : (wave, error) result =
  let what = "wave" in
  match
    read_object ~what json
      ~fields:
        [ "id"; "title"; "touches"; "checks"; "claims"; "verdicts_changed" ]
  with
  | Error e -> Error e
  | Ok pairs ->
      let* id = require_string ~what "id" pairs in
      let* title = require_string ~what "title" pairs in
      let* touches = require_string_list ~what "touches" pairs in
      let* checks = require_string_list ~what "checks" pairs in
      let* claims = require_string_list ~what "claims" pairs in
      let* verdicts_changed = require_string_list ~what "verdicts_changed" pairs in
      Ok { id; title; touches; checks; claims; verdicts_changed }

let parse_wave_string (text : string) : (wave, error) result =
  match Yojson.Safe.from_string text with
  | json -> parse_wave json
  | exception Yojson.Json_error msg -> Error (error "wave" msg)
