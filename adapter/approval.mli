(* The approval of the human: the commands that the agent surface may execute
   in this project. The agent surface asks the program, the program asks the
   human, and the approval is bound to the commands themselves. *)

type record = { by : string; reason : string; at : int; command_texts : string list; command_digests : string list }

(* The version of the format of the journal. *)
val version : int

(* The journal of this version of the format. *)
val path : string -> string

(* The journal of the previous version. It stays where it is. *)
val previous_path : string -> string

val digest_of_command : string -> string

(* The commands a claim declares: its environment, checks and control. *)
val commands_of_claim : environment:string option -> Domain.claim -> string list

(* The commands a specification declares: the commands of every claim. *)
val commands_of_spec : Domain.spec -> string list

val load : string -> (record list, string) result

(* The journal of the previous version, read as it was written. *)
val read_previous : string -> (record list, string) result

(* The journal of this version is written with the records it holds. *)
val write : string -> record list -> (int, string) result

(* The journal of the previous version is moved to the journal of this one. The
   old journal stays where it is. *)
val migrate : string -> (int, string) result

(* The approval of the human adds a record and never removes one. *)
val approve : string -> by:string -> reason:string -> commands:string list -> (int, string) result

(* The digests of every approved command. *)
val approved : record list -> string list

val covered : record list -> string -> bool

(* The commands that the human did not approve. *)
val unapproved : record list -> string list -> string list
