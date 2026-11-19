open Domain

type result = {
  code : int;
  outcome : outcome;
  stdout : string;
  stderr : string;
  truncated : bool;
  (* The process was asked to stop, not that it failed on its own. *)
  interrupted : bool;
}

(* The command runs. The optional flag tells the process that it may be asked
   to stop: the run that started it can change its mind, and the child hears
   it rather than being left behind. *)
val run : ?timeout:float -> ?cancel:bool ref -> root:string -> string -> result
