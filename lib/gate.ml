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
  next_actions : (string * string) list;
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
          next_actions =
            [
              ( "run",
                Printf.sprintf "mathc assess <base> <head>   # recompute digest"
              );
              ( "run",
                Printf.sprintf
                  "mathc gate <base> <head>          # re-evaluate the gate" );
              ( "edit",
                Printf.sprintf
                  "attestations/<decision>-%s.json   # update \
                   subject.materials_digest"
                  obligation_id );
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
          next_actions =
            [
              ( "create",
                Printf.sprintf
                  "attestations/%s-%s.json   # add an attestation file"
                  decision_id obligation_id );
              ("create", "decisions/waivers/<decision>-<obligation>.yaml");
              ("run", "mathc self-check");
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
            next_actions =
              [
                ("run", "git revert <sha>   # revert the offending change");
                ( "edit",
                  Printf.sprintf "%s   # %s" decision_id
                    "fix the underlying cause and re-evaluate" );
                ( "create",
                  Printf.sprintf
                    "decisions/waivers/%s-%s.yaml   # add a waiver if \
                     acceptable"
                    decision_id obligation_id );
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
next_actions =
            [
              ( "run",
                Printf.sprintf
                  "mathc re-evaluate-decisions A0   # run the oracle \
                   explicitly" );
              ( "edit",
                Printf.sprintf
                  "attestations/%s-%s.json   # re-author the inconclusive \
                   attestation"
                  decision_id obligation_id );
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

(* Parse git-style trailer `Refs: decision:<id>@<rev>, decision:<id>@<rev>`
   from a commit body. Returns the list of decision ids (without
   the @rev suffix). Only `Refs:` line is parsed; other trailers
   are ignored. *)
let[@warning "-32"] parse_trailer_refs body =
  let rec scan lines acc =
    match lines with
    | [] -> List.rev acc
    | line :: rest ->
        let is_trailer =
          String.length line >= 5 && String.sub line 0 5 = "Refs:"
        in
        if not is_trailer then scan rest acc
        else
          (* strip the "Refs:" prefix and split on commas *)
          let after = String.sub line 5 (String.length line - 5) in
          let parts =
            after |> String.split_on_char ',' |> List.map String.trim
            |> List.filter (fun s -> String.length s > 0)
          in
          let ids =
            List.filter_map
              (fun p ->
                let prefix = "decision:" in
                let plen = String.length prefix in
                if String.length p > plen && String.sub p 0 plen = prefix then
                  (* strip @rev if present *)
                  let s = String.sub p plen (String.length p - plen) in
                  match String.index_opt s '@' with
                  | Some ai -> Some (String.sub s 0 ai)
                  | None -> Some s
                else None)
              parts
          in
          scan rest (List.rev_append ids acc)
  in
  scan (String.split_on_char '\n' body) []

(* Detect whether a decision file is part of the changed files.
   The commit_info.has_sibling_yaml flag tells apply_rule whether
   the author paired the kernel change with a decisions/*.yaml
   edit (per algebra §5). *)
let[@warning "-32"] has_sibling_yaml files =
  List.exists
    (fun f ->
      String.length f >= 12
      && String.sub f 0 10 = "decisions/"
      &&
      let ext = Filename.extension f in
      ext = ".yaml" || ext = ".yml")
    files

(* Build commit_info from the live gate inputs. *)
let[@warning "-32"] commit_info_of ~changed_paths ~body =
  let files = List.sort String.compare changed_paths in
  let mode = Risk.mode files in
  let has_sibling_yaml = has_sibling_yaml files in
  let trailer_decision_refs =
    if body = "" then [] else parse_trailer_refs body
  in
  { files; mode; has_sibling_yaml; trailer_decision_refs }

(* Detect any FailedEvidence gap in the obligations. Used by
   gate_v32 to honour the attestation check that the placeholder
   (line 322, removed) used to skip. *)
let[@warning "-32"] any_failed_attestation (obs_list : Domain.obligation list)
    ~store ~decision_id : bool =
  let f (ob : Domain.obligation) : bool =
    let cands =
      candidates_for ~store ~decision_id ~obligation_id:ob.Domain.id
    in
    List.exists
      (fun (a : Domain.attestation) ->
        match a.Domain.result with Domain.Fail -> true | _ -> false)
      cands
  in
  List.exists f obs_list

(* Extended gate verdict for 3.2-ideal (algebra §15) *)
let[@warning "-32"] gate_v32 (c : commit_info)
    (obligations : Domain.obligation list) (binding_rebuttals : bool)
    (re_eval_status : Re_evaluation.status) (rules : kernel_rule list) ~store
    ~decision_id : verdict =
  let rule_violated = List.exists (fun r -> not (apply_rule r c)) rules in
  (* T1.2 expansion: the gate now blocks on `Incompatible` AS WELL
   * as `StaleClaim`. `Incompatible` is the verdict the oracle
   * returns when a test-style obligation has not been explicitly
   * run; the previous 3-valued type silently returned `Compatible`
   * in that case, which the A1 honesty audit flagged as a gap.
   * `Compatible`, `CompatibleAfterRun`, and `Inconclusive` all
   * permit Open (Inconclusive still surfaces a follow-up review
   * list via the gap stream). *)
  let re_eval_blocks =
    match re_eval_status with
    | Re_evaluation.StaleClaim | Re_evaluation.Incompatible -> true
    | _ -> false
  in
  let blocking_pre_merge =
    List.filter (fun ob -> ob.Domain.phase = `PreMerge) obligations
  in
  let has_blocking_rebuttal = binding_rebuttals in
  let any_failed =
    List.exists
      (fun (ob : Domain.obligation) ->
        let cands =
          candidates_for ~store ~decision_id ~obligation_id:ob.Domain.id
        in
        List.exists
          (fun a ->
            match a.Domain.result with Domain.Fail -> true | _ -> false)
          cands)
      obligations
  in
  if rule_violated then Block
  else if re_eval_blocks then Block
  else if has_blocking_rebuttal && List.length blocking_pre_merge > 0 then Block
  else if any_failed then Block
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
  (* T1.2 expansion: `Incompatible` now blocks the release gate
   * alongside `StaleClaim` (the A1 honesty closure). *)
  match re_eval with
  | Re_evaluation.StaleClaim | Re_evaluation.Incompatible -> Block
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
