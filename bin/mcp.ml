(** THE MACHINE SURFACE FOR AGENTS.

    THE AGENT HAD TO READ THE SOURCE. The measurement of 2026-11-07
    measured what the protocol cost an agent: 35 of the 47 extra tool
    calls went into reading the method's own source to learn what the
    verbs were and what they refused. The page fixed that - one read
    instead of thirty-five - but the page is prose, and a program
    cannot read prose.

    So the verbs are exposed as MCP methods, and each of them returns
    **the next step**, not a list of successes. The criterion is
    written down: "no method returns a list of successes; an agent
    that has the map knows what to do next, without reading the
    method's documentation".

    WHAT THE METHODS ARE. They are the verbs, and nothing else: the
    server runs the tool and hands back what it said. The logic stays
    in one place, and the protocol layer stays a translation - which is
    what the third version got wrong, when the interface was a second
    implementation of the method's rules.

    The bound is named: the server runs the PROJECT'S commands, so
    whoever can call the server can run the project's checks. That is
    not a new power - the agent that calls it usually has a shell - and
    it is said here rather than left for somebody to find.

    THE PROTOCOL. JSON-RPC over stdio, read with the JSON library:
    one request per line, one answer per line. The requests and the
    answers are data, and the shape of the data is the one the
    protocol names - which is written here by hand, because a protocol
    is a protocol and not a format with a library behind it. *)

(** The protocol version this server speaks. A client that asks for a
    version it names is answered in that version when it is one this
    server knows; otherwise the answer is the version below. *)
let protocol_version = "2024-11-05"

(** The tools, as the protocol wants them: a name, a description and a
    schema of the arguments.

    The description is what an agent reads before it calls, so it says
    what the method does AND what comes back - including the next step,
    because that is the whole contract. *)
