(* lib/lifecycle.ml — lifecycle computation for math-coding v1.0. *)

open Packet

(* Compute lifecycle from git history.
   - No witness → Draft
   - Witness + proposition changed → Drift
   - Witness + files changed but proposition same → Stale
   - Witness + proposition same + files match → Applied *)
let compute_lifecycle git pkt =
  match pkt.witness with
  | [] -> Draft
  | last :: _ ->
      let proposition_match =
        Git.proposition_in_commit git pkt.last.sha pkt.proposition
      in
      if not proposition_match then Drift
      else
        let files_match =
          Git.files_in_commit git pkt.last.sha pkt.files
        in
        if files_match then Applied
        else Stale

(* Manual transitions (via CLI). *)
let transition_explicit pkt target =
  match pkt.status with
  | Some _ when pkt.status = Some target -> pkt
  | _ -> { pkt with status = Some target }
