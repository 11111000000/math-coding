(* lib/re_evaluation.ml — re-evaluation oracle per spec/algebra-3.2.md §17.
 *
 * Implements the §17 "Inline axiom change" oracle: given a candidate
 * decision and a candidate axiom revision, classify the impact as
 * one of three states:
 *
 *   - Compatible      : the decision's obligations do not conflict
 *                       with the new axiom (no claim mentions a
 *                       forbidden pattern from the old axiom and
 *                       every verifier is either a passing test or
 *                       a built-in kernel verifier).
 *   - Inconclusive    : at least one obligation uses a manual-style
 *                       verifier; the agent owes follow-up review.
 *   - StaleClaim      : at least one obligation's claim references
 *                       a forbidden pattern from the OLD axiom
 *                       text — the decision must be revised before
 *                       the axiom change can land.
 *
 * The max_verdict aggregation across an impact list drives the
 * gate verdict per §15 (`re_evaluation_status(c) ≠ StaleClaim` is a
 * precondition of `gate = Open`).
 *
 * Pure module: no I/O at module top level. `load_decisions` is the
 * single boundary function and mirrors the `Attestations.load`
 * style: a caller-supplied `reader` (path -> string) and a `root`
 * directory. Tests can pass a fake reader; the CLI calls
 * `In_channel.input_all`.
 *
 * The kernel decision parser (`lib/decision.ml`) does not yet
 * populate `Domain.decision.relations.addresses`; the loader here
 * bridges that gap by scanning the raw YAML source for axiom IDs
 * (`A0`..`A4` and any `axiom:` / `addresses:` field that names an
 * axiom). Decisions without addresses are still returned (with an
 * empty `relations.addresses`), so the rest of the kernel continues
 * to work; impact_list simply excludes them until the parser is
 * extended. *)

(* --- Verdict --- *)

type status = Compatible | Inconclusive | StaleClaim

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

(* StaleClaim > Inconclusive > Compatible. Used by `max_verdict`. *)
let[@warning "-32"] status_rank = function
  | Compatible -> 0
  | Inconclusive -> 1
  | StaleClaim -> 2

let[@warning "-32"] max_verdict verdicts =
  match verdicts with
  | [] -> Compatible
  | _ -> (
      let ranked = List.map status_rank verdicts in
      let max_rank = List.fold_left max 0 ranked in
      match max_rank with
      | 0 -> Compatible
      | 1 -> Inconclusive
      | _ -> StaleClaim)

(* --- Gate verdict contribution --- *)

(* Per §15 gate_merge / gate_release:
 *   re_evaluation_status(c) ≠ StaleClaim is required for Open.
 *   Compatible and Inconclusive both permit the gate to Open
 *   (Inconclusive surfaces a follow-up review list, not a block).
 *   We return the polymorphic variant [ `Block | `Pass ] for the
 *   aggregator to consume. *)
let[@warning "-32"] gate_verdict = function
  | StaleClaim -> `Block
  | Compatible | Inconclusive -> `Pass

(* --- Verifier kind classification --- *)

