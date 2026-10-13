(* lib/mcp/protocol.ml — JSON-RPC 2.0 message types + codec.
 *
 * This module is the wire layer of the MCP server stub. It does
 * ONE thing: convert between JSON-RPC 2.0 request strings and the
 * `request` record the dispatcher consumes, and back.
 *
 * Scope. JSON-RPC 2.0 is the spec adopted by the Model Context
 * Protocol (claude-code, opencode, cursor all speak JSON-RPC 2.0
 * over stdio for local MCP servers). The spec is small enough to
 * implement by hand:
 *
 *   request  := { "jsonrpc": "2.0", "id": <id>, "params": <p>?, "method": <s> }
 *   response := { "jsonrpc": "2.0", "id": <id>, "result": <r> | "error": <e> }
 *
 * `id` may be a string, number, or null. The MCP server MUST NOT
 * invent an `id` for a notification (the spec lets notifications
 * omit `id`); this stub slice supports request/response only and
 * treats notifications as invalid (a server echo will say
 * `code = -32600 Invalid Request`). The slice is small enough
 * that supporting notifications is a follow-up.
 *
 * Error codes (per JSON-RPC 2.0 §5.1):
 *   -32700  Parse error      — body is not valid JSON
 *   -32600  Invalid Request  — body is JSON but not a Request
 *   -32601  Method not found — method name is unknown
 *   -32602  Invalid params   — params shape is wrong
 *   -32603  Internal error   — mathc subprocess failed or returned
 *                              non-zero
 *
 * This module depends on `Jsonl` (the kernel's hand-rolled JSON
 * parser/stringifier) — the kernel does NOT depend on us, so the
 * adapter-rule asymmetry holds (OCAML_BEST_PRACTICES §10.1:
 * "Adapters may use yojson (or anything else). Kernel may not.").
 *
 * The dispatch boundary (where the method name is mapped to a
 * mathc argv) is OUTSIDE this module; protocol.ml just gives the
 * data, dispatch.ml decides what to do with it. *)

(* --- error code constants (per JSON-RPC 2.0 §5.1) --- *)

let parse_error_code = -32700
let invalid_request_code = -32600
let method_not_found_code = -32601
let invalid_params_code = -32602
let internal_error_code = -32603

(* --- data types --- *)

(* A request `id` may be a string, an integer, or null. The MCP
   spec lets the client pick; we preserve the wire shape verbatim
   so the response `id` matches the request `id` byte-for-byte. *)
type id = Jsonl of Jsonl.value

type request = {
  id : id option;            (* None for notifications; this slice rejects them *)
  method_ : string;          (* the JSON-RPC method name, e.g. "mathc/validate" *)
  params : Jsonl.value option; (* the params object (Object { ... }) or absent *)
}

(* The result is intentionally an arbitrary Jsonl.value; the
   dispatcher hands back whatever the mathc subprocess printed,
   which is itself a JSON value. *)
type response = {
  id : id option;
  result : Jsonl.value option;
  error : rpc_error option;
}

and rpc_error = {
  code : int;
  message : string;
  data : Jsonl.value option;
}

(* --- id helpers --- *)

let id_of_json (v : Jsonl.value) : id = Jsonl v

let id_to_json (id : id) : Jsonl.value =
  match id with Jsonl v -> v

(* --- response constructors --- *)

let response_error ?(id = None) ?(data = None) code message =
  { id; result = None; error = Some { code; message; data } }

let response_result ?(id = None) (result : Jsonl.value) =
  { id; result = Some result; error = None }

(* --- params helpers --- *)

(* Look up a string parameter by key. The error code is
   -32602 (Invalid params) on miss; this surfaces as a JSON-RPC
   error so the client knows their input shape was wrong, not
   that the server crashed. *)
let string_param (params : Jsonl.value option) key : (string, rpc_error) result =
  match params with
  | None | Some Jsonl.Null ->
      Error { code = invalid_params_code; message = "Invalid params: missing params object"; data = None }
  | Some (Jsonl.Object ps) -> (
      match List.assoc_opt key ps with
      | Some (Jsonl.String s) -> Ok s
      | Some _ ->
          Error { code = invalid_params_code; message = Printf.sprintf "Invalid params: \"%s\" must be a string" key; data = None }
      | None ->
          Error { code = invalid_params_code; message = Printf.sprintf "Invalid params: \"%s\" is required" key; data = None })
  | _ ->
      Error { code = invalid_params_code; message = "Invalid params: params must be an Object"; data = None }

(* Look up a string array parameter (paths list for `mathc/mode`). *)
let string_array_param (params : Jsonl.value option) key : (string list, rpc_error) result =
  match params with
  | None | Some Jsonl.Null ->
      Error { code = invalid_params_code; message = "Invalid params: missing params object"; data = None }
  | Some (Jsonl.Object ps) -> (
      match List.assoc_opt key ps with
      | Some (Jsonl.Array xs) ->
          let rec walk acc = function
            | [] -> Ok (List.rev acc)
            | (Jsonl.String s) :: rest -> walk (s :: acc) rest
            | _ :: _ ->
                Error
                  {
                    code = invalid_params_code;
                    message = Printf.sprintf "Invalid params: \"%s\" must be an array of strings" key;
                    data = None;
                  }
          in
          walk [] xs
      | Some _ ->
          Error { code = invalid_params_code; message = Printf.sprintf "Invalid params: \"%s\" must be an array of strings" key; data = None }
      | None ->
          Error { code = invalid_params_code; message = Printf.sprintf "Invalid params: \"%s\" is required" key; data = None })
  | _ ->
      Error { code = invalid_params_code; message = "Invalid params: params must be an Object"; data = None }

