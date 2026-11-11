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

val outcome_to_string : outcome -> string
val outcome_of_string : string -> outcome option
val independence_to_string : independence -> string
val independence_of_string : string -> independence option
val independence_rank : independence -> int
val source_kind_to_string : source_kind -> string
val source_kind_of_string : string -> source_kind option
val obligation_kind_to_string : obligation_kind -> string
val obligation_kind_of_string : string -> obligation_kind option
val phase_to_string : phase -> string
val phase_of_string : string -> phase option
val register_to_string : register -> string
val register_of_string : string -> register option
val state_to_string : state -> string
val verdict_to_string : verdict -> string
val verdict_to_exit : verdict -> int
val digest_string : string -> string
val definition_digest : claim -> string
val verifier_digest : claim -> string
