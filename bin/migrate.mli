open Domain

(* The migration of a project of the previous version of the format to the
   version of this method. It is a human action: the agent surface does not
   move the journals of a project.

   With --dry-run the migration prints what it would do and writes nothing. *)
val run : string -> bool -> int
