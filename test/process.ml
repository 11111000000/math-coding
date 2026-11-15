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
