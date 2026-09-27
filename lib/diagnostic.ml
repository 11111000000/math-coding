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
