(* core/plugin.ml — plugin registry and dispatcher.

   The plugin architecture allows multiple packet formats to coexist.
   In v2.0-Y only the canonical v2.0 format is implemented; legacy
   plugins (v1.0, v0.99, v0.854) are deferred to v2.0.1+ as per
   the migration plan.

   See Theorem: y-fixed-point.math-coding for the formal model. *)

open Types

(* A FormatPlugin reads and writes a specific schema version.
   In v2.0-Y only one plugin exists: Format_v2_0. *)
module type FormatPlugin = sig
  val name : string
  val version : string
  val can_parse : string -> bool
  val parse : string -> (decision, string) result
end

(* All registered plugins. Future plugins register themselves
   in all_plugins when added. *)
let plugins : (module FormatPlugin) list ref = ref []

let register_plugin (p : (module FormatPlugin)) : unit =
  plugins := p :: !plugins

(* Load plugin by trying each one in order. *)
let load_plugin path : (module FormatPlugin) =
  let content =
    try
      let ic = open_in path in
      let len = in_channel_length ic in
      really_input_string ic len
    with _ -> ""
  in
  let rec try_plugins = function
    | [] -> failwith ("no plugin can parse " ^ path)
    | ((module P : FormatPlugin) as p) :: rest ->
      if P.can_parse content then p
      else try_plugins rest
  in
  try_plugins !plugins

(* Plugin v2.0: the canonical format. *)
module Format_v2_0 : FormatPlugin = struct
  let name = "v2.0"
  let version = "2.0"
  (* can_parse: detect by schema_version field; default to v2.0
     if missing (backward-compatible for legacy packets in v2.0-Y). *)
  let can_parse content =
    try
      let lines = String.split_on_char '\n' content in
      let rec find = function
        | [] -> true (* default: assume v2.0 *)
        | line :: rest ->
          let trimmed = String.trim line in
          if String.starts_with ~prefix:"schema_version:" trimmed then
            let value = String.sub trimmed 14
              (String.length trimmed - 14) in
            let v = String.trim value in
            String.length v >= 3 && String.sub v 0 3 = "2.0"
          else find rest
      in
      find lines
    with _ -> true

  let parse path : (decision, string) result =
    (* Delegate to Parse.parse_packet — same logic. *)
    let dir = Filename.dirname path in
    let rel = Filename.basename dir in
    Parse.parse_packet ~rel_path:rel dir
end

(* Default registration: only v2.0 plugin in v2.0-Y. *)
let () = register_plugin (module Format_v2_0)