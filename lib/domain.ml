type timestamp = string
type id = string
type kind = Decision | Obligation | Attestation | Waiver | Change
type epistemic = Declared | Derived | Attested | Reviewed | Observed
type freshness = Fresh | Stale | AtRisk | Unknown

type acceptance =
  | All of acceptance list
  | Any of acceptance list
  | Verifier of { id : string; result : result }
  | Review of {
      review_authority : string;
      minimum_independence : string option;
    }

and result = Pass | Fail | Inconclusive | InfrastructureError

type scope_target =
  | PathTarget of { path : string; match_ : [ `Exact | `Tree ] }
  | CapabilityTarget of string
  | InterfaceTarget of string

type scope = scope_target list
type outcome = { id : id; statement : string }

type assumption = {
  id : id;
  state : [ `Assumed | `Unknown ];
  statement : string;
  owner : string;
  consequence_if_false : string option;
  review_on : (string * timestamp option) list;
}

type obligation = {
  id : id;
  decision : id;
  outcome : id option;
  claim : string;
  subjects : scope;
  acceptance : acceptance;
  kind : [ `Invariant | `Acceptance | `Recovery | `Operational ];
  phase : [ `PreMerge | `PreRelease | `PostRelease ];
}

type reversal = {
  signal : string;
  condition : string option;
  action : [ `Revert | `Halt | `Review | `Rework ];
}

type risk = { declared_triggers : string list; owner : string }

type relations = {
  supersedes : id list;
  addresses : id list;
  depends_on : id list;
}

type decision = {
  id : id;
  revision : string;
  parents : string list;
  intent_source : string;
  intent_text : string;
  commitment : string;
  scope : scope;
  outcomes : outcome list;
  obligations : obligation list;
  assumptions : assumption list;
  reversal : reversal list;
  risk : risk;
  relations : relations;
}

type attestation = {
  id : string;
  decision : id;
  decision_revision : string option;
  decision_digest : string option;
  obligation : id;
  obligation_digest : string option;
  candidate_tree : string;
  materials_digest : string;
  kind : [ `Test | `Review | `Build | `Analysis | `Observation ];
  producer_identity : string;
  producer_run : string option;
  environment_class : string option;
  result : result;
  issued_at : timestamp;
  valid_until : timestamp option;
  evidence_digest : string option;
}

type waiver = {
  id : id;
  policy_id : id;
  rule : string;
  subject : id;
  scope : scope;
  issuer : string;
  issued_at : timestamp;
  expires_at : timestamp;
  reason : string;
  unverified_obligation : id option;
  compensating_controls : string list;
}

type change = {
  id : id;
  base_commit : string;
  candidate_tree : string;
  files : (string * string) list;
  materials : (string * string) list;
  decisions : id list;
  detected_triggers : string list;
}

type gap_kind =
  | MissingEvidence
  | StaleEvidence
  | FailedEvidence
  | Inconclusive
  | InfrastructureError_
  | MissingReview
  | MissingObligation
  | SupersessionCycle
  | SelfReference

type gap = {
  id : id;
  kind : gap_kind;
  subject : id;
  obligation : id option;
  state :
    [ `Missing | `Stale | `Failed | `Inconclusive | `Infrastructure | `Waived ];
  causes : string list;
  remedies : (string * string) list;
}

type gate = Open | Open_with_waiver of id list | Blocked of gap list

type diagnostic = {
  code : string;
  kind :
    [ `Input
    | `Question
    | `Deficit
    | `Infrastructure
    | `Conflict
    | `Authorization ];
  severity : [ `Info | `Warn | `Block ];
  subject : id option;
  path : string list;
  message : string;
  cause : string list;
  policy_rule : string option;
  retryable : bool;
  autofix_safe : bool;
  next_actions : (string * string) list;
}
