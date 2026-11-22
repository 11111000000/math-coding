open Unix
open Helpers

(* The runner waits for a child without adding a delay of its own. The pause
   between the polls starts short and grows, so a child that ends at once is
   noticed at once and a child that runs long is still polled rarely. The
   timeout and the outcome of the child are untouched by this.

   The measure must survive a loaded machine, so the runner is compared with
   the same children started right beside it. Spawning a child and waiting
   for it without any pause gives the cost of the machine at this moment;
   the runner must not cost more than a little on top of that. A fixed pause
   of fifty milliseconds would add exactly that much to every child. *)
let () =
  let root = Sys.getcwd () in
  let spawn_without_pause () =
    let channel = Unix.open_process_args "/bin/sh" [| "/bin/sh"; "-c"; "true" |] in
    ignore (Unix.close_process channel)
  in  let differences =
    List.init 20 (fun _ ->
        let reference_started = Unix.gettimeofday () in
        spawn_without_pause ();
        let reference_elapsed = Unix.gettimeofday () -. reference_started in
        let runner_started = Unix.gettimeofday () in
        let result = Process.run ~root "true" in
        let runner_elapsed = Unix.gettimeofday () -. runner_started in
        check "a child that ends at once is a pass" (result.code = 0);
        check "a child that ends at once says nothing" (result.stdout = "");
        runner_elapsed -. reference_elapsed)
  in
  (* The smallest difference is the luckiest pair of children, so a busy
     machine cannot hide the pause of the runner behind its own noise. *)
  let smallest =
    List.fold_left (fun a b -> if a < b then a else b) infinity differences
  in
  let largest = List.fold_left (fun a b -> if a > b then a else b) 0.0 differences in
  if Sys.getenv_opt "MATHC_TEST_TIMING" <> None then
    Printf.printf "timing: smallest %.4f largest %.4f\n" smallest largest;
  (* A fixed pause of fifty milliseconds would put every difference over thirty
     milliseconds. The runner must stay far below that, and the measure is a
     difference between two neighbours, so a busy machine slows both sides
     alike. *)
  check "a child that ends at once is noticed at once" (smallest < 0.02);
  (* The pause must not grow without bound either: a child that runs for a
     while is still waited for without a busy loop. *)
  let started = Unix.gettimeofday () in
  let result = Process.run ~timeout:5.0 ~root "sleep 0.2" in
  let elapsed = Unix.gettimeofday () -. started in
  check "a child that runs a while is still a pass" (result.code = 0);
  check "a child that runs a while is waited for" (elapsed >= 0.2 && elapsed < 2.0);
  print_endline "process-wait: PASS"

(* The sweep removes the copies of killed runs by age. A directory that
   pretends to be two days old is a leftover: it goes. A fresh directory
   belongs to a live run: it stays. *)
let () =
  let root = Filename.get_temp_dir_name () in
  let old_dir = Filename.concat root "mathc-v5-swept-dead-run" in
  let fresh_dir = Filename.concat root "mathc-v5-swept-live-run" in
  Io.remove_tree old_dir;
  Io.remove_tree fresh_dir;
  Unix.mkdir old_dir 0o700;
  Unix.mkdir fresh_dir 0o700;
  let now = Unix.gettimeofday () in
  Unix.utimes old_dir now (now -. (48.0 *. 60.0 *. 60.0));
  Io.sweep_stale ();
  check "a leftover copy of a killed run is swept" (not (Sys.file_exists old_dir));
  check "a fresh copy of a live run is kept" (Sys.file_exists fresh_dir);
  Io.remove_tree fresh_dir;
  print_endline "process-sweep: PASS"
