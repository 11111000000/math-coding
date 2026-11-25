open Helpers

let () =
  with_repo (fun root ->
      ignore (run root "init");
      ignore (run root "goal \"measure\" subject.txt owner");
      write root "subject.txt" "expected\n";
      (* The agent surface runs and declares only what the human approved. *)
      expect root "approve --by owner --reason \"the fixture approves the check\" --command \"true\"" 0;
      let requests =
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2026-07-28\"}}\n{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\"}\n{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"map\",\"arguments\":{}}}\n{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"tools/call\",\"params\":{\"name\":\"add\",\"arguments\":{\"id\":\"sample\",\"text\":\"measure\",\"scope\":\"subject.txt\",\"falsifier\":\"not measured\",\"requirement\":\"verifier:true\",\"control\":\"true\"}}}\n{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"1.0\"}}\n{\"jsonrpc\":\"2.0\",\"id\":6,\"method\":\"tools/call\",\"params\":{\"name\":\"add\",\"arguments\":{\"text\":\"missing id\"}}}\n{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"tools/call\",\"params\":{\"name\":\"add\",\"arguments\":{\"id\":\"x\",\"text\":\"x\",\"scope\":\"subject.txt\",\"falsifier\":\"x\",\"requirement\":\"verifier:true\",\"unknown\":true}}}\n{\"jsonrpc\":\"1.0\",\"id\":8,\"method\":\"ping\"}\n{\"jsonrpc\":\"2.0\",\"id\":10,\"method\":\"tools/call\",\"params\":{\"name\":\"run\",\"arguments\":{}}}\nnot-json\n"
      in
      let command = Printf.sprintf "%s --root %s mcp" (Filename.quote (binary ())) (Filename.quote root) in
      let channel = Unix.open_process_in (Printf.sprintf "%s <<'EOF'\n%sEOF" command requests) in
      let output = In_channel.input_all channel in
      ignore (Unix.close_process_in channel);
      let first_line = String.split_on_char '\n' output |> List.find (fun line -> String.trim line <> "") in
      let initialized = Yojson.Safe.from_string first_line in
      let protocol_ok =
        match field "result" initialized with
        | Some result -> field "protocolVersion" result = Some (`String "2026-07-28")
        | None -> false
      in
      check "MCP protocol version is exact" protocol_ok;
      check "tools have output schemas" (contains output "outputSchema");
      check "map returns structured content" (contains output "structuredContent");
      check "malformed request gets JSON-RPC error" (contains output "-32700");
      check "no prose is emitted" (not (contains output "math-coding 5 dev shell"));
      check "protocol negotiation rejects old version" (contains output "-32602");
      check "missing required arguments are errors" (contains output "required string argument is missing");
      check "unknown arguments are rejected" (contains output "unknown argument");
      check "invalid JSON-RPC version is rejected" (contains output "-32600");
      let responses = String.split_on_char '\n' output
        |> List.filter (fun line -> String.trim line <> "")
        |> List.map Yojson.Safe.from_string in
      let added = List.find_opt (fun response -> field "id" response = Some (`Int 4)) responses in
      (match added with
       | Some response ->
           (match field "result" response with
            | Some result ->
                (match field "structuredContent" result with
                 | Some content -> check "a textual add result is a successful tool call" (field "ok" content = Some (`Bool true))
                 | None -> failwith "add has no structured content");
                check "a textual add result is not a tool error" (field "isError" result = Some (`Bool false))
            | None -> failwith "add has no result")
       | None -> failwith "add has no response");
      let ran = List.find_opt (fun response -> field "id" response = Some (`Int 10)) responses in
      (match ran with
       | Some response ->
           (match field "result" response with
            | Some result ->
                (* An unknown verdict is the normal state of a project whose
                   checks have not run. The tool answered, so the call is not an
                   error; the verdict is the data. *)
                check "an unknown verdict is not a tool error" (field "isError" result = Some (`Bool false));
                (match field "structuredContent" result with
                 | Some content ->
                     check "run returns the map as data" (field "ok" content = Some (`Bool true));
                     (match field "data" content with
                      | Some data ->
                          check "run returns the current map as data"
                            (field "verdict" data = Some (`String "unknown")
                            &&
                            match field "next" data with
                            | Some (`String next) -> contains next "check the claim sample"
                            | _ -> false)
                      | None -> failwith "run has no map data")
                 | None -> failwith "run has no structured content")
            | None -> failwith "run has no result")
       | None -> failwith "run has no response");
      print_endline "mcp: PASS")

(* A command that could not answer at all is a tool error: the map of a
   project without a specification is not a map. *)
let () =
  with_repo (fun root ->
      let requests =
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2026-07-28\"}}\n{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"map\",\"arguments\":{}}}\n"
      in
      let command = Printf.sprintf "%s --root %s mcp" (Filename.quote (binary ())) (Filename.quote root) in
      let channel = Unix.open_process_in (Printf.sprintf "%s <<'EOF'\n%sEOF" command requests) in
      let output = In_channel.input_all channel in
      ignore (Unix.close_process_in channel);
      let responses = String.split_on_char '\n' output
        |> List.filter (fun line -> String.trim line <> "")
        |> List.map Yojson.Safe.from_string in
      let called = List.find_opt (fun response -> field "id" response = Some (`Int 2)) responses in
      (match called with
       | Some response ->
           (match field "result" response with
            | Some result ->
                check "a broken specification is a tool error" (field "isError" result = Some (`Bool true));
                (match field "structuredContent" result with
                 | Some content -> check "a broken specification is not ok" (field "ok" content = Some (`Bool false))
                 | None -> failwith "map has no structured content")
            | None -> failwith "map has no result")
       | None -> failwith "map has no response");
      print_endline "mcp-broken-spec: PASS")

