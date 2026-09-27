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
let ambiguous_acceptance ?(obligation_id = "") ?(item_position = -1) () =
  let pos_str =
    if item_position >= 0 then Printf.sprintf " (all[%d])" item_position else ""
  in
  let msg =
    Printf.sprintf
      "obligation %s: acceptance item carries both verifier and review%s; \
       verifier wins, review is dropped"
      obligation_id pos_str
  in
  create ~code:"MC-AMBIGUOUS-ACCEPTANCE" ~kind:Conflict ~severity:Warn msg

(* MC-MALFORMED-ACCEPTANCE: emitted when an acceptance item has the
   right field shape (verifier+result OR review) but the values do
   not parse. E.g., verifier="x" with result="bogus" — `result` is
   not one of pass/fail/inconclusive/infrastructure-error. *)
let malformed_acceptance ?(obligation_id = "") ?(item_position = -1) reason =
  let pos_str =
    if item_position >= 0 then Printf.sprintf " (all[%d])" item_position else ""
  in
  let msg =
    Printf.sprintf "obligation %s: acceptance item%s is malformed: %s"
      obligation_id pos_str reason
  in
  create ~code:"MC-MALFORMED-ACCEPTANCE" ~kind:Input ~severity:Warn msg

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

let render d =
  Printf.sprintf "[%s] %s/%s: %s"
    (string_of_severity d.severity)
    (string_of_kind d.kind) d.code d.message
