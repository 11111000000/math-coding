(* The machine surface for agents: the verbs, spoken over MCP.

   THE GAP THIS FILLS. The agent arm of 2026-11-07 measured what the
   protocol cost an agent, and the largest part was not the
   bookkeeping: 35 of the 47 extra tool calls went into reading the
   method's SOURCE to learn what the verbs were and what they refused.
   The page fixed that for a reader of prose. A program cannot read
   prose - so the verbs are exposed as MCP methods, and each of them
   returns the NEXT STEP, not a list of successes.

   THE SUBJECT. A temporary git repository, as everywhere else: the
   method's own tree is not the subject of its own test.

   THE NEGATIVE CONTROL. The same battery, pointed at a server that
   answers nothing, must FAIL. A battery that passes against both the
   real server and a broken one is not a battery, it is a comment. *)

open Domain

(* --- the tool under test ------------------------------------------------ *)

let method_binary () =
  let candidates =
    match Sys.getenv_opt "MATHC" with
    | Some p -> [ p ]
    | None ->
        let here = Filename.dirname Sys.argv.(0) in
        let cwd = Sys.getcwd () in
        [
          Filename.concat (Filename.dirname here) "bin/mathc.exe";
          Filename.concat (Filename.dirname cwd) "bin/mathc.exe";
        ]
  in
  match List.find_opt Sys.file_exists candidates with
  | Some p -> p
  | None ->
      failwith
        (Printf.sprintf "the tool under test was not found; looked at %s"
           (String.concat ", " candidates))

let read_file path =
  let channel = open_in path in
  let content = In_channel.input_all channel in
  close_in channel;
  content

let contains (haystack : string) (needle : string) =
  let n = String.length haystack and m = String.length needle in
  let found = ref false in
  let i = ref 0 in
  while (not !found) && !i + m <= n do
    if String.sub haystack !i m = needle then found := true else i := !i + 1
  done;
  !found

(* --- the server ---------------------------------------------------------- *)

(* The server is asked a list of requests and answers with a list of
   answers. The requests go in on stdin and the answers come out on
   stdout; everything the server prints must be on that channel and
   nowhere else, because the channel IS the protocol. *)
let ask (binary : string) (root : string) (requests : string list) : string list =
  let input = Filename.temp_file "mathc-mcp" ".in" in
  let output = Filename.temp_file "mathc-mcp" ".out" in
  let channel = open_out input in
  List.iter
    (fun line ->
      output_string channel line;
      output_char channel '\n')
    requests;
  close_out channel;
  let cmd =
    Printf.sprintf "%s --root %s mcp < %s > %s 2>&1"
      (Filename.quote binary) (Filename.quote root) (Filename.quote input)
      (Filename.quote output)
  in
  ignore (Sys.command cmd);
  let text = read_file output in
  Sys.remove input;
  Sys.remove output;
  String.split_on_char '\n' text
  |> List.filter (fun line -> String.trim line <> "")

(* One field of one answer.

   The answer of a call carries its payload under "result", so the
   field is looked for there too - and the lookup is a search and not
   an index, because the shape of the answer is the protocol's and not
   the test's. *)
let rec find (name : string) (json : Yojson.Safe.t) : Yojson.Safe.t option =
  match json with
  | `Assoc pairs -> (
      match List.assoc_opt name pairs with
      | Some v -> Some v
      | None -> (
          match List.assoc_opt "result" pairs with
          | Some r -> find name r
          | None -> None))
  | _ -> None

let field (answer : string) (name : string) : string =
  match Yojson.Safe.from_string answer with
  | json -> (
      match find name json with
      | Some (`String s) -> s
      | Some v -> Yojson.Safe.to_string v
      | None -> "")
  | exception Yojson.Json_error _ -> ""

(* --- the subject --------------------------------------------------------- *)

let with_repository (f : string -> unit) =
  let path = Filename.temp_file "mathc-mcp" ".dir" in
  Sys.remove path;
  Unix.mkdir path 0o755;
  let root = path in
  let shell cmd =
    if Sys.command cmd <> 0 then failwith ("the test's own setup failed: " ^ cmd)
  in
  shell (Printf.sprintf "git -C %s init -q ." (Filename.quote root));
  let file = Filename.concat root "subject.txt" in
  let channel = open_out file in
  output_string channel "the subject\n";
  close_out channel;
  shell (Printf.sprintf "git -C %s add -A ." (Filename.quote root));
  shell
    (Printf.sprintf
       "git -C %s -c user.email=test@example -c user.name=test commit -qm init ."
       (Filename.quote root));
  let cleanup () = ignore (Sys.command ("rm -rf " ^ Filename.quote root)) in
  (try f root with e ->
     cleanup ();
     raise e);
  cleanup ()

(* --- the battery --------------------------------------------------------- *)

