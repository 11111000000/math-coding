type outcome =
  | Pass
  | Fail
  | Inconclusive
  | Infrastructure_error
  | Not_run

type verdict = Green | Red | Unknown | Vacant
type independence = Self_attested | Fresh_context | External

type source_kind =
  | Madr
  | Adr_tools
  | Arc42
  | Task
  | Specification

type source_review = {
  by : string;
  reason : string;
  at : int;
  previous_digest : string;
}

type source_ref = {
  kind : source_kind;
  path : string;
  section : string option;
  digest : string;
  review : source_review option;
}

type obligation_kind = Invariant | Acceptance | Recovery | Operational | Judgment
type phase = Pre_merge | Pre_release | Post_release
type register = Fact | Hypothesis | Judgment | Undeclared

type requirement =
  | Verifier of string
  | Review of { authority : string; minimum_independence : independence }
  | All of requirement list
  | Any of requirement list

type waiver = {
  gap : string;
  scope : string list;
  issuer : string;
  issued_at : int;
  expires_at : int;
  reason : string;
  compensating_controls : string list;
  recovery : string;
  review_on : string list;
}

type claim = {
  id : string;
  text : string;
  scope : string list;
  source : source_ref option;
  kind : obligation_kind;
  phase : phase;
  owner : string option;
  review_on : string list;
  requirements : requirement list;
  falsifier : string;
  register : register;
  control : string option;
  waiver : waiver option;
}

type environment = { class_ : string; fingerprint : string }
type producer = { class_ : string; identity : string; run : string option }

type evidence = {
  claim_id : string;
  requirement : requirement;
  candidate_tree : string;
  materials_digest : string;
  definition_digest : string;
  verifier_digest : string;
  environment : environment;
  producer : producer;
  independence : independence;
  outcome : outcome;
  issued_at : int;
  valid_until : int option;
  evidence_ref : string option;
  control_reach : string option;
}

type execution_scale = Wall_clock_seconds | Tokens | Steps
type execution_log = {
  scale : execution_scale;
  value : float;
  observed_at : int;
  observed_by : string;
}

type state = Holds | Refuted | Inconclusive | NotCheckable | Outdated | NeverChecked | Waived
type goal = { text : string; scope : string list; by : string; at : int; reason : string option }
type spec = { goal : goal option; claims : claim list }

let outcome_to_string = function
  | Pass -> "pass"
  | Fail -> "fail"
  | Inconclusive -> "inconclusive"
  | Infrastructure_error -> "infrastructure-error"
  | Not_run -> "not-run"

let outcome_of_string = function
  | "pass" -> Some Pass
  | "fail" -> Some Fail
  | "inconclusive" -> Some Inconclusive
  | "infrastructure-error" -> Some Infrastructure_error
  | "not-run" -> Some Not_run
  | _ -> None

let independence_to_string = function
  | Self_attested -> "self"
  | Fresh_context -> "fresh-context"
  | External -> "external"

let independence_of_string = function
  | "self" -> Some Self_attested
  | "fresh-context" -> Some Fresh_context
  | "external" -> Some External
  | _ -> None

let independence_rank = function Self_attested -> 0 | Fresh_context -> 1 | External -> 2

let source_kind_to_string = function
  | Madr -> "madr"
  | Adr_tools -> "adr-tools"
  | Arc42 -> "arc42"
  | Task -> "task"
  | Specification -> "specification"

let source_kind_of_string = function
  | "madr" -> Some Madr
  | "adr-tools" -> Some Adr_tools
  | "arc42" -> Some Arc42
  | "task" -> Some Task
  | "specification" -> Some Specification
  | _ -> None

let obligation_kind_to_string = function
  | Invariant -> "invariant"
  | Acceptance -> "acceptance"
  | Recovery -> "recovery"
  | Operational -> "operational"
  | Judgment -> "judgment"

let obligation_kind_of_string = function
  | "invariant" -> Some Invariant
  | "acceptance" -> Some Acceptance
  | "recovery" -> Some Recovery
  | "operational" -> Some Operational
  | "judgment" -> Some Judgment
  | _ -> None

let phase_to_string = function
  | Pre_merge -> "pre-merge"
  | Pre_release -> "pre-release"
  | Post_release -> "post-release"

let phase_of_string = function
  | "pre-merge" -> Some Pre_merge
  | "pre-release" -> Some Pre_release
  | "post-release" -> Some Post_release
  | _ -> None

let register_to_string = function
  | Fact -> "fact"
  | Hypothesis -> "hypothesis"
  | Judgment -> "judgment"
  | Undeclared -> "unknown"

let register_of_string = function
  | "fact" -> Some Fact
  | "hypothesis" -> Some Hypothesis
  | "judgment" -> Some Judgment
  | "unknown" -> Some Undeclared
  | _ -> None

let state_to_string = function
  | Holds -> "holds"
  | Refuted -> "refuted"
  | Inconclusive -> "inconclusive"
  | NotCheckable -> "not-checkable"
  | Outdated -> "outdated"
  | NeverChecked -> "never-checked"
  | Waived -> "waived"

let verdict_to_string = function
  | Green -> "green"
  | Red -> "red"
  | Unknown -> "unknown"
  | Vacant -> "vacant"

let verdict_to_exit = function Green -> 0 | Red -> 1 | Unknown | Vacant -> 3

let digest_string text = Digestif.SHA256.(to_hex (digest_string text))

let rec requirement_repr = function
  | Verifier command -> "verifier:" ^ command
  | Review { authority; minimum_independence } ->
      "review:" ^ authority ^ ":" ^ independence_to_string minimum_independence
  | All requirements -> "all(" ^ String.concat ";" (List.map requirement_repr requirements) ^ ")"
  | Any requirements -> "any(" ^ String.concat ";" (List.map requirement_repr requirements) ^ ")"

let rec verifier_commands = function
  | Verifier command -> [ command ]
  | Review _ -> []
  | All requirements | Any requirements -> List.concat_map verifier_commands requirements

let definition_digest c =
  let source =
    match c.source with
    | None -> []
    | Some s ->
        let review =
          match s.review with
          | None -> [ ""; ""; "0"; "" ]
          | Some r -> [ r.by; r.reason; string_of_int r.at; r.previous_digest ]
        in
        [ source_kind_to_string s.kind; s.path; Option.value ~default:"" s.section; s.digest ] @ review
  in
  let requirements = List.map requirement_repr c.requirements |> List.sort_uniq String.compare in
  [ c.id; c.text; String.concat "," c.scope; obligation_kind_to_string c.kind;
    phase_to_string c.phase; Option.value ~default:"" c.owner;
    String.concat "," (List.sort_uniq String.compare c.review_on);
    String.concat ";" requirements; c.falsifier; register_to_string c.register ]
  @ source
  |> String.concat "\n"
  |> digest_string

let verifier_digest c =
  let commands = List.concat_map verifier_commands c.requirements in
  String.concat "\n" (commands @ Option.to_list c.control) |> digest_string
