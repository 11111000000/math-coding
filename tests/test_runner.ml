(* tests/test_runner.ml — minimal test framework.

   Exits with code 0 on success, 1 on first failure. Each test
   prints PASS/FAIL with line number. Designed for `dune test`
   which captures the exit code. *)

let passed = ref 0
let failed = ref 0

let rec string_of_value v =
  match v with
  | `String s -> "\"" ^ s ^ "\""
  | `Int i -> string_of_int i
  | `Float f -> string_of_float f
  | `Bool b -> string_of_bool b
  | `List xs -> "[" ^ String.concat ";" (List.map string_of_value xs) ^ "]"
  | `Pair (a, b) -> "(" ^ string_of_value a ^ "," ^ string_of_value b ^ ")"
  | `Verdict v -> Types.verdict_to_string v

let assert_eq ?(label = "") actual expected =
  if actual = expected then begin
    incr passed;
    Printf.printf "  PASS %s\n" label
  end else begin
    incr failed;
    Printf.printf "  FAIL %s\n    expected: %s\n    actual:   %s\n"
      label
      (String.escaped (string_of_value expected))
      (String.escaped (string_of_value actual))
  end

let assert_pass ?(label = "") verdicts =
  let fail_reasons =
    List.filter_map
      (fun (v, reason) -> match v with
        | Types.Pass | Types.Skip -> None
        | Types.Warn -> Some ("WARN: " ^ reason)
        | Types.Fail -> Some ("FAIL: " ^ reason))
      verdicts
  in
  if fail_reasons = [] then begin
    incr passed;
    Printf.printf "  PASS %s\n" label
  end else begin
    incr failed;
    Printf.printf "  FAIL %s\n    %s\n"
      label
      (String.concat "\n    " fail_reasons)
  end

let assert_fail ?(label = "") verdicts predicate =
  let fails =
    List.filter (fun (v, _) -> v = Types.Fail) verdicts
  in
  let ok = predicate fails in
  if ok then begin
    incr passed;
    Printf.printf "  PASS %s\n" label
  end else begin
    incr failed;
    Printf.printf "  FAIL %s\n    expected Fail verdict(s) matching predicate\n"
      label
  end

let assert_verdict ?(label = "") verdicts expected =
  let has v =
    List.exists (fun (vv, _) -> vv = v) verdicts
  in
  if has expected then begin
    incr passed;
    Printf.printf "  PASS %s\n" label
  end else begin
    incr failed;
    Printf.printf "  FAIL %s\n    expected verdict %s in %s\n"
      label
      (Types.verdict_to_string expected)
      (String.concat ", "
         (List.map (fun (v, r) ->
            Printf.sprintf "%s(%s)" (Types.verdict_to_string v) r) verdicts))
  end

let summary () =
  Printf.printf "\n%d passed, %d failed\n" !passed !failed;
  if !failed > 0 then exit 1

let s v = `String v
let i v = `Int v
let f v = `Float v
let b v = `Bool v
let l v = `List v
let p a b = `Pair (a, b)
let v x = `Verdict x

let verdict_count_pass verds =
  List.length (List.filter (fun (v, _) -> v = Types.Pass) verds)
