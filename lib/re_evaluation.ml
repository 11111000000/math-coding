(* lib/re_evaluation.ml — re-evaluation oracle per spec/algebra-3.2.md §17.
 *
 * Implements the §17 "Inline axiom change" oracle: given a candidate
 * decision and a candidate axiom revision, classify the impact as
 * one of five states (T1.2 expansion from the previous three):
 *
 *   - Compatible           : legacy / deprecated. Returned by
 *                            built-in verifiers that the gate
 *                            invokes in-process (mathc-validate,
 *                            mathc-gate, mathc-self-check). The
 *                            gate does NOT shell out from a pure
 *                            module; built-ins are validated at
 *                            gate-runtime, so the oracle can safely
 *                            mark them compatible without an
 *                            explicit run. Kept in the type for
 *                            backward-compatibility with callers
 *                            that pre-date the T1.2 transition.
 *   - CompatibleAfterRun   : explicit pass after a run. Returned
 *                            only by `re_evaluate_after_run` for
 *                            obligations whose verifier ran and
 *                            passed. This is the new "I have
 *                            actually executed the test" verdict.
 *   - Inconclusive         : at least one obligation uses a
 *                            manual-style verifier (review, no
 *                            verifier); the agent owes follow-up
 *                            review. Surfaces as a follow-up list,
 *                            does NOT block the gate (same as the
 *                            pre-T1.2 behaviour).
 *   - Incompatible         : a test-style obligation whose verifier
 *                            has not been run yet. The oracle is
 *                            honest: without an explicit run, a
 *                            passing-test verdict cannot be claimed.
 *                            Blocks the gate (T1.2 A1 closure:
 *                            `Compatible` now requires an explicit
 *                            run).
 *   - StaleClaim           : at least one obligation's claim
 *                            references a forbidden pattern from
 *                            the OLD axiom text — the decision
 *                            must be revised before the axiom
 *                            change can land.
 *
 * The max_verdict aggregation across an impact list drives the
 * gate verdict per §15 (`re_evaluation_status(c) ∈
 * {StaleClaim, Incompatible}` is a precondition of `gate = Open`;
 * `Inconclusive`, `Compatible`, and `CompatibleAfterRun` permit
 * Open with a follow-up review list for Inconclusive).
 *
 * Pure module: no I/O at module top level. `load_decisions` is the
 * single boundary function and mirrors the `Attestations.load`
 * style: a caller-supplied `reader` (path -> string) and a `root`
 * directory. Tests can pass a fake reader; the CLI calls
 * `In_channel.input_all`.
 *
 * As of T2.1 (decision parser addresses), the kernel decision
 * parser (`lib/decision.ml::parse_decision`) populates
 * `Domain.decision.relations.addresses` directly from the parsed
 * YAML — the explicit `relations.addresses` block, the explicit
 * `axiom:` / `axiom-id:` / `axioms:` keys, and any prose `A<id>`
 * token embedded in the decision tree. The loader here no longer
 * needs a raw-YAML bridge and is reduced to a thin parser wrapper. *)

(* --- Verdict --- *)

type status =
  | Compatible
  | CompatibleAfterRun
  | Inconclusive
  | Incompatible
  | StaleClaim

(* --- Axiom revision record --- *)

(* A lightweight record that carries the diff between old and new
 * axiom. The kernel does not store full axiom text; the loader
 * (or test harness) builds this record from the on-disk axiom
 * files. `old_forbidden_patterns` and `new_forbidden_patterns` are
 * the substrings that, if mentioned by a decision obligation's
 * claim, indicate the claim was written against the OLD axiom and
 * may no longer hold (algebra §17 re_evaluate rule 1). *)
type axiom_revision = {
  axiom_id : string;
  old_sha : string;
  new_sha : string;
  old_forbidden_patterns : string list;
  new_forbidden_patterns : string list;
}

(* --- Status ordering --- *)

