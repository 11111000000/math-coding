(* core/signing.ml — signing mode for math-coding v2.0-Y.

   Three signing modes from .mathrc:
     - Strict: every commit must be signed (GPG/SSH)
     - Lenient: only amend commits must be signed
     - Off: signatures are not checked

   Default mode is Lenient. The mode is read from .mathrc at
   runtime. *)

(* Three modes. *)
type mode = Strict | Lenient | Off

let mode_to_string = function
  | Strict -> "strict"
  | Lenient -> "lenient"
  | Off -> "off"

let mode_of_string = function
  | "strict" -> Strict
  | "off" -> Off
  | _ -> Lenient

(* Read the mode from .mathrc. *)
let read_mathrc path =
  if not (Sys.file_exists path) then []
  else
    let ic = open_in path in
    let content =
      try
        let len = in_channel_length ic in
        really_input_string ic len
      with _ -> ""
    in
    close_in ic;
    let lines = String.split_on_char '\n' content in
    List.filter_map
      (fun line ->
        let trimmed = String.trim line in
        if String.length trimmed = 0 || trimmed.[0] = '#' then None
        else if String.contains trimmed ':' then begin
          let idx = String.index trimmed ':' in
          let key = String.trim (String.sub trimmed 0 idx) in
          let value = String.trim
            (String.sub trimmed (idx + 1) (String.length trimmed - idx - 1)) in
          Some (key, value)
        end else None)
      lines

(* Default mode if not specified. *)
let () = ()
let default_mode = Lenient

(* Current mode. Cached after first read. *)
let current_mode = ref None

(* Read the mode from .mathrc, falling back to default. *)
let mode () =
  match !current_mode with
  | Some m -> m
  | None ->
      let entries = read_mathrc ".mathrc" in
      let m =
        try
          List.assoc "SIGNING_MODE" entries
          |> mode_of_string
        with Not_found -> default_mode
      in
      current_mode := Some m;
      m

(* Read a value from .mathrc by key. *)
let get key =
  let entries = read_mathrc ".mathrc" in
  try List.assoc key entries
  with Not_found -> ""

(* Check all keys. *)
let keys () = read_mathrc ".mathrc"