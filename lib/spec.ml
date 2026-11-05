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
  match read_object ~what json ~fields:[ "id"; "subject"; "scope"; "check"; "falsifier"; "register" ] with
  | Error e -> Error e
  | Ok pairs ->
      let* id = require_string ~what "id" pairs in
      let* text = require_string ~what "subject" pairs in
      let* scope = require_string_list ~what "scope" pairs in
      let* check = require_string ~what "check" pairs in
      let* falsifier = require_string ~what "falsifier" pairs in
      let* register = require_register ~what "register" pairs in
      if scope = [] then
        Error
          (error (what ^ ".scope")
             "must not be empty: a claim about nothing is not a claim")
      else Ok { id; subject = { text; scope }; check; falsifier; register }

(** Parse the standing specification: the claims of a project. *)
let parse_spec (json : Yojson.Safe.t) : (claim list, error) result =
  match read_object ~what:"spec" json ~fields:[ "claims" ] with
  | Error e -> Error e
  | Ok pairs -> (
      match List.assoc_opt "claims" pairs with
      | Some (`List items) ->
          let rec claims acc = function
            | [] -> Ok (List.rev acc)
            | item :: rest -> (
                match parse_claim item with
                | Ok c -> claims (c :: acc) rest
                | Error e -> Error e)
          in
          claims [] items
      | Some _ -> Error (error "spec.claims" "expected a list")
      | None -> Error (error "spec.claims" "is required"))

let parse_spec_string (text : string) : (claim list, error) result =
  match Yojson.Safe.from_string text with
  | json -> parse_spec json
  | exception Yojson.Json_error msg -> Error (error "spec" msg)

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