let tools_json () =
  `List
    [
      ( `Assoc
        [
          ("name", `String "map");
          ( "description",
            `String
              "The standing specification of the project: the claims, their states, \
               the uncovered files, and the verdict. Returns the next step as well - \
               what to do next - so the map is enough to act on." );
          ("inputSchema", `Assoc [ ("type", `String "object"); ("properties", `Assoc []) ]);
        ] );
      ( `Assoc
        [
          ("name", `String "next");
          ( "description",
            `String
              "The next work, one item: a wave to carry out, a claim to check, or the \
               first uncovered file. Never a list." );
          ("inputSchema", `Assoc [ ("type", `String "object"); ("properties", `Assoc []) ]);
        ] );
      ( `Assoc
        [
          ("name", `String "add");
          ( "description",
            `String
              "Declare a claim: a proposition about a subject, the ways it must be \
               closed, and the command that breaks the subject and must fail with it. \
               The scope must name existing paths; a promise about a subject that does \
               not exist yet is accepted and is called a plan. Returns the next step." );
          ( "inputSchema",
            `Assoc
              [
                ("type", `String "object");
                ( "properties",
                  `Assoc
                    [
                      ("id", `Assoc [ ("type", `String "string") ]);
                      ("subject", `Assoc [ ("type", `String "string") ]);
                      ( "scope",
                        `Assoc
                          [
                            ("type", `String "string");
                            ( "description",
                              `String
                                "The paths the claim is about, comma-separated. They \
                                 must exist in the tree." );
                          ] );
                      ("falsifier", `Assoc [ ("type", `String "string") ]);
                      ( "register",
                        `Assoc
                          [
                            ("type", `String "string");
                            ( "enum",
                              `List
                                [ `String "fact"; `String "hypothesis";
                                  `String "judgment"; `String "unknown" ] );
                          ] );
                      ( "requirement",
                        `Assoc
                          [
                            ("type", `String "string");
                            ( "description",
                              `String
                                "How the claim is closed: verifier:COMMAND, or \
                                 review:WHO. May be given more than once." );
                          ] );
                      ( "control",
                        `Assoc
                          [
                            ("type", `String "string");
                            ( "description",
                              `String
                                "The command that breaks the subject and must fail \
                                 with it: a check that cannot fail proves nothing." );
                          ] );
                    ] );
              ] );
        ] );
      ( `Assoc
        [
          ("name", `String "run");
          ( "description",
            `String
              "Run the project's checks and bind every proof to the content it ran \
               against. Returns the verdict and the next step." );
          ("inputSchema", `Assoc [ ("type", `String "object"); ("properties", `Assoc []) ]);
        ] );
      ( `Assoc
        [
          ("name", `String "wave");
          ( "description",
            `String
              "Declare a unit of work: a wave with its intent, the checks it must pass, \
               the promises it makes, and the strongest objection against it - and what \
               would refute that objection. A wave without the objection is refused." );
          ( "inputSchema",
            `Assoc
              [
                ("type", `String "object");
                ( "properties",
                  `Assoc
                    [
                      ("id", `Assoc [ ("type", `String "string") ]);
                      ("title", `Assoc [ ("type", `String "string") ]);
                      ("intent", `Assoc [ ("type", `String "string") ]);
                      ("objection", `Assoc [ ("type", `String "string") ]);
                      ("refuted_by", `Assoc [ ("type", `String "string") ]);
                      ( "check",
                        `Assoc
                          [
                            ("type", `String "string");
                            ( "description",
                              `String "A command that must pass. May be given more than once." );
                          ] );
                      ( "commit",
                        `Assoc
                          [
                            ("type", `String "string");
                            ( "description",
                              `String
                                "A promise: CLAIM=STATE, the state the claim will be in \
                                 when the wave is done. May be given more than once." );
                          ] );
                    ] );
              ] );
        ] );
      ( `Assoc
        [
          ("name", `String "close");
          ( "description",
            `String
              "Close a wave: its checks must pass and every promise it made must be met. \
               Returns the next step." );
          ( "inputSchema",
            `Assoc
              [
                ("type", `String "object");
                ( "properties",
                  `Assoc [ ("wave", `Assoc [ ("type", `String "string") ]) ] );
              ] );
        ] );
      ( `Assoc
        [
          ("name", `String "install");
          ( "description",
            `String
              "Write the page for agents into the project: a generated block inside \
               AGENTS.md, built from the tool's own help and the project's \
               specification. Nothing outside the block is touched." );
          ("inputSchema", `Assoc [ ("type", `String "object"); ("properties", `Assoc []) ]);
        ] );
      ( `Assoc
        [
          ("name", `String "doctor");
          ( "description",
            `String
              "Check that the project is set up for the method: git, the standing \
               specification, the aim, and whether the page for agents is current. \
               Changes nothing." );
          ("inputSchema", `Assoc [ ("type", `String "object"); ("properties", `Assoc []) ]);
        ] );
    ]

(** One of the methods, run as the verb it stands for.

    The verb is the logic; the server is the translation. The output
    and the exit code are both taken, and a refusal is a refusal and
    not a crash: the answer says what the tool said. *)
let run_verb ~(root : string) (args : string list) : string * int =
  let quoted = List.map Filename.quote args in
  let tool =
    match Exec.own_path () with
    | Some path -> path
    | None -> "mathc"
  in
  (* The tool is run in the project the server was started in - the
     server speaks about ONE project, and that project is the
     directory it was started from. *)
  let command =
    tool ^ " --root " ^ Filename.quote root ^ " " ^ String.concat " " quoted
  in
  Exec.capture ~root command

(** The next step, as the tool says it.

    It is one item and never a list: the tool was built so that the
    queue leads, and a list is a catalogue. *)
let next_step ~(root : string) : string =
  let out, _ = run_verb ~root [ "next" ] in
  String.trim out

(** The answer of one method: what it said, and what to do next. *)
let answer_with_next ~(root : string) (text : string)
    (extra : (string * Yojson.Safe.t) list) : Yojson.Safe.t =
  `Assoc
    (( "text",
        `String (if String.length text > 0 && text.[String.length text - 1] = '\n' then
                     String.sub text 0 (String.length text - 1)
                   else text) )
    :: extra @ [ ("next", `String (next_step ~root)) ])

(** The map, as data, with the next step beside it. *)
let map_method ~(root : string) : Yojson.Safe.t =
  let out, _ = run_verb ~root [ "map"; "--json" ] in
  let json =
    match Yojson.Safe.from_string out with
    | j -> j
    | exception Yojson.Json_error _ -> `Null
  in
  `Assoc [ ("map", json); ("next", `String (next_step ~root)) ]

(** The claim to add, as the arguments of the verb. *)
let add_method ~(root : string) (args : (string * Yojson.Safe.t) list) :
    Yojson.Safe.t =
  let get name =
    match List.assoc_opt name args with Some (`String s) -> s | _ -> ""
  in
  let requirements =
    match List.assoc_opt "requirement" args with
    | Some (`String s) -> [ s ]
    | Some (`List items) ->
        List.filter_map (function `String s -> Some s | _ -> None) items
    | _ -> []
  in
  let verb_args =
    [ "add"; get "id"; get "subject"; get "scope"; get "falsifier";
      (if get "register" = "" then "unknown" else get "register") ]
    @ List.concat_map (fun r -> [ "--requirement"; r ]) requirements
    @ (if get "control" = "" then [] else [ "--control"; get "control" ])
  in
  let out, code = run_verb ~root verb_args in
  let ok = code = 0 in
  `Assoc
    [
      ("ok", `Bool ok);
      ("text", `String out);
      ("next", `String (next_step ~root));
    ]

(** One call of one method. *)
let call_tool ~(root : string) (name : string)
    (args : (string * Yojson.Safe.t) list) : Yojson.Safe.t * bool =
  match name with
  | "map" -> (map_method ~root, false)
  | "next" ->
      let out, _ = run_verb ~root [ "next" ] in
      (`Assoc [ ("text", `String out); ("next", `String (String.trim out)) ], false)
  | "add" -> (add_method ~root args, false)
  | "run" ->
      let out, code = run_verb ~root [ "run" ] in
      ( `Assoc
          [
            ("ok", `Bool (code = 0));
            ("text", `String out);
            ("next", `String (next_step ~root));
          ],
        false )
  | "wave" ->
      let get name =
        match List.assoc_opt name args with Some (`String s) -> s | _ -> ""
      in
      let many name =
        match List.assoc_opt name args with
        | Some (`String s) -> [ s ]
        | Some (`List items) ->
            List.filter_map (function `String s -> Some s | _ -> None) items
        | _ -> []
      in
      let verb_args =
        [ "wave"; get "id"; get "title"; "--intent"; get "intent";
          "--objection"; get "objection"; "--refuted-by"; get "refuted_by" ]
        @ List.concat_map (fun c -> [ "--check"; c ]) (many "check")
        @ List.concat_map (fun c -> [ "--commit"; c ]) (many "commit")
      in
      let out, code = run_verb ~root verb_args in
      (`Assoc [ ("ok", `Bool (code = 0)); ("text", `String out) ], false)
  | "close" ->
      let get name =
        match List.assoc_opt name args with Some (`String s) -> s | _ -> ""
      in
      let out, code = run_verb ~root [ "close"; get "wave" ] in
      ( `Assoc
          [
            ("ok", `Bool (code = 0));
            ("text", `String out);
            ("next", `String (next_step ~root));
          ],
        false )
  | "install" ->
      let out, code = run_verb ~root [ "install" ] in
      (`Assoc [ ("ok", `Bool (code = 0)); ("text", `String out) ], false)
  | "doctor" ->
      let out, code = run_verb ~root [ "doctor" ] in
      (`Assoc [ ("ok", `Bool (code = 0)); ("text", `String out) ], false)
  | other ->
      (`String ("there is no method named " ^ other), true)

(** One request, one answer.

    A request without an id is a notification, and a notification is
    answered with nothing - the protocol says so, and answering it
    would put a line on the wire that the client is not waiting for. *)
let handle ~(root : string) (request : Yojson.Safe.t) : Yojson.Safe.t option =
  let get name =
    match request with
    | `Assoc pairs -> (
        match List.assoc_opt name pairs with Some v -> Some v | None -> None)
    | _ -> None
  in
  let id = get "id" in
  let method_ =
    match get "method" with Some (`String m) -> m | _ -> ""
  in
  let params =
    match get "params" with Some p -> p | None -> `Assoc []
  in
  let args_of_params =
    match params with `Assoc pairs -> pairs | _ -> []
  in
  let result json =
    match id with
    | Some i -> Some (`Assoc [ ("jsonrpc", `String "2.0"); ("id", i); ("result", json) ])
    | None -> None
  in
  let error code message =
    match id with
    | Some i ->
        Some
          (`Assoc
            [
              ("jsonrpc", `String "2.0");
              ("id", i);
              ( "error",
                `Assoc [ ("code", `Int code); ("message", `String message) ] );
            ])
    | None -> None
  in
  match method_ with
  | "initialize" ->
      (* The version the client asks for, when it is one this server
         knows; otherwise the version this server speaks. *)
      let version =
        match List.assoc_opt "protocolVersion" args_of_params with
        | Some (`String v) when v = protocol_version -> v
        | _ -> protocol_version
      in
      result
        (`Assoc
          [
            ("protocolVersion", `String version);
            ("capabilities", `Assoc [ ("tools", `Assoc []) ]);
            ( "serverInfo",
              `Assoc [ ("name", `String "mathc"); ("version", `String "4") ] );
          ])
  | "notifications/initialized" -> None
  | "ping" -> result (`Assoc [])
  | "tools/list" -> result (`Assoc [ ("tools", tools_json ()) ])
  | "tools/call" ->
      let name =
        match List.assoc_opt "name" args_of_params with
        | Some (`String n) -> n
        | _ -> ""
      in
      let args =
        match List.assoc_opt "arguments" args_of_params with
        | Some (`Assoc pairs) -> pairs
        | _ -> []
      in
      let content, is_error = call_tool ~root name args in
      result
        (`Assoc
          [
            ( "content",
              `List [ `Assoc [ ("type", `String "text"); ("text", `String (Yojson.Safe.to_string content)) ] ] );
            ("isError", `Bool is_error);
          ])
  | other -> error (-32601) ("there is no method named " ^ other)

(** The server loop.

    One request per line, one answer per line. The line is JSON and is
    read with the JSON library; a line that is not JSON is answered
    with an error and the loop goes on, because a broken client must
    not take the server down with it. *)
let mcp_loop ~(root : string) =
  let input = stdin in
  let rec loop () =
    match input_line input with
    | line ->
        let trimmed = String.trim line in
        if trimmed <> "" then begin
          let answer =
            match Yojson.Safe.from_string trimmed with
            | json -> handle ~root json
            | exception Yojson.Json_error msg ->
                Some
                  (`Assoc
                    [
                      ("jsonrpc", `String "2.0");
                      ("id", `Null);
                      ( "error",
                        `Assoc [ ("code", `Int (-32700)); ("message", `String msg) ] );
                    ])
          in
          match answer with
          | Some json ->
              print_endline (Yojson.Safe.to_string json);
              flush stdout
          | None -> ()
        end;
        loop ()
    | exception End_of_file -> ()
  in
  loop ()
