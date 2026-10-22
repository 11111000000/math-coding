(* tests/support/forge_stub/forge_stub.ml
 *
 * A minimal OCaml HTTP server used by tests/rebuttal_forge_stub.ml
 * as the target of mathc forge-verify HTTP probes. *)

(* Read one HTTP request head from `fd` and return it.
 *
 * Terminates on the first blank line — the RFC 9112 end of the
 * header section — and stops reading at that byte: a client that
 * sent its headers and is waiting (keep-alive) must not be left
 * blocked in `Unix.read` while the stub owes it a response. Also
 * terminates on EOF (`Unix.read` returning 0), returning whatever
 * arrived, so a client that hangs up mid-request cannot wedge the
 * server.
 *
 * Line terminators: `\r\n` and bare `\n` both end a line; the `\r`
 * is dropped rather than accumulated. The accumulator keeps one
 * line per output line so the returned string is the header block
 * re-normalised to `\n`.
 *
 * Any request body is deliberately NOT drained: reading past the
 * blank line is exactly what this function refuses to do. The
 * single caller serves bodyless GETs, so the socket receive queue
 * is empty at close and the peer sees FIN, not RST. *)
let[@warning "-32"] read_request fd =
  let buf = Bytes.create 4096 in
  let acc = Buffer.create 256 in
  let line = Buffer.create 128 in
  let head_done = ref false in
  while not !head_done do
    let n = Unix.read fd buf 0 (Bytes.length buf) in
    if n <= 0 then head_done := true
    else
      for i = 0 to n - 1 do
        if not !head_done then
          match Bytes.unsafe_get buf i with
          | '\r' -> ()
          | '\n' ->
              if Buffer.length line = 0 then head_done := true
              else begin
                Buffer.add_string acc (Buffer.contents line);
                Buffer.add_char acc '\n';
                Buffer.clear line
              end
          | c -> Buffer.add_char line c
      done
  done;
  Buffer.contents acc

let[@warning "-32"] write_all fd buf off len =
  let written = ref off in
  while !written < off + len do
    let n = Unix.write fd buf !written (off + len - !written) in
    written := !written + n
  done

let[@warning "-32"] respond ss body =
  let len = String.length body in
  let header =
    Printf.sprintf
      "HTTP/1.1 200 OK\r\n\
       Content-Type: application/json\r\n\
       Content-Length: %d\r\n\
       Connection: close\r\n\
       \r\n"
      len
  in
  let hbuf = Bytes.unsafe_of_string header in
  let bbuf = Bytes.unsafe_of_string body in
  (try write_all ss hbuf 0 (String.length header) with Unix.Unix_error _ -> ());
  try write_all ss bbuf 0 (String.length body) with Unix.Unix_error _ -> ()

(* Answer one accepted connection: read the request head, then send
   `body` with `Connection: close`. Every socket error is swallowed
   -- a probe that hangs up early must not take the server down. *)
let[@warning "-32"] serve_connection ss body =
  (try
     Unix.setsockopt ss Unix.TCP_NODELAY true;
     read_request ss |> ignore;
     respond ss body
   with Unix.Unix_error _ -> ());
  try Unix.close ss with Unix.Unix_error _ -> ()

(* Accept every connection, not just the first.
   `with_stub` in tests/rebuttal_forge_stub.ml spends one connection
   on its readiness probe (`wait_until_ready`) and the probe under
   test then opens a second. A single-shot server answered the
   first, exited, and left the second to ECONNREFUSED -- which
   `forge_mirror` maps to `[]`, so the positive case failed for a
   reason that had nothing to do with what it asserts. The
   `python3 -m http.server` stub this executable replaced in 5a4fec8
   served every connection; this loop restores that contract.

   Termination: `with_stub` SIGTERMs the child in `Fun.protect`, and
   SIGTERM's default disposition ends the process. The parent-pid
   check is the second line of defence, for the case where the test
   binary dies first: an orphan would otherwise hold its port for
   the rest of the session. *)
let[@warning "-32"] serve_forever sock body =
  let parent = Unix.getppid () in
  let rec loop () =
    match Unix.accept sock with
    | exception Unix.Unix_error ((Unix.EINTR | Unix.ECONNABORTED), _, _) ->
        loop ()
    | ss, _caller ->
        serve_connection ss body;
        if Unix.getppid () = parent then loop ()
  in
  loop ()

let[@warning "-32"] main =
  if Array.length Sys.argv < 3 then (
    Printf.fprintf stderr "usage: forge_stub <port> <response-body>\n";
    exit 2);
  let port = int_of_string Sys.argv.(1) in
  let body = Sys.argv.(2) in
  let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Unix.setsockopt sock Unix.SO_REUSEADDR true;
  Unix.bind sock (Unix.ADDR_INET (Unix.inet_addr_of_string "127.0.0.1", port));
  Unix.listen sock 16;
  serve_forever sock body

let _ = main
