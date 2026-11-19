(* The exit codes of the tool are a contract with the consumer: the number
   says what happened, and the same number has to mean the same thing in
   every command. Two kinds of emptiness are told apart here. A vacant
   project has no standing specification: the tool answered that there is
   nothing here, and that answer is a verdict, not a failure. A specification
   that cannot be read is an internal failure: the tool could not answer the
   question it was asked. A consumer that cannot tell the two apart reads a
   broken tool as an unfinished project and waits for work that nobody will
   ever do. *)

let ok = 0
let red_or_protected = 1
let usage = 2
let vacant = 3
let stopped = 4
let internal_failure = 5

(* The table the help of the tool prints. The text lives here and not in the
   help, so that the number a command returns and the number the help names
   come from one place and cannot drift apart. *)
let describe =
  [ ("successful actions and next/context", ok);
    ("run/map verdict green", ok);
    ("run/map verdict red or protected", red_or_protected);
    ("usage error", usage);
    ("unknown/vacant", vacant);
    ("run stopped before it finished", stopped);
    ("the tool could not answer", internal_failure) ]

(* The lines of that table, as the help prints them. *)
let lines () = List.map (fun (text, code) -> Printf.sprintf "  %-37s%d" text code) describe
