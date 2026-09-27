(* lib/gate.ml — pure gate-evaluation scaffold.
 *
 * `evaluate` takes the changed paths and the loaded Memory.t and
 * returns a Gate.t:
 *
 *   - verdict: Pass | Open_with_waiver | Block | Unknown
 *   - gaps: per-decision gap list (scaffold: aggregated at decision
 *           level; future revisions under obligation
 *           gate-attestation-store-fill promote this to per-obligation)
 *
 * This is a SCAFFOLD. Without an attestation store (see
 * bootstrap/gate-decision.md obligation
 * attestation-store-future-revision) we cannot compute
 * Pass(o, c, g) per spec/semantics.md §"Evaluation". The scaffold
 * returns Unknown with explicit causes for every decision whose
 * decision_entry has non-zero obligations. A future revision
 * extends this to consume attestations and emit real verdicts.
 *
 * Pure module: no I/O, no `Unix.*`, no `Printf.printf` (OCAML
 * best practices §1.3). The CLI is the only I/O boundary. *)

type verdict = Pass | Open_with_waiver | Block | Unknown

type gap = {
  obligation_id : string;
  kind :
    [ `MissingEvidence
    | `StaleEvidence
    | `MissingReview
    | `NoAttestationStore
    | `Unknown ];
  causes : string list;
  remedies : string list;
}

type t = {
  verdict : verdict;
  gaps : gap list;
  obligation_count : int;
  now : string;
  base : string;
  head : string;
}

let[@warning "-32"] verdict_to_string = function
  | Pass -> "pass"
  | Open_with_waiver -> "open-with-waiver"
  | Block -> "block"
  | Unknown -> "unknown"

(* `evaluate` is the scaffold evaluator. Until
   gate-attestation-store-fill lands, every loaded decision is
   reported as `Unknown` with cause "no attestation store
   available". The verdict is Pass only when there are no
   decisions OR no paths changed — i.e. nothing to gate on.
   Future revisions replace the body with the real Pass/Fail/
   Unknown computation. *)
let[@warning "-32"] evaluate ~now ~base ~head ~memory ~changed_paths =
  let gaps =
    List.map
      (fun entry ->
        {
          obligation_id = entry.Memory.decision_id;
          kind = `NoAttestationStore;
          causes =
            [
              "decision " ^ entry.Memory.decision_id ^ " has "
              ^ string_of_int entry.Memory.obligations
              ^ " obligation(s); no attestation store available in v3-alpha \
                 scaffold";
              "verdict cannot move past Unknown until \
               gate-attestation-store-fill";
            ];
          remedies =
            [
              "load attestations from a future lib/attestations/ store";
              "wait for gate-attestation-store-fill revision";
            ];
        })
      memory.Memory.decisions
  in
  let obligation_count = List.length gaps in
  let verdict =
    match (changed_paths, obligation_count) with
    | [], _ | _, 0 -> Pass
    | _ -> Unknown
  in
  { verdict; gaps; obligation_count; now; base; head }
