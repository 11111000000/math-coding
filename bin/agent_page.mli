(* The page for agents: the block that names the verbs of the method and the
   aim of the project. *)

val block_begin : string
val block_end : string
val usage_verbs : string list

(* The text of the block for the given specification. *)
val entry_page : Domain.spec -> string

val contains : string -> string -> bool

(* The page with the current block in it. *)
val with_block : string -> string -> string
