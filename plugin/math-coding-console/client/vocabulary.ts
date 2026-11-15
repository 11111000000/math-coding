import type { ConsoleTheme } from "../shared/theme";
import type { ClaimState, EvidenceOutcome, StateReason, Verdict } from "../shared/domain";

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
export const UNKNOWN_STATE_REASON = "This version does not report a reason for this state.";

const REASON_TEXT: Record<StateReason, string> = {
  current: "The recorded evidence is fresh and still applies to this claim.",
  "never-checked": "No check has produced evidence for this claim yet.",
  "source-changed": "The linked source changed after the evidence was recorded.",
  "materials-changed": "The materials covered by this claim changed after the evidence was recorded.",
  "definition-changed": "The definition of this claim changed after the evidence was recorded.",
  "verifier-changed": "The verifier changed after the evidence was recorded.",
  "environment-changed": "The environment changed after the evidence was recorded, for example because the built program is now a different one.",
  expired: "The recorded evidence passed its validity period and no current result replaced it.",
  "not-run": "The declared check did not run, so the claim has no current observation.",
  inconclusive: "The check ran, but the observation neither established nor refuted the claim.",
  "infrastructure-error": "The check could not produce an observation because of an infrastructure error.",
  refuted: "A current observation contradicted the claim.",
  waived: "A recorded waiver covers the gap of this claim.",
  "not-checkable": "No declared condition can establish or refute this claim.",
};

export function stateReasonText(reason?: StateReason): string {
  return reason === undefined ? UNKNOWN_STATE_REASON : REASON_TEXT[reason];
}

export function formatTime(seconds: number): string {
  return `${new Date(seconds * 1000).toISOString().replace("T", " ").slice(0, 16)} UTC`;
}
