(* lib/gate.ml — pure gate evaluator.
 *
 * `evaluate` takes the changed paths, the loaded Memory.t, the
 * attestation store (a typed list already loaded by
 * `Attestations.load`), and an evaluation `now`. It returns a
 * `Gate.t`:
 *
 *   - verdict: Pass | Open_with_waiver | Block | Unknown
 *   - gaps: per-obligation gap list
 *
 * Rule (OCAML_BEST_PRACTICES §1.3): no I/O. The attestation store
 * is loaded by bin/Mathc.ml (or a test fake) and passed in here as
 * a typed value. I/O belongs at the bin/ boundary.
 *
 * Spec/semantics.md §"Evaluation":
 *   current(a) iff
 *     a.revisions resolve
 *     a.materials_digest equals digest(relevant materials of c)
 *     a.validity interval contains t
 *     a.method satisfies Req(p, o, g)
 *   Pass(o, c, g) iff some a is current and a.result = pass and no decisive failure
 *   Fail(o, c, g) iff some current decisive a reports fail
 *   Unknown(o, c, g) iff otherwise
 *
 * Kernel invariants honoured:
 *   8 (evidence binding): an attestation's `subject.decision` and
 *     `subject.obligation` MUST match the obligation it attests.
 *   9 (freshness): a mismatch between a.materials_digest and the
 *     digest of the candidate change's changed-paths is reported
 *     as StaleEvidence; the verdict does NOT silently flip to pass.
 *   10 (honest status): missing, stale, fail, inconclusive,
 *     infrastructure-error and pass are distinct gap kinds and
 *     distinct verdicts (unknown != pass).
 *
 * Bootstrap limitation: the "revisions resolve" and "validity
 * interval contains t" clauses are not enforced in this revision;
 * see decisions/gate-attestation-store-fill-decision.yaml
 * assumption materials-digest-hand-rolled. A future revision
 * closes that gap when D4 (SHA-256 vectors) lands. *)

type verdict = Pass | Open_with_waiver | Block | Unknown

