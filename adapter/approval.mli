(* The approval of the human: the commands that the agent surface may execute
   in this project. The agent surface asks the program, the program asks the
   human, and the approval is bound to the commands themselves. *)

type record = { by : string; reason : string; at : int; commands : string list }

val path : string -> string

val digest_of_command : string -> string

(* The commands a claim declares: its checks and its control. *)
val commands_of_claim : Domain.claim -> string list

(* The commands a specification declares: the commands of every claim. *)
val commands_of_spec : Domain.spec -> string list

val load : string -> (record list, string) result

(* The approval of the human adds a record and never removes one. *)
val approve : string -> by:string -> reason:string -> commands:string list -> (int, string) result

(* The digests of every approved command. *)
val approved : record list -> string list

val covered : record list -> string -> bool

(* The commands that the human did not approve. *)
val unapproved : record list -> string list -> string list
