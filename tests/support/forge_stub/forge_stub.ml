(* tests/support/forge_stub/forge_stub.ml
 *
 * A minimal OCaml HTTP server used by tests/rebuttal_forge_stub.ml
 * as the target of mathc forge-verify HTTP probes. *)

let[@warning "-32"] read_request fd =
  let buf = Bytes.create 4096 in
  let acc = Buffer.create 256 in
  let cr_seen = ref false in
  let rec loop () =
    let n = Unix.read fd buf 0 (Bytes.length buf) in
    if n <= 0 then Buffer.contents acc
    else begin
      let chunk = Bytes.sub_string buf 0 n in
      
      let len = String.length chunk in
      let i = ref 0 in
      while !i < len do
        let c = chunk.[!i] in
        incr i;
        if c = '\r' then begin
          if !cr_seen then ()
          else cr_seen := true
        end else if c = '\n' then begin
          let line = Buffer.contents acc in
          Buffer.clear acc;
          cr_seen := false;
          if line = "" then ()
          else begin
            Buffer.add_string acc line;
            Buffer.add_char acc '\n';
            ignore (loop ())
          end
        end else begin
          if !cr_seen then Buffer.add_string acc (String.make 1 c)
        end
      done;
      loop ()
    end
  in
  loop ()

let[@warning "-32"] write_all fd buf off len =
  let written = ref off in
  while !written < off + len do
    let n = Unix.write fd buf !written (off + len - !written) in
    written := !written + n
  done

let[@warning "-32"] main =
  if Array.length Sys.argv < 3 then (
    Printf.fprintf stderr "usage: forge_stub <port> <response-body>\n";
    exit 2);
  let port = int_of_string Sys.argv.(1) in
  let body = Sys.argv.(2) in
  let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Unix.setsockopt sock Unix.SO_REUSEADDR true;
  Unix.bind sock (Unix.ADDR_INET (Unix.inet_addr_of_string "127.0.0.1", port));
  Unix.listen sock 1;
  let ss, _caller = Unix.accept sock in
  Unix.setsockopt ss Unix.TCP_NODELAY true;
  ignore (read_request ss);
  let len = String.length body in
  let header =
    Printf.sprintf
      "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n"
      len
  in
  let hbuf = Bytes.unsafe_of_string header in
  let bbuf = Bytes.unsafe_of_string body in
  (try write_all ss hbuf 0 (String.length header)
   with Unix.Unix_error _ -> ());
  (try write_all ss bbuf 0 (String.length body)
   with Unix.Unix_error _ -> ())

let _ = main
