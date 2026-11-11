val read_file : string -> string
val write_atomic : string -> string -> unit
val mkdir_p : string -> unit
val temp_dir : string -> string
val copy_file : string -> string -> unit
val remove_tree : string -> unit
val with_temp_dir : (string -> 'a) -> 'a
