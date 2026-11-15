open Helpers

(* The runner waits for a child without adding a delay of its own. The pause
   between the polls starts short and grows, so a child that ends at once is
   noticed at once and a child that runs long is still polled rarely. The
   timeout and the outcome of the child are untouched by this. *)
let () =
  let root = Sys.getcwd () in
  let latencies =
    List.init 20 (fun _ ->
        let started = Unix.gettimeofday () in
        let result = Process.run ~root "true" in
        let elapsed = Unix.gettimeofday () -. started in
        check "a child that ends at once is a pass" (result.code = 0);
        check "a child that ends at once says nothing" (result.stdout = "");
        elapsed)
  in
  let fastest = List.fold_left (fun a b -> if a < b then a else b) infinity latencies in
  let slowest = List.fold_left (fun a b -> if a > b then a else b) 0.0 latencies in
  let total = List.fold_left ( +. ) 0.0 latencies in
  if Sys.getenv_opt "MATHC_TEST_TIMING" <> None then
    Printf.printf "timing: fastest %.4f slowest %.4f total %.4f\n" fastest slowest total;
  (* A fixed pause of 50 milliseconds would make every one of the twenty
     children cost at least that much, so the fastest of them could never be
     under 45 milliseconds. The wait of the runner must stay below it. *)
  check "a child that ends at once is noticed at once" (fastest < 0.045);
  (* The pause must not grow without bound either: a child that runs for a
     while is still waited for without a busy loop. *)
  let started = Unix.gettimeofday () in
  let result = Process.run ~timeout:5.0 ~root "sleep 0.2" in
  let elapsed = Unix.gettimeofday () -. started in
  check "a child that runs a while is still a pass" (result.code = 0);
  check "a child that runs a while is waited for" (elapsed >= 0.2 && elapsed < 2.0);
  print_endline "process-wait: PASS"
