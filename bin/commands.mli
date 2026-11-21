val init : string -> int
val goal : string -> string -> string list -> string -> string -> int
val add : string -> string -> string -> string list -> string -> string -> Domain.requirement list -> string -> string -> int
val run : ?changed:bool -> ?limit:float -> string -> bool -> int
val map : string -> bool -> int
val next : string -> int
val context : string -> int
val waive : string -> string -> string -> string -> int -> string -> int
val record : string -> string -> string -> string -> string -> int option -> string option -> int
val review_decision : string -> string -> string -> string -> string -> int option -> int
val install : string -> int
val authorize : string -> string -> string -> int
val approve : string -> string -> string -> string list -> int
val re_evaluate : string -> int
val review_source : string -> string -> string -> string -> int
val version : unit -> int

(* The migration of a project of the previous version of the format. It is a
   human action: the agent surface does not move the journals of a project. *)
val migrate : string -> bool -> int

(* The limit of a run in seconds: the run stops itself and says so. *)
val default_limit : float
