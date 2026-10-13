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
      ( "add",
        Printf.sprintf "%s: |\n  <one-line description>" field );
      ("run", "mathc validate decisions/<file>.yaml");
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  create ~code ~kind:Deficit ~severity:Block ~path:[ field ]
    ~policy_rule:(Some "schemas/decision.json")
    ~next_actions:actions ~retryable:false ~autofix_safe:false message

let mc_missing_schema ?(next_actions = []) message =
  mc_missing_field ~code:"MC-MISSING-SCHEMA" ~field:"schema"
    ~next_actions message

let mc_missing_id ?(next_actions = []) message =
  mc_missing_field ~code:"MC-MISSING-ID" ~field:"id"
    ~next_actions message

let mc_missing_revision ?(next_actions = []) message =
  mc_missing_field ~code:"MC-MISSING-REVISION" ~field:"revision"
    ~next_actions message

let mc_missing_intent ?(next_actions = []) message =
  mc_missing_field ~code:"MC-MISSING-INTENT" ~field:"intent"
    ~next_actions message

let mc_missing_commitment ?(next_actions = []) message =
  mc_missing_field ~code:"MC-MISSING-COMMITMENT" ~field:"commitment"
    ~next_actions message

let mc_missing_scope ?(next_actions = []) message =
  mc_missing_field ~code:"MC-MISSING-SCOPE" ~field:"scope"
    ~next_actions message

let mc_missing_outcomes ?(next_actions = []) message =
  mc_missing_field ~code:"MC-MISSING-OUTCOMES" ~field:"outcomes"
    ~next_actions message

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
      ("edit",
       Printf.sprintf
         "id: |\n  %s\n  The id field should be a short lower-snake-case \
          string (e.g. `redis-origin-fallback`), optionally suffixed with \
          `@rev` to pin a specific revision (e.g. `redis-origin-fallback@3`)."
         (if id = "" then "<short-id>" else id) );
      ("run", "mathc validate decisions/<file>.yaml");
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  create ~code:"MC-INVALID-ID-FORMAT" ~kind:Deficit ~severity:Block
    ~path:[ "id" ]
    ~policy_rule:(Some "schemas/decision.json / decision.id")
    ~next_actions:actions ~retryable:false ~autofix_safe:false message