(* --- request parser --- *)

(* Walk a Jsonl.value tree and extract the three Request fields.
   Returns `Error` with a JSON-RPC error code if the shape is
   wrong. The shape contract (per JSON-RPC 2.0 §4.1):
     - top-level value MUST be an Object
     - "jsonrpc" MUST be the string "2.0"
     - "method" MUST be a string
     - "id" MUST be present (this slice rejects notifications),
       and MUST be a string, integer, or null
     - "params", if present, MUST be an Object or Array *)
let parse_request (s : string) : (request, rpc_error) result =
  let v =
    try Ok (Jsonl.parse s) with
    | Jsonl.Parse_error { msg; _ } ->
        Error
          {
            code = parse_error_code;
            message = "Parse error: " ^ msg;
            data = None;
          }
  in
  match v with
  | Error e -> Error e
  | Ok (Jsonl.Object ps) ->
      (* 1) jsonrpc == "2.0" *)
      let check_rpc =
        match List.assoc_opt "jsonrpc" ps with
        | Some (Jsonl.String "2.0") -> Ok ()
        | Some _ ->
            Error
              {
                code = invalid_request_code;
                message = "Invalid Request: \"jsonrpc\" field must be the string \"2.0\"";
                data = None;
              }
        | None ->
            Error
              {
                code = invalid_request_code;
                message = "Invalid Request: missing \"jsonrpc\" field";
                data = None;
              }
      in
      (* 2) method is a string *)
      let check_method =
        match List.assoc_opt "method" ps with
        | Some (Jsonl.String m) -> Ok m
        | Some _ ->
            Error
              {
                code = invalid_request_code;
                message = "Invalid Request: \"method\" must be a string";
                data = None;
              }
        | None ->
            Error
              {
                code = invalid_request_code;
                message = "Invalid Request: missing \"method\" field";
                data = None;
              }
      in
      (* 3) id is a string|int|null and present (no notifications) *)
      let check_id =
        match List.assoc_opt "id" ps with
        | Some (Jsonl.String _ | Jsonl.Int _ | Jsonl.Null) ->
            Ok (Some (id_of_json (List.assoc "id" ps)))
        | Some _ ->
            Error
              {
                code = invalid_request_code;
                message =
                  "Invalid Request: \"id\" must be a string, integer, or null";
                data = None;
              }
        | None ->
            Error
              {
                code = invalid_request_code;
                message =
                  "Invalid Request: \"id\" field required (notifications not supported in this slice)";
                data = None;
              }
      in
      (* 4) params, if present, is an Object or Array *)
      let check_params =
        match List.assoc_opt "params" ps with
        | Some (Jsonl.Object _ as p) -> Ok (Some p)
        | Some (Jsonl.Array _ as p) -> Ok (Some p)
        | Some _ ->
            Error
              {
                code = invalid_request_code;
                message = "Invalid Request: \"params\" must be an Object or Array";
                data = None;
              }
        | None -> Ok None
      in
      (match check_rpc, check_method, check_id, check_params with
       | Ok (), Ok m, Ok id, Ok params -> Ok { id; method_ = m; params }
       | Error e, _, _, _ -> Error e
       | _, Error e, _, _ -> Error e
       | _, _, Error e, _ -> Error e
       | _, _, _, Error e -> Error e)
  | Ok _ ->
      Error
        {
          code = invalid_request_code;
          message = "Invalid Request: top-level value must be an Object";
          data = None;
        }

(* --- response encoder --- *)

(* Encode a response as a JSON object. Keys are sorted by Jsonl's
   `stringify` (Object fields are sorted lexicographically before
   serialization), so the wire shape is stable for testing. *)
let encode_response (r : response) : string =
  let fields : (string * Jsonl.value) list =
    match r with
    | { id = None; result = Some res; error = None } ->
        [ ("jsonrpc", Jsonl.String "2.0"); ("result", res) ]
    | { id = None; error = Some e; result = None } ->
        let data_field =
          match e.data with Some d -> [ ("data", d) ] | None -> []
        in
        [
          ("jsonrpc", Jsonl.String "2.0");
          ( "error",
            Jsonl.Object
              (("code", Jsonl.Int e.code)
              :: ("message", Jsonl.String e.message)
              :: data_field) );
        ]
    | { id = Some id; result = Some res; error = None } ->
        [
          ("id", id_to_json id);
          ("jsonrpc", Jsonl.String "2.0");
          ("result", res);
        ]
    | { id = Some id; error = Some e; result = None } ->
        let data_field =
          match e.data with Some d -> [ ("data", d) ] | None -> []
        in
        [
          ("id", id_to_json id);
          ("jsonrpc", Jsonl.String "2.0");
          ( "error",
            Jsonl.Object
              (("code", Jsonl.Int e.code)
              :: ("message", Jsonl.String e.message)
              :: data_field) );
        ]
    | _ ->
        [
          ( "error",
            Jsonl.Object
              [
                ("code", Jsonl.Int internal_error_code);
                ( "message",
                  Jsonl.String
                    "Internal error: response has both result and error" );
              ] );
          ("jsonrpc", Jsonl.String "2.0");
        ]
  in
  Jsonl.stringify (Jsonl.Object fields)