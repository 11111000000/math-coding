import type { MessageKey } from "./message";

/**
 * The errors the console knows by name.
 *
 * A failure the human is meant to read travels as a code, not as a sentence.
 * The sentence lives in the catalogue of the interface, so the same failure
 * reads in the language the human chose; a code the catalogue does not hold is
 * shown as it is, because an invented translation would hide the failure.
 *
 * The errors that carry the output of the program — an exit code, a path, a
 * line of the standard error — keep their text. They report what happened, not
 * what the interface says.
 */

export const ERROR_CODES = [
  "run_checks_disabled",
  "human_decisions_disabled",
  "run_checks_needs_confirmation",
  "human_decision_needs_confirmation",
  "decision_not_available",
  "binary_path_not_absolute",
  "binary_not_mathc5",
  "map_inconsistent",
  "claim_sets_differ",
  "goals_differ",
  "project_changed",
  "workspace_busy",
  "workspace_unavailable",
  "review_needs_claim",
  "record_needs_claim",
  "record_needs_authority",
  "waive_needs_claim",
  "outcome_unknown",
  "validity_whole",
  "validity_positive",
  "decision_needs_by",
  "decision_needs_reason",
  "decision_needs_reason_accepted_risk",
  "decision_needs_reason_authorization",
  "decision_needs_outcome",
  "decision_needs_validity",
  "decision_needs_recovery",
  "days_required",
  "settings_invalid_json",
  "settings_invalid_shape",
  "settings_conflict",
  "settings_unavailable",
  "settings_not_saved",
  "settings_not_reset",
  "settings_invalid",
] as const;

export type ErrorCode = (typeof ERROR_CODES)[number];

/** The key of the catalogue that holds the text of a code. */
export const ERROR_KEYS: Record<ErrorCode, MessageKey> = {
  run_checks_disabled: "error.run_checks_disabled",
  human_decisions_disabled: "error.human_decisions_disabled",
  run_checks_needs_confirmation: "error.run_checks_needs_confirmation",
  human_decision_needs_confirmation: "error.human_decision_needs_confirmation",
  decision_not_available: "error.decision_not_available",
  binary_path_not_absolute: "error.binary_path_not_absolute",
  binary_not_mathc5: "error.binary_not_mathc5",
  map_inconsistent: "error.map_inconsistent",
  claim_sets_differ: "error.claim_sets_differ",
  goals_differ: "error.goals_differ",
  project_changed: "error.project_changed",
  workspace_busy: "error.workspace_busy",
  workspace_unavailable: "error.workspace_unavailable",
  review_needs_claim: "error.review_needs_claim",
  record_needs_claim: "error.record_needs_claim",
  record_needs_authority: "error.record_needs_authority",
  waive_needs_claim: "error.waive_needs_claim",
  outcome_unknown: "error.outcome_unknown",
  validity_whole: "error.validity_whole",
  validity_positive: "error.validity_positive",
  decision_needs_by: "error.decision_needs_by",
  decision_needs_reason: "error.decision_needs_reason",
  decision_needs_reason_accepted_risk: "error.decision_needs_reason_accepted_risk",
  decision_needs_reason_authorization: "error.decision_needs_reason_authorization",
  decision_needs_outcome: "error.decision_needs_outcome",
  decision_needs_validity: "error.decision_needs_validity",
  decision_needs_recovery: "error.decision_needs_recovery",
  days_required: "error.days_required",
  settings_invalid_json: "error.settings_invalid_json",
  settings_invalid_shape: "error.settings_invalid_shape",
  settings_conflict: "error.settings_conflict",
  settings_unavailable: "error.settings_unavailable",
  settings_not_saved: "error.settings_not_saved",
  settings_not_reset: "error.settings_not_reset",
  settings_invalid: "error.settings_invalid",
};

export function isErrorCode(value: string): value is ErrorCode {
  return (ERROR_CODES as readonly string[]).includes(value);
}

/**
 * A failure that travels as a code.
 *
 * The detail is the data of the failure: the list of the accepted outcomes,
 * for example. It is never translated, because it is not a sentence.
 */
export class CodedError extends Error {
  readonly code: ErrorCode;
  readonly detail: string | undefined;

  constructor(code: ErrorCode, detail?: string) {
    super(detail === undefined ? code : `${code}: ${detail}`);
    this.name = "CodedError";
    this.code = code;
    this.detail = detail;
  }
}

/**
 * The code and the detail of a failure that reached the client.
 *
 * A failure that carries no code is the text of the program or of the host;
 * the console shows it as it is.
 */
export function readCodedError(error: unknown): { code: ErrorCode; detail: string | undefined } | null {
  const message = error instanceof Error ? error.message : String(error);
  const separator = message.indexOf(": ");
  const head = separator === -1 ? message : message.slice(0, separator);
  if (!isErrorCode(head)) return null;
  return { code: head, detail: separator === -1 ? undefined : message.slice(separator + 2) };
}