let mc_invalid_revision_format ?(revision = "") ?(next_actions = [])
    message =
  let default_actions =
    [
      ("edit",
       Printf.sprintf
         "revision: |\n  %s\n  The revision field is a string (e.g. \"5\") \
          or a sha256-prefixed digest (e.g. \"rev:41aa92\")."
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
      ("edit",
       Printf.sprintf
         "axiom_link:\n  - %s\n  Axiom-shaped tokens start with `A`, have \
          digits, optionally have `@rev` or `.sub` suffix (e.g. `A0`, \
          `A1@2`, `A3.sub`)."
         (if token = "" then "<A0>" else token) );
      ("run", "mathc validate decisions/<file>.yaml");
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  create ~code:"MC-INVALID-AXIOM-LINK" ~kind:Deficit ~severity:Block
    ~path:[ "axiom_link" ]
    ~policy_rule:(Some "spec/algebra-3.2.md §17 + lib/decision.ml:is_axiom_token")
    ~next_actions:actions ~retryable:false ~autofix_safe:false message

(* MC-COUNTEREXAMPLE-MISSING: emitted when a decision has an
   empty `counterexample` field. The contract depends on the
   decision's `mode`:
     - mode in {tiny, light}: counterexample is OPTIONAL.
       When absent, the diagnostic is a Warn and the verdict
       stays `accept` (counterexample is a dialectical slot,
       not a hard requirement, so legacy decisions without it
       stay valid per spec/algebra-3.2.md §11).
     - mode in {standard, strict, exhaustive}: counterexample is
       REQUIRED. When absent, the diagnostic is a Block and
       the verdict is `reject` with exit code 1. The rule was
       introduced by sub-decision
       `decisions/plan-2026-10-improvements/t6-2.yaml` and is
       part of an A3-protected transition (requires human review
       before merge) per `spec/constitution.md` §Self-application.
   The default severity is `Warn` so callers that do not pass
   one get the legacy soft-warning behaviour; the CLI bin/Mathc.ml
   passes `~severity:Block` when the mode is >= standard. *)
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
      ("edit", "spec/algebra-3.2.md §11 (dialectical slots)");
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  let policy_rule =
    match severity with
    | Block ->
        Some
          "spec/algebra-3.2.md §11 + \
           decisions/plan-2026-10-improvements/t6-2.yaml"
    | Warn | Info -> None
  in
  create ~code ~kind:Deficit ~severity ~policy_rule ~next_actions:actions
    ~retryable:false ~autofix_safe:false message

(* MC-ANTITHESIS-MISSING: emitted by `mathc validate` (via
   `lib/decision.ml::parse_decision`) when a decision with
   `mode >= standard` carries no antithesis. Mirrors
   `mc_counterexample_missing` for the antithesis slot. The contract
   is set by spec/algebra-3.2.md §11 (v3 dialectic method) and
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
      ("edit", "spec/algebra-3.2.md §11 (dialectic slots)");
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  let policy_rule =
    match severity with
    | Block ->
        Some
          "spec/algebra-3.2.md §11 + \
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

(* MC-AXIOM-LINK-MISSING: emitted by `mathc validate` (via
   `lib/decision.ml::parse_decision`) when a decision carries
   `state: active` with an empty `axiom_link` list. The
   contract is set by spec/algebra-3.2.md §7 ("A decision must
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
      "%sdecision has state=active but empty axiom_link: spec/algebra-3.2.md \
       §7 requires every active decision to name the axiom(s) it addresses via \
       the axiom_link field; add one (e.g. axiom_link: [A0]) to the decision \
       front-matter"
      prefix
  in
  create ~code:"MC-AXIOM-LINK-MISSING" ~kind:Deficit ~severity:Block
    ~policy_rule:(Some "spec/algebra-3.2.md §7")
    ~next_actions:
      [
        ("add", "axiom_link: [A0]");
        ("verify", "mathc validate <path-to-decision>");
      ]
    msg

(* MC-SHA-MISMATCH: emitted when a Decision carries both
   `body_sha` and `yaml_sha` and the two values disagree. Per
   spec/algebra-3.2.md §7 ("if D.body_sha ≠ ∅ ∧ D.yaml_sha ≠ ∅
   then D.body_sha = D.yaml_sha") and the schema contract in
   schemas/decision.json (both fields share the pattern
   `^sha256:[0-9a-f]{64}$`). The check is parser-side:
   `lib/decision.ml::sha_match_check` returns a `(bool, Diagnostic.t list)`
   accumulator; when both hashes are present and not string-equal,
   `mc_sha_mismatch` emits a Block diagnostic. Either field absent
   makes the invariant vacuously true (no mismatch is possible) and
   no diagnostic is emitted. Author remediation: re-run
   `scripts/axiom-link-seed.py --dry-run --verbose` (or a future
   `scripts/sha-recompute.py`) to recompute BOTH fields from the
   placeholder-substitution algorithm recorded in
   scripts/axiom-link-seed.py:105-123. This block-level emit is
   called from `bin/Mathc.ml::validate_with_counts` (T0.2 stream ε). *)
let mc_sha_mismatch ?(decision_id = "") ?(body_sha = "") ?(yaml_sha = "")
    ?(next_actions = []) () =
  let prefix =
    if decision_id = "" then "" else Printf.sprintf "%s: " decision_id
  in
  let body = if body_sha = "" then "<absent>" else body_sha in
  let yaml = if yaml_sha = "" then "<absent>" else yaml_sha in
  let msg =
    Printf.sprintf
      "%sbody_sha (%s) and yaml_sha (%s) disagree: spec/algebra-3.2.md §7 \
       requires both hashes to be equal when both are present. Recompute via \
       the placeholder-substitution algorithm (sha256 of the decision with \
       both fields replaced by 'sha256:' + 64 zeros); see \
       scripts/axiom-link-seed.py:105-123 for the canonical implementation."
      prefix body yaml
  in
  let default_actions =
    [
      ( "replace",
        "body_sha and yaml_sha with the recomputed digest (both fields must \
         carry the SAME value when both are present)" );
      ("run", "scripts/axiom-link-seed.py --dry-run --verbose  # reference impl");
      ("verify", "mathc validate <path-to-decision>");
    ]
  in
  let actions =
    match next_actions with [] -> default_actions | _ -> next_actions
  in
  create ~code:"MC-SHA-MISMATCH" ~kind:Deficit ~severity:Block
    ~policy_rule:(Some "spec/algebra-3.2.md §7") ~next_actions:actions msg

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

let explain (code : string) : string option =
  match code with
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
         codified in spec/algebra-3.2.md §11 and enforced by\n\
         `bin/Mathc.ml::validate_with_counts::counterexample_violation`\n\
         and `lib/decision.ml::parse_decision` (parser-level\n\
         reject for mode >= standard).\n\n\
         ### Occurs when\n\
         The CLI emits `MC-COUNTEREXAMPLE-MISSING` when\n\
         `counterexample` is absent. For mode >= standard the\n\
         severity is `block` and the verdict is `reject` (exit 1);\n\
         for mode in {tiny, light} the severity is `warn` and the\n\
         verdict stays `accept` (legacy soft-warning behaviour).\n\n\
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
         `axiom_link` field. Spec/algebra-3.2.md §7 requires\n\
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
  | "MC-SHA-MISMATCH" ->
      Some
        "### Definition\n\
         A Decision carries BOTH `body_sha` and `yaml_sha` and\n\
         the two values disagree. Spec/algebra-3.2.md §7\n\
         requires `if D.body_sha ≠ ∅ ∧ D.yaml_sha ≠ ∅ then\n\
         D.body_sha = D.yaml_sha`. Either field alone is\n\
         permitted (the invariant is vacuously satisfied); the\n\
         mismatch only triggers when BOTH are present and not\n\
         string-equal.\n\n\
         ### Occurs when\n\
         `lib/decision.ml::sha_match_check` returns false\n\
         for a parsed Decision. `bin/Mathc.ml::validate_with_counts`\n\
         converts the disagreement into an `MC-SHA-MISMATCH`\n\
         diagnostic with verdict `reject` and exit code 1. The\n\
         check is parser-side; it DOES NOT re-hash the file\n\
         (the schema contract is that the embedded hashes\n\
         agree, not that they were computed at validate time).\n\n\
         ### Remediation\n\
         Recompute BOTH `body_sha` and `yaml_sha` using the\n\
         placeholder-substitution algorithm: replace each\n\
         field's value with the placeholder `sha256:` + 64\n\
         zeros (same length as a real digest), sha256 the\n\
         resulting file content, and set BOTH fields to the\n\
         resulting hex digest. The reference implementation\n\
         lives in `scripts/axiom-link-seed.py:105-123`. Re-run\n\
         `mathc validate` to confirm `MC-SHA-MISMATCH` is\n\
         gone."
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
         `^A[0-9]+(@[A-Za-z0-9_.-]+)?$` (starts with `A`,
         has digits, optionally has `@rev` or `.sub` suffix).\n\n\
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
  | _ -> None

let render d =
  Printf.sprintf "[%s] %s/%s: %s"
    (string_of_severity d.severity)
    (string_of_kind d.kind) d.code d.message
