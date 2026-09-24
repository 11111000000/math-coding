(* core/migrate.ml — convention migration for math-coding v2.0-Y.

   The migrate module adds new fields to existing packets when the
   convention schema evolves. In v2.0-Y the schema is fixed
   (schema_version = 2.0); migration is a no-op for the canonical
   format. Future schema bumps will add migration logic here.

   See Theorem: y-fixed-point.math-coding — convention applies to
   itself; migration is part of that. *)

(* The current schema version this build supports. *)
let current_version = "2.0"

(* Migrate a single packet's frontmatter to the current schema.
   For v2.0-Y this is a no-op: the canonical schema is already
   what we read.

   Future versions will:
     1. add new fields with defaults
     2. rename deprecated fields
     3. emit a commit "convention: migration to vN" *)
let migrate_packet d =
  (* No-op for v2.0-Y. *)
  d

(* Migrate all packets in the project.
   Returns the count of packets touched. *)
let migrate_all () =
  let math_dir = "math" in
  if not (Sys.file_exists math_dir) then 0
  else
    let dirs = Parse.list_packet_dirs math_dir in
    let touched = ref 0 in
    List.iter
      (fun dir ->
        match Parse.parse_packet dir with
        | Ok _ -> incr touched
        | Error _ -> ())
      dirs;
    !touched