import type { ConsoleTheme } from "../shared/theme";
import type { ClaimState, EvidenceOutcome, StateReason, Verdict } from "../shared/domain";
import type { MessageKey } from "../shared/message";
import { translate } from "./i18n/translate";

export type Tone = "neutral" | "good" | "warn" | "bad" | "info";

export function toneColor(theme: ConsoleTheme, tone: Tone): string {
  switch (tone) {
    case "good": return theme.colors.statusSuccess;
    case "warn": return theme.colors.statusWarning;
    case "bad": return theme.colors.statusDanger;
    case "info": return theme.colors.accent;
    case "neutral": return theme.colors.foregroundMuted;
  }
}

export function verdictColor(theme: ConsoleTheme, verdict: Verdict): string {
  if (verdict === "green") return theme.colors.statusSuccess;
  if (verdict === "red") return theme.colors.statusDanger;
  if (verdict === "unknown") return theme.colors.statusWarning;
  return theme.colors.foregroundMuted;
}

export function claimStateColor(theme: ConsoleTheme, state: ClaimState): string {
  switch (state) {
    case "holds": return theme.colors.statusSuccess;
    case "refuted": return theme.colors.statusDanger;
    case "outdated":
    case "waived": return theme.colors.statusWarning;
    case "inconclusive": return theme.colors.accent;
    case "not-checkable":
    case "never-checked": return theme.colors.foregroundMuted;
  }
}

export function outcomeColor(theme: ConsoleTheme, outcome: EvidenceOutcome): string {
  switch (outcome) {
    case "pass": return theme.colors.statusSuccess;
    case "fail": return theme.colors.statusDanger;
    case "inconclusive": return theme.colors.statusWarning;
    case "infrastructure-error": return theme.colors.accent;
    case "not-run": return theme.colors.foregroundMuted;
  }
}

export function claimStateIcon(state: ClaimState): string {
  switch (state) {
    case "holds": return "Check";
    case "refuted": return "X";
    case "inconclusive": return "CircleHelp";
    case "not-checkable": return "Ban";
    case "outdated": return "Clock3";
    case "never-checked": return "CircleDashed";
    case "waived": return "ShieldAlert";
  }
}

export function outcomeIcon(outcome: EvidenceOutcome): string {
  switch (outcome) {
    case "pass": return "Check";
    case "fail": return "X";
    case "inconclusive": return "CircleHelp";
    case "infrastructure-error": return "TriangleAlert";
    case "not-run": return "Minus";
  }
}

export function stateOrder(state: ClaimState): number {
  switch (state) {
    case "refuted": return 0;
    case "outdated": return 1;
    case "inconclusive": return 2;
    case "not-checkable": return 3;
    case "never-checked": return 4;
    case "waived": return 5;
    case "holds": return 6;
  }
}

/**
 * The reason a state was reported.
 *
 * The text says what the map reports. It never guesses a cause the map did
 * not give, and it never promises that a check will repair anything.
 */
/**
 * The reason a state was reported.
 *
 * The text says what the map reports. It never guesses a cause the map did
 * not give, and it never promises that a check will repair anything. The
 * reason is named by a key, so the interface reads it in the language of the
 * human.
 */
const REASON_KEYS: Record<StateReason, MessageKey> = {
  current: "state.reason_current",
  "never-checked": "state.reason_never_checked",
  "source-changed": "state.reason_source_changed",
  "materials-changed": "state.reason_materials_changed",
  "definition-changed": "state.reason_definition_changed",
  "verifier-changed": "state.reason_verifier_changed",
  "environment-changed": "state.reason_environment_changed",
  expired: "state.reason_expired",
  "not-run": "state.reason_not_run",
  inconclusive: "state.reason_inconclusive",
  "infrastructure-error": "state.reason_infrastructure_error",
  refuted: "state.reason_refuted",
  waived: "state.reason_waived",
  "not-checkable": "state.reason_not_checkable",
};

/** The key of the catalogue that holds the reason of a state. */
export function stateReasonKey(reason?: StateReason): MessageKey {
  return reason === undefined ? "state.reason_unknown" : REASON_KEYS[reason];
}

/** The reason of a state in English, for the brief of an agent. */
export function stateReasonText(reason?: StateReason): string {
  return translate("en", stateReasonKey(reason));
}

export function formatTime(seconds: number): string {
  return `${new Date(seconds * 1000).toISOString().replace("T", " ").slice(0, 16)} UTC`;
}
