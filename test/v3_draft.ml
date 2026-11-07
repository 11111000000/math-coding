(* The third version's decisions, as drafts.

   WHAT IS CARRIED ACROSS AND WHAT IS NOT. The scope and the
   verifiers - the mechanical part, readable off the old file without
   understanding it. Not the register, not the falsifier, and not the
   question whether the old decision is still true: those are the
   person's, and a draft that decides them is a port, not a draft.

   THE NEGATIVE CONTROL. A decision with no scope cannot become a
   claim - the method would refuse it at the door - so it must produce
   no draft rather than one with an empty scope. And a draft that
   carries the old decision's register across is exactly the mistake
   the tool exists to avoid, so the check says no to that too. *)

(* A decision of the third version, as the converter hands it over. *)
let decision_json () : Yojson.Safe.t =
  `Assoc
    [
      ("id", `String "wavecode-strict-layering");
      ( "intent",
        `String
          "The layering is strict, so that a domain change cannot reach the interface by accident." );
      ( "commitment",
        `String
          "The kernel stays pure and offline.\nEvery architectural commitment lands as a YAML file." );
      ("state", `String "active");
      ( "scope",
        `Assoc
          [
            ("paths", `List [ `String "ui/src/**"; `String "bin/Mathc.ml" ]);
            ("capabilities", `List [ `String "kernel-validates" ]);
          ] );
      ( "obligations",
        `List
          [
            `Assoc
              [
                ("id", `String "wavecode-strict-layering-kernel-validates");
                ("acceptance",
                  `Assoc
                    [
                      ( "all",
                        `List [ `Assoc [ ("verifier", `String "mathc validate") ] ] );
                    ]);
              ];
            `Assoc
              [
                ("id", `String "wavecode-strict-layering-witness-from-v1");
                ("acceptance",
                  `Assoc
                    [
                      ( "all",
                        `List [ `Assoc [ ("verifier", `String "mathc self-check") ] ] );
                    ]);
              ];
          ] );
    ]

(* A field of the old decision, read the way the adapter reads it. *)
let field name (json : Yojson.Safe.t) : Yojson.Safe.t option =
  match json with
  | `Assoc pairs -> List.assoc_opt name pairs
  | _ -> None

let () =
  let draft = V3.draft_of_decision (decision_json ()) in
  assert (draft <> None);
  let c = match draft with Some c -> c | None -> assert false in
  (* the id is carried *)
  assert (c.Domain.id = "wavecode-strict-layering");
  (* the subject is the first line of the old contract *)
  assert (c.Domain.subject.text = "The kernel stays pure and offline.");
  (* the scope is carried, and the old glob becomes the new prefix *)
  assert (c.Domain.subject.scope = [ "ui/src/"; "bin/Mathc.ml" ]);
  (* the verifiers are carried *)
  assert
    (c.Domain.requirements
    = [ Domain.Verified_by "mathc self-check"; Domain.Verified_by "mathc validate" ]);
  (* and the rest is left to the person *)
  assert (c.Domain.register = Domain.Undeclared);
  assert (c.Domain.falsifier <> "");
  assert (c.Domain.accepted = None);

  (* THE NEGATIVE CONTROL: a decision with no scope produces no draft. *)
  let no_scope =
    match field "scope" (decision_json ()) with
    | Some scope -> `Assoc [ ("paths", `List []) ]
    | None -> `Assoc []
  in
  let without =
    `Assoc
      [
        ("id", `String "x");
        ("commitment", `String "nothing");
        ("scope", no_scope);
      ]
  in
  assert (V3.draft_of_decision without = None);

  (* And a decision with no id produces no draft either. *)
  let no_id =
    `Assoc
      [
        ("commitment", `String "nothing");
        ("scope", `Assoc [ ("paths", `List [ `String "src/" ]) ]);
      ]
  in
  assert (V3.draft_of_decision no_id = None);

  print_endline "v3: PASS"
