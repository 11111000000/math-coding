let protocol_version = "2026-07-28"

let run_verb ~root args =
  let project_root = if Filename.is_relative root then Filename.concat (Sys.getcwd ()) root else root in
  let command =
    String.concat " "
      (Filename.quote Sys.executable_name :: "--root" :: Filename.quote project_root
       :: List.map Filename.quote args)
  in
  Process.run ~timeout:120.0 ~root command

let next_step ~root =
  let result = run_verb ~root [ "next" ] in
  `String (String.trim result.stdout)

let parsed ~root args =
  let result = run_verb ~root args in
  match Yojson.Safe.from_string result.stdout with
  | json -> `Assoc [ "ok", `Bool (result.code = 0); "data", json; "next", next_step ~root ]
  | exception Yojson.Json_error _ ->
      `Assoc [ "ok", `Bool (result.code = 0); "text", `String (result.stdout ^ result.stderr);
               "next", next_step ~root ]

let schema ?(required = []) properties =
  `Assoc
    [ "type", `String "object";
      "properties", `Assoc properties;
      "required", `List (List.map (fun name -> `String name) required);
      "additionalProperties", `Bool false ]

let output_schema =
  `Assoc
    [ "type", `String "object";
      "properties",
        `Assoc
          [ "ok", `Assoc [ "type", `String "boolean" ];
            "data", `Assoc [];
            "text", `Assoc [ "type", `String "string" ];
            "next", `Assoc [ "type", `String "string" ] ];
      "required", `List [ `String "ok"; `String "next" ] ]

let tool name description input_schema =
  `Assoc
    [ "name", `String name;
      "description", `String description;
      "inputSchema", input_schema;
      "outputSchema", output_schema ]

let tools =
  [ tool "map" "The current obligations, evidence, uncovered files and next action." (schema []);
    tool "next" "One read-only next action." (schema []);
    tool "context" "The bounded context for continuing the current task." (schema []);
    tool "run" "Execute project checks and bind evidence. May have side effects." (schema []);
    tool "adopt" "Detect ADR and specification sources without changing them." (schema []);
    tool "import-adr" "Read an ADR into a source-linked draft, never active."
      (schema ~required:[ "path" ] [ "path", `Assoc [ "type", `String "string" ] ]);
    tool "add" "Declare an obligation with an explicit verifier and control."
      (schema ~required:[ "id"; "text"; "scope"; "falsifier"; "requirement" ]
         [ "id", `Assoc [ "type", `String "string" ];
           "text", `Assoc [ "type", `String "string" ];
           "scope", `Assoc [ "type", `String "string" ];
           "falsifier", `Assoc [ "type", `String "string" ];
           "register", `Assoc [ "type", `String "string" ];
           "requirement", `Assoc [ "type", `String "string" ];
           "control", `Assoc [ "type", `String "string" ];
           "source", `Assoc [ "type", `String "string" ] ]);
    tool "doctor" "Check repository setup without changing it." (schema []) ]

let field name json =
  match json with `Assoc pairs -> List.assoc_opt name pairs | _ -> None

let string_arg name args =
  match field name args with Some (`String value) -> value | _ -> ""

let call ~root name args =
  match name with
  | "map" | "context" -> parsed ~root [ "map"; "--json" ]
  | "next" -> (
      let result = run_verb ~root [ "next" ] in
      `Assoc [ "ok", `Bool (result.code = 0); "text", `String result.stdout;
               "next", next_step ~root ])
  | "run" -> (
      let result = run_verb ~root [ "run" ] in
      `Assoc [ "ok", `Bool (result.code = 0); "text", `String (result.stdout ^ result.stderr);
               "next", next_step ~root ])
  | "adopt" -> parsed ~root [ "adopt" ]
  | "import-adr" -> parsed ~root [ "import-adr"; string_arg "path" args ]
  | "doctor" -> (
      let result = run_verb ~root [ "doctor" ] in
      `Assoc [ "ok", `Bool (result.code = 0); "text", `String (result.stdout ^ result.stderr);
               "next", next_step ~root ])
  | "add" ->
      let arguments =
        [ "add"; string_arg "id" args; string_arg "text" args;
          string_arg "scope" args; string_arg "falsifier" args;
          (match string_arg "register" args with "" -> "unknown" | value -> value);
          "--requirement"; string_arg "requirement" args;
          "--control"; string_arg "control" args;
          "--source"; string_arg "source" args ]
      in
      parsed ~root arguments
  | _ -> `Assoc [ "ok", `Bool false; "text", `String ("unknown tool: " ^ name); "next", next_step ~root ]

let handle ~root request =
  let id = field "id" request in
  let method_ = match field "method" request with Some (`String method_) -> method_ | _ -> "" in
  let params = Option.value ~default:(`Assoc []) (field "params" request) in
  let respond result =
    match id with
    | Some id -> Some (`Assoc [ "jsonrpc", `String "2.0"; "id", id; "result", result ])
    | None -> None
  in
  let error code message =
    match id with
    | Some id ->
        Some (`Assoc [ "jsonrpc", `String "2.0"; "id", id;
                       "error", `Assoc [ "code", `Int code; "message", `String message ] ])
    | None -> None
  in
  match method_ with
  | "initialize" ->
      respond
        (`Assoc
          [ "protocolVersion", `String protocol_version;
            "capabilities", `Assoc [ "tools", `Assoc [] ];
            "serverInfo", `Assoc [ "name", `String "mathc"; "version", `String "5" ] ])
  | "notifications/initialized" -> None
  | "ping" -> respond (`Assoc [])
  | "tools/list" -> respond (`Assoc [ "tools", `List tools ])
  | "tools/call" ->
      let name = match field "name" params with Some (`String name) -> name | _ -> "" in
      let arguments = Option.value ~default:(`Assoc []) (field "arguments" params) in
      let result = call ~root name arguments in
      let is_error = match field "ok" result with Some (`Bool ok) -> not ok | _ -> true in
      respond
        (`Assoc
          [ "content", `List [ `Assoc [ "type", `String "text"; "text", `String (Yojson.Safe.to_string result) ] ];
            "structuredContent", result;
            "isError", `Bool is_error ])
  | _ -> error (-32601) ("there is no method named " ^ method_)

let loop ~root =
  let rec next () =
    match input_line stdin with
    | line -> (
        let response =
          match Yojson.Safe.from_string (String.trim line) with
          | json -> handle ~root json
          | exception Yojson.Json_error error ->
              Some (`Assoc [ "jsonrpc", `String "2.0"; "id", `Null;
                             "error", `Assoc [ "code", `Int (-32700); "message", `String error ] ])
        in
        (match response with
         | Some json -> print_endline (Yojson.Safe.to_string json); flush stdout
         | None -> ());
        next ())
    | exception End_of_file -> ()
  in
  next ();
  0