let check_the_server_in (binary : string) (root : string) =
  let shell cmd =
    if Sys.command cmd <> 0 then
      failwith ("the test's own setup failed: " ^ cmd)
  in
  shell (Printf.sprintf "%s --root %s init 3 > /dev/null" (Filename.quote binary) (Filename.quote root));
  shell
    (Printf.sprintf "%s --root %s goal \"the aim\" subject.txt \"the owner\" > /dev/null"
       (Filename.quote binary) (Filename.quote root));

  (* The handshake. *)
  let answers =
    ask binary root
      [
        {|{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05"}}|};
      ]
  in
  assert (List.length answers = 1);
  let handshake = List.hd answers in
  assert (contains handshake "protocolVersion");
  assert (contains handshake "mathc");

  (* A notification is answered with nothing: the protocol says so,
     and an answer that nobody waits for is a line on the wire that
     the client has to skip. *)
  let answers =
    ask binary root
      [
        {|{"jsonrpc":"2.0","method":"notifications/initialized"}|};
        {|{"jsonrpc":"2.0","id":7,"method":"tools/list"}|};
      ]
  in
  assert (List.length answers = 1);
  let tools = List.hd answers in
  (* The tools an agent needs: the map, the next step, the
     declaration, the run, the unit of work, the closing, the page
     and the check of the setup. The person's moves - the aim, the
     acceptance, the record of somebody else's word - are NOT here:
     they are the person's, and an agent that could take them would
     be taking them. *)
  List.iter
    (fun name -> assert (contains tools name))
    [ "map"; "next"; "add"; "run"; "wave"; "close"; "install"; "doctor" ];
  List.iter
    (fun name -> assert (not (contains tools ("\"" ^ name ^ "\""))))
    [ "goal"; "accept"; "record"; "draft" ];

  (* The map, and the next step beside it. THE CRITERION: no method
     returns a list of successes, and an agent that has the map
     knows what to do next. *)
  let answers =
    ask binary root
      [ {|{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"map","arguments":{}}}|} ]
  in
  let answer = List.hd answers in
  assert (contains answer "verdict");
  let content = field answer "content" in
  assert (contains content "next");
  assert (contains content "uncovered");

  (* The next work: one item, never a list. *)
  let answers =
    ask binary root
      [ {|{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"next","arguments":{}}}|} ]
  in
  let content = field (List.hd answers) "content" in
  assert (contains content "next");

  (* A declaration over the wire. *)
  let answers =
    ask binary root
      [
        {|{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"add","arguments":{"id":"mcp-claim","subject":"the subject holds","scope":"subject.txt","falsifier":"the check fails","register":"fact","requirement":"verifier:true","control":"false"}}}|};
      ]
  in
  let content = field (List.hd answers) "content" in
  assert (contains content "mcp-claim declared");

  (* And a run binds the proof. *)
  let answers =
    ask binary root
      [ {|{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"run","arguments":{}}}|} ]
  in
  let content = field (List.hd answers) "content" in
  assert (contains content "mcp-claim: verified");

  (* A unit of work, over the wire. THE TWO METHODS THAT WERE ONLY
     NAMED: a name in the list of tools is not a method that works,
     and the battery has to CALL it - otherwise the check is a
     comment with a file name on it. *)
  let answers =
    ask binary root
      [
        {|{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"wave","arguments":{"id":"mcp-wave","title":"a wave over the wire","intent":"to check that the wave can be made over the wire","objection":"the wire may lose the dialectic","refuted_by":"the wave refuses to be made without it","check":"true","commit":"mcp-claim=holds"}}}|};
      ]
  in
  let content = field (List.hd answers) "content" in
  assert (contains content "mcp-wave created");
  (* The wave exists: the tool says so, and the queue names it. *)
  let answers =
    ask binary root
      [ {|{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"next","arguments":{}}}|} ]
  in
  let content = field (List.hd answers) "content" in
  assert (contains content "mcp-wave");

  (* And it closes when its promise is met. *)
  let answers =
    ask binary root
      [ {|{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"close","arguments":{"wave":"mcp-wave"}}}|} ]
  in
  let content = field (List.hd answers) "content" in
  assert (contains content "mcp-wave closed");

  (* A broken line does not take the server down. *)
  let answers =
    ask binary root
      [ "this is not json"; {|{"jsonrpc":"2.0","id":9,"method":"ping"}|} ]
  in
  assert (List.length answers = 2)

let check_the_server (binary : string) =
  with_repository (fun root -> check_the_server_in binary root)

let () =
  check_the_server (method_binary ());
  (* THE NEGATIVE CONTROL. A server that answers nothing must fail the
     battery: otherwise the battery is a comment with a file name on
     it. The broken server is a program that says nothing and
     succeeds - the worst kind, because it looks alive. *)
  let silent = Filename.temp_file "mathc-silent" ".sh" in
  let channel = open_out silent in
  output_string channel "#!/bin/sh\nexit 0\n";
  close_out channel;
  Unix.chmod silent 0o755;
  let detected =
    try
      check_the_server silent;
      false
    with _ -> true
  in
  Sys.remove silent;
  assert detected;

  (* AND THE ASSERTIONS THAT NEED A PROJECT MUST HAVE TEETH. The same
     battery, pointed at a directory that is NOT a project of the
     method: the handshake and the list of tools still answer, and the
     map and the wave must NOT - because there is nothing there to map
     and nothing to make a wave of.

     Without this, the broken server above would have failed the
     battery at the FIRST assertion, and the assertions further down -
     the ones about the map, the wave and the closing - would never
     have been shown to be able to fail at all. *)
  let not_a_project = Filename.temp_file "mathc-not" ".dir" in
  Sys.remove not_a_project;
  Unix.mkdir not_a_project 0o755;
  let detected =
    try
      check_the_server_in (method_binary ()) not_a_project;
      false
    with _ -> true
  in
  ignore (Sys.command ("rm -rf " ^ Filename.quote not_a_project));
  assert detected;
  print_endline "mcp: PASS"
