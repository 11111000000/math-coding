(* The vocabulary of the exit codes of the tool. The number is the contract:
   a consumer reads it and decides what to do next. *)

val ok : int
val red_or_protected : int
val usage : int
val vacant : int
val stopped : int
val internal_failure : int

(* The table of the codes as the help of the tool prints it: the text and the
   number of every code. *)
val describe : (string * int) list

(* The lines of that table, ready to be printed. *)
val lines : unit -> string list
