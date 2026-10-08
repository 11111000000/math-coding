(* lib/domain.ml — math-coding 3.2-ideal algebra types.
   See spec/algebra-3.2.md §7 (Decision), §13 (Attestation),
   §15 (phase-aware gate), §17 (Axiom change), and the schemas
   under schemas/ for the canonical field names.

   v3.2 extensions over 3.0:
     - decision.state:    draft | active | retired | superseded
     - decision.mode:     tiny | light | standard | strict | exhaustive
     - decision.mode_floor_used, body_sha, yaml_sha (optional)
     - decision.counterexample: optional string (algebra §7)
     - assumption.state widened to 5 epistemic markers + `Assumed`
       legacy value; new evidence, confidence fields
     - relations extended to 8 kinds (revises, supersedes, refines,
       depends_on, conflicts_with, addresses, implements, verifies)
       and a superseded_by inverse
     - obligation.phase, obligation.obligation_domain extracted
     - attestation extended with environment_class_level,
       environment_class_label, substrate_digest,
       substrate_fingerprint, ci_run_id

   Backward compatibility: 27 of 28 active decisions in decisions/*.yaml
   carry at least one assumption in the legacy `Assumed` state (verified
   at HEAD via `grep -c '^state: assumed' decisions/*.yaml`). The widened
   epistemic_marker enum preserves `Assumed and `Unknown alongside the
   four new markers `Fact | `Hypothesis | `Judgment | `Proven. `Unknown
   is shared between the legacy and 3.2 enums — they are the same
   variant. *)

type timestamp = string
type id = string
type kind = Decision | Obligation | Attestation | Waiver | Change
type epistemic = Declared | Derived | Attested | Reviewed | Observed
type freshness = Fresh | Stale | AtRisk | Unknown

(* Enforcement phase for an obligation (algebra §15).
   - `PreMerge    : blocking for the merge gate
   - `PreRelease  : blocking for the release gate (in addition to merge)
   - `PostRelease : monitoring-only; violations surface as AssuranceGap
                    and never block merge or release. *)
type phase = [ `PreMerge | `PreRelease | `PostRelease ]

(* Assurance mode. Used as a floor on what the kernel will demand
   (algebra §3, §7). Five levels, monotonically increasing. *)
type mode = [ `Tiny | `Light | `Standard | `Strict | `Exhaustive ]

(* Trust level (algebra §1 universal set 𝓣, §10 rebuttal binding,
   §12 trust dynamics). Monotonic: Untrusted < Authenticated <
   Delegated < Authoritative. Carried by the rebutter at the time
   a rebuttal is recorded (`trust_level_at_rebuttal`); the binding
   check (algebra §10) compares this rank against the authority
   floor required by the obligation's mode. *)
type trust = [ `Untrusted | `Authenticated | `Delegated | `Authoritative ]

(* Coarse environment class label (algebra §13, §14).
   Matches schemas/common.json#/definitions/environment_class_label. *)
type environment_class_label =
  [ `Dev | `Staging | `StagingIntegration | `ProdMirror | `Prod ]

(* 5 epistemic markers (algebra §7, axiom A5 v0.854).
   The legacy 3.0 value `Assumed is preserved here so the same
   field name (`state`) can carry both the legacy 3.0 enum and
   the 3.2 marker enum without a parallel field.
   `Unknown is shared by both enums and means the same thing in
   each. *)
type epistemic_marker =
  [ `Fact | `Hypothesis | `Judgment | `Unknown | `Proven | `Assumed ]

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

(* obligation_domain — algebra §1, §8. Classifier pair
   (obligation_kind × path_namespace) used by the auto-inference
   rule and by the trust function. *)
type obligation_domain = { obligation_kind : string; path_namespace : string }

(* Assumption (algebra §7). `state` is the widened 5-marker
   epistemic_marker; legacy `Assumed maps to `Assumed;
   `Unknown is shared. `evidence` is required when state = `Judgment
   (human-rationale observation); `confidence is required when
   state ∈ {`Fact, `Hypothesis} and is otherwise optional. *)
type assumption = {
  id : id;
  state : epistemic_marker;
  statement : string;
  owner : string;
  consequence_if_false : string option;
  review_on : (string * timestamp option) list;
  evidence : string option;
  confidence : float option;
}

type obligation = {
  id : id;
  decision : id;
  outcome : id option;
  claim : string;
  subjects : scope;
  acceptance : acceptance;
  kind : [ `Invariant | `Acceptance | `Recovery | `Operational ];
  phase : phase;
  obligation_domain : obligation_domain option;
}

type reversal = {
  signal : string;
  condition : string option;
  action : [ `Revert | `Halt | `Review | `Rework ];
}

type risk = { declared_triggers : string list; owner : string }

(* Relations (algebra §7, 8 kinds). supersedes/revises/refines/
   depends_on are acyclic (I6, I7). conflicts_with is symmetric.
   superseded_by is the inverse of supersedes — already used by
   existing decisions; formalised in 3.2. *)
type relations = {
  revises : id list;
  supersedes : id list;
  superseded_by : id list;
  refines : id list;
  depends_on : id list;
  conflicts_with : id list;
  addresses : id list;
  implements : id list;
  verifies : id list;
}

(* Decision entity (algebra §7). body_sha and yaml_sha must
   agree (body_sha = yaml_sha) when both are present. mode_floor_used
   is the assurance floor that the agent adopted when authoring this
   Decision; it is informational. counterexample is required for
   modes ≥ light (algebra §11) but is optional here so that
   parser layer can default it. axiom_link carries the axiom IDs
   (e.g. "A1", "A3") this Decision addresses; the JSON schema
   lists it as a top-level array property (schemas/decision.json)
   even though the algebra §7 syntax only carries the `addresses`
   relation. It is additive and defaults to [] when absent. *)
type decision = {
  id : id;
  rev : string;
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
  counterexample : string option;
  state : [ `Draft | `Active | `Retired | `Superseded ];
  mode : mode;
  mode_floor_used : mode option;
  body_sha : string option;
  yaml_sha : string option;
  axiom_link : string list;
}

(* Attestation entity (algebra §13). environment_class is the
   legacy free-form string; environment_class_level + label are
   the typed 3.2 form. substrate_digest and substrate_fingerprint
   anchor the attestation to the substrate it was produced
   against (algebra §16). ci_run_id closes the id derivation
   loop in algebra §13. *)
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
  environment_class_level : int option;
  environment_class_label : environment_class_label option;
  result : result;
  issued_at : timestamp;
  valid_until : timestamp option;
  evidence_digest : string option;
  substrate_digest : string option;
  substrate_fingerprint : string option;
  ci_run_id : string option;
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

(* ExecutionLog — declared by decisions/time-honesty.yaml.
   Holds the wall-clock / token-budget / step-count observation
   that closes the time-honesty feedback loop. The runtime
   harness writes this; the agent cites it. Never constructed by
   the parser in commit 2b853ca; it is added now as a domain
   entity so that future parsers and attesters have a sealed
   type. The new constructor `ExecutionLog` is intentionally
   NOT added to `kind` (which stays sealed at five); ExecutionLog
   is observation, Attestation is certification — they are
   distinct per A0 (Separation). *)
type execution_scale = [ `WallClockMinutes | `TokenBudget | `StepCount ]

type execution_log = {
  scale : execution_scale;
  value : float;
  observed_at : timestamp;
  observed_by : id;
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

(* `lib/gate.ml::attestation_kind_str` is the live implementation
   of the attestation-kind-to-string mapping. It is colocated
   with `required_attestation_satisfied` because the kind field
   of `Domain.attestation` collides with the top-level
   `Domain.kind` type alias; the record pattern
   `match a with | { kind = \`Review; _ } -> ...` works because
   in pattern context the label `kind` resolves to the record
   field, not the type alias. Moving the helper into
   `lib/domain.ml` would re-introduce the same collision. *)
