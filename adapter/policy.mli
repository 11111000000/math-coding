type t = { protected_paths : string list; authorized_by : string }

(* The journal of the authorization of a protected transition. *)
type authorization = {
  base_head : string;
  by : string;
  reason : string;
  changed : string list;
  at : int;
}

(* The version of the format of the journal. *)
val version : int

(* The journal of this version of the format. *)
val authorization_path : string -> string

(* The journal of the previous version. *)
val previous_authorization_path : string -> string

val load : string -> (t option, string) result
val changed : string -> t -> (string list, string) result
val authorize : string -> t -> string -> string -> int
val check : string -> (unit, string) result

(* The journal of the previous version, read as it was written. *)
val read_previous_authorization : string -> (authorization option, string) result

(* The journal of this version is written with the authorization it holds. *)
val write_authorization : string -> authorization -> (int, string) result

(* The journal of the previous version is moved to the journal of this one. The
   old journal stays where it is. *)
val migrate_authorization : string -> (int, string) result
