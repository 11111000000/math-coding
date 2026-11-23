import type { ConsoleTheme } from "../shared/theme";
import type { ClaimState, EvidenceOutcome, IndependenceLevel, StateReason, Verdict } from "../shared/domain";
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
    case "waived":
    case "not-checkable": return theme.colors.statusWarning;
    case "inconclusive": return theme.colors.accent;
    case "never-checked": return theme.colors.foregroundMuted;
    case "accepted-by-a-person": return theme.colors.foregroundMuted;
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
    case "outdated": return "Clock3";
    case "never-checked": return "CircleDashed";
    case "waived": return "ShieldAlert";
    case "not-checkable": return "TriangleAlert";
    case "accepted-by-a-person": return "ShieldCheck";
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
    case "accepted-by-a-person": return 6;
    case "holds": return 7;
  }
}

/**
 * The reason of a state was reported.
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
  "tool-changed": "state.reason_tool_changed",
  "not-checkable": "state.reason_not_checkable",
};

/** The key of the catalogue that holds the reason of a state. */
export function stateReasonKey(reason?: StateReason): MessageKey {
  return reason === undefined ? "state.reason_unknown" : REASON_KEYS[reason];
}

/**
 * The tone of the reason of a state.
 *
 * The reason `tool-changed` is an information: the claim still holds, and the
 * evidence still applies, but the program that produced it is not the program
 * that reads it. The reader deserves to see that the observer changed, and the
 * reason is not a failure and not the ordinary `current` either. Every other
 * reason keeps the quiet tone of a note.
 */
export function stateReasonTone(reason?: StateReason): Tone {
  return reason === "tool-changed" ? "info" : "neutral";
}

/** The icon of the reason of a state. */
export function stateReasonIcon(reason?: StateReason): string {
  return reason === "tool-changed" ? "RefreshCw" : "CircleHelp";
}

/** The reason of a state in English, for the brief of an agent. */
export function stateReasonText(reason?: StateReason): string {
  return translate("en", stateReasonKey(reason));
}

export function formatTime(seconds: number): string {
  return `${new Date(seconds * 1000).toISOString().replace("T", " ").slice(0, 16)} UTC`;
}

/**
 * The names of the domain values the interface shows.
 *
 * A state, an outcome and a verdict are values of the method, and the method
 * names them in one language. The interface names them in the language of the
 * human, so the words live in the catalogue and the code holds the key.
 */
const CLAIM_STATE_KEYS: Record<ClaimState, MessageKey> = {
  holds: "state.claim_holds",
  refuted: "state.claim_refuted",
  inconclusive: "state.claim_inconclusive",
  outdated: "state.claim_outdated",
  "never-checked": "state.claim_never_checked",
  waived: "state.claim_waived",
  "not-checkable": "state.claim_not_checkable",
  "accepted-by-a-person": "state.claim_accepted_by_person",
};

const OUTCOME_KEYS: Record<EvidenceOutcome, MessageKey> = {
  pass: "state.outcome_pass",
  fail: "state.outcome_fail",
  inconclusive: "state.outcome_inconclusive",
  "infrastructure-error": "state.outcome_infrastructure_error",
  "not-run": "state.outcome_not_run",
};

const VERDICT_KEYS: Record<Verdict, MessageKey> = {
  green: "state.verdict_green",
  red: "state.verdict_red",
  unknown: "state.verdict_unknown",
  vacant: "state.verdict_vacant",
};

/** The key of the catalogue that holds the name of a state. */
export function claimStateKey(state: ClaimState): MessageKey {
  return CLAIM_STATE_KEYS[state];
}

/** The key of the catalogue that holds the name of an outcome. */
export function outcomeKey(outcome: EvidenceOutcome): MessageKey {
  return OUTCOME_KEYS[outcome];
}

/** The key of the catalogue that holds the name of a verdict. */
export function verdictKey(verdict: Verdict): MessageKey {
  return VERDICT_KEYS[verdict];
}

const INDEPENDENCE_KEYS: Record<IndependenceLevel, MessageKey> = {
  self: "state.independence_self",
  "fresh-context": "state.independence_fresh_context",
  external: "state.independence_external",
};

/**
 * The key of the catalogue that holds the name of an independence level.
 *
 * A record of a generation that did not name the independence of the
 * observation carries an unknown one, and the catalogue holds a word for it.
 */
export function independenceKey(level: IndependenceLevel | null): MessageKey {
  if (level === null) return "state.independence_unknown";
  return INDEPENDENCE_KEYS[level];
}

/**
 * The key of the catalogue that holds the name of a kind of requirement.
 *
 * The tree of the requirements is drawn in the graph, and its nodes carry the
 * kind of the node: all, any, a verifier or a review.
 */
export function requirementKindKey(kind: string): MessageKey | null {
  switch (kind) {
    case "all": return "state.requirement_all";
    case "any": return "state.requirement_any";
    case "verifier": return "state.requirement_verifier";
    case "review": return "state.requirement_review";
    default: return null;
  }
}
