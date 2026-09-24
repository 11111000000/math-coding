(* core/formats/current.ml — canonical v2.0 format plugin.

   This module is the Format_v2_0 plugin entry point. The actual
   parsing logic lives in Parse.parse_packet (single source of
   truth). The plugin exists as a separate module to allow
   future legacy plugins (v1.0, v0.99, v0.854) to coexist.

   See math/modeling/semantics.tex for V7 (schema_version
   validation). *)

open Types

(* The canonical v2.0 format. All current packets use this.
   Plugin definition lives in core/plugin.ml (Format_v2_0).
   This module re-exports helpers specific to the v2.0 format. *)

(* The expected schema_version string. *)
let canonical_version = "2.0"

(* Validate that a decision has the correct schema_version. *)
let validate_schema_version d =
  if d.schema_version = canonical_version then
    Pass
  else
    Fail

(* Fill in defaults when migrating from a hypothetical prior version.
   For v2.0-Y, no migration is needed (only v2.0 packets exist). *)
let apply_defaults d =
  { d with schema_version = canonical_version }