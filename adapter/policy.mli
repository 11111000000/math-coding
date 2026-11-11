type t = { protected_paths : string list; authorized_by : string }

val load : string -> (t option, string) result
val changed : string -> t -> (string list, string) result
val authorize : string -> t -> string -> string -> int
val check : string -> (unit, string) result