(* The agent surface asks the human first. A command that nobody approved is
   neither declared nor executed: the refusal names the command and the step
   of the human, and the tree stays as it was. *)
let () =
  with_repo (fun root ->
      ignore (run root "init");
      ignore (run root "goal \"measure\" subject.txt owner");
      write root "subject.txt" "expected\n";
      (* The human declares a claim. The human did not approve its command. *)
      expect root "add sample \"the subject is expected\" subject.txt \"the subject is not expected\" fact --requirement \"verifier:grep -q expected subject.txt\" --control \"printf broken > subject.txt\"" 0;
      let requests =
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2026-07-28\"}}\n{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"add\",\"arguments\":{\"id\":\"other\",\"text\":\"measure\",\"scope\":\"subject.txt\",\"falsifier\":\"not measured\",\"requirement\":\"verifier:echo unapproved\",\"control\":\"true\"}}}\n{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"run\",\"arguments\":{}}}\n"
      in
      let command = Printf.sprintf "%s --root %s mcp" (Filename.quote (binary ())) (Filename.quote root) in
      let channel = Unix.open_process_in (Printf.sprintf "%s <<'EOF'\n%sEOF" command requests) in
      let output = In_channel.input_all channel in
      ignore (Unix.close_process_in channel);
      let responses = String.split_on_char '\n' output
        |> List.filter (fun line -> String.trim line <> "")
        |> List.map Yojson.Safe.from_string in
      let refusal id =
        match List.find_opt (fun response -> field "id" response = Some (`Int id)) responses with
        | Some response -> (
            match field "result" response with
            | Some result ->
                let text =
                  match field "structuredContent" result with
                  | Some content -> (match field "text" content with Some (`String text) -> text | _ -> "")
                  | None -> ""
                in
                (field "isError" result, text)
            | None -> failwith "the refusal has no result")
        | None -> failwith "the refusal has no response"
      in
      let declared_error, declared_text = refusal 2 in
      check "an unapproved command is not declared" (declared_error = Some (`Bool true));
      check "the refusal names the command" (contains declared_text "echo unapproved");
      check "the refusal names the step of the human" (contains declared_text "mathc approve");
      let run_error, run_text = refusal 3 in
      check "an unapproved check is not executed" (run_error = Some (`Bool true));
      check "the refusal of the run names the check" (contains run_text "grep -q expected subject.txt");
      (* The tree is untouched: the claim was not declared and no evidence was written. *)
      let specification = Io.read_file (Filename.concat root "spec.json") in
      check "the refused claim is not in the specification" (not (contains specification "\"other\""));
      check "the refused run writes no evidence"
        (not (Sys.file_exists (Filename.concat root ".math/v7/evidence.jsonl")));
     print_endline "mcp-approval: PASS")

(* The environment prefix is a command too: an approval of the verifier and the
   control does not authorize a different environment. *)
let () =
  with_repo (fun root ->
      ignore (run root "init");
      ignore (run root "goal \"the environment is approved\" subject.txt owner");
      write root "subject.txt" "expected\n";
      expect root "add sample \"the subject is expected\" subject.txt \"the subject is not expected\" fact --requirement \"verifier:true\" --control \"printf broken > subject.txt\" --environment \"touch marker &&\"" 0;
      expect root "approve --by owner --reason \"only the commands\" --command \"true\"" 0;
      expect root "approve --by owner --reason \"only the commands\" --command \"printf broken > subject.txt\"" 0;
      let requests =
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2026-07-28\"}}\n{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"run\",\"arguments\":{}}}\n"
      in
      let command = Printf.sprintf "%s --root %s mcp" (Filename.quote (binary ())) (Filename.quote root) in
      let channel = Unix.open_process_in (Printf.sprintf "%s <<'EOF'\n%sEOF" command requests) in
      let output = In_channel.input_all channel in
      ignore (Unix.close_process_in channel);
      check "the unapproved environment is refused" (contains output "touch marker");
      check "the unapproved environment is not executed" (not (Sys.file_exists (Filename.concat root "marker")));
      expect root "approve --by owner --reason \"the environment\" --command \"touch marker && sh -c true\"" 0;
      let answer = run root "map --json" in
      check "the approved environment is recorded in the approval journal"
        (contains (Io.read_file (Filename.concat root ".math/v7/approval.json")) "touch marker && sh -c true");
      ignore answer;
      print_endline "mcp-environment-approval: PASS")
