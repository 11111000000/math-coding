open Domain

val is_repository : string -> bool
val head_commit : string -> string option
val repository_files : string -> (string list, string) result
val path_contains : dir:string -> path:string -> bool
val files_under : string list -> scope:string list -> string list
val digest_of_repo_file : string -> string -> string option
val digest_of_scope : ?files:string list -> string -> scope:string list -> string option
val uncovered : string -> claim list -> goal_scope:string list -> (string list, string) result
val digest_of_file : string -> string option
