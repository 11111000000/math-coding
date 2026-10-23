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

(* --- scope materials (semantics A) ------------------------------------- *)

(* Does the path segment [pat] match the path segment [s]? `*` matches
   any run of characters within the segment. *)
let[@warning "-32"] segment_match (pat : string) (s : string) : bool =
  let parts = String.split_on_char '*' pat in
  let rec go parts s =
    match parts with
    | [] -> true
    | [ last ] ->
        (* The last literal part must match the END of the segment. *)
        let n = String.length last and m = String.length s in
        m >= n && String.sub s (m - n) n = last
    | p :: rest ->
        let n = String.length p in
        if n = 0 then go rest s
        else if
          String.length s >= n && String.sub s 0 n = p
        then go rest (String.sub s n (String.length s - n))
        else false
  in
  go parts s

(* Does the repository-relative path [path] match the glob [pattern]?
   `**` matches any number of path segments; `*` matches within one
   segment; everything else is literal. *)
let[@warning "-32"] glob_match (pattern : string) (path : string) : bool =
  let ps = String.split_on_char '/' pattern in
  let qs = String.split_on_char '/' path in
  let rec go ps qs =
    match (ps, qs) with
    | [], [] -> true
    | "**" :: ps, qs ->
        go ps qs
        || (match qs with [] -> false | _ :: qs' -> go ("**" :: ps) qs')
    | p :: ps, q :: qs when segment_match p q -> go ps qs
    | _ -> false
  in
  go ps qs

