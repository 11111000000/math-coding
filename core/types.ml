(* core/types.ml — type definitions for math-coding v2.0-Y.

   The Decision type mirrors math/modeling/syntax.tex verbatim.
   See theorem `curry-howard.triple` for the formal specification.

   Any divergence between this OCaml code and the LaTeX is recorded
   as a `KNOWN DIVERGENCE` comment with an issue reference. *)

(* --- Decision --- *)

type substrate =
  | None
  | Shell of { run : string }
  | Pbt   of { run : string }
  | Tla   of { spec : string }
  | Coq   of { spec : string }
  | Alloy of { spec : string }
  | Bpmn  of { spec : string }
  | PbtPrism of { run : string }

type witness_entry = {
  sha  : string;
  date : string;
  by   : string;
}

(* See Theorem: motivation.register-and-why *)
type register =
  | RFact
  | RHypothesis
  | RJudgment
  | RUnknown

(* See Theorem: process-fsm.fsm *)
type fsm_state =
  | SDraft
  | SApplied
  | SReviewed
  | SRetired
  | SAbandoned

type actor =
  | AHuman
  | AAgent
  | ASystem

type beneficiary =
  | User
  | Developer
  | Team
  | FutureSelf
  | System
  | Other of string

type decision = {
  schema_version : string;
  name          : string;
  proposition   : string;
  code          : string option;
  witness       : witness_entry option;
  register      : register;
  state         : fsm_state;
  actor         : actor;
  confidence    : float;
  superseded_by : string option;
  beneficiary   : beneficiary;
  substrate     : substrate;
}

(* --- Kernel output --- *)

type verdict = Pass | Warn | Fail | Skip

type lifecycle = Draft | Applied | Drift | Stale

type status = {
  lifecycle : lifecycle;
  verdict   : verdict;
  reason    : string option;
}

(* --- Helpers --- *)

let verdict_to_string = function
  | Pass -> "Pass"
  | Warn -> "Warn"
  | Fail -> "Fail"
  | Skip -> "Skip"

let lifecycle_to_string = function
  | Draft   -> "draft"
  | Applied -> "applied"
  | Drift   -> "drift"
  | Stale   -> "stale"

let register_to_string = function
  | RFact       -> "fact"
  | RHypothesis -> "hypothesis"
  | RJudgment   -> "judgment"
  | RUnknown    -> "unknown"

let register_of_string = function
  | "fact"       -> RFact
  | "hypothesis" -> RHypothesis
  | "judgment"   -> RJudgment
  | "unknown"    -> RUnknown
  | _            -> RFact (* default; V3 fails on inconsistency *)

let fsm_state_to_string = function
  | SDraft    -> "draft"
  | SApplied  -> "applied"
  | SReviewed -> "reviewed"
  | SRetired  -> "retired"
  | SAbandoned -> "abandoned"

let fsm_state_of_string = function
  | "draft"    -> SDraft
  | "applied"  -> SApplied
  | "reviewed" -> SReviewed
  | "retired"  -> SRetired
  | "abandoned" -> SAbandoned
  | _          -> SDraft (* default *)

let actor_to_string = function
  | AHuman  -> "human"
  | AAgent  -> "agent"
  | ASystem -> "system"

let actor_of_string = function
  | "human"  -> AHuman
  | "agent"  -> AAgent
  | "system" -> ASystem
  | _        -> AAgent

let beneficiary_to_string = function
  | User       -> "user"
  | Developer  -> "developer"
  | Team       -> "team"
  | FutureSelf -> "future_self"
  | System     -> "system"
  | Other s    -> "Other:" ^ s

let beneficiary_of_string = function
  | "user"        -> User
  | "developer"   -> Developer
  | "team"        -> Team
  | "future_self" -> FutureSelf
  | "system"      -> System
  | s when String.length s > 6 && String.sub s 0 6 = "Other:" ->
    Other (String.sub s 6 (String.length s - 6))
  | _ -> System

let substrate_path (s : substrate) : string option =
  match s with
  | None -> None
  | Shell r -> Some r.run
  | Pbt r -> Some r.run
  | Tla r -> Some r.spec
  | Coq r -> Some r.spec
  | Alloy r -> Some r.spec
  | Bpmn r -> Some r.spec
  | PbtPrism r -> Some r.run

let empty_decision name = {
  schema_version = "2.0";
  name;
  proposition = "";
  code = None;
  witness = None;
  register = RFact;
  state = SDraft;
  actor = AAgent;
  confidence = 0.5;
  superseded_by = None;
  beneficiary = System;
  substrate = None;
}

let schema_version_of_string = function
  | "2.0" -> "2.0"
  | _    -> "unknown"