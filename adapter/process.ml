open Domain

type result = {
  code : int;
  outcome : outcome;
  stdout : string;
  stderr : string;
}

let classify = function
  | 0 -> Pass
  | 1 -> Fail
  | 2 | 3 -> Inconclusive
  | 126 | 127 -> Not_run
  | _ -> Infrastructure_error

let limited_read path =
  let input = open_in_bin path in
  let buffer = Bytes.create 65536 in
  let output = Buffer.create 65536 in
  let rec pump remaining =
    if remaining > 0 then (
      let count = Stdlib.input input buffer 0 (min 65536 remaining) in
      if count > 0 then (
        Buffer.add_bytes output (Bytes.sub buffer 0 count);
        pump (remaining - count)))
  in
  pump (1024 * 1024);
  close_in input;
  Buffer.contents output

let run ?(timeout = 30.0) ~root command =
  let directory = Io.temp_dir "mathc-process" in
  Fun.protect ~finally:(fun () -> Io.remove_tree directory) (fun () ->
      let stdout_path = Filename.concat directory "stdout" in
      let stderr_path = Filename.concat directory "stderr" in
      let stdout_fd = Unix.openfile stdout_path [ Unix.O_CREAT; Unix.O_WRONLY ] 0o600 in
      let stderr_fd = Unix.openfile stderr_path [ Unix.O_CREAT; Unix.O_WRONLY ] 0o600 in
      let pid = Unix.fork () in
      if pid = 0 then (
        ignore (Unix.setsid ());
        Unix.chdir root;
        Unix.dup2 stdout_fd Unix.stdout;
        Unix.dup2 stderr_fd Unix.stderr;
        Unix.close stdout_fd;
        Unix.close stderr_fd;
        Unix.execv "/bin/sh" [| "sh"; "-c"; command |]);
      Unix.close stdout_fd;
      Unix.close stderr_fd;
      let started = Unix.gettimeofday () in
      let rec wait () =
        match Unix.waitpid [ Unix.WNOHANG ] pid with
        | 0, _ ->
            if Unix.gettimeofday () -. started > timeout then (
              Unix.kill (-pid) 9;
              snd (Unix.waitpid [] pid))
            else (
              Unix.sleepf 0.05;
              wait ())
        | _, status -> status
      in
      let status = wait () in
      let code =
        match status with
        | Unix.WEXITED code -> code
        | Unix.WSIGNALED signal | Unix.WSTOPPED signal -> 128 + signal
      in
      { code; outcome = classify code; stdout = limited_read stdout_path;
        stderr = limited_read stderr_path })
