open Domain

type result = {
  code : int;
  outcome : outcome;
  stdout : string;
  stderr : string;
}

val run : ?timeout:float -> root:string -> string -> result
