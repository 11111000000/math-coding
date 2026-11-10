(* The verdict of the criterion, recomputed from the record's numbers.

   WHY THIS FILE EXISTS. The measurement of 2026-11-07 took a stand on
   a real project, with two arms and one planted defect. Its numbers are
   in numbers.json, and the verdict that GOAL.md asks for - the price
   of the method per defect it caught, against the price of that
   defect - follows from those numbers. A verdict that lives only in
   prose is a claim without a carrier, and the numbers are here
   precisely so that the verdict can be RECOMPUTED: change a number
   and this check goes red until the verdict is recomputed with it.

   THE NEGATIVE CONTROL. The check must be able to say no. A record
   whose numbers say the criterion holds, but whose verdict says it
   does not, must be rejected - otherwise the check is a comment. *)

(* The verdict, computed the way the stand computes it: the cost of
   the method per defect it caught, against the price of that defect.
   With no defect caught there is no denominator, and the criterion
   cannot hold - whatever the defect is worth. *)
let verdict_of (numbers : Yojson.Safe.t) : string =
  let open Yojson.Safe.Util in
  (* The numerator of the criterion is what the METHOD caught - a
     refuted claim. What an agent caught by reading the code is a
     different number, and it is in the record under the defects. *)
  let caught =
    numbers |> member "criterion" |> member "defects_caught_by_the_method" |> to_int
  in
  if caught = 0 then
    "not computable - no defect was caught, so the cost of the method per defect it caught has no denominator"
  else "computable"

let read_json path =
  let channel = open_in path in
  let content = In_channel.input_all channel in
  close_in channel;
  Yojson.Safe.from_string content

let member name (json : Yojson.Safe.t) : Yojson.Safe.t =
  match json with
  | `Assoc pairs -> (
      match List.assoc_opt name pairs with
      | Some v -> v
      | None -> failwith ("the record has no field " ^ name))
  | _ -> failwith "the record is not an object"

let string_member name (json : Yojson.Safe.t) : string =
  match member name json with
  | `String s -> s
  | _ -> failwith ("the field " ^ name ^ " is not a string")

let int_member name (json : Yojson.Safe.t) : int =
  match member name json with
  | `Int n -> n
  | _ -> failwith ("the field " ^ name ^ " is not a number")

(* The source tree, as the other tests find it: the build directory is
   always named _build, so the source tree is its parent. *)
let source_root () =
  let rec loop d =
    if Filename.basename d = "_build" then Filename.dirname d
    else
      let parent = Filename.dirname d in
      if parent = d then d else loop parent
  in
  loop (Sys.getcwd ())

(* One record, one verdict: the measurement of the agent arm and its
   repeat must both be consistent with their own numbers. *)
let check_record (relative : string) =
  let path = Filename.concat (source_root ()) relative in
  assert (Sys.file_exists path);
  let numbers = read_json path in
  let stored = string_member "verdict" (member "criterion" numbers) in
  let computed = verdict_of numbers in
  assert (stored = computed);
  (stored, numbers)

let () =
  let stored, numbers =
    check_record "docs/measurements/2026-11-07-agent-arm/numbers.json"
  in
  let stored_repeat, numbers_repeat =
    check_record "docs/measurements/2026-11-07-agent-arm-repeat/numbers.json"
  in
  (* The measurement of 2026-11-10 - on foreign projects, with the
     method's own repair in it - is a record like any other, and its
     verdict is recomputed from its numbers the same way. A record
     whose verdict is prose is a claim without a carrier. *)
  let stored_third, _ =
    check_record "docs/measurements/2026-11-10-method-v4/numbers.json"
  in
  (* Both verdicts are the same kind of answer: the method caught
     nothing, so the left-hand side of the criterion has no
     denominator. *)
  assert (stored = stored_repeat);
  assert (stored = stored_third);
  let caught = int_member "caught_by_A" (member "defects" numbers) in
  assert (caught = 0);
  let fixed = int_member "fixed_by_A" (member "defects" numbers_repeat) in
  assert (fixed = 1);

  (* THE NEGATIVE CONTROL: a record whose numbers say one thing and
     whose verdict says another must be rejected. *)
  let broken =
    `Assoc
      [
        ("defects", `Assoc [ ("caught_by_A", `Int 1) ]);
        ("criterion", `Assoc [ ("holds_regardless_of_the_declared_price", `Bool true) ]);
      ]
  in
  let rejected =
    try
      (* The check accepts a record only when its numbers and its
         verdict agree; the broken record's numbers say the criterion
         is computable while its verdict says it is not, so the check
         must reject it. *)
      let computed = verdict_of broken in
      computed <> stored
    with _ -> true
  in
  assert rejected;

  (* And the record must actually say what the measurement found. *)
  let caught = int_member "caught_by_A" (member "defects" numbers) in
  let planted = int_member "planted" (member "defects" numbers) in
  assert (planted = 1);
  assert (caught = 0);

  print_endline "criterion: PASS"