(* The materials digest of a scope.
 *
 * This is the reference value that `subject.materials_digest` is
 * compared against, and it is the value an attestation producer must
 * write. Before this function existed the two sides computed
 * DIFFERENT things and could never be equal:
 *
 *   - the gate compared against sha256 of the changed PATH NAMES
 *     (materials_digest_of, above);
 *   - the producers wrote sha256 of a command's OUTPUT, or "".
 *
 * The empty string was treated as a wildcard, so the only attestation
 * that ever satisfied the freshness check was the one that carried no
 * evidence at all: the mechanism rewarded dishonesty.
 *
 * Under this definition the digest is bound to the CONTENT of the
 * files the scope names. The content is addressed by git's blob id,
 * which is itself content-derived, so the digest changes exactly when
 * a named file's bytes change — and both sides compute it the same
 * way, from the same input, with no file reading at all.
 *
 * [blobs] is the (path, blob-id) list of the repository's tracked
 * files. [scope_paths] is the decision's `scope.paths`. *)
let[@warning "-32"] scope_materials_digest ~(blobs : (string * string) list)
    ~(scope_paths : string list) ~(exclude : string list) : string =
  (* The attestation store is EVIDENCE ABOUT the scope, not part of
     it. A decision that lists its own attestations in its scope
     creates a self-reference: the digest of the scope then depends
     on the attestation that carries the digest, so the attestation is
     stale the moment it is committed, and no signing can ever
     satisfy it. The store is excluded by prefix for that reason. *)
  let excluded p = List.exists (fun pre -> String.length p >= String.length pre
                                      && String.sub p 0 (String.length pre) = pre)
                      exclude
  in
  let matched =
    List.filter
      (fun (p, _) ->
        (not (excluded p))
        && List.exists (fun sc -> glob_match sc p) scope_paths)
      blobs
  in
  let matched =
    List.sort (fun (a, _) (b, _) -> String.compare a b) matched
  in
  let buf = Buffer.create 4096 in
  List.iter
    (fun (p, id) ->
      Buffer.add_string buf p;
      Buffer.add_char buf '\000';
      Buffer.add_string buf id;
      Buffer.add_char buf '\n')
    matched;
  Digest.sha256_hex (Buffer.contents buf)

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
(* `required_attestation_satisfied ra store` returns true when
   at least one attestation in `store` matches the
   (kind_, producer) pair declared by `ra`. The check is the
   exact-match closure: both fields must equal.

   `ra_scope_paths` is NOT enforced. It is parsed
   (`Decision.parse_scope_paths`), carried on the record, and
   rendered into the gap cause by `required_attestation_gap` for
   human traceability, and that is its entire effect on the
   verdict. A requirement with a non-empty `scope_paths` is
   satisfied by exactly the same store contents as the same
   requirement with none.

   This comment previously claimed the opposite: that a
   non-empty `ra_scope_paths` "filters by the attestation's
   candidate_tree (commit SHA) being mentioned in the
   attestation's `subject.candidate_tree` field". Three things
   were wrong with that. It described a filter the function
   does not implement. It read `scope_paths` as a commit SHA,
   where the field is an array of path GLOBS
   (`decision-required-attestations-2026-10.yaml`: "scope_paths
   is an optional array of glob strings"; the example there is
   `bin/Mathc.ml`, `spec/**/*.md`) -- a domain confusion, not a
   typo. And it contradicted the decision that governs this
   code, which states in terms that the predicate "is documented
   but not yet enforced" and that "the gate filter is currently
   (kind_, producer_identity)".

   Enforcing it is not a comment-sized change and was not made
   here. Beyond needing its own decision, it would flip the
   corpus: `scope_paths` would have to be matched against a
   commit SHA, and 0 of the 765 committed attestations carry
   one (749 carry the literal `HEAD`, 16 a branch name), so
   every scoped requirement would go unsatisfied and pass
   verdicts would become blocks. That would be a true statement
   about an unobserved corpus mistaken for a defect in the
   filter -- and it is precisely the retro-fitting of history
   that `candidate-tree-resolves-to-a-commit` forbids.
   Forward-path: now that new attestations carry a resolved
   commit id, the predicate becomes implementable at all; it
   stays unenforced until the store is re-observed rather than
   rewritten. *)
let[@warning "-32"] attestation_kind_str (a : Domain.attestation) : string =
  match a with
  | { kind = `Test; _ } -> "test"
  | { kind = `Review; _ } -> "review"
  | { kind = `Build; _ } -> "build"
  | { kind = `Analysis; _ } -> "analysis"
  | { kind = `Observation; _ } -> "observation"

let[@warning "-32"] required_attestation_satisfied
    (ra : Decision.required_attestation) store =
  List.exists
    (fun a ->
      String.equal (attestation_kind_str a) ra.ra_kind
      && String.equal a.Domain.producer_identity ra.ra_producer)
    store

(* `required_attestation_gap entry store` returns gaps for
   every `required_attestations:` item declared by `entry`
   that is not satisfied by `store`. Empty list when every
   requirement is satisfied (or when `required_attestations` is
   absent). The `obligation_id` is synthesised from the
   `(decision_id, kind, producer)` triple because the
   required-attestation gate is per-decision, not per-obligation;
   the gate ties each gap back to its source for traceability. *)
let[@warning "-32"] required_attestation_gap entry store =
  match entry.Memory.source with
  | source when source <> "" -> (
      match
        Decision.parse_required_attestations
          (match Codec.load_yaml_string source with v -> v)
      with
      | Some [] | None -> []
      | Some requireds ->
          List.filter_map
            (fun (ra : Decision.required_attestation) ->
              let k = ra.ra_kind in
              let p = ra.ra_producer in
              let scope_suffix =
                match ra.ra_scope_paths with
                | [] -> ""
                | paths ->
                    Printf.sprintf " (scope: %s)" (String.concat ", " paths)
              in
              let cause_msg =
                Printf.sprintf "required_attestation unfulfilled: %s from %s%s"
                  k p scope_suffix
              in
              if required_attestation_satisfied ra store then None
              else
                let gap =
                  {
                    obligation_id =
                      Printf.sprintf "%s/required-attestation:%s:%s"
                        entry.Memory.decision_id k p;
                    kind = `MissingReview;
                    causes = [ cause_msg ];
                    remedies =
                      [
                        "produce the listed attestation in attestations/";
                        "or remove the requirement from the decision";
                      ];
                    next_actions =
                      [
                        ( "run",
                          Printf.sprintf
                            "mathc attest --kind %s --producer %s %s.md" k p
                            entry.Memory.decision_id );
                      ];
                  }
                in
                Some gap)
            requireds)
  | _ -> []

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
(* `aggregate gaps` collapses a list of gaps to a verdict:
   *   - any FailedEvidence -> Block (the executable knowable)
   *   - any MissingReview -> Block (the human knowable; missing
   *     required-attestation gaps are tagged with this kind)
   *   - empty list          -> Pass
   *   - otherwise            -> Unknown (e.g. stale evidence)
   *
   * `MissingReview` is treated as blocking per
   * `decisions/decision-required-attestations-2026-10.yaml`: a
   * required human review whose attestation is absent is a
   * knownable gap, not an infrastructural one. Treating it as
   * Unknown would let a CI step sleep on a missing review;
   * treating it as FailedEvidence would conflate review-needs
   * with real execution failures; treating it as its own
   * Block-class is the middle path. *)
