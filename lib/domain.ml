type outcome =
  | Pass
  | Fail
  | Inconclusive
  | Infrastructure_error
  | Not_run

type verdict = Green | Red | Unknown | Vacant
type independence = Self_attested | Fresh_context | External
type risk = Low | Medium | High

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
}

type claim = {
  id : string;
  text : string;
  scope : string list;
  source : source_ref option;
  owner : string option;
  risk : risk;
  archived : bool;
  (* Empty means "unclassified"; claim_risks always returns a semantic label. *)
  risks : string list;
  requirements : requirement list;
  falsifier : string;
  register : register;
  control : string option;
  waiver : waiver option;
  (* Its own environment when it declares one, else the one of the spec. *)
  environment : string option;
}
type environment = { class_ : string; fingerprint : string }
type producer = { class_ : string; identity : string; run : string option }

(* The tool that produced a record: the binary that wrote it. It is not a
   freshness binding - the evidence stays applicable when the tool changes -
   but the map names the difference, so the reader knows that the observer of
   the evidence is not the observer of the map. *)
type tool = { class_ : string; fingerprint : string }

type evidence = {
  claim_id : string;
  requirement : requirement;
  candidate_tree : string;
  materials_digest : string;
  definition_digest : string;
  verifier_digest : string;
  environment : environment;
  tool : tool;
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

type state = Holds | Refuted | Inconclusive | Outdated | NeverChecked | Waived | Observed
type goal = { text : string; scope : string list; by : string; at : int; reason : string option }
type spec = { goal : goal option; claims : claim list; environment : string option }

(* The effective environment of a claim: its own, else the one of the spec. *)
let effective_environment (spec : spec) (claim : claim) =
  match claim.environment with Some value -> Some value | None -> spec.environment

let active_claims (spec : spec) = List.filter (fun (claim : claim) -> not claim.archived) spec.claims

let valid_risk_label value =
  value <> ""
  && String.length value <= 128
  && not (String.exists (fun ch -> ch < ' ' || ch = '\127') value)

let claim_risks (claim : claim) =
  if claim.risks = [] then [ "unclassified" ] else claim.risks
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
  | Outdated -> "outdated"
  | NeverChecked -> "never-checked"
  | Waived -> "waived"
  | Observed -> "observed"

let risk_to_string = function
  | Low -> "low"
  | Medium -> "medium"
  | High -> "high"

let risk_of_string = function
  | "low" -> Some Low
  | "medium" -> Some Medium
  | "high" -> Some High
  | _ -> None

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
  [ c.id; c.text; String.concat "," c.scope; Option.value ~default:"" c.owner;
    String.concat ";" requirements; c.falsifier; register_to_string c.register;
    risk_to_string c.risk; string_of_bool c.archived;
    String.concat "," (claim_risks c) ]
  @ source
  |> String.concat "\n"
  |> digest_string

(* The declared environment is a prefix of the check and of the control, so it
   belongs to the digest of the check. *)
let verifier_digest c =
  let commands = List.concat_map verifier_commands c.requirements in
  let environment = match c.environment with None -> [] | Some value -> [ "environment=" ^ value ] in
  String.concat "\n" (environment @ commands @ Option.to_list c.control) |> digest_string