(* StaleClaim > Incompatible > Inconclusive > Compatible > CompatibleAfterRun.
 * Used by `max_verdict` to aggregate per-obligation verdicts into
 * one per-decision verdict. The ranking mirrors the gate's
 * permissiveness: any `StaleClaim` or `Incompatible` makes the
 * decision block; `Inconclusive` keeps the gate open but surfaces
 * a follow-up review; the `Compatible*` verdicts are fully open. *)
let[@warning "-32"] status_rank = function
  | CompatibleAfterRun -> 0
  | Compatible -> 1
  | Inconclusive -> 2
  | Incompatible -> 3
  | StaleClaim -> 4

let[@warning "-32"] max_verdict verdicts =
  match verdicts with
  | [] -> CompatibleAfterRun
  | _ -> (
      let ranked = List.map status_rank verdicts in
      let max_rank = List.fold_left max 0 ranked in
      match max_rank with
      | 0 -> CompatibleAfterRun
      | 1 -> Compatible
      | 2 -> Inconclusive
      | 3 -> Incompatible
      | _ -> StaleClaim)

(* --- Gate verdict contribution --- *)

(* Per §15 gate_merge / gate_release:
 *   re_evaluation_status(c) ∈ {StaleClaim, Incompatible} blocks
 *   Open. The remaining verdicts (Compatible, CompatibleAfterRun,
 *   Inconclusive) permit the gate to Open; `Inconclusive` surfaces
 *   a follow-up review list, not a block.
 *   We return the polymorphic variant [ `Block | `Pass ] for the
 *   aggregator to consume. *)
let[@warning "-32"] gate_verdict = function
  | StaleClaim | Incompatible -> `Block
  | Compatible | CompatibleAfterRun | Inconclusive -> `Pass

(* --- Verifier kind classification --- *)