let[@warning "-32"] aggregate gaps =
  let blocking =
    List.exists
      (fun g -> g.kind = `FailedEvidence || g.kind = `MissingReview)
      gaps
  in
  match gaps with _ when blocking -> Block | [] -> Pass | _ -> Unknown

(* --- waiver-aware aggregation (math-coding 3.3) ---
 *
 * `aggregate` above is the whole verdict vocabulary for a
 * subject with no relief path: Pass, Block, or Unknown. The
 * waiver step lives here, as a separate pure function, for two
 * reasons.
 *
 * 1. Honesty of the verdict (constitution.md Invariant 10):
 *    "missing, stale, failed, inconclusive, infrastructure
 *    error, WAIVED and passed states MUST remain
 *    distinguishable". `Open_with_waiver` is its own variant and
 *    its own reportable string; a caller that folds it into Pass
 *    has broken Invariant 10 and, by `spec/semantics.md` §Merge
 *    Gate ("A merge with a Waiver MUST report `open-with-waiver`,
 *    never `pass`"), the merge-gate rule as well.
 *
 * 2. Referenceability (constitution.md Invariant 14c): "a verdict
 *    `Open_with_waiver` that produces exit 0 MUST reference a
 *    waiver whose `expires_at` is strictly greater than the
 *    evaluation time and whose scope covers every gap in the
 *    verdict." A verdict variant cannot reference anything on
 *    its own, so this function returns the waiver alongside the
 *    verdict: `covered` pairs every waived gap with the waiver
 *    that lifts it. The caller (bin/Mathc.ml) prints that pairing
 *    into the subject entry; a reader of the output can then see
 *    WHICH waiver, issued by WHOM, until WHEN, covering WHICH
 *    obligations. A waiver that is applied silently is not an
 *    acknowledgment, it is an unattributed pass.
 *
 * Which gap classes a waiver may lift: only the three that mean
 * "we do not know yet" (`MissingEvidence`, `StaleEvidence`,
 * `Unknown`). A decisive failure and a missing required review
 * are knowable gaps — the executable said no, or the human has
 * not spoken — and constitution.md §Waivers does not let a
 * waiver convert `fail` into anything else. *)

let[@warning "-32"] waivable_kind = function
  | `MissingEvidence | `StaleEvidence | `Unknown -> true
  | `FailedEvidence | `MissingReview | `NoAttestationStore -> false

(* Aggregate one subject's gaps, consulting `waivers` at `now`.
 * Pure: `waivers` is a loaded typed list (lib/waiver.ml performs
 * the I/O at the bin/ boundary), so this is unit-testable without
 * a filesystem.
 *
 * Returns `(verdict, covered)`:
 *   - `Pass`             -> `(Pass, [])`      nothing to waive
 *   - `Block`            -> `(Block, [])`     a fail is never waived
 *   - `Unknown`          -> `(Unknown, [])`   at least one gap is
 *                                            unwaived or unwaivable
 *   - `Open_with_waiver` -> every gap waivable AND every gap
 *                           covered at `now`
 *
 * `Unknown` is returned rather than `Open_with_waiver` if even
 * ONE gap is uncovered: partial relief is not relief. Partial
 * coverage is the interesting failure mode (a global waiver
 * filed against one obligation of a decision whose other
 * obligations are also missing) and it must not read as green.
 * `Waiver.covers` does the scoping — strict on
 * `unverified_obligation`, legacy decision-wide when the field
 * is absent (lib/waiver.ml). *)
let[@warning "-32"] aggregate_with_waivers (waivers : Waiver.t list)
    ~decision_id ~now gaps =
  match aggregate gaps with
  | Pass -> (Pass, [])
  | Block -> (Block, [])
  (* `aggregate` has no waiver input and so never returns this
     variant; the branch is defensive completeness, not a
     reachable path. If a future `aggregate` grows a waiver
     step, this branch is where it must report `covered = []`. *)
  | Open_with_waiver -> (Open_with_waiver, [])
  | Unknown ->
      let covered =
        List.filter_map
          (fun gap ->
            if not (waivable_kind gap.kind) then None
            else
              Option.map
                (fun (w : Waiver.t) -> (gap, w))
                (Waiver.covers waivers ~decision_id
                   ~obligation_id:gap.obligation_id ~now))
          gaps
      in
      if
        List.for_all (fun gap -> waivable_kind gap.kind) gaps
        && List.length covered = List.length gaps
      then (Open_with_waiver, covered)
      else (Unknown, [])

(* T3.1: v3.0 evaluate path now consults `Risk.mode files` and
 * surfaces rebuttal obligations for `mode >= strict`, per algebra
 * §10:
 *
 *   ∀ c, mode(c) ≥ strict: rebuttals(c) may exist (not required)
 *   ∀ c, mode(c) = exhaustive: rebuttals(c) required for
 *                              non-Unblocked verdict
 *
 * The previous v3.0 behaviour silently returned Unknown for
 * axiom-touching commits that lacked rebuttals; the new behaviour
 * mirrors gate_v32 by promoting to Block when rebuttals are empty
 * and the mode demands them. Pure function — `rebuttals` is loaded
 * by `bin/Mathc.ml::do_gate` (or a test fake) and passed in here
 * as a typed value; no I/O inside `evaluate` (OCAML_BEST_PRACTICES
 * §1.3).
 *
 * Kernel Invariant 14 (exit honesty): Block MUST exit non-zero,
 * and the gate verdict MUST reflect the strongest signal in the
 * store + the rebuttal binding. A rebuttal-less strict/exhaustive
 * commit is, by the spec, a Block. *)
let[@warning "-32"] rebuttal_gating_for_mode (m : Domain.mode) :
    [ `Required | `Optional ] =
  match m with `Strict | `Exhaustive -> `Required | _ -> `Optional

(* Lifecycle filter (decision lifecycle-commands-2026-10):
   only active and draft decisions are part of the active set
   that contributes obligation gaps to the gate verdict.
   Retired and superseded decisions are historical; their
   obligations remain in the source YAML but the gate does not
   ask the user to attest to them every commit. *)
let[@warning "-32"] active_entries (memory : Memory.t) :
    Memory.decision_entry list =
  List.filter
    (fun (entry : Memory.decision_entry) ->
      match entry.Memory.state with
      | `Active | `Draft -> true
      | `Retired | `Superseded -> false)
    memory.Memory.decisions

(* [materials_of_decision] maps a decision id to the reference
 * materials digest for that decision (semantics A: the digest of the
 * CONTENT of the files its scope names). It is injected so that
 * [Gate] stays pure — the git adapter lives in bin/. *)
let[@warning "-32"] evaluate ~now ~base ~head ~memory ~changed_paths ~store
    ~rebuttals ~materials_of_decision =
  let active_decisions = active_entries memory in
  let applicable_count =
    List.fold_left
      (fun acc entry -> acc + List.length entry.Memory.obligation_ids)
      0 active_decisions
  in
  let gaps =
    List.concat_map
      (fun entry ->
        List.filter_map
          (fun obl_id ->
            obligation_gap ~decision_id:entry.Memory.decision_id
              ~obligation_id:obl_id
              ~materials_digest:(materials_of_decision entry.Memory.decision_id)
              ~store)
          entry.Memory.obligation_ids)
      active_decisions
    @ List.concat_map
        (fun entry -> required_attestation_gap entry store)
        active_decisions
  in
  let obligation_count = applicable_count in
  let base_verdict =
    match (changed_paths, obligation_count) with
    | [], _ | _, 0 -> Pass
    | _ -> aggregate gaps
  in
  let mode = Risk.mode changed_paths in
  let rebuttals_required =
    match rebuttal_gating_for_mode mode with
    | `Required -> List.length rebuttals = 0
    | `Optional -> false
  in
  let verdict = if rebuttals_required then Block else base_verdict in
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
  mode : Domain.mode;
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