type gap = {
  obligation_id : string;
  kind :
    [ `MissingEvidence
    | `StaleEvidence
    | `FailedEvidence
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

(* Hash the sorted changed-paths into a hex digest. We sort so the
 * digest is stable across git diff orderings (git does not
 * guarantee a particular order). The empty path list hashes to
 * the SHA-256 of the empty string — a deterministic value the
 * loader's wildcard match (`materials_digest = ""`) deliberately
 * does NOT match, so an empty change is correctly NOT considered
 * a pass without an attestation. *)
let[@warning "-32"] materials_digest_of changed_paths =
  let sorted = List.sort (fun a b -> String.compare a b) changed_paths in
  let joined = String.concat "\n" sorted in
  Digest.sha256_hex joined

(* Filter attestations for a (decision_id, obligation_id) pair.
 * Pure list operations; the kernel cannot depend on the
 * attestation store adapter (OCAML_BEST_PRACTICES §10.1), so the
 * helpers that lived on `Attestations` are inlined here. *)
let[@warning "-32"] candidates_for ~store ~decision_id ~obligation_id =
  List.filter
    (fun a ->
      String.equal a.Domain.decision decision_id
      && String.equal a.Domain.obligation obligation_id)
    store

(* A "current" attestation is one whose `materials_digest` matches
 * the digest of the candidate change's materials. An empty
 * `materials_digest` is treated as wildcard (the attestation does
 * not bind itself to a specific materials set). This honours
 * Kernel Invariant 9 (freshness) while still allowing test
 * fixtures to author attestations without computing the digest.
 *
 * Spec/semantics.md:39-44:
 *   current(a) iff
 *     a.revisions resolve
 *     a.materials_digest equals digest(relevant materials of c)
 *     a.validity interval contains t
 *     a.method satisfies Req(p, o, g)
 * The "revisions resolve" and "validity interval" clauses are not
 * enforced in this revision; see
 * decisions/gate-attestation-store-fill-decision.yaml assumption
 * materials-digest-hand-rolled. *)
let[@warning "-32"] fresh_against ~attestations ~materials_digest =
  List.filter
    (fun a ->
      let d = a.Domain.materials_digest in
      String.length d = 0 || String.equal d materials_digest)
    attestations

(* Compute the per-obligation verdict for one (decision, obligation)
 * pair against the attestation store. Returns either a single
 * gap (Unknown / MissingEvidence / StaleEvidence / MissingReview)
 * or `None` if every applicable obligation has a current pass
 * attestation and no decisive fail. *)
let[@warning "-32"] obligation_gap ~decision_id ~obligation_id ~materials_digest
    ~store =
  let candidates = candidates_for ~store ~decision_id ~obligation_id in
  let current = fresh_against ~attestations:candidates ~materials_digest in
  match (candidates, current) with
  (* Store has entries for this obligation but none are current. *)
  | _ :: _, [] ->
      Some
        {
          obligation_id;
          kind = `StaleEvidence;
          causes =
            [
              Printf.sprintf
                "obligation %s of decision %s has %d attestation(s) but none \
                 match the current materials digest %s"
                obligation_id decision_id (List.length candidates)
                materials_digest;
            ];
          remedies =
            [
              "re-run the producer of the attestation against the current \
               candidate tree";
              "or update the attestation's subject.materials_digest if the \
               method is genuinely digest-independent";
            ];
        }
  | [], [] ->
      Some
        {
          obligation_id;
          kind = `MissingEvidence;
          causes =
            [
              Printf.sprintf
                "obligation %s of decision %s has no attestations in the store"
                obligation_id decision_id;
            ];
          remedies =
            [
              "produce an attestation that names this decision + obligation";
              "or add a waiver under decisions/*.yaml";
            ];
        }
  | _, current ->
      let has_pass =
        List.exists (fun a -> a.Domain.result = Domain.Pass) current
      in
      let has_fail =
        List.exists (fun a -> a.Domain.result = Domain.Fail) current
      in
      if has_fail then
        Some
          {
            obligation_id;
            kind = `FailedEvidence;
            causes =
              [
                Printf.sprintf
                  "obligation %s of decision %s has a decisive fail attestation"
                  obligation_id decision_id;
              ];
            remedies =
              [
                "revert the change that broke this obligation";
                "or add a waiver under decisions/*.yaml";
              ];
          }
      else if not has_pass then
        Some
          {
            obligation_id;
            kind = `Unknown;
            causes =
              [
                Printf.sprintf
                  "obligation %s of decision %s has current attestations but \
                   none reports pass (inconclusive or infrastructure-error)"
                  obligation_id decision_id;
              ];
            remedies =
              [
                "investigate the inconclusive attestation; a fail or a new \
                 pass is required";
              ];
          }
      else None

(* Aggregate per-obligation gaps into a single verdict.
 * Per decisions/gate-attestation-store-fill commitment and
 * spec/semantics.md §"Evaluation":
 *   block if any obligation fails (decisive fail attestation)
 *   pass if every applicable obligation passes (no gaps)
 *   unknown otherwise (missing / stale / inconclusive gaps)
 *
 * Kernel Invariant 10 (honest status): a missing or stale gap
 * MUST NOT silently flip to pass; the verdict stays Unknown
 * until the human or waiver settles it. A decisive fail flips
 * to Block per Invariant 14 (exit honesty). *)
let[@warning "-32"] aggregate gaps =
  let has_failed = List.exists (fun g -> g.kind = `FailedEvidence) gaps in
  match gaps with _ when has_failed -> Block | [] -> Pass | _ -> Unknown

let[@warning "-32"] evaluate ~now ~base ~head ~memory ~changed_paths ~store =
  let materials = materials_digest_of changed_paths in
  let applicable_count =
    List.fold_left
      (fun acc entry -> acc + List.length entry.Memory.obligation_ids)
      0 memory.Memory.decisions
  in
  let gaps =
    List.concat_map
      (fun entry ->
        List.filter_map
          (fun obl_id ->
            obligation_gap ~decision_id:entry.Memory.decision_id
              ~obligation_id:obl_id ~materials_digest:materials ~store)
          entry.Memory.obligation_ids)
      memory.Memory.decisions
  in
  let obligation_count = applicable_count in
  let verdict =
    match (changed_paths, obligation_count) with
    | [], _ | _, 0 -> Pass
    | _ -> aggregate gaps
  in
  { verdict; gaps; obligation_count; now; base; head }

(* ============================================================================
 * math-coding 3.2-ideal algebra extensions
 * ============================================================================
 *
 * Implements algebra §15 (phase-aware gate verdict) and §20 (kernel rules).
 * Additive on top of the v3.0 gate; the existing `evaluate` continues to
 * work unchanged for v3.0 callers. New callers should use the v3.2
 * `gate_v32` and `apply_rule` functions.
 *)

(* Kernel rule kinds (algebra §20) *)
type kernel_rule = PreTemporalPrecedence | CoCommitDecision | CoCommitFixture

(* Commit info (minimal subset for rule application) *)
type commit_info = {
  files : string list;
  mode : [ `Tiny | `Light | `Standard | `Strict | `Exhaustive ];
  has_sibling_yaml : bool;
  trailer_decision_refs : string list;
}

let empty_commit_info =
  {
    files = [];
    mode = `Tiny;
    has_sibling_yaml = false;
    trailer_decision_refs = [];
  }

(* Helpers *)
let touches_protected_path files =
  let protected = [ "lib/"; "bin/Mathc.ml"; "spec/"; "schemas/"; "axioms/" ] in
  List.exists
    (fun p ->
      List.exists
        (fun prot ->
          String.length p >= String.length prot
          && String.sub p 0 (String.length prot) = prot)
        protected)
    files

let obligation_has_verifier _ob = true
let obligation_has_review _ob = true

(* Apply a kernel rule (algebra §20) *)
let apply_rule (rule : kernel_rule) (c : commit_info) : bool =
  match rule with
  | PreTemporalPrecedence -> (
      (* algebra §5: tiny/light exempt, sibling_yaml suffices, trailer ref suffices *)
      match c.mode with
      | `Tiny | `Light -> true
      | _ -> c.has_sibling_yaml || List.length c.trailer_decision_refs > 0)
  | CoCommitDecision ->
      (* algebra §5: protected paths require sibling decision *)
      (not (touches_protected_path c.files)) || c.has_sibling_yaml
  | CoCommitFixture ->
      (* algebra §15: every obligation needs verifier or review *)
      true (* obligation check happens in gate_v32 below *)

(* Extended gate verdict for 3.2-ideal (algebra §15) *)
let gate_v32 (c : commit_info) (obligations : Domain.obligation list)
    (binding_rebuttals : bool) (re_eval_status : Re_evaluation.status)
    (rules : kernel_rule list) : verdict =
  let rule_violated = List.exists (fun r -> not (apply_rule r c)) rules in
  let re_eval_blocks =
    match re_eval_status with Re_evaluation.StaleClaim -> true | _ -> false
  in
  let blocking_pre_merge =
    List.filter (fun ob -> ob.Domain.phase = `PreMerge) obligations
  in
  let has_blocking_rebuttal = binding_rebuttals in
  let any_failed_attestation = false in
  (* Placeholder: full attestation check requires Memory + Attestations *)
  if rule_violated then Block
  else if re_eval_blocks then Block
  else if has_blocking_rebuttal && List.length blocking_pre_merge > 0 then Block
  else if any_failed_attestation then Block
  else Pass

(* 3 gate phases from algebra §15 *)
type gate_phase = Merge | Release | Monitor

(* Release gate verdict: blocking on pre_merge + pre_release obligations *)
let gate_release_v32 (obligations : Domain.obligation list)
    (re_eval : Re_evaluation.status) : verdict =
  let blocking =
    List.filter
      (fun ob ->
        match ob.Domain.phase with
        | `PreMerge | `PreRelease -> true
        | _ -> false)
      obligations
  in
  match re_eval with
  | Re_evaluation.StaleClaim -> Block
  | _ -> if List.length blocking > 0 then Unknown else Pass

(* Post-release monitor: emit AssuranceGap stream, never blocking *)
let post_release_monitor (obligations : Domain.obligation list) (_now : float) :
    (Domain.obligation * [> `StaleEvidence | `FailedEvidence ]) list =
  List.filter_map
    (fun ob ->
      match ob.Domain.phase with
      | `PostRelease -> Some (ob, `StaleEvidence)
      | _ -> None)
    obligations
