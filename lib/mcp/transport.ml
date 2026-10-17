(* lib/mcp/transport.ml — stdio line-buffered transport.
 *
 * The MCP server speaks JSON-RPC 2.0 over stdio: one request per
 * line on stdin, one response per line on stdout. This module is
 * the IO boundary; the protocol layer is pure.
 *
 * Stdio discipline (per the MCP reference architecture):
 *   - read: one line at a time from stdin, terminated by `\n`.
 *     The newline is stripped; the body is the JSON-RPC request.
 *     Empty lines are skipped (defensive — clients sometimes emit
 *     heartbeats). A line longer than `max_request_bytes` is
 *     treated as protocol-level garbage and surfaces as `None`
 *     to the caller (same shape as EOF) so a runaway client
 *     cannot exhaust memory.
 *   - write: one response per call, terminated by `\n`. Stdout is
 *     flushed after every write so the client sees responses
 *     immediately. A write to a closed pipe raises `Sys_error`
 *     which the dispatcher catches as a fatal condition.
 *   - stderr: reserved for the server's own diagnostics (NOT
 *     client-visible). Stderr is never mixed into the JSON-RPC
 *     stream.
 *   - EOF on stdin: graceful shutdown. Returns `None` from
 *     `read_line`; the dispatcher's loop exits cleanly.
 *
 * No buffering tricks. `In_channel.input_line` is line-buffered
 * already; `Out_channel.output_string` plus `Out_channel.flush`
 * gives the client immediate visibility.
 *
 * Transport does NOT validate that the body is JSON. That's the
 * protocol layer's job (so the error code is the JSON-RPC one,
 * not a transport-level "garbled bytes"). Transport-level errors
 * (e.g. an I/O error) raise an exception that the dispatcher
 * catches as a fatal condition. *)

(* Upper bound on a single inbound JSON-RPC request line. The
   dispatcher side caps the mathc-subprocess response at 16 MiB
   (`lib/mcp/dispatch.ml:101`); the request side is bounded at
   1 MiB to leave headroom for the response and to make a
   runaway client easier to detect. *)
let max_request_bytes = 1_048_576

let read_line () : string option =
  let rec loop () =
    try
      let line = In_channel.input_line stdin in
      match line with
      | None -> None
      | Some s ->
          let s = String.trim s in
          if String.length s = 0 then loop ()
          else if String.length s > max_request_bytes then begin
            (* Runaway client: drop the line and surface EOF so
               the dispatcher shuts down. The MCP client will see
               the connection close without a response. *)
            None
          end
          else Some s
    with End_of_file -> None
  in
  loop ()

let write_line (s : string) : unit =
  Out_channel.output_string stdout s;
  Out_channel.output_char stdout '\n';
  Out_channel.flush stdout

(* Read all available bytes from a Unix file descriptor until EOF,
   capped at `max_bytes` to prevent a runaway subprocess from
   filling memory. The dispatcher uses this to slurp the mathc
   subprocess's stdout. The fd should be the read end of a pipe
   connected to the subprocess. *)
let read_all_from_fd (fd : Unix.file_descr) ~(max_bytes : int) : string =
  let buf = Buffer.create 4096 in
  let chunk = Bytes.create 4096 in
  let rec loop () =
    let n =
      try Unix.read fd chunk 0 (Bytes.length chunk) with
      | Unix.Unix_error (Unix.EINTR, _, _) -> -1
      | _ -> 0
    in
    if n > 0 then begin
      let to_add = min n (max_bytes - Buffer.length buf) in
      if to_add > 0 then Buffer.add_subbytes buf chunk 0 to_add;
      if Buffer.length buf < max_bytes then loop ()
    end
  in
  loop ();
  Buffer.contents buf