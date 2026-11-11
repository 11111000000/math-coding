open Helpers

let () =
  with_repo (fun root ->
      ignore (run root "init");
      ignore (run root "goal \"measure\" subject.txt owner");
      write root "subject.txt" "expected\n";
      let requests =
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2026-07-28\"}}\n{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\"}\n{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"map\",\"arguments\":{}}}\n{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"tools/call\",\"params\":{\"name\":\"add\",\"arguments\":{\"id\":\"sample\",\"text\":\"measure\",\"scope\":\"subject.txt\",\"falsifier\":\"not measured\",\"requirement\":\"verifier:true\"}}}\nnot-json\n"
      in
      let command = Printf.sprintf "%s --root %s mcp" (Filename.quote (binary ())) (Filename.quote root) in
      let channel = Unix.open_process_in (Printf.sprintf "%s <<'EOF'\n%sEOF" command requests) in
      let output = In_channel.input_all channel in
      ignore (Unix.close_process_in channel);
      check "MCP protocol version is current" (contains output "2026-07-28");
      check "tools have output schemas" (contains output "outputSchema");
      check "map returns structured content" (contains output "structuredContent");
      check "malformed request gets JSON-RPC error" (contains output "-32700");
      check "no prose is emitted" (not (contains output "math-coding 5 dev shell"));
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
      print_endline "mcp: PASS")