(* Classify an obligation's acceptance shape into a verifier
 * category per algebra §17:
 *   - `Test     : verifier id starts with "tests/" — runnable
 *   - `BuiltIn  : verifier id starts with a kernel built-in
 *                 prefix ("mathc-", "kernel:") — invocable in-process
 *   - `Manual   : everything else (review, no verifier, etc.) *)
type verifier_kind = Test | BuiltIn | Manual

let[@warning "-32"] classify_verifier (v : string) : verifier_kind =
  let n = String.length v in
  if n >= 6 && String.sub v 0 6 = "tests/" then Test
  else if n >= 6 && String.sub v 0 6 = "mathc-" then BuiltIn
  else if n >= 7 && String.sub v 0 7 = "kernel:" then BuiltIn
  else Manual

(* Pull the verifier id off the first item of an acceptance list.
 * Returns "" if the acceptance shape has no verifier (e.g. a
 * bare review). Callers treat "" as Manual. The recursive walk
 * descends into nested `All` / `Any` groups because
 * `acceptance` is a recursive variant. *)
let[@warning "-32"] first_verifier_id (acc : Domain.acceptance) : string =
  let rec from_items = function
    | [] -> ""
    | Domain.Verifier { id; _ } :: _ -> id
    | Domain.Review _ :: rest -> from_items rest
    | Domain.All inner :: rest -> (
        match from_items inner with "" -> from_items rest | id -> id)
    | Domain.Any inner :: rest -> (
        match from_items inner with "" -> from_items rest | id -> id)
  in
  match acc with
  | Domain.All items -> from_items items
  | Domain.Any items -> from_items items
  | Domain.Verifier { id; _ } -> id
  | Domain.Review _ -> ""

(* --- Pattern matching --- *)

(* Case-insensitive substring match. The axiom diff is small (a
 * handful of forbidden patterns), so a linear scan per pattern
 * is more than fast enough and avoids regex escaping bugs. *)
let[@warning "-32"] str_contains_ci haystack needle =
  let h = String.lowercase_ascii haystack in
  let n = String.lowercase_ascii needle in
  let h_len = String.length h in
  let n_len = String.length n in
  if n_len = 0 then true
  else if h_len < n_len then false
  else
    let rec scan i =
      if i + n_len > h_len then false
      else if String.sub h i n_len = n then true
      else scan (i + 1)
    in
    scan 0

let[@warning "-32"] claim_references_any claim patterns =
  List.exists (fun p -> str_contains_ci claim p) patterns

(* --- Per-obligation evaluation (no run) --- *)

(* evaluate_obligation : Obligation × AxiomRevision → status
 *
 * Per algebra §17 (T1.2 expansion):
 *   ∀ ob ∈ d.obligations:
 *     - ob.claim references A_old.forbidden_patterns → StaleClaim
 *     - ob.acceptance.verifier is test-style, no run → Incompatible
 *       (T1.2 A1 closure: explicit run required for Compatible)
 *     - ob.acceptance.verifier is builtin-style → Compatible
 *       (gate invokes these in-process; no separate run needed)
 *     - ob.acceptance.verifier is manual-style → Inconclusive
 *       (agent owes follow-up review; same as pre-T1.2 behaviour)
 *
 * The pure oracle (no I/O). This is the per-obligation verdict
 * BEFORE any test was actually executed. Callers that want a
 * verdict-after-run should use `evaluate_obligation_after_run`
 * instead. *)
let[@warning "-32"] evaluate_obligation (ob : Domain.obligation) rev : status =
  let verifier_id = first_verifier_id ob.Domain.acceptance in
  let kind = classify_verifier verifier_id in
  let claim = ob.Domain.claim in
  let stale =
    claim_references_any claim rev.old_forbidden_patterns
    || claim_references_any claim rev.new_forbidden_patterns
  in
  if stale then StaleClaim
  else
    match kind with
    | Test ->
        (* Test-style verifier without an explicit run: the T1.2
         * A1 closure says the oracle MUST NOT claim `Compatible`
         * until the test has actually been executed. Return
         * `Incompatible`; the agent must run the test (via
         * `mathc re-evaluate-decisions` or another runner) and
         * then re-query the oracle for a `CompatibleAfterRun`. *)
        Incompatible
    | BuiltIn ->
        (* Built-in verifiers (mathc-validate, mathc-gate,
         * mathc-self-check) are invoked in-process by the gate
         * itself. Without an explicit run, the verdict is still
         * `Compatible` (legacy semantics preserved). *)
        Compatible
    | Manual ->
        (* Manual-style verifier: §17 says return Inconclusive.
         * The agent owes follow-up review. T1.2 preserves this
         * mapping verbatim; `Inconclusive` is still in the type. *)
        Inconclusive

(* --- Per-obligation evaluation (after run) --- *)

(* evaluate_obligation_after_run : Obligation × AxiomRevision → status
 *
 * Same logic as `evaluate_obligation` except that a test-style
 * verifier returns `CompatibleAfterRun` rather than `Incompatible`.
 * This is the per-obligation verdict AFTER an explicit run by
 * `mathc re-evaluate-decisions` (or any other runner that supplies
 * fresh evidence). The T1.2 contract:
 *
 *   - The CLI subcommand emits one attestation per (decision,
 *     obligation) pair that recorded a `CompatibleAfterRun` pass.
 *   - `gate_v32` then sees `CompatibleAfterRun` for the obligation
 *     and the gate is permitted to Open.
 *
 * The "run was done" semantic is encoded by the function name; the
 * oracle trusts the caller to have actually run the test before
 * invoking this function. A caller that has not run should use
 * `evaluate_obligation` instead and accept the `Incompatible`
 * verdict. *)
let[@warning "-32"] evaluate_obligation_after_run (ob : Domain.obligation) rev :
    status =
  let verifier_id = first_verifier_id ob.Domain.acceptance in
  let kind = classify_verifier verifier_id in
  let claim = ob.Domain.claim in
  let stale =
    claim_references_any claim rev.old_forbidden_patterns
    || claim_references_any claim rev.new_forbidden_patterns
  in
  if stale then StaleClaim
  else
    match kind with
    | Test ->
        (* Test-style verifier after an explicit run that passed:
         * the oracle returns `CompatibleAfterRun`. The gate sees
         * this as `Pass` and the decision is permitted to Open. *)
        CompatibleAfterRun
    | BuiltIn -> Compatible
    | Manual ->
        (* Manual review is still a human activity; even after a
         * test-run on sibling obligations, a manual verifier
         * still surfaces as `Inconclusive` until a human
         * attests. *)
        Inconclusive

(* --- Public API: re_evaluate --- *)

(* re_evaluate : Decision × AxiomRevision → status
 *
 * The pure, no-run oracle. Per algebra §17 (T1.2 expansion):
 *   ∀ ob ∈ d.obligations:
 *     - ob.claim references A_old.forbidden_patterns → StaleClaim
 *     - ob.acceptance.verifier is test-style → Incompatible
 *       (no run was done; T1.2 A1 closure)
 *     - ob.acceptance.verifier is builtin-style → Compatible
 *     - ob.acceptance.verifier is manual-style → Inconclusive
 * The decision-level verdict is the max of per-obligation verdicts
 * under `status_rank`. *)
let[@warning "-32"] re_evaluate (d : Domain.decision) (rev : axiom_revision) :
    status =
  max_verdict
    (List.map (fun ob -> evaluate_obligation ob rev) d.Domain.obligations)

(* --- Public API: re_evaluate_after_run --- *)

(* re_evaluate_after_run : Decision list × AxiomRevision →
 *   (Decision × status) list
 *
 * Walks a list of decisions and returns each decision paired
 * with its post-run verdict under `rev`. Same per-obligation
 * rules as `re_evaluate`, except test-style verifiers that pass
 * return `CompatibleAfterRun` (the "I have actually run the
 * test" verdict). The list is in the order of the input.
 *
 * `mathc re-evaluate-decisions <axiom-rev>` invokes this function
 * to obtain per-decision post-run verdicts and emits one
 * attestation per `CompatibleAfterRun` obligation. *)
let[@warning "-32"] re_evaluate_after_run (decisions : Domain.decision list)
    (rev : axiom_revision) : (Domain.decision * status) list =
  List.map
    (fun (d : Domain.decision) ->
      ( d,
        max_verdict
          (List.map
             (fun (ob : Domain.obligation) ->
               evaluate_obligation_after_run ob rev)
             d.Domain.obligations) ))
    decisions

(* --- Impact list --- *)

(* impact_list : Decision list × axiom_id → Decision list
 *
 * Returns the subset of decisions whose relations.addresses list
 * contains `axiom_id` (i.e. they directly reference the axiom
 * being changed). Per algebra §17:
 *   impact-list(d) = {d' : A ∈ d'.referenced_axioms ∨ ...}
 * `referenced_axioms` is realised here as `relations.addresses`
 * (the §7 field that "implements one or more axioms"). *)
let[@warning "-32"] addresses_axiom (d : Domain.decision) (axiom_id : string) :
    bool =
  List.exists
    (fun ref -> String.equal ref axiom_id)
    d.Domain.relations.Domain.addresses

let[@warning "-32"] impact_list (decisions : Domain.decision list)
    (axiom_id : string) : Domain.decision list =
  List.filter (fun d -> addresses_axiom d axiom_id) decisions

(* transitive_impact_list : Decision list × axiom_id → Decision list
 *
 * Extends impact_list with decisions whose `depends_on` list names
 * one of the directly-impacted decisions. This is the operational
 * approximation of algebra §17's
 *   "A ∈ transitive_referenced_axioms(d')"
 * for the relation graph the kernel actually carries (depends_on,
 * not raw axiom-id transitive closure). *)

let[@warning "-32"] transitive_impact_list (decisions : Domain.decision list)
    (axiom_id : string) : Domain.decision list =
  let direct = impact_list decisions axiom_id in
  let direct_ids : string list =
    List.map (fun (d : Domain.decision) -> d.Domain.id) direct
  in
  let indirect =
    List.filter
      (fun (d : Domain.decision) ->
        List.exists
          (fun (parent_id : string) ->
            List.mem parent_id d.Domain.relations.Domain.depends_on)
          direct_ids)
      decisions
  in
  let combined : Domain.decision list = direct @ indirect in
  (* Deduplicate while preserving order (direct first, then
   * indirect). Track seen ids separately from the result
   * accumulator so the type of each is unambiguous. *)
  let dedup (xs : Domain.decision list) : Domain.decision list =
    let step ((acc_seen, acc_out) : string list * Domain.decision list)
        (d : Domain.decision) =
      if List.mem d.Domain.id acc_seen then (acc_seen, acc_out)
      else (d.Domain.id :: acc_seen, d :: acc_out)
    in
    let seen, out = List.fold_left step ([], []) xs in
    List.rev out
  in
  dedup combined

(* --- Remediation template --- *)

(* Render a markdown remediation block. The agent can paste this
 * into a PR comment or a follow-up commit body when the gate
 * blocks on StaleClaim. *)
let[@warning "-32"] remediation (d : Domain.decision) (axiom_id : string) :
    string =
  Printf.sprintf
    {|## Decision %s requires update

This decision references axiom %s which has been changed.

### Action required

1. Review the new axiom text in `axioms/%s.md`.
2. Update the decision's obligation claim(s) to reflect the new
   semantics.
3. Create a new revision (`rev+1`) of this decision under
   `decisions/%s.yaml`.
4. Re-run `mathc validate` and `mathc gate` so the obligations are
   re-attested against the new axiom.

### Current commitment

```
%s
```

### Suggested new commitment

[TODO: depends on the specific axiom change — open the new axiom
text in `axioms/%s.md`, identify which phrases in the current
commitment are now stale, and rewrite them.]
|}
    d.Domain.id axiom_id axiom_id d.Domain.id d.Domain.commitment axiom_id

(* --- Loader (boundary I/O) --- *)

(* Enumerate candidate decision paths under <root>/decisions/*.yaml
 * (also accepting .yml and .json). Missing directory -> []. The
 * kernel never crashes on a missing decisions directory; the
 * caller decides the priority. *)
let[@warning "-32"] list_decision_files (root : string) : string list =
  let dir = Filename.concat root "decisions" in
  if not (Sys.file_exists dir) then []
  else if not (Sys.is_directory dir) then []
  else
    try
      Sys.readdir dir |> Array.to_list
      |> List.filter (fun name ->
          let sfx = Filename.extension name in
          sfx = ".yaml" || sfx = ".yml" || sfx = ".json")
      |> List.map (fun name -> Filename.concat dir name)
    with _ -> []

(* Read one decision file via the caller-supplied reader. The
 * reader contract: empty string means "missing or empty", and we
 * return None for that. Parse failures are swallowed — the
 * kernel is best-effort over the corpus and never crashes on a
 * malformed decision (mirrors `Attestations.read_one`).
 *
 * Post-T2.1: `Decision.parse_decision_yaml` already populates
 * `relations.addresses` (YAML block + `axiom:` / `axiom-id:` /
 * `axioms:` keys + prose `A<id>` tokens). The loader is now a
 * thin parser wrapper. *)
let[@warning "-32"] read_decision (reader : string -> string) (path : string) :
    Domain.decision option =
  let raw = reader path in
  if raw = "" then None
  else
    let v =
      try Codec.load_yaml_string raw
      with _ -> ( try Jsonl.parse raw with _ -> Jsonl.Null)
    in
    match v with Jsonl.Object _ -> Decision.parse_decision_yaml v | _ -> None

(* load_decisions : reader × root → Domain.decision list
 *
 * Boundary function. Mirrors `Attestations.load`:
 *   - takes a `reader` callback (caller controls I/O),
 *   - walks <root>/decisions/*.yaml,
 *   - parses each file with `Decision.parse_decision_yaml`,
 *   - skips malformed files silently (the kernel is best-effort). *)
let[@warning "-32"] load_decisions ~reader ~root =
  match list_decision_files root with
  | [] -> []
  | files ->
      List.filter_map
        (fun path ->
          match read_decision reader path with Some d -> Some d | None -> None)
        files
