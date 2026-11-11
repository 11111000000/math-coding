open Domain

type result = {
  code : int;
  outcome : outcome;
  stdout : string;
  stderr : string;
  truncated : bool;
}

val run : ?timeout:float -> root:string -> string -> result