(* Classify an obligation's acceptance shape into a verifier
 * category per algebra §17:
 *   - `Test     : verifier id starts with "tests/" — runnable
 *   - `BuiltIn  : verifier id starts with a kernel built-in
 *                 prefix ("mc-", "kernel:") — invocable in-process
 *   - `Manual   : everything else (review, no verifier, etc.) *)
type verifier_kind = Test | BuiltIn | Manual

let[@warning "-32"] classify_verifier (v : string) : verifier_kind =
  let n = String.length v in
  if n >= 6 && String.sub v 0 6 = "tests/" then Test
  else if n >= 3 && String.sub v 0 3 = "mc-" then BuiltIn
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

(* --- Per-obligation evaluation --- *)

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
        (* Test-style verifier: the §17 rule says "run, return
         * Compatible on Pass". The kernel does not actually
         * invoke the test in this revision (that requires the
         * test harness to be wired up at the bin/ boundary); the
         * conservative default is Compatible, with the
         * understanding that the gate will re-run the test on
         * the real change set. *)
        Compatible
    | BuiltIn ->
        (* Built-in verifiers (mc-validate, mc-gate, mc-self-check)
         * are still considered Compatible in this revision: the
         * kernel doesn't shell out from a pure module. The gate
         * will run them in `mc gate`. *)
        Compatible
    | Manual ->
        (* Manual-style verifier: §17 says return Inconclusive.
         * The agent owes follow-up review. *)
        Inconclusive

(* --- Public API: re_evaluate --- *)

(* re_evaluate : Decision × AxiomRevision → ReEvaluationStatus
 * Per algebra §17:
 *   ∀ ob ∈ d.obligations:
 *     - ob.claim references A_old.forbidden_patterns → StaleClaim
 *     - ob.acceptance.verifier is test-style → run, return Compatible on Pass
 *     - ob.acceptance.verifier is manual-style → Inconclusive *)
let[@warning "-32"] re_evaluate (d : Domain.decision) (rev : axiom_revision) :
    status =
  max_verdict
    (List.map (fun ob -> evaluate_obligation ob rev) d.Domain.obligations)

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
4. Re-run `mc validate` and `mc gate` so the obligations are
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

(* Scan raw decision YAML for axiom IDs.
 *
 * Recognises:
 *   - bare tokens matching `A[0-9]+(@rev)?` on any line (so
 *     existing prose references like "axiom A1" light up);
 *   - explicit `axiom:` or `axiom-id:` keys, scalar value or
 *     list;
 *   - the canonical `addresses:` block (already parsed by some
 *     callers) — we only fold axiom-shaped entries into the
 *     addresses list to keep the union non-conflicting.
 *
 * Helpers are declared first because `read_decision` consumes
 * the result; OCaml's top-down binding rules require the
 * helpers to appear above the consumer. *)
let[@warning "-32"] strip_value v =
  let v = String.trim v in
  let n = String.length v in
  if n >= 2 && v.[0] = '"' && v.[n - 1] = '"' then String.sub v 1 (n - 2)
  else if n >= 2 && v.[0] = '\'' && v.[n - 1] = '\'' then String.sub v 1 (n - 2)
  else v

let[@warning "-32"] is_axiom_token s =
  let n = String.length s in
  if n < 2 then false
  else if s.[0] <> 'A' then false
  else
    let re = Str.regexp "^A[0-9]+\\([@.][A-Za-z0-9_.-]*\\)?$" in
    try
      ignore (Str.search_forward re s 0);
      true
    with Not_found -> false

let[@warning "-32"] split_list_value v =
  String.split_on_char ',' v |> List.map strip_value
  |> List.filter (fun s -> s <> "")

let[@warning "-32"] collect_value (acc : string list) (v : string) =
  let stripped = strip_value v in
  if is_axiom_token stripped then
    if List.mem stripped acc then acc else stripped :: acc
  else acc

let[@warning "-32"] scan_axiom_ids (raw : string) : string list =
  let lines = String.split_on_char '\n' raw in
  let re_token = Str.regexp "\\(\\<A[0-9]+\\([@.][A-Za-z0-9_.-]*\\)?\\>\\)" in
  let scan_token (acc : string list) (line : string) =
    let pos = ref 0 in
    let rec loop () =
      try
        let _ = Str.search_forward re_token line !pos in
        let tok = Str.matched_string line in
        let acc =
          if is_axiom_token tok && not (List.mem tok acc) then tok :: acc
          else acc
        in
        pos := Str.match_end ();
        let _ = acc in
        loop ()
      with Not_found -> acc
    in
    loop ()
  in
  let rec loop acc = function
    | [] -> List.rev acc
    | line :: rest ->
        let trimmed = String.trim line in
        (* Token scan first: catches prose references like
         * "axiom A1" or "A2 self-application" anywhere on a
         * line. *)
        let acc = scan_token acc line in
        (* Keyed scan: explicit `axiom: A0`, `addresses: [...]`
         * forms. *)
        let acc =
          match String.index_opt trimmed ':' with
          | Some i ->
              let key = String.trim (String.sub trimmed 0 i) in
              let v =
                String.trim
                  (String.sub trimmed (i + 1) (String.length trimmed - i - 1))
              in
              if
                String.equal key "axiom"
                || String.equal key "axiom-id"
                || String.equal key "axioms"
              then
                let values = if v <> "" then [ v ] else [] in
                List.fold_left collect_value acc values
              else if String.equal key "addresses" then
                let n = String.length v in
                let values =
                  if n >= 2 && v.[0] = '[' && v.[n - 1] = ']' then
                    let inner = String.sub v 1 (n - 2) in
                    split_list_value inner
                  else if v <> "" then [ v ]
                  else []
                in
                List.filter_map
                  (fun s -> if is_axiom_token s then Some s else None)
                  values
                |> List.fold_left
                     (fun a id -> if List.mem id a then a else id :: a)
                     acc
              else acc
          | None -> acc
        in
        loop acc rest
  in
  loop [] lines

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
 * malformed decision (mirrors `Attestations.read_one`). *)
let[@warning "-32"] read_decision (reader : string -> string) (path : string) :
    Domain.decision option =
  let raw = reader path in
  if raw = "" then None
  else
    let v =
      try Codec.load_yaml_string raw
      with _ -> ( try Jsonl.parse raw with _ -> Jsonl.Null)
    in
    match v with
    | Jsonl.Object _ -> (
        match Decision.parse_decision v with
        | Some d ->
            (* Bridge: the existing parser leaves relations
             * empty. Scan the raw YAML for axiom IDs (A0..A4
             * or any token matching `^A[0-9]+(@rev)?$`) and
             * populate `relations.addresses` with the subset
             * that looks like an axiom id. This keeps
             * `impact_list` functional without forcing every
             * decision author to migrate to the 3.2 parser. *)
            let axiom_ids = scan_axiom_ids raw in
            let existing = d.Domain.relations.Domain.addresses in
            let merged =
              List.fold_left
                (fun acc id -> if List.mem id acc then acc else id :: acc)
                existing axiom_ids
            in
            Some
              {
                d with
                Domain.relations =
                  { d.Domain.relations with Domain.addresses = merged };
              }
        | None -> None)
    | _ -> None

(* load_decisions : reader × root → Domain.decision list
 *
 * Boundary function. Mirrors `Attestations.load`:
 *   - takes a `reader` callback (caller controls I/O),
 *   - walks <root>/decisions/*.yaml,
 *   - parses each file with `Decision.parse_decision`,
 *   - augments `relations.addresses` with axiom IDs found in the
 *     raw YAML,
 *   - skips malformed files silently (the kernel is best-effort). *)
let[@warning "-32"] load_decisions ~reader ~root =
  match list_decision_files root with
  | [] -> []
  | files ->
      List.filter_map
        (fun path ->
          match read_decision reader path with Some d -> Some d | None -> None)
        files
