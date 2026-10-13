(* bin/mathc_mcp.ml — MCP server entry point.
 *
 * This binary is a thin JSON-RPC 2.0 server over stdio. It
 * exposes the seven read-only mathc subcommands listed in
 * `decisions/mcp-server-impl-2026-10.yaml`:
 *
 *   mathc/validate     mathc/explain     mathc/packages
 *   mathc/mode         mathc/re-evaluate mathc/rebuttals
 *   mathc/self-check
 *
 * Wire protocol: one request per line on stdin, one response per
 * line on stdout. stderr is reserved for the server's own
 * diagnostics (NOT client-visible). EOF on stdin exits cleanly.
 *
 * The dispatcher shells out to the mathc binary; this entry
 * point does the read/parse/dispatch/encode loop only.
 *
 * Exit codes: the server exits 0 on graceful EOF. Any other exit
 * is reserved for fatal dispatcher bugs (the protocol layer
 * never reaches the catch-all in production). *)

let[@warning "-32"] main_loop () =
  let rec loop () =
    match Transport.read_line () with
    | None ->
        (* EOF on stdin → graceful shutdown. *)
        ()
    | Some line ->
        (* Parse → dispatch → encode → write. *)
        let response =
          match Protocol.parse_request line with
          | Ok req -> Dispatch.handle req
          | Error err ->
              Protocol.response_error ~data:err.data err.code err.message
        in
        Transport.write_line (Protocol.encode_response response);
        loop ()
  in
  loop ()

let () = main_loop ()