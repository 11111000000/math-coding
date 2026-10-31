type severity = Info | Warn | Block

type kind =
  | Input
  | Question
  | Deficit
  | Infrastructure
  | Conflict
  | Authorization

type subject = Subject of string | Anonymous

type t = {
  code : string;
  kind : kind;
  severity : severity;
  subject : subject;
  path : string list;
  message : string;
  cause : string list;
  policy_rule : string option;
  retryable : bool;
  autofix_safe : bool;
  next_actions : (string * string) list;
}

let create ?(code = "MC-UNKNOWN") ?(kind = Input) ?(severity = Info)
    ?(subject = Anonymous) ?(path = []) ?(cause = []) ?(policy_rule = None)
    ?(retryable = false) ?(autofix_safe = false) ?(next_actions = []) message =
  {
    code;
    kind;
    severity;
    subject;
    path;
    message;
    cause;
    policy_rule;
    retryable;
    autofix_safe;
    next_actions;
  }

let input code message = create ~code ~kind:Input message
let question code message = create ~code ~kind:Question message
let deficit code message = create ~code ~kind:Deficit ~severity:Block message

let infra code message =
  create ~code ~kind:Infrastructure ~retryable:true message

let authorization code message = create ~code ~kind:Authorization message

(* Standard verb set for next_actions snippets. Every snippet is a
   (verb, body) pair where the verb names the action and the body
   is a literal block the author can paste into their editor or
   shell. Whitelist: add, run, create, edit, replace, supersede.
   See decisions/plan-2026-10-improvements/t4-1.yaml for the
   rationale and the meta-decision audit. *)
let verbs_for_ks : string list =
  [ "add"; "run"; "create"; "edit"; "replace"; "supersede" ]

let verb_is_known v = List.mem v verbs_for_ks

(* Default next_actions for an MC-* code that has no code-specific
   snippet (the explain registry documents prose remediation; the
   snippet is the copy-pasteable companion). The default points the
   author at `mathc explain-diagnostic <CODE>` and the README
   troubleshooting section. *)
let default_next_actions code =
  [
    ("run", "mathc explain-diagnostic " ^ code);
    ("edit", "README.md#troubleshooting");
  ]

(* Build a (verb, body) entry after validating the verb. Returns
   a list so callers can add many entries; an unknown verb becomes
   `edit` (the OCaml entry says: do not silently drop a clause). *)
let safe_action verb body =
  if verb_is_known verb then (verb, body) else ("edit", body)

(* MC-AMBIGUOUS-ACCEPTANCE: emitted by the conformance runner when
   an obligation's `all` or `any` list contains an item with both
   `verifier` + `result` AND `review` fields. Per
   OCAML_BEST_PRACTICES §9.1 the verifier shape is preferred and
   the review is silently dropped; we surface the ambiguity as a
   Warn-level diagnostic so the author can disambiguate.
   Severity is Warn (not Block) because the kernel still produces a
   well-typed Domain.acceptance for the verifier half — the
   alternative would be to refuse the whole obligation, which is
   heavier than the spec requires. *)
let ambiguous_acceptance ?(obligation_id = "") ?(item_position = -1)
    ?(next_actions = []) () =
  let pos_str =
    if item_position >= 0 then Printf.sprintf " (all[%d])" item_position else ""
  in
  let msg =
    Printf.sprintf
      "obligation %s: acceptance item carries both verifier and review%s; \
       verifier wins, review is dropped"
      obligation_id pos_str
  in
  let default_actions =
    [
      ( "edit",
        Printf.sprintf
          "obligations:\n\
          \  - id: %s\n\
          \    acceptance:\n\
          \      all:\n\
          \        - verifier: oracles\n\
          \          result: pass    # or review: <text>"
          obligation_id );
      ("run", "mathc validate decisions/<file>.yaml");
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  create ~code:"MC-AMBIGUOUS-ACCEPTANCE" ~kind:Conflict ~severity:Warn
    ~next_actions:actions msg

(* MC-MALFORMED-ACCEPTANCE: emitted when an acceptance item has the
   right field shape (verifier+result OR review) but the values do
   not parse. E.g., verifier="x" with result="bogus" — `result` is
   not one of pass/fail/inconclusive/infrastructure-error. *)
let malformed_acceptance ?(obligation_id = "") ?(item_position = -1)
    ?(next_actions = []) reason =
  let pos_str =
    if item_position >= 0 then Printf.sprintf " (all[%d])" item_position else ""
  in
  let msg =
    Printf.sprintf "obligation %s: acceptance item%s is malformed: %s"
      obligation_id pos_str reason
  in
  let default_actions =
    [
      ( "replace",
        "result: pass    # one of: pass | fail | inconclusive | \
         infrastructure-error" );
      ( "edit",
        Printf.sprintf
          "obligations:\n  - id: %s\n    acceptance:\n      all: []"
          obligation_id );
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  create ~code:"MC-MALFORMED-ACCEPTANCE" ~kind:Input ~severity:Warn
    ~next_actions:actions msg

(* MC-PARSE: emitted when the kernel's hand-rolled JSON/YAML reader
   hits a malformed token. The diagnostic carries the parser's
   line/col context; the snippet points the author at the affected
   file path and at `mathc validate`. *)
let mc_parse ?(path = []) ?(cause = []) ?(next_actions = []) message =
  let code = "MC-PARSE" in
  let default_actions =
    [
      ("edit", "open the file at the line/col printed in `message`");
      ("run", "mathc validate <file>");
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  create ~code ~kind:Input ~severity:Warn ~path ~cause ~next_actions:actions
    ~retryable:false ~autofix_safe:false message

(* MC-DECISION-INVALID: emitted when a parseable file is missing a
   required top-level field. The diagnostic's `path` carries the
   field name; the snippet shows the YAML key the author should
   add. *)
let mc_decision_invalid ?(path = []) ?(next_actions = []) message =
  let code = "MC-DECISION-INVALID" in
  let field = match path with [ f ] -> f | _ -> "<field>" in
  let default_actions =
    [
      ("add", Printf.sprintf "%s: |\n  <one-line description>" field);
      ("run", "mathc validate decisions/<file>.yaml");
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  create ~code ~kind:Input ~severity:Warn ~path ~next_actions:actions
    ~retryable:false ~autofix_safe:false message

(* === Slice A (D8 audit closure): per-field parser-level helpers ===
 *
 * Each helper builds a `Diagnostic.t` for one specific `MC-*` code.
 * The helper's `path` parameter carries the field name (e.g.
 * `~path:["id"]`); `next_actions` defaults to a snippet that names
 * the YAML key the author should add. Severity is `Block` because
 * every one of these rejects the file (the schema requires the
 * field); the CLI's pre-parse checks for axiom_link, counterexample,
 * and antithesis run first and emit their own codes when they fire.
 *
 * The pre-parse check on the seven top-level fields still exists
 * in `bin/Mathc.ml::first_missing_required`; when that check fires,
 * the CLI emits the same `MC-DECISION-INVALID` as today. The new
 * helpers here apply when `first_missing_required` does NOT fire
 * (the field exists in raw form but is not a string/int/etc.) —
 * a case that today falls into the coarse "missing or invalid
 * required field" fallback and that the audit D8 documented. *)

let mc_missing_field ~code ~field ?(next_actions = []) message =
  let default_actions =
    [
      ("add", Printf.sprintf "%s: |\n  <one-line description>" field);
      ("run", "mathc validate decisions/<file>.yaml");
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  create ~code ~kind:Deficit ~severity:Block ~path:[ field ]
    ~policy_rule:(Some "schemas/decision.json") ~next_actions:actions
    ~retryable:false ~autofix_safe:false message

let mc_missing_schema ?(next_actions = []) message =
  mc_missing_field ~code:"MC-MISSING-SCHEMA" ~field:"schema" ~next_actions
    message

let mc_missing_id ?(next_actions = []) message =
  mc_missing_field ~code:"MC-MISSING-ID" ~field:"id" ~next_actions message

let mc_missing_revision ?(next_actions = []) message =
  mc_missing_field ~code:"MC-MISSING-REVISION" ~field:"revision" ~next_actions
    message

let mc_missing_intent ?(next_actions = []) message =
  mc_missing_field ~code:"MC-MISSING-INTENT" ~field:"intent" ~next_actions
    message

let mc_missing_commitment ?(next_actions = []) message =
  mc_missing_field ~code:"MC-MISSING-COMMITMENT" ~field:"commitment"
    ~next_actions message

let mc_missing_scope ?(next_actions = []) message =
  mc_missing_field ~code:"MC-MISSING-SCOPE" ~field:"scope" ~next_actions message

let mc_missing_outcomes ?(next_actions = []) message =
  mc_missing_field ~code:"MC-MISSING-OUTCOMES" ~field:"outcomes" ~next_actions
    message

let mc_missing_obligations ?(next_actions = []) message =
  mc_missing_field ~code:"MC-MISSING-OBLIGATIONS" ~field:"obligations"
    ~next_actions message

let mc_missing_risk_owner ?(next_actions = []) message =
  mc_missing_field ~code:"MC-MISSING-RISK-OWNER" ~field:"risk.owner"
    ~next_actions message

(* Format validation: id and revision have a documented shape (id is
   one of "short-string", "short-string@rev"; revision is a string or
   int). The kernel emits a Block diagnostic with a specific code
   when the value is present but does not match. *)
let mc_invalid_id_format ?(id = "") ?(next_actions = []) message =
  let default_actions =
    [
      ( "edit",
        Printf.sprintf
          "id: |\n\
          \  %s\n\
          \  The id field should be a short lower-snake-case string (e.g. \
           `redis-origin-fallback`), optionally suffixed with `@rev` to pin a \
           specific revision (e.g. `redis-origin-fallback@3`)."
          (if id = "" then "<short-id>" else id) );
      ("run", "mathc validate decisions/<file>.yaml");
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  create ~code:"MC-INVALID-ID-FORMAT" ~kind:Deficit ~severity:Block
    ~path:[ "id" ] ~policy_rule:(Some "schemas/decision.json / decision.id")
    ~next_actions:actions ~retryable:false ~autofix_safe:false message

let mc_invalid_revision_format ?(revision = "") ?(next_actions = []) message =
  let default_actions =
    [
      ( "edit",
        Printf.sprintf
          "revision: |\n\
          \  %s\n\
          \  The revision field is a string (e.g. \"5\") or a sha256-prefixed \
           digest (e.g. \"rev:41aa92\")."
          (if revision = "" then "<revision>" else revision) );
      ("run", "mathc validate decisions/<file>.yaml");
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  create ~code:"MC-INVALID-REVISION-FORMAT" ~kind:Deficit ~severity:Block
    ~path:[ "revision" ]
    ~policy_rule:(Some "schemas/decision.json / decision.revision")
    ~next_actions:actions ~retryable:false ~autofix_safe:false message

(* Axiom link: a value that does not match the axiom-shaped regex
   `^A[0-9]+(\([@.][A-Za-z0-9_.-]*\)?$` is rejected. The diagnostic
   names the offending token. *)
let mc_invalid_axiom_link ?(token = "") ?(next_actions = []) message =
  let default_actions =
    [
      ( "edit",
        Printf.sprintf
          "axiom_link:\n\
          \  - %s\n\
          \  Axiom-shaped tokens start with `A`, have digits, optionally have \
           `@rev` or `.sub` suffix (e.g. `A0`, `A1@2`, `A3.sub`)."
          (if token = "" then "<A0>" else token) );
      ("run", "mathc validate decisions/<file>.yaml");
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  create ~code:"MC-INVALID-AXIOM-LINK" ~kind:Deficit ~severity:Block
    ~path:[ "axiom_link" ]
    ~policy_rule:
      (Some "spec/kernel-contract.md §17 + lib/decision.ml:is_axiom_token")
    ~next_actions:actions ~retryable:false ~autofix_safe:false message

(* MC-COUNTEREXAMPLE-MISSING: emitted when a decision has an
   empty `counterexample` field. The contract depends on the
   decision's `mode`:
     - mode in {tiny, light}: counterexample is OPTIONAL.
       When absent, the diagnostic is a Warn and the verdict
       stays `accept` (counterexample is a dialectical slot,
       not a hard requirement, so legacy decisions without it
       stay valid per spec/kernel-contract.md §11).
     - mode in {standard, strict, exhaustive}: counterexample is
       REQUIRED. When absent, the diagnostic is a Block and
       the verdict is `reject` with exit code 1. The rule was
       introduced by sub-decision
       `decisions/plan-2026-10-improvements/t6-2.yaml` and is
       part of an A3-protected transition (requires human review
       before merge) per `spec/constitution.md` §Self-application.
   The default severity is `Warn` so callers that do not pass
   one get the legacy soft-warning behaviour; the CLI bin/Mathc.ml
   passes `~severity:Block` when the mode is >= standard.

   After the A2 YAML-parser fix (`decisions/fix-yaml-parser-2026-10`,
   commit 3f14b76), the absence predicate reads from the parsed
   `Decision.counterexample` field only — the parser no longer
   silently drops the `counterexample:` key when `risk.declared_triggers`
   is given in the inline-sequence form `key: - foo\n- bar`.
   The diagnostic therefore fires on genuine absence, not on
   parser limitation. The pre-fix false-positive case (a
   decision whose counterexample was present but parser-dropped)
   is closed; see `tests/cli/yaml-parser.t` and
   `tests/cli/counterexample-warn.t` for the regression pins. *)
let mc_counterexample_missing ?(decision_id = "") ?(severity = Warn)
    ?(next_actions = []) message =
  let code = "MC-COUNTEREXAMPLE-MISSING" in
  let default_actions =
    [
      ( "add",
        Printf.sprintf
          "counterexample: |\n\
          \  %s\n\
          \  A known failing case that would falsify this commitment.\n\
          \  Resolution: name the strongest objection to the decision."
          (if decision_id = "" then "<decision-id>" else decision_id) );
      ("edit", "spec/kernel-contract.md §11 (dialectical slots)");
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  let policy_rule =
    match severity with
    | Block ->
        Some
          "spec/kernel-contract.md §11 + \
           decisions/plan-2026-10-improvements/t6-2.yaml"
    | Warn | Info -> None
  in
  create ~code ~kind:Deficit ~severity ~policy_rule ~next_actions:actions
    ~retryable:false ~autofix_safe:false message

(* MC-ANTITHESIS-MISSING: emitted by `mathc validate` (via
   `lib/decision.ml::parse_decision`) when a decision with
   `mode >= standard` carries no antithesis. Mirrors
   `mc_counterexample_missing` for the antithesis slot. The contract
   is set by spec/kernel-contract.md §11 (v3 dialectic method) and
   introduced by `decisions/dialectic-method-v3-2026-10.yaml`.
   Distinct from counterexample: antithesis is the coherent
   counter-position the author considered; counterexample is the
   strongest objection the kernel surfaces to a future reader.
   Author remediation: add `antithesis: | <one paragraph>` to the
   decision front-matter. *)
let mc_antithesis_missing ?(decision_id = "") ?(severity = Warn)
    ?(next_actions = []) message =
  let code = "MC-ANTITHESIS-MISSING" in
  let default_actions =
    [
      ( "add",
        Printf.sprintf
          "antithesis: |\n\
          \  %s\n\
          \  A coherent counter-position the author considered and\n\
          \  rejected. Distinct from counterexample: antithesis is the\n\
          \  position the author engaged with; counterexample is the\n\
          \  strongest objection the kernel surfaces to a future reader\n\
          \  regardless of what the author considered."
          (if decision_id = "" then "<decision-id>" else decision_id) );
      ("edit", "spec/kernel-contract.md §11 (dialectic slots)");
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  let policy_rule =
    match severity with
    | Block ->
        Some
          "spec/kernel-contract.md §11 + \
           decisions/dialectic-method-v3-2026-10.yaml"
    | Warn | Info -> None
  in
  create ~code ~kind:Deficit ~severity ~policy_rule ~next_actions:actions
    ~retryable:false ~autofix_safe:false message

(* Aliases — the stream η (T4.1) compact contract refers to the
   `mc_` prefix; the existing call sites in bin/Mathc.ml use the
   unprefixed names. Both names refer to the same function so that
   old and new code can coexist; new code should prefer the `mc_`
   form per the convention codified in
   decisions/plan-2026-10-improvements/t4-1.yaml. *)
let mc_ambiguous_acceptance = ambiguous_acceptance
let mc_malformed_acceptance = malformed_acceptance

(* MC-ACCEPTANCE-DECLARED-RESULT: emitted by `mathc validate` when an
   acceptance item carries a `result:` key.

   An acceptance item NAMES a check. The outcome of that check is
   measured by running it, and it is recorded in the attestation store
   -- never in the promise's own file. The corpus carried 863 such
   keys, every one of them `pass`, and nothing read them: the kernel
   parsed them and no verdict ever consulted them. So they were
   decoration that reads like evidence -- a reader opening a decision
   saw "pass" next to a promise and could not tell that no check had
   run.

   The constitution's separation is `declared != derived != attested !=
   reviewed != observed`. A `result:` in the corpus is a DECLARED
   outcome standing where an ATTESTED one belongs, and the block
   exists to stop it from coming back. *)
let declared_result_acceptance ?(obligation_id = "") ?(item_position = -1)
    ?(next_actions = []) () =
  let pos_str =
    if item_position >= 0 then Printf.sprintf " (all[%d])" item_position else ""
  in
  let msg =
    Printf.sprintf
      "obligation %s: acceptance item%s declares a `result:`. The outcome of a \
       check is measured, not declared: remove the key, and let the check \
       write its verdict into the attestation store."
      obligation_id pos_str
  in
  let default_actions =
    [
      ("edit", "remove the `result:` line: an acceptance item names the check");
      ( "run",
        "bash scripts/sign-store.sh   # measure the outcome, do not declare it"
      );
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  create ~code:"MC-ACCEPTANCE-DECLARED-RESULT" ~kind:Input ~severity:Block
    ~path:
      [ Printf.sprintf "obligations.%s.acceptance.all.result" obligation_id ]
    ~policy_rule:(Some "spec/constitution.md#epistemic-separation")
    ~next_actions:actions msg

let mc_declared_result_acceptance = declared_result_acceptance

(* MC-AXIOM-LINK-MISSING: emitted by `mathc validate` (via
   `lib/decision.ml::parse_decision`) when a decision carries
   `state: active` with an empty `axiom_link` list. The
   contract is set by spec/kernel-contract.md §7 ("A decision must
   name the axiom(s) it addresses via `axiom_link`") and
   enforced by the parser-level check (lib/decision.ml:794).
   Draft, Retired, and Superseded decisions are exempt; only
   active decisions carry the contract. Author remediation:
   add `axiom_link: [A0]` (or a more specific axiom list) to
   the decision front-matter. This block-level emit is called
   from `bin/Mathc.ml::validate_with_counts` (T2.2 stream). *)
let axiom_link_missing ?(decision_id = "") () =
  let prefix =
    if decision_id = "" then "" else Printf.sprintf "%s: " decision_id
  in
  let msg =
    Printf.sprintf
      "%sdecision has state=active but empty axiom_link: \
       spec/kernel-contract.md §7 requires every active decision to name the \
       axiom(s) it addresses via the axiom_link field; add one (e.g. \
       axiom_link: [A0]) to the decision front-matter"
      prefix
  in
  create ~code:"MC-AXIOM-LINK-MISSING" ~kind:Deficit ~severity:Block
    ~policy_rule:(Some "spec/kernel-contract.md §7")
    ~next_actions:
      [
        ("add", "axiom_link: [A0]");
        ("verify", "mathc validate <path-to-decision>");
      ]
    msg

(* MC-SHA-MISMATCH: emitted when a Decision carries both
   `body_sha` and `yaml_sha` and the two values disagree. Per
   spec/kernel-contract.md §7 ("if D.body_sha ≠ ∅ ∧ D.yaml_sha ≠ ∅
   then D.body_sha = D.yaml_sha") and the schema contract in
   schemas/decision.json (both fields share the pattern
   `^sha256:[0-9a-f]{64}$`). The check is parser-side:
   `lib/decision.ml::sha_match_check` returns a `(bool, Diagnostic.t list)`
   accumulator; when both hashes are present and not string-equal,
   `mc_sha_mismatch` emits a Block diagnostic. Either field absent
   makes the invariant vacuously true (no mismatch is possible) and
   no diagnostic is emitted. Author remediation: run
   `mathc rehash <path>` to recompute BOTH fields from the
   placeholder-substitution algorithm (kernel contract §7.1; kernel
   implementation `lib/decision.ml::body_canonical_sha256`, reference
   implementation `scripts/axiom-link-seed.py:133-169`). This
   block-level emit is called from
   `bin/Mathc.ml::validate_with_counts` (T0.2 stream ε). *)
let mc_sha_mismatch ?(decision_id = "") ?(body_sha = "") ?(yaml_sha = "")
    ?(next_actions = []) () =
  let prefix =
    if decision_id = "" then "" else Printf.sprintf "%s: " decision_id
  in
  let body = if body_sha = "" then "<absent>" else body_sha in
  let yaml = if yaml_sha = "" then "<absent>" else yaml_sha in
  let msg =
    Printf.sprintf
      "%sbody_sha (%s) and yaml_sha (%s) disagree: spec/kernel-contract.md §7 \
       requires both hashes to be equal when both are present. Recompute via \
       the placeholder-substitution algorithm (sha256 of the decision with \
       both fields replaced by 'sha256:' + 64 zeros); see \
       scripts/axiom-link-seed.py:133-169 for the reference implementation."
      prefix body yaml
  in
  let default_actions =
    [
      ( "replace",
        "body_sha and yaml_sha with the recomputed digest (both fields must \
         carry the SAME value when both are present)" );
      ("run", "mathc rehash <path-to-decision>");
      ("verify", "mathc validate <path-to-decision>");
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  create ~code:"MC-SHA-MISMATCH" ~kind:Deficit ~severity:Block
    ~policy_rule:(Some "spec/kernel-contract.md §7") ~next_actions:actions msg

(* MC-SHA-DIGEST-STALE: emitted when `body_sha` and `yaml_sha` agree
   with each other but the shared value is not the digest of the file
   they live in. This is the check that the "tamper-evident trail"
   claim in adoption/SKILL.md:33 rests on: without it, any edit to a
   decision body leaves the stored digest untouched and every
   downstream verdict still reads `pass`.

   Deliberately a separate code rather than a reuse of
   MC-SHA-MISMATCH: the two failures have different remediations
   (this one is a stale value, not two disagreeing fields) and
   conflating them would have hidden the 64-zero placeholder case,
   which is "equal but wrong". *)
let mc_sha_digest_stale ?(decision_id = "") ?(stored = "") ?(computed = "")
    ?(next_actions = []) () =
  let prefix =
    if decision_id = "" then "" else Printf.sprintf "%s: " decision_id
  in
  let msg =
    Printf.sprintf
      "%sstored digest (%s) is not the digest of this file (%s): \
       spec/kernel-contract.md §7.1 defines body_sha as sha256 of the file \
       with both digest fields replaced by 'sha256:' + 64 zeros, so an edit to \
       the body that was not accompanied by a recompute leaves the stored \
       value stale. The body of this decision changed under a digest that \
       still claims the old content."
      prefix stored computed
  in
  let default_actions =
    [
      ("run", "mathc rehash <path-to-decision>  # recompute both fields");
      ("verify", "mathc validate <path-to-decision>");
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  create ~code:"MC-SHA-DIGEST-STALE" ~kind:Deficit ~severity:Block
    ~policy_rule:(Some "spec/kernel-contract.md §7.1") ~next_actions:actions msg

(* MC-BODY-SHA-PATTERN-VIOLATION: body_sha or yaml_sha is present but
   does not match the documented pattern `^sha256:[0-9a-f]{64}$`.
   The schema declares the pattern (schemas/decision.json:103-110 for
   body_sha, :113-120 for yaml_sha) and the gate evaluator
   (`lib/decision.ml::sha_match_check`) enforces equality between the
   two; before this commit, the kernel did not enforce the pattern,
   so a value like `"sha256:' + sha + '"` (literal shell-template
   artifact) or a too-short digest would silently pass equality
   checks against itself and reach the gate. Author remediation:
   replace the offending value with the canonical SHA-256 of the
   decision body (with both body_sha and yaml_sha replaced by
   `sha256:` + 64 zeros), computed by the same algorithm as
   `scripts/axiom-link-seed.py`. The migration script
   `scripts/fix-non-pattern-sha.sh` (referenced from
   `decisions/kernel-bugs-v3.4-2026-10.yaml`) automates the
   one-line per-affected-repo remediation. *)
let mc_body_sha_pattern_violation ?(decision_id = "") ~field ~value
    ?(next_actions = []) () =
  let prefix =
    if decision_id = "" then "" else Printf.sprintf "%s: " decision_id
  in
  let msg =
    Printf.sprintf
      "%s%s value `%s` does not match the documented pattern \
       `^sha256:[0-9a-f]{64}$` (71 characters total). schemas/decision.json \
       declares this pattern as required for body_sha and yaml_sha; the kernel \
       now enforces it (decisions/kernel-bugs-v3.4-2026-10). Recompute the \
       digest with the canonical algorithm and replace the value."
      prefix field value
  in
  let default_actions =
    [
      ( "replace",
        Printf.sprintf
          "%s with the canonical sha256: <64 hex chars> digest of the decision \
           body (both body_sha and yaml_sha, computed with the \
           placeholder-substitution algorithm in scripts/axiom-link-seed.py)"
          field );
      ( "run",
        "scripts/fix-non-pattern-sha.sh  # automated migration; idempotent" );
      ("verify", "mathc validate <path-to-decision>");
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  create ~code:"MC-BODY-SHA-PATTERN-VIOLATION" ~kind:Deficit ~severity:Block
    ~policy_rule:(Some "schemas/decision.json#body_sha/yaml_sha")
    ~next_actions:actions msg

(* MC-VERIFIER-SCHEME-UNKNOWN: emitted by `mathc validate`
   when an `obligations[*].acceptance.all[*].verifier` string
   begins with a scheme token that is NOT in the canonical
   allowlist documented in
   `decisions/verifier-scheme-convention-2026-11.yaml`.

   THE LIST IS NOT WRITTEN IN THIS FILE. The allowlist is ONE
   binding — `canonical_verifier_schemes` and
   `canonical_verifier_prefixes` in bin/Mathc.ml — and this
   diagnostic RENDERS what the kernel passes in
   (`render_canonical_schemes` below). It used to keep its own
   copy, and the copy was wrong: it named six exact schemes and
   omitted the seventh, `shell-grep-absent`, which the kernel
   learned on 2026-10-29. So the diagnostic told an author that
   a scheme the kernel accepts was not canonical, and an author
   who believed it wrapped the scheme in single quotes to get
   past the warning — which is how `verifier: 'shell-grep-absent
   ...'` reached the corpus with the quote still inside the
   token. The repair is the removal of the copy, not the
   addition of the seventh name to it.

   The split is: scheme = first whitespace-delimited token of
   the verifier string (per `parse_verifier_string` in
   `bin/Mathc.ml`). The check is parser-side — it walks every
   obligation's acceptance list and emits one Warn diagnostic
   per non-canonical scheme.

   Severity is Warn (not Block): the kernel still produces a
   well-typed Domain.acceptance for the item, the decision
   parses-ok, and the verdict is `parse-ok`. The diagnostic
   flags the operator that the scheme is non-canonical so the
   convention is discoverable.

   Author remediation: replace the scheme token with one of
   the canonical tokens the kernel names, or with a scheme
   under one of the canonical prefixes the kernel names — the
   message names them, and it names the ones the kernel holds.
   For an unknown scheme that is in active use (e.g., a hex-tag
   identifier like `verifier: mathc-validate-runs-on-fixture`),
   the convention is to migrate to `mathc` + a subcommand arg,
   OR open a follow-up decision that extends the allowlist.

   The `obligation_id` and `scheme` parameters are
   interpolated into the message and the path; the diagnostic
   is registered in `lib/diagnostic.ml::explain`. *)
(* MC-VERIFIER-PATH-UNRESOLVED: a verifier's evidence path does not
   resolve inside the project tree that contains the decision.
   *
   * An ABSOLUTE path is wrong in every case - it is pinned to one
   * machine's directory layout, so it resolves on the author's
   * workstation and nowhere else - and is therefore a Block. A
   * relative path that does not resolve is not necessarily an error:
   * it may name a build artifact, a generated file, or a case
   * selector, so it is a Warn that makes the gap visible.
   *
   * The schema forbids a sibling `path:` key on an acceptance item
   * (schemas/common.json: additionalProperties false, properties
   * verifier/result/review), but nothing enforced it: the parser
   * dropped the key silently. This turns the silent drop into a
   * verdict. *)
let mc_verifier_path_unresolved ?(obligation_id = "") ?(path = "")
    ?(reason = "does not resolve") ?(next_actions = []) () =
  let code = "MC-VERIFIER-PATH-UNRESOLVED" in
  let what =
    Printf.sprintf "obligation %s: verifier path %s %s" obligation_id path
      reason
  in
  let default_actions =
    [
      ("edit", "make the path project-relative, or drop the key");
      ("run", "mathc validate decisions/<file>.yaml");
      ("run", "mathc explain-diagnostic " ^ code);
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  create ~code ~kind:Input ~severity:Warn
    ~path:[ Printf.sprintf "obligations.%s.acceptance.path" obligation_id ]
    ~policy_rule:(Some "decisions/verifier-path-resolution-2026-10.yaml")
    ~next_actions:actions what

(* THE CANONICAL LIST, RENDERED FROM WHAT THE KERNEL OWNS.
 *
 * The kernel's two bindings are the only answer to "which schemes
 * can the kernel execute". This function prints them; it does not
 * know them. A prefix is printed with a `*` because that is how it
 * matches: a prefix scheme may carry any suffix. The `mark`
 * argument wraps each entry (the `explain` body wants backticks,
 * the one-line message does not) so that the two say the same
 * thing in the same notation. *)
let render_canonical_schemes ~mark ~exact ~prefixes =
  let m s = mark ^ s ^ mark in
  String.concat ", "
    (List.map m exact @ List.map (fun p -> m (p ^ "*")) prefixes)

let mc_verifier_scheme_unknown ?(obligation_id = "") ?(scheme = "")
    ?(verifier = "") ?(exact_schemes = []) ?(prefix_schemes = [])
    ?(next_actions = []) () =
  let code = "MC-VERIFIER-SCHEME-UNKNOWN" in
  let prefix =
    if obligation_id = "" then ""
    else Printf.sprintf "obligation %s: " obligation_id
  in
  (* The list is the kernel's, or it is not printed at all: a
     diagnostic that cannot be told what the kernel accepts says
     so instead of answering from memory. *)
  let listed =
    if exact_schemes = [] && prefix_schemes = [] then
      "(the kernel's canonical list: bin/Mathc.ml::canonical_verifier_schemes \
       and ::canonical_verifier_prefixes)"
    else
      "("
      ^ render_canonical_schemes ~mark:"" ~exact:exact_schemes
          ~prefixes:prefix_schemes
      ^ ")"
  in
  let msg =
    Printf.sprintf
      "%sverifier scheme %S is not in the canonical list %s; convention \
       documented in decisions/verifier-scheme-convention-2026-11.yaml"
      prefix scheme listed
  in
  let _ = verifier in
  let default_actions =
    [
      ( "replace",
        Printf.sprintf "verifier: \"%s <args>\"    # use a canonical scheme"
          scheme );
      ("run", "mathc validate decisions/<file>.yaml");
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  create ~code ~kind:Input ~severity:Warn
    ~path:
      [ Printf.sprintf "obligations.%s.acceptance.all.verifier" obligation_id ]
    ~policy_rule:(Some "decisions/verifier-scheme-convention-2026-11.yaml")
    ~next_actions:actions ~retryable:false ~autofix_safe:false msg

(* MC-MATERIALS-DIGEST-EMPTY: emitted when an attestation with
   kind_ ∈ {test, build, observation} carries an empty
   `subject.materials_digest`. Per A0 (separation), runtime-
   produced attestations MUST name the materials they were produced
   against; a human review (`kind_: review`) is exempt because
   humans can declare without a runtime anchor. The historical
   schema allowed empty materials_digest for any kind_, which
   silently review-laundered runtime-evidence claims (REPORT.md
   §3.6). This Block diagnostic closes the loophole.

   The grandfathering note for legacy build/test attestations issued
   before 2026-10-16 lives in `lib/attestations/attestations.ml::load`;
   the kernel-side validator (`lib/codec.ml::parse_attestation`)
   does not grandfather -- it rejects. Author remediation: produce
   a fresh attestation whose `materials_digest` carries the SHA-256
   of the run's input artefact (test output, build artefact, observed
   metric). The existing `attestations/*.json` files in the math-
   coding repo carry `kind_: build` from the `ci-bot` producer;
   per `decisions/kernel-bugs-v3.4-2026-10` reversal section,
   those are grandfathered by the loader, not the validator. *)
let mc_materials_digest_empty ?(subject = "") ?(kind = "") ?(next_actions = [])
    () =
  let prefix =
    match (subject, kind) with
    | "", "" -> ""
    | s, "" -> Printf.sprintf "%s: " s
    | "", k -> Printf.sprintf "<%s>: " k
    | s, k -> Printf.sprintf "%s (kind_=%s): " s k
  in
  let msg =
    Printf.sprintf
      "%ssubject.materials_digest is empty for a runtime-kind attestation. Per \
       A0 (epistemic separation, spec/constitution.md §0), \
       test/build/observation attestations MUST name the materials they were \
       produced against; only `kind_: review` may carry an empty digest (a \
       human declaration without a runtime anchor). Add a SHA-256 of the run's \
       input artefact to subject.materials_digest."
      prefix
  in
  let default_actions =
    [
      ( "compute",
        "sha256 of the run's input artefact (test output, build artefact, \
         observed metric); set subject.materials_digest to the hex digest" );
      ("set", "subject.materials_digest: \"sha256:<64 hex chars>\"");
      ("regenerate", "mathc attest ... --subject.materials_digest=<digest>");
      ("verify", "mathc validate <path-to-attestation>");
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  create ~code:"MC-MATERIALS-DIGEST-EMPTY" ~kind:Deficit ~severity:Block
    ~policy_rule:(Some "spec/constitution.md §0; A0 separation")
    ~next_actions:actions msg

(* MC-PRODUCER-CLASS-UNDECLARED: emitted when `producer.identity`
   carries no claim class. Per decisions/attestation-producer-vocab-
   2026-10, an identity is `<class>:<subject>` with class in
   {human, agent, ci}. An untagged identity says nothing about WHO
   produced the attestation, so a reader cannot tell a human
   declaration from a machine observation without out-of-band
   knowledge of the producer's habits. The corpus measured 62 such
   files (`ci-bot` 40, `dune:test` 6, `ci-bot:dune-runtest` 7,
   `ci-bot:re-evaluate-decisions` 4, `sub-agent-A4-batchA` 3,
   `test` 2) at the time of the decision; they remain readable
   through the store loader, which does not validate.

   Note what this diagnostic does NOT claim: it does not assert that
   a tagged `human:` identity is TRUE. Nothing in this repository can
   establish that -- no attestation in the store carries a signature
   (0 of 765), so there is no key class to compare against. The tag
   is a declaration, and the schema only requires that a claim be
   made in the open. See mc_producer_human_unanchored below for the
   rule that does carry weight. *)
let mc_producer_class_undeclared ?(subject = "") ?(next_actions = []) ~identity
    () =
  let prefix = if subject = "" then "" else Printf.sprintf "%s: " subject in
  let msg =
    Printf.sprintf
      "%sproducer.identity %S declares no claim class. Per \
       decisions/attestation-producer-vocab-2026-10, an identity is \
       `<class>:<subject>` with class in {human, agent, ci}, so a reader can \
       tell a human DECLARATION from a machine OBSERVATION without out-of-band \
       knowledge. `ci:` fits an automated job, `agent:` a model-driven agent, \
       `human:` a person."
      prefix identity
  in
  let default_actions =
    [
      ( "identify",
        "which of human / agent / ci actually produced this attestation" );
      ("set", "producer.identity: \"ci:<job>\" (machine) or \"agent:<id>\"");
      ("regenerate", "mathc attest ... --producer=<class>:<subject>");
      ("verify", "mathc validate <path-to-attestation>");
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  create ~code:"MC-PRODUCER-CLASS-UNDECLARED" ~kind:Deficit ~severity:Block
    ~policy_rule:(Some "decisions/attestation-producer-vocab-2026-10")
    ~next_actions:actions msg

(* MC-PRODUCER-HUMAN-UNANCHORED: emitted when an attestation whose
   `producer.identity` declares the `human:` class carries a RUNTIME
   kind (test / build / analysis / observation) and names no
   `producer.run`.

   This is the rule that carries the epistemic weight, and the reason
   is a dialectical one. A `human:` producer on `kind_: review` is
   claiming the WEAK class -- "a human declaration without a runtime
   anchor", the same exemption MC-MATERIALS-DIGEST-EMPTY grants. An
   agent that falsely claims it gains nothing, because review-class
   evidence is already the weaker kind. So the human tag on a review
   is left unconstrained: there is no attack to defend against.

   A `human:` producer on a RUNTIME kind is the opposite: it takes a
   machine-grade claim (a test passed, a build succeeded) and attaches
   a person's name to it. That is the upgrade the whole attestation
   store exists to prevent -- commit 9c1f7ab records the same failure
   at scale, when attest-batch mass-signed 793 files as
   human:integration-experiment without asking. Requiring
   `producer.run` makes the claim falsifiable rather than
   unauditable: the claim now names a command, `mathc verify`
   executes that command, and a producer whose named run does not
   reproduce the recorded materials_digest is caught by a named,
   failing verifier instead of by an inspection nobody performs.

   What it does NOT do is verify that a person typed the string. A
   `human:` tag remains a declaration. Closing that would need key
   separation (a signature whose key_id is bound to a human key), and
   0 of the 765 stored attestations carry a signature today -- so
   this rule is the strongest one the substrate can currently carry,
   not the strongest one that would be desirable. *)
let mc_producer_human_unanchored ?(subject = "") ?(next_actions = []) ~identity
    ~kind () =
  let prefix =
    match (subject, kind) with
    | "", "" -> ""
    | s, "" -> Printf.sprintf "%s: " s
    | "", k -> Printf.sprintf "<%s>: " k
    | s, k -> Printf.sprintf "%s (kind_=%s): " s k
  in
  let msg =
    Printf.sprintf
      "%sproducer.identity %S declares the human class on a runtime-kind \
       attestation but names no producer.run. Per \
       decisions/attestation-producer-vocab-2026-10, a human producer may \
       declare a `kind_: review` without a runtime anchor -- that is the WEAK \
       class, so a false claim there gains nothing -- but a \
       test/build/analysis/observation claim is machine-grade evidence and \
       must name the run that produced it, so that anyone can re-run it and \
       check the recorded materials_digest."
      prefix identity
  in
  let default_actions =
    [
      ("run", "the command that actually produced this result");
      ( "set",
        "producer.run: \"<command>\" (the `--run` argument of mathc attest)" );
      ("regenerate", "mathc attest ... --producer=<id> --run=<command>");
      ("verify", "mathc verify <decision> --format=json");
      ( "or",
        "reissue as `--kind review` if this is a human judgement with no \
         runtime anchor" );
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  create ~code:"MC-PRODUCER-HUMAN-UNANCHORED" ~kind:Deficit ~severity:Block
    ~policy_rule:(Some "decisions/attestation-producer-vocab-2026-10")
    ~next_actions:actions msg

(* MC-DUPLICATE-KEY: emitted when the same mapping key is declared
   twice in one scope of a decision file.

   Semantics: a duplicated key is an AUTHOR ERROR, not a merge
   request and not a "last one wins" rule. The justification is
   threefold.

   (1) Spec. YAML 1.2 §3.2.1 requires the keys of a mapping to be
       unique; a mapping that declares `obligations:` twice is not
       a valid YAML mapping. Choosing "concatenate" or "last
       wins" would invent a project dialect the spec does not
       sanction, and would silently change what the file means.

   (2) Honesty. The kernel's readers (`lib/schema.ml::take_*`)
       resolve via `List.assoc_opt`, i.e. FIRST occurrence wins.
       So the second block is not overridden — it is UNREACHABLE.
       The content is parsed into the tree and no reader can ever
       see it. When that key is `obligations`, the promises the
       author wrote sit outside the gate: `mathc self-check`
       reports on obligations that were never checked. A verdict
       that is silent about what it did not read is the failure
       mode spec/constitution.md calls out.

   (3) Precedent. MC-AMBIGUOUS-ACCEPTANCE and
       MC-MALFORMED-ACCEPTANCE are the same shape — the kernel
       keeps a well-typed reading, drops the rest, and says so at
       Warn. This code joins that family.

   Severity is Warn, not Block, deliberately: the kernel still
   produces a valid `Domain.decision` from the surviving block, so
   refusing to type the file would be a larger behavioural change
   than the defect warrants. Once the corpus carries no duplicate
   keys the diagnostic is silent; promoting it to Block is a
   severity flip that needs its own decision, not a side effect
   of this one. *)
let mc_duplicate_key ~key ?(path = []) ?(occurrences = 2) ?(lines = [])
    ?(next_actions = []) () =
  let code = "MC-DUPLICATE-KEY" in
  (* `obligations` and `obligations[1].acceptance.all[2].result` read
     as a locator; a bare key reads as `"obligations"` because it is
     quoted as an identifier, not a path. *)
  let plain_seg seg =
    let n = String.length seg in
    (* `[3]` is an array index, not a key: keep it bare so the path
       reads `obligations[0].acceptance.all[2].result`. *)
    if n >= 3 && seg.[0] = '[' && seg.[n - 1] = ']' then seg
    else
      let alpha i =
        let c = seg.[i] in
        (c >= 'a' && c <= 'z')
        || (c >= 'A' && c <= 'Z')
        || c = '_' || c = '-'
        || (c >= '0' && c <= '9')
      in
      if n > 0 && alpha 0 then
        let rec all i = if i >= n then true else alpha i && all (i + 1) in
        if all 1 then seg else Printf.sprintf "%S" seg
      else Printf.sprintf "%S" seg
  in
  let where =
    match path with
    | [] -> Printf.sprintf "%S" key
    | _ -> String.concat "." (List.map plain_seg path)
  in
  let lines_str =
    match lines with
    | [] -> ""
    | ls ->
        Printf.sprintf " (lines %s)"
          (String.concat ", " (List.map string_of_int ls))
  in
  let unreachable = occurrences - 1 in
  let msg =
    Printf.sprintf
      "mapping key %s is declared %d times in the same scope%s; the kernel \
       reads the FIRST occurrence and the other %d %s unreachable — that \
       content never reaches the gate. A repeated key is not appended and not \
       overridden; merge the %d declarations into one."
      where occurrences lines_str unreachable
      (if unreachable = 1 then "block is" else "blocks are")
      occurrences
  in
  let default_actions =
    [
      ( "edit",
        Printf.sprintf "merge the %d `%s:` blocks into a single declaration"
          occurrences key );
      ("run", "mathc validate decisions/<file>.yaml");
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  create ~code ~kind:Conflict ~severity:Warn ~path
    ~policy_rule:(Some "spec/constitution.md §0; YAML 1.2 §3.2.1 unique keys")
    ~retryable:false ~autofix_safe:false ~next_actions:actions msg

(* MC-UNPARSED-TAIL: emitted when the parser stops reading a
   document before the end and the CLI would otherwise discard the
   remainder in silence.

   `Codec.load_yaml_string` is `let pairs, _ = parse_yaml_pairs
   tokens 0` — the unconsumed remainder is thrown away. That
   remainder is every line from where the parser gave up to EOF.
   `mathc validate` still reports `parse-ok`, so a decision can be
   missing its whole `obligations:`, `risk:`, `relations:` and
   `reversal:` tail while the gate reports it as fully checked.

   This is the more dangerous half of the silent-drop family, and
   it is a DIFFERENT mechanism from MC-DUPLICATE-KEY: the content
   is not even in the tree, so a duplicate-key walk cannot see it.
   The corpus reached it through `fold_continuation`, whose "a
   deeper line with a colon is a nested key" heuristic misfires on
   prose ("Mitigation: rename the ..."), after which
   `parse_yaml_pairs` sees a token deeper than the mapping it is
   closing and returns early.

   Severity is Warn for the same reason as MC-DUPLICATE-KEY: the
   parsed prefix is usually a well-typed decision, and refusing to
   type it would be a bigger behavioural change than the defect
   warrants. Unlike a duplicate key, though, this one changes what
   the kernel knows about the file, so the message names the first
   unread line and says how much was lost. *)
let mc_unparsed_tail ?(path = []) ?(line = 0) ?(content = "") ?(lost = 0)
    ?(document_marker = false) ?(next_actions = []) () =
  let code = "MC-UNPARSED-TAIL" in
  let preview =
    let t = String.trim content in
    if t = "" then ""
    else Printf.sprintf " (%S)" (String.sub t 0 (min 60 (String.length t)))
  in
  let lost_str =
    if lost <= 0 then "" else Printf.sprintf " and %d more line(s)" (lost - 1)
  in
  let msg =
    if document_marker then
      Printf.sprintf
        "the file carries a SECOND `---` document marker at line %d. The \
         loader reads the first `---` as front-matter and stops at the next \
         one, so everything after line %d — the rest of this document and any \
         second document — is unread and never reaches the gate. This file is \
         one decision: delete the stray marker, or move the prose that needed \
         it into a `|` block scalar."
        line line
    else
      Printf.sprintf
        "the parser stopped at line %d%s and could not read the rest of the \
         file%s; every top-level key from there to EOF is missing from the \
         kernel's reading, so whatever that tail promised is outside the gate. \
         The usual cause is a multi-line scalar the loader cannot follow: a \
         folded plain scalar whose continuation carries a colon (\"Mitigation: \
         ...\"), a quoted sequence item continued on deeper lines, or a \
         sequence item indented less than its siblings. Put such prose in a \
         `|` block scalar, or align the indentation — the wording does not \
         have to change."
        line preview lost_str
  in
  let default_actions =
    [
      ( "edit",
        "rewrite the multi-line value as a `|` block scalar (or align the \
         sequence indentation) so the loader can read it to EOF" );
      ("run", "mathc validate decisions/<file>.yaml");
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  create ~code ~kind:Input ~severity:Warn ~path
    ~policy_rule:(Some "spec/constitution.md §0 (honest status)")
    ~retryable:false ~autofix_safe:false ~next_actions:actions msg

let severity_of_string = function
  | "info" -> Some Info
  | "warn" -> Some Warn
  | "block" -> Some Block
  | _ -> None

let string_of_severity = function
  | Info -> "info"
  | Warn -> "warn"
  | Block -> "block"

let kind_of_string = function
  | "input" -> Some Input
  | "question" -> Some Question
  | "deficit" -> Some Deficit
  | "infrastructure" -> Some Infrastructure
  | "conflict" -> Some Conflict
  | "authorization" -> Some Authorization
  | _ -> None

let string_of_kind = function
  | Input -> "input"
  | Question -> "question"
  | Deficit -> "deficit"
  | Infrastructure -> "infrastructure"
  | Conflict -> "conflict"
  | Authorization -> "authorization"

let code s = s

(* MC-* code registry used by `mathc explain-diagnostic <CODE>`.
   Each entry is a markdown body with three sections, delimited
   by `### Definition` / `### Occurs when` / `### Remediation`
   (the binary CLI parses the body into those three fields and
   emits them as JSON keys). The whitelist mirrors the codes
   emitted by `bin/Mathc.ml:validate_with_counts` and the
   conformance runner in `lib/decision.ml`. Adding a new code
   to the kernel without registering it here leaves the CLI
   unable to describe a code it itself emits; the registry
   and the emitter MUST be updated together (see
   decisions/plan-2026-10-improvements/t4-2.yaml reversal
   clause `registry-async-with-codes`). *)

(* MC-NEGATIVE-CONTROL-MISSING: emitted by `mathc validate` when a
   decision declares at least one EXECUTABLE verifier but names no
   `negative_control`.
 *
 * A check that cannot fail is not a check. The corpus had 232
 * decisions and not one of them declared how its verifier could be
 * seen to fail - so every one of them looked equally trustworthy,
 * and the difference between a fixture with teeth and a fixture that
 * passes whatever happens was invisible.
 *
 * The field names the fixture that demonstrates the failure: a
 * negative control, not a claim about the product. It is a Warn
 * rather than a Block while the corpus carries the debt; the count
 * is pinned by tests/fixtures/negative-control-debt.sh and may only
 * fall. *)
let mc_negative_control_missing ?(decision_id = "") ?(next_actions = []) () =
  let code = "MC-NEGATIVE-CONTROL-MISSING" in
  let prefix =
    if decision_id = "" then "" else Printf.sprintf "decision %s: " decision_id
  in
  let msg =
    Printf.sprintf
      "%sdeclares an executable verifier but names no `negative_control`. A \
       check that cannot fail is not a check: the negative control is the \
       fixture that demonstrates the verifier FAILS when the property it \
       guards is broken. Without it, a fixture with teeth and a fixture that \
       passes whatever happens are indistinguishable - both report green."
      prefix
  in
  let default_actions =
    [
      ( "add",
        "negative_control: tests/fixtures/<name>.sh   # the fixture that fails \
         when the property is broken" );
      ("run", "mathc validate decisions/<file>.yaml");
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  create ~code ~kind:Input ~severity:Warn ~path:[ "negative_control" ]
    ~policy_rule:(Some "decisions/negative-control-required-2026-10.yaml")
    ~next_actions:actions msg

let explain ?(exact_schemes = []) ?(prefix_schemes = []) (code : string) :
    string option =
  match code with
  | "MC-NEGATIVE-CONTROL-MISSING" ->
      Some
        "### Definition\n\
         A decision declares at least one EXECUTABLE verifier and names\n\
         no `negative_control`.\n\n\
         ### Occurs when\n\
         `mathc validate` walks the decision's obligations, finds a\n\
         verifier the kernel can execute (file-exists, dir-exists,\n\
         mathc, dune, tests/, scripts/), and finds no `negative_control`\n\
         field on the decision.\n\n\
         ### Remediation\n\
         Add `negative_control: <path to a fixture>` naming the fixture\n\
         that demonstrates the verifier FAILS when the property it\n\
         guards is broken. A check that cannot fail is not a check.\n"
  | "MC-VERIFIER-PATH-UNRESOLVED" ->
      Some
        "### Definition\n\
         A verifier's evidence path does not resolve inside the project\n\
         tree that contains the decision.\n\n\
         ### Occurs when\n\
         `mathc validate` walks the decision's acceptance items and finds\n\
         a `path:` key that is absolute, or that names a file which does\n\
         not exist under the project root. The schema forbids the key\n\
         outright (schemas/common.json), but the parser used to drop it\n\
         silently - so the obligation's recorded result was unbacked and\n\
         nothing said so.\n\n\
         ### Remediation\n\
         Make the path project-relative and resolvable, or drop the key\n\
         when the obligation has no in-tree subject.\n"
  | "MC-VERIFIER-SCHEME-UNKNOWN" ->
      (* The two lists are the kernel's; this body RENDERS them. A
         body that carried its own copy of the list was a second
         answer to "what can the kernel execute", and it was wrong
         for a month: it omitted `shell-grep-absent`, which the
         kernel learned on 2026-10-29. When the caller does not
         pass the bindings, the body names where they live instead
         of guessing what they are. *)
      let exact_text =
        match exact_schemes with
        | [] ->
            "the kernel's binding `canonical_verifier_schemes` (bin/Mathc.ml)"
        | xs -> render_canonical_schemes ~mark:"`" ~exact:xs ~prefixes:[]
      in
      let prefix_text =
        match prefix_schemes with
        | [] ->
            "the kernel's binding `canonical_verifier_prefixes` (bin/Mathc.ml)"
        | xs -> render_canonical_schemes ~mark:"`" ~exact:[] ~prefixes:xs
      in
      Some
        ("### Definition\n\
          An `obligations[*].acceptance.all[*].verifier` string begins\n\
          with a scheme token that is NOT in the canonical allowlist\n\
          documented in `decisions/verifier-scheme-convention-2026-11.yaml`.\n\
          Canonical exact schemes: " ^ exact_text
       ^ ". Canonical prefixes (the scheme may have any suffix): " ^ prefix_text
       ^ ". The verifier string is\n\
          whitespace-split; the FIRST token is the scheme.\n\n\
          ### Occurs when\n\
          `mathc validate` walks every obligation's acceptance list and\n\
          runs `parse_verifier_string` (bin/Mathc.ml) to split scheme\n\
          from args. When the scheme is not in the canonical list, the\n\
          validator emits one Warn-level `MC-VERIFIER-SCHEME-UNKNOWN`\n\
          diagnostic per non-canonical item, naming the obligation id\n\
          and the scheme token. The verdict is still `parse-ok`:\n\
          the kernel produces a typed Domain.acceptance for the item,\n\
          and the warning is the signal that the convention is not\n\
          met. The corpus carried such schemes by historical\n\
          necessity until 2026-11, and\n\
          decisions/corpus-tranche-broken-schemes-2026-11.yaml is the\n\
          decision that repaired them. The diagnostic remains the\n\
          discoverability surface: it is what tells an author that a\n\
          scheme the kernel does not know is not a scheme.\n\n\
          ### Remediation\n\
          Replace the scheme token with a canonical one. For\n\
          shell-style predicates that need a custom check, prefer\n\
          `shell-grep` + needle (the needle is PRESENT) or\n\
          `shell-grep-absent` + needle (the needle is ABSENT). For\n\
          in-process fixtures, use `file-exists` / `dir-exists`.\n\
          For cross-binary invocations, use `mathc <subcmd>` where\n\
          `<subcmd>` is in the read-only allowlist (validate, assess,\n\
          find, self-check, explain, explain-diagnostic, context,\n\
          packages, version). For a new scheme family, open a\n\
          follow-up decision that EXTENDS the allowlist rather than\n\
          inventing a new token. Re-run `mathc validate` to confirm\n\
          the diagnostic is gone.")
  | "MC-AMBIGUOUS-ACCEPTANCE" ->
      Some
        "### Definition\n\
         An obligation's acceptance list contains an item with both\n\
         `verifier` + `result` AND `review` fields.\n\n\
         ### Occurs when\n\
         The kernel parses the verifier-half successfully and the\n\
         review-half is silently dropped (per\n\
         OCAML_BEST_PRACTICES §9.1 the verifier shape wins).\n\
         Surfaced by `mathc validate` as an extra Warn diagnostic\n\
         on the `accept` verdict.\n\n\
         ### Remediation\n\
         Remove either the `verifier`/`result` block or the `review`\n\
         block so each acceptance item carries one shape only."
  | "MC-ACCEPTANCE-DECLARED-RESULT" ->
      Some
        "### Definition\n\
         An acceptance item declares a `result:`. An acceptance item\n\
         names a check; the outcome of that check is measured by\n\
         running it and recorded in the attestation store. A declared\n\
         outcome in the promise's own file is a DECLARED result where\n\
         an ATTESTED one belongs (spec/constitution.md\n\
         \"Epistemic Separation\": declared != derived != attested !=\n\
         reviewed != observed).\n\n\
         ### Occurs when\n\
         `mathc validate` walks every acceptance item and finds a\n\
         `result:` key. The corpus carried 863 of them, all `pass`,\n\
         and no verdict ever consulted them.\n\n\
         ### Remediation\n\
         Remove the `result:` line. The check stays; the outcome moves\n\
         to the store, where it is measured."
  | "MC-MALFORMED-ACCEPTANCE" ->
      Some
        "### Definition\n\
         An acceptance item has the right field structure\n\
         (verifier+result OR review) but the values do not parse\n\
         — e.g., `result: bogus` instead of `pass`/`fail`/\n\
         `inconclusive`/`infrastructure-error`.\n\n\
         ### Occurs when\n\
         `mathc validate` walks every acceptance and reports each\n\
         unparseable item. The verdict is still `accept` because\n\
         the kernel typed the rest of the decision; the\n\
         diagnostic tells the author the malformed item is ignored.\n\n\
         ### Remediation\n\
         Replace `result: <bad>` with one of\n\
         `pass` | `fail` | `inconclusive` | `infrastructure-error`."
  | "MC-UNPARSED-TAIL" ->
      Some
        "### Definition\n\
         The kernel's YAML loader stopped reading the document\n\
         before the end of the file, and `Codec.load_yaml_string`\n\
         discarded the remaining lines without saying so.\n\n\
         ### Occurs when\n\
         `mathc validate` calls\n\
         `lib/codec.ml::load_yaml_string_full`, which keeps the\n\
         token list that `parse_yaml_pairs` did NOT consume. A\n\
         non-empty remainder means the parser met a token deeper\n\
         than the mapping it was closing and returned early\n\
         (`parse_yaml_pairs`, the `head_indent tokens > cur_indent`\n\
         clause). The verdict is still `parse-ok` — the prefix that\n\
         WAS read usually types fine — so without this diagnostic\n\
         a decision can be missing its entire `obligations:`,\n\
         `risk:`, `relations:` and `reversal:` tail while the gate\n\
         reports it as fully checked.\n\n\
         The corpus reached this through `fold_continuation`, whose\n\
         \"a deeper line containing a colon is a nested key, stop\n\
         folding\" heuristic misfires on prose: English sentences\n\
         contain colons (`Mitigation: rename the install step`).\n\n\
         This is a different mechanism from `MC-DUPLICATE-KEY`.\n\
         A duplicated key is IN the tree and unreachable; an\n\
         unparsed tail is NOT in the tree at all. Fixing the\n\
         duplicate does not restore the tail, and vice versa.\n\n\
         ### Remediation\n\
         Look at the line the diagnostic names. Put the prose in a\n\
         `|` block scalar (`consequence_if_false: |`) so the\n\
         continuation is read as text rather than guessed at, or\n\
         rewrap the plain scalar so no continuation line carries a\n\
         colon. Both preserve the wording. Re-run\n\
         `mathc validate <file>` — the file must print `parse-ok`\n\
         with no `MC-UNPARSED-TAIL` line on stderr.\n\n\
         The parser-side fix for `fold_continuation` itself is\n\
         tracked as a follow-up decision; see\n\
         `decisions/duplicate-mapping-keys-silent-drop-2026-10.yaml`."
  | "MC-DUPLICATE-KEY" ->
      Some
        "### Definition\n\
         The same mapping key is declared more than once in one\n\
         scope of a decision file (YAML 1.2 §3.2.1 requires the\n\
         keys of a mapping to be unique).\n\n\
         ### Occurs when\n\
         `mathc validate` walks the parsed document\n\
         (`lib/codec.ml::duplicate_keys`) and finds a key bound\n\
         twice in one mapping. The kernel's readers\n\
         (`lib/schema.ml::take_string` / `take_array` /\n\
         `take_object` / `take_number`) all resolve a key with\n\
         `List.assoc_opt`, which returns the FIRST binding — so\n\
         the later block is not overridden, it is UNREACHABLE:\n\
         its content is in the tree and no reader can ever see\n\
         it.\n\n\
         The severity is Warn because the kernel still produces a\n\
         well-typed decision from the surviving block. For a\n\
         duplicated `obligations:` key that means the dropped\n\
         obligations never reach `mathc gate` or `mathc\n\
         self-check`, so a verdict can be `pass` about promises\n\
         that were never checked — the diagnostic is the only\n\
         signal that the file says more than the gate read.\n\n\
         ### Remediation\n\
         Merge the declarations into one. Two `obligations:`\n\
         blocks become one list holding every obligation from\n\
         both, in the order you want them checked; two\n\
         `counterexample:` blocks become one `|` block whose\n\
         text contains both halves. Do NOT delete the second\n\
         block to silence the warning — that deletes the\n\
         promises the author wrote. After editing, recompute\n\
         `body_sha` / `yaml_sha` (`lib/decision.ml::\n\
         body_canonical_sha256`, spec/kernel-contract.md §7.1) and\n\
         bump `revision` if the file declares one, then re-run\n\
         `mathc validate <file>`.\n\n\
         See `decisions/duplicate-mapping-keys-silent-drop-\n\
         2026-10.yaml` for the corpus that motivated the code."
  | "MC-PARSE" ->
      Some
        "### Definition\n\
         The decision file could not be parsed by the kernel's\n\
         hand-rolled JSON/YAML reader.\n\n\
         ### Occurs when\n\
         `mathc validate` rejects the file with this code when\n\
         the parser hits a malformed token (unbalanced quotes,\n\
         bad indentation in a block scalar, etc.). The exit\n\
         code is 1.\n\n\
         ### Remediation\n\
         Re-read the parser error message (it carries `line` and\n\
         `col`); fix the token; re-run `mathc validate`."
  | "MC-DECISION-INVALID" ->
      Some
        "### Definition\n\
         The decision file is parseable but is missing a required\n\
         top-level field (`schema`, `id`, `intent`, `commitment`,\n\
         `scope`, `outcomes`, `obligations`) or the body does\n\
         not satisfy the schema constraints.\n\n\
         ### Occurs when\n\
         `mathc validate` surfaces the FIRST missing field\n\
         (not all of them) so the author has a single actionable\n\
         next step. Exit code is 1.\n\n\
         ### Remediation\n\
         Add the named field. For `obligations`, an empty list\n\
         is acceptable but the field itself must be present.\n\
         Re-run `mathc validate`."
  | "MC-COUNTEREXAMPLE-MISSING" ->
      Some
        "### Definition\n\
         A decision carries an empty `counterexample` field.\n\
         The contract depends on the decision's `mode`:\n\
         mode in {tiny, light}: counterexample is OPTIONAL;\n\
         mode in {standard, strict, exhaustive}: counterexample\n\
         is REQUIRED (Block severity, reject). The rule is\n\
         codified in spec/kernel-contract.md §11 and enforced by\n\
         `bin/Mathc.ml::validate_with_counts::counterexample_violation`\n\
         and `lib/decision.ml::parse_decision` (parser-level\n\
         reject for mode >= standard).\n\n\
         ### Occurs when\n\
         After the A2 YAML-parser fix (`decisions/fix-yaml-parser-2026-10`,\n\
         commit 3f14b76 — `lib/codec.ml::parse_yaml_pairs` now accepts\n\
         the inline-sequence form `key: - foo\\n- bar`), the only way\n\
         `counterexample:` can be absent in the parsed decision is when\n\
         the YAML truly omits the key. The diagnostic fires on genuine\n\
         absence, not on parser limitation: a pre-fix decision that\n\
         carried a counterexample after `risk.declared_triggers: - foo`\n\
         used to surface this code as a false positive; it no longer\n\
         does (see `tests/cli/yaml-parser.t` scenario 1 and\n\
         `tests/cli/counterexample-warn.t` scenario 3). For mode >=\n\
         standard the severity is `block` and the verdict is `reject`\n\
         (exit 1); for mode in {tiny, light} the severity is `warn` and\n\
         the verdict stays `accept` (dialectical slot, not a hard\n\
         requirement). Both paths read the post-parse absence predicate\n\
         on `Decision.counterexample`.\n\n\
         ### Remediation\n\
         Add a `counterexample: |` block with one or two\n\
         sentences naming the strongest objection to the\n\
         decision. Re-run `mathc validate`. For mode >=\n\
         standard an absent counterexample is a blocker; a\n\
         quick fix is to drop the decision to `mode: light`,\n\
         but the long-term fix is to record the strongest\n\
         objection."
  | "MC-AXIOM-LINK-MISSING" ->
      Some
        "### Definition\n\
         A `state: active` decision carries an empty\n\
         `axiom_link` field. Spec/kernel-contract.md §7 requires\n\
         every active decision to name the axiom(s) it\n\
         addresses via the `axiom_link` field (e.g.\n\
         `axiom_link: [A0]`).\n\n\
         ### Occurs when\n\
         `lib/decision.ml::parse_decision` rejects the\n\
         decision (returns None) because `state = Active` and\n\
         `axiom_link = []`. The CLI surfaces this as\n\
         `MC-AXIOM-LINK-MISSING` with verdict `reject` and\n\
         exit code 1. Draft / Retired / Superseded decisions\n\
         are exempt; only active decisions carry the contract.\n\n\
         ### Remediation\n\
         Add `axiom_link: [A<n>]` to the decision front-matter,\n\
         listing the axiom(s) the decision addresses. If the\n\
         decision is a transitional draft that should not be\n\
         evaluated yet, change its state to `draft` instead.\n\
         Re-run `mathc validate`."
  | "MC-AXIOM-LINK-INFERENCE-EMPTY" ->
      Some
        "### Definition\n\
         A soft-warn emitted by `mathc new-decision` when the\n\
         produced decision lacks an `axiom_link` field. The\n\
         warn names the top-3 most-likely axiom IDs based on\n\
         the decision's `scope.paths`.\n\n\
         ### Occurs when\n\
         `lib/new_decision/new_decision.ml::run` detects that\n\
         the rendered template (Full or `--template=full`\n\
         default) carries no `axiom_link:` block. The CLI\n\
         infers candidates via\n\
         `lib/decision.ml::infer_axiom_candidates` and emits\n\
         `deficit/MC-AXIOM-LINK-INFERENCE-EMPTY: ...; top\n\
         candidates: <ax1>, <ax2>, <ax3>; add axiom_link` on\n\
         stderr. The Minimal template hardcodes `axiom_link:\n\
         [A0]` and never fires this warn. The warn is\n\
         SUGGEST-ONLY: the `axiom_link` field is NEVER\n\
         auto-filled; the author retains full control.\n\n\
         ### Remediation\n\
         Edit the produced decision's front-matter to add an\n\
         `axiom_link: [...]` block. Use the candidates named\n\
         in the warn as a starting point (e.g. `axiom_link:\n\
         [A0, A1]` for lib/-shaped decisions), but trust your\n\
         own judgement — the inference is opinionated and the\n\
         final choice is yours. Re-run `mathc validate` after\n\
         the edit; the soft-warn goes away once `axiom_link`\n\
         is non-empty."
  | "MC-SHA-MISMATCH" ->
      Some
        "### Definition\n\
         A Decision carries BOTH `body_sha` and `yaml_sha` and\n\
         the two values disagree. Spec/kernel-contract.md §7\n\
         requires `if D.body_sha ≠ ∅ ∧ D.yaml_sha ≠ ∅ then\n\
         D.body_sha = D.yaml_sha`. Either field alone is\n\
         permitted (the invariant is vacuously satisfied); the\n\
         mismatch only triggers when BOTH are present and not\n\
         string-equal.\n\n\
         ### Occurs when\n\
         `lib/decision.ml::sha_match_check` returns false\n\
         for a parsed Decision. `bin/Mathc.ml::validate_with_counts`\n\
         converts the disagreement into an `MC-SHA-MISMATCH`\n\
         diagnostic with verdict `reject` and exit code 1. This\n\
         covers the case where the two stored fields disagree with\n\
         EACH OTHER; when they agree with each other but not with\n\
         the file, the diagnostic is `MC-SHA-DIGEST-STALE`\n\
         (see `decisions/enforce-body-sha-digest-2026-10`).\n\n\
         ### Remediation\n\
         Recompute BOTH `body_sha` and `yaml_sha` using the\n\
         placeholder-substitution algorithm: replace each\n\
         field's value with the placeholder `sha256:` + 64\n\
         zeros (same length as a real digest), sha256 the\n\
         resulting file content, and set BOTH fields to\n\
         the resulting hex digest. `mathc rehash <path> --write`\n\
         does this and verifies the result is a fixed point before\n\
         writing. The reference implementation lives in\n\
         `scripts/axiom-link-seed.py:133-169`. Re-run\n\
         `mathc validate` to confirm `MC-SHA-MISMATCH` is\n\
         gone."
  | "MC-SHA-DIGEST-STALE" ->
      Some
        "### Definition\n\
         A Decision's `body_sha` and `yaml_sha` agree with each\n\
         other, and both are wrong: their shared value is not the\n\
         digest of the file they live in. Spec/kernel-contract.md §7.1\n\
         defines `body_sha` as the sha256 of the file's own bytes\n\
         with both digest fields replaced by the placeholder\n\
         `sha256:` + 64 zeros, so an edit to the body that was not\n\
         accompanied by a recompute leaves the stored value stale.\n\n\
         This is the check that carries the tamper-evidence claim\n\
         in `adoption/SKILL.md`. Without it, a decision body could\n\
         be rewritten under a digest that still asserted the old\n\
         content, and every downstream verdict still read `pass`.\n\
         Equal-but-wrong is why it is a separate code and not a\n\
         reuse of `MC-SHA-MISMATCH`: the 64-zero placeholder\n\
         emitted by `mathc new-decision` satisfies the equality\n\
         invariant forever, which is precisely this failure.\n\n\
         ### Occurs when\n\
         `lib/decision.ml::sha_match_check` is given the file's raw\n\
         bytes and recomputes the digest, then finds it differs from\n\
         the stored `body_sha`. `bin/Mathc.ml::validate_with_counts`\n\
         passes the bytes it already read for parsing, so the\n\
         validate path cannot silently fall back to the weaker\n\
         string-only check. Verdict `reject`, exit code 1.\n\n\
         `mathc self-check` recomputes it too, for every\n\
         decision, and reports the subject as `fail` (exit 1). It\n\
         previously read the attestation store without looking at the\n\
         decision bytes, so a tampered decision came back `unknown`\n\
         - indistinguishable from one that merely lacked an\n\
         attestation. `load_decision_entry` already keeps the raw text\n\
         in `Memory.source`, so no extra I/O was needed; the verdict\n\
         is forced to Block AFTER waiver aggregation, so a stale\n\
         digest cannot be waived away.\n\n\
         KNOWN GAP: `mathc gate` does not yet look at the digest.\n\
         It has the bytes (`Gate.evaluate` receives `Memory.t`,\n\
         whose entries carry `Memory.source`) but does not check\n\
         them. Recorded in\n\
         `decisions/enforce-body-sha-digest-2026-10`.\n\n\
         ### Remediation\n\
         Run `mathc rehash <path> --write`. It recomputes both\n\
         fields from the file's own bytes, verifies each stamped\n\
         file is a fixed point (re-hashing the result must\n\
         reproduce the digest) before writing, and refuses to write\n\
         a file that fails that check. Dry-run by default: omit\n\
         `--write` to see what would change. Then re-run\n\
         `mathc validate`."
  | "MC-BODY-SHA-PATTERN-VIOLATION" ->
      Some
        "### Definition\n\
         A Decision carries a `body_sha` or `yaml_sha` whose value\n\
         does not match the schema-declared pattern\n\
         `^sha256:[0-9a-f]{64}$` (71 characters total). The schema\n\
         (`schemas/decision.json`) documents the pattern but the\n\
         kernel historically only enforced equality between\n\
         `body_sha` and `yaml_sha`; before this commit, a value like\n\
         `\"sha256:' + sha + '\"` (literal shell-template artifact)\n\
         or a too-short digest would silently pass equality\n\
         checks against itself and reach the gate.\n\n\
         ### Occurs when\n\
         `lib/decision.ml::parse_decision_yaml` finds a non-empty\n\
         `body_sha` or `yaml_sha` whose string is not exactly 71\n\
         characters OR does not start with `sha256:`. The kernel\n\
         emits `MC-BODY-SHA-PATTERN-VIOLATION` (Block, exit 1).\n\
         Per `decisions/kernel-bugs-v3.4-2026-10`, the check is\n\
         parser-side and runs BEFORE the parser continues.\n\n\
         ### Remediation\n\
         Replace the offending value with the canonical\n\
         SHA-256 of the decision body (with both fields replaced\n\
         by `sha256:` + 64 zeros). The reference implementation\n\
         lives in `scripts/axiom-link-seed.py:105-123`. For an\n\
         automated migration across a brownfield repo, run\n\
         `scripts/fix-non-pattern-sha.sh` (idempotent; decisions\n\
         whose `body_sha` already matches the pattern are left\n\
         untouched). Re-run `mathc validate` to confirm the\n\
         violation is gone."
  | "MC-MATERIALS-DIGEST-EMPTY" ->
      Some
        "### Definition\n\
         An attestation carries `subject.materials_digest: \"\"`\n\
         for a runtime-kind attestation (`kind_` in\n\
         `{test, build, observation}`). Per A0 (epistemic\n\
         separation, `spec/constitution.md` §0), a runtime\n\
         attestation MUST name the materials it was produced\n\
         against; only `kind_: review` may carry an empty digest\n\
         (a human declaration without a runtime anchor).\n\n\
         ### Occurs when\n\
         `lib/codec.ml::parse_attestation` finds a non-review\n\
         attestation whose `subject.materials_digest` is the\n\
         empty string. The kernel emits\n\
         `MC-MATERIALS-DIGEST-EMPTY` (Block, exit 1). Per\n\
         `decisions/kernel-bugs-v3.4-2026-10`, the loader in\n\
         `lib/attestations/attestations.ml` grandfathered legacy\n\
         build/test attestations whose `issued_at` predates\n\
         2026-10-16; new attestations produced after this commit\n\
         must carry the digest.\n\n\
         ### Remediation\n\
         Compute the SHA-256 of the run's input artefact (test\n\
         output, build artefact, observed metric) and set\n\
         `subject.materials_digest` to the hex digest. Re-run\n\
         `mathc validate` (or the producer script) to confirm the\n\
         violation is gone."
  | "MC-PRODUCER-CLASS-UNDECLARED" ->
      Some
        "### Definition\n\
         `producer.identity` carries no claim class. Per\n\
         `decisions/attestation-producer-vocab-2026-10`, an identity\n\
         is `<class>:<subject>` with `class` in {human, agent, ci}.\n\
         An untagged identity says nothing about WHO produced the\n\
         attestation, so a reader cannot tell a human DECLARATION\n\
         from a machine OBSERVATION without out-of-band knowledge.\n\n\
         ### Occurs when\n\
         `lib/codec.ml::validate_attestation_producer` finds an\n\
         identity that does not match\n\
         `^(human|agent|ci):[A-Za-z0-9][A-Za-z0-9._:/-]*$`. The kernel\n\
         emits `MC-PRODUCER-CLASS-UNDECLARED` (Block, exit 1). The\n\
         store loader in `lib/attestations/attestations.ml` does not\n\
         validate, so attestations committed before 2026-10-23\n\
         carrying untagged identities (`ci-bot`, `dune:test`,\n\
         `test`, `sub-agent-A4-batchA`, 62 files at the time of the\n\
         decision) remain readable.\n\n\
         ### What this does NOT claim\n\
         A tagged `human:` identity is a DECLARATION, not a proof.\n\
         No attestation in the store carries a signature (0 of 765),\n\
         so there is no key class against which a claim could be\n\
         checked. See `MC-PRODUCER-HUMAN-UNANCHORED` for the rule\n\
         that carries the weight.\n\n\
         ### Remediation\n\
         Tag the identity: `ci:<job>` for an automated job,\n\
         `agent:<id>` for a model-driven agent, `human:<name>` for a\n\
         person. Re-run `mathc validate`."
  | "MC-PRODUCER-HUMAN-UNANCHORED" ->
      Some
        "### Definition\n\
         An attestation whose `producer.identity` declares the\n\
         `human:` class carries a RUNTIME kind (test / build /\n\
         analysis / observation) and names no `producer.run`.\n\n\
         The rule is asymmetric on purpose. A `human:` producer on\n\
         `kind_: review` is claiming the WEAK class -- the same\n\
         exemption `MC-MATERIALS-DIGEST-EMPTY` grants for an empty\n\
         `materials_digest` -- so a false claim there upgrades\n\
         nothing and is left unconstrained. A `human:` producer on a\n\
         runtime kind attaches a person's name to a machine-grade\n\
         claim, which IS the upgrade the store exists to prevent\n\
         (commit 9c1f7ab records it at scale: attest-batch\n\
         mass-signed 793 files as `human:integration-experiment`\n\
         without asking). Requiring `producer.run` makes the claim\n\
         falsifiable: `mathc verify` executes the named command.\n\n\
         ### Occurs when\n\
         `lib/codec.ml::validate_attestation_producer` finds a\n\
         `human:`-class identity whose `kind_` is not `review` and\n\
         whose `producer.run` is absent or empty. The kernel emits\n\
         `MC-PRODUCER-HUMAN-UNANCHORED` (Block, exit 1).\n\n\
         ### What this does NOT claim\n\
         It does not verify that a person typed the string. Closing\n\
         that gap needs key separation -- a DSSE signature whose\n\
         `key_id` is bound to a human key -- and 0 of the 765 stored\n\
         attestations carry a signature, so this is the strongest\n\
         rule the current substrate can carry, not the strongest\n\
         one that would be desirable.\n\n\
         ### Remediation\n\
         Name the run that produced the result: reissue with\n\
         `mathc attest ... --producer=<id> --run=<command>`, which\n\
         sets `producer.run` and derives `materials_digest` from the\n\
         command's output. If the attestation is genuinely a human\n\
         judgement with no runtime anchor, reissue it as\n\
         `--kind review`, where an empty digest is already legal."
  | "MC-MISSING-SCHEMA" ->
      Some
        "### Definition\n\
         The decision file is parseable but is missing the top-level\n\
         `schema` field. The `schemas/decision.json` schema contract\n\
         requires every decision to declare its schema family (e.g.\n\
         `math-coding/3.0-alpha`).\n\n\
         ### Occurs when\n\
         `lib/decision.ml::parse_decision` does not find a `schema`\n\
         key at the top level. The CLI emits `MC-MISSING-SCHEMA`\n\
         with verdict `reject` and exit code 1. The diagnostic's\n\
         `path` is `[\"schema\"]`.\n\n\
         ### Remediation\n\
         Add `schema: math-coding/3.0-alpha` (or the schema family\n\
         the decision targets) to the front-matter. Re-run\n\
         `mathc validate`."
  | "MC-MISSING-ID" ->
      Some
        "### Definition\n\
         The decision file is parseable but is missing the top-level\n\
         `id` field. The schema contract requires every decision\n\
         to declare an id.\n\n\
         ### Occurs when\n\
         `lib/decision.ml::parse_decision` does not find an `id`\n\
         key at the top level. The CLI emits `MC-MISSING-ID` with\n\
         verdict `reject` and exit code 1. The diagnostic's `path`\n\
         is `[\"id\"]`.\n\n\
         ### Remediation\n\
         Add `id: <short-id>` (e.g. `redis-origin-fallback`) to the\n\
         front-matter. Re-run `mathc validate`."
  | "MC-MISSING-REVISION" ->
      Some
        "### Definition\n\
         The decision file is parseable but is missing the\n\
         top-level `revision` field.\n\n\
         ### Occurs when\n\
         `lib/decision.ml::parse_decision` does not find a\n\
         `revision` key at the top level. The CLI emits\n\
         `MC-MISSING-REVISION` with verdict `reject` and exit\n\
         code 1. The diagnostic's `path` is `[\"revision\"]`.\n\n\
         ### Remediation\n\
         Add `revision: <rev>` (string or sha256-prefixed digest,\n\
         e.g. `revision: 5` or `revision: rev:41aa92`) to the\n\
         front-matter. Re-run `mathc validate`."
  | "MC-MISSING-INTENT" ->
      Some
        "### Definition\n\
         The decision file is parseable but is missing the\n\
         top-level `intent` field.\n\n\
         ### Occurs when\n\
         `lib/decision.ml::parse_decision` does not find an\n\
         `intent` key at the top level (the YAML form expects a\n\
         scalar string; the JSON form expects an object with\n\
         `source` and `text` keys). The CLI emits\n\
         `MC-MISSING-INTENT` with verdict `reject` and exit code\n\
         1. The diagnostic's `path` is `[\"intent\"]`.\n\n\
         ### Remediation\n\
         Add an `intent:` block (YAML form: scalar string; JSON\n\
         form: `{source, text}` object). Re-run `mathc validate`."
  | "MC-MISSING-COMMITMENT" ->
      Some
        "### Definition\n\
         The decision file is parseable but is missing the\n\
         top-level `commitment` field.\n\n\
         ### Occurs when\n\
         `lib/decision.ml::parse_decision` does not find a\n\
         `commitment` key at the top level. The CLI emits\n\
         `MC-MISSING-COMMITMENT` with verdict `reject` and exit\n\
         code 1. The diagnostic's `path` is\n\
         `[\"commitment\"]`.\n\n\
         ### Remediation\n\
         Add a `commitment: |` block (one or more sentences\n\
         stating the commitment the decision makes). Re-run\n\
         `mathc validate`."
  | "MC-MISSING-SCOPE" ->
      Some
        "### Definition\n\
         The decision file is parseable but is missing the\n\
         top-level `scope` field.\n\n\
         ### Occurs when\n\
         `lib/decision.ml::parse_decision` does not find a\n\
         `scope` key at the top level (YAML form: object with\n\
         `capabilities` / `paths` / `exclusions`; JSON form:\n\
         array of `{kind, path|capability}`). The CLI emits\n\
         `MC-MISSING-SCOPE` with verdict `reject` and exit code\n\
         1. The diagnostic's `path` is `[\"scope\"]`.\n\n\
         ### Remediation\n\
         Add a `scope:` block (YAML or JSON form). Re-run\n\
         `mathc validate`."
  | "MC-MISSING-OUTCOMES" ->
      Some
        "### Definition\n\
         The decision file is parseable but is missing the\n\
         top-level `outcomes` field.\n\n\
         ### Occurs when\n\
         `lib/decision.ml::parse_decision` does not find an\n\
         `outcomes` key at the top level. The CLI emits\n\
         `MC-MISSING-OUTCOMES` with verdict `reject` and exit\n\
         code 1. The diagnostic's `path` is `[\"outcomes\"]`.\n\n\
         ### Remediation\n\
         Add `outcomes: []` (empty list is acceptable but the\n\
         field itself must be present) or a list of outcomes\n\
         with `id` and `statement` keys. Re-run `mathc validate`."
  | "MC-MISSING-OBLIGATIONS" ->
      Some
        "### Definition\n\
         The decision file is parseable but is missing the\n\
         top-level `obligations` field.\n\n\
         ### Occurs when\n\
         `lib/decision.ml::parse_decision` does not find an\n\
         `obligations` key at the top level. The CLI emits\n\
         `MC-MISSING-OBLIGATIONS` with verdict `reject` and\n\
         exit code 1. The diagnostic's `path` is\n\
         `[\"obligations\"]`.\n\n\
         ### Remediation\n\
         Add `obligations: []` (empty list is acceptable but\n\
         the field itself must be present) or a list of\n\
         obligation items. Re-run `mathc validate`."
  | "MC-MISSING-RISK-OWNER" ->
      Some
        "### Definition\n\
         The decision file is parseable but the `risk` object is\n\
         missing its `owner` key.\n\n\
         ### Occurs when\n\
         `lib/decision.ml::parse_decision_yaml` injects the\n\
         schema default `human:maintainer` if the entire risk\n\
         block is missing, but if `risk` is present without\n\
         `owner` (e.g. `risk: {declared_triggers: [...]}`), the\n\
         parser returns `MC-MISSING-RISK-OWNER` with verdict\n\
         `reject` and exit code 1. The diagnostic's `path` is\n\
         `[\"risk.owner\"]`.\n\n\
         ### Remediation\n\
         Add `owner: human:maintainer` (or another owner id)\n\
         to the `risk:` block. Re-run `mathc validate`."
  | "MC-INVALID-ID-FORMAT" ->
      Some
        "### Definition\n\
         The decision's `id` field is present but does not match\n\
         the schema regex `^[a-z][a-z0-9-]*(@[A-Za-z0-9_.-]+)?$`\n\
         (short lower-snake-case, optionally suffixed with `@rev`).\n\n\
         ### Occurs when\n\
         `lib/decision.ml::parse_decision` finds a value at the\n\
         `id` key but the value is empty, or contains characters\n\
         the regex forbids (e.g. uppercase, `_`). The CLI emits\n\
         `MC-INVALID-ID-FORMAT` with verdict `reject` and exit\n\
         code 1. The diagnostic's `path` is `[\"id\"]` and the\n\
         message carries the offending value.\n\n\
         ### Remediation\n\
         Replace `id:` with a short lower-snake-case string, e.g.\n\
         `id: redis-origin-fallback`. If you need to pin a\n\
         specific revision, suffix with `@rev` (e.g.\n\
         `id: redis-origin-fallback@3`). Re-run `mathc validate`."
  | "MC-INVALID-REVISION-FORMAT" ->
      Some
        "### Definition\n\
         The decision's `revision` field is present but does not\n\
         match the schema contract (a string or sha256-prefixed\n\
         digest, never null).\n\n\
         ### Occurs when\n\
         `lib/decision.ml::parse_decision` finds a value at the\n\
         `revision` key but the value is a JSON null, an array,\n\
         or an object — none of which the schema accepts. The CLI\n\
         emits `MC-INVALID-REVISION-FORMAT` with verdict `reject`\n\
         and exit code 1. The diagnostic's `path` is\n\
         `[\"revision\"]` and the message carries the offending\n\
         value.\n\n\
         ### Remediation\n\
         Replace `revision:` with a string or sha256-prefixed\n\
         digest, e.g. `revision: 5` or `revision: rev:41aa92`.\n\
         Re-run `mathc validate`."
  | "MC-INVALID-AXIOM-LINK" ->
      Some
        "### Definition\n\
         The decision's `axiom_link` field contains a token that\n\
         does not match the axiom-shaped regex\n\
         `^A[0-9]+(@[A-Za-z0-9_.-]+)?$` (starts with `A`,\n\
        \         has digits, optionally has `@rev` or `.sub` suffix).\n\n\
         ### Occurs when\n\
         `lib/decision.ml::parse_decision` finds an `axiom_link`\n\
         value but a token is not axiom-shaped (e.g. `foo`,\n\
         `A`, or `A-1`). The CLI emits `MC-INVALID-AXIOM-LINK`\n\
         with verdict `reject` and exit code 1. The diagnostic's\n\
         `path` is `[\"axiom_link\"]` and the message carries the\n\
         offending token.\n\n\
         ### Remediation\n\
         Replace the offending token with an axiom-shaped one\n\
         (e.g. `A0`, `A1@2`, `A3.sub`). If the value was meant\n\
         to be a non-axiom identifier, remove it from the\n\
         `axiom_link` list and put it under `relations.addresses`\n\
         instead. Re-run `mathc validate`."
  | "MC-POLICY-CYCLE" ->
      Some
        "### Definition\n\
         A `parent:` chain in `policies.yaml` contains a\n\
         cycle (a → b → a). `lib/policy.ml::resolve_policy` walks\n\
         the chain to compute the resolved policy; cycles\n\
         terminate the walk early and surface this diagnostic.\n\
         The decision in scope is\n\
         `decisions/multi-policy-hierarchy-2026-10`.\n\n\
         ### Occurs when\n\
         `Policy.resolve_policy` is called on a policy whose\n\
         `parent` field transitively points back to itself\n\
         (direct cycle a → a or 2-step a → b → a). The\n\
         function returns `Error (Diagnostic.t)` carrying this\n\
         code rather than infinite-looping.\n\n\
         ### Remediation\n\
         Trace the `parent:` references in `policies.yaml`\n\
         from the named cycle root and break the loop. The\n\
         simplest fix is to remove the `parent:` line from one\n\
         of the policies; if the relationship is genuinely\n\
         parent-child, restructure it into a 3-tier chain\n\
         (grandparent → parent → child) without re-pointing\n\
         to a previously-on-path ancestor. Re-run\n\
         `mathc explain-diagnostic MC-POLICY-CYCLE` is not\n\
         relevant to the fix; the diagnostic is removed once\n\
         the chain is acyclic."
  | "MC-POLICY-NOT-FOUND" ->
      Some
        "### Definition\n\
         `lib/policy.ml::resolve_policy` was called with a\n\
         `policy_id` that is not in the registry. The\n\
         resolution function returns `Error (Diagnostic.t)`\n\
         with this code rather than returning `default_policy`.\n\
         The decision in scope is\n\
         `decisions/multi-policy-hierarchy-2026-10`.\n\n\
         ### Occurs when\n\
         `Policy.resolve_policy policies id` is called and\n\
         no policy in `policies` has `policy_id = id`. This\n\
         is distinct from `MC-POLICY-CYCLE`: a missing-id is\n\
         an input error; a cycle is a structural loop in the\n\
         registry. Both are emitted by the same function\n\
         under different conditions.\n\n\
         ### Remediation\n\
         Confirm that the `policy_id` matches one in\n\
         `policies.yaml` exactly (the registry uses\n\
         exact-string equality). Add a stub policy entry\n\
         with the missing id if the call site is correct;\n\
         otherwise, fix the call site to use a known id."
  | _ -> None

let render d =
  Printf.sprintf "[%s] %s/%s: %s"
    (string_of_severity d.severity)
    (string_of_kind d.kind) d.code d.message
