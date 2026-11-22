open Domain

(* A record of the journal that could not be read, with the line it stands on
   and the reason it could not be read. *)
type damage = { line : int; reason : string }

(* The records of the journal that can be read, and the ones that cannot. *)
type journal = { records : evidence list; damaged : damage list }

val append : string -> evidence -> unit

(* The path the journal of this version stands at. *)
val path : string -> string

(* The journal is written again, with the records that can be read. *)
val write : string -> evidence list -> unit

(* A damaged record is not a reason to lose the journal: the records that can be
   read are returned, the damaged ones are named. *)
val read : string -> (journal, string) result

(* The journal of the previous version of the format, read by the reader of
   that version. The records it holds are read, not guessed: the migration
   writes them down again in the current version. *)
val read_previous : string -> (journal, string) result

(* The path the journal of the previous version stands at. The migration keeps
   the old file: it moves the journal, it does not delete it. *)
val previous_path : string -> string

(* The journal is written again with the records that can be read; the damaged
   original is kept beside it. The path of the copy is returned. *)
val rewrite : string -> journal -> int -> (string option, string) result

val damaged_path : string -> int -> string
