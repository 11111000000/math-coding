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

(* MC-COUNTEREXAMPLE-MISSING: emitted when a `state: active`
   decision has no `counterexample` field (a dialectical slot
   required for mode >= light per spec/algebra-3.2.md §11).
   Verdict stays `accept`; the diagnostic is a Warn. *)
let mc_counterexample_missing ?(decision_id = "") ?(next_actions = []) message =
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
  create ~code ~kind:Deficit ~severity:Warn ~next_actions:actions
    ~retryable:false ~autofix_safe:false message

(* Aliases — the stream η (T4.1) compact contract refers to the
   `mc_` prefix; the existing call sites in bin/Mathc.ml use the
   unprefixed names. Both names refer to the same function so that
   old and new code can coexist; new code should prefer the `mc_`
   form per the convention codified in
   decisions/plan-2026-10-improvements/t4-1.yaml. *)
let mc_ambiguous_acceptance = ambiguous_acceptance
let mc_malformed_acceptance = malformed_acceptance

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
         A `state: active` decision carries an empty\n\
         `counterexample` field. Spec/algebra-3.2.md §11 names\n\
         the counterexample as a required dialectical slot for\n\
         modes >= light.\n\n\
         ### Occurs when\n\
         `mathc validate` emits this as a Warn diagnostic; the\n\
         verdict stays `accept` (counterexample is a dialectical\n\
         slot, not a hard requirement) so legacy decisions stay\n\
         valid. The diagnostic reminds the author to add it.\n\n\
         ### Remediation\n\
         Add a `counterexample: |` block with one or two\n\
         sentences naming the strongest objection to the\n\
         decision. Re-run `mathc validate`."
  | _ -> None

let render d =
  Printf.sprintf "[%s] %s/%s: %s"
    (string_of_severity d.severity)
    (string_of_kind d.kind) d.code d.message
