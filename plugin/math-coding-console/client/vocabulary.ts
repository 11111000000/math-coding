import type { PluginTheme } from "@getpaseo/plugin";
import type { ClaimState, EvidenceOutcome, Verdict } from "../shared/domain";

export type Tone = "neutral" | "good" | "warn" | "bad" | "info";

export function toneColor(theme: PluginTheme, tone: Tone): string {
  switch (tone) {
    case "good": return theme.colors.statusSuccess;
    case "warn": return theme.colors.statusWarning;
    case "bad": return theme.colors.statusDanger;
    case "info": return theme.colors.accent;
    case "neutral": return theme.colors.foregroundMuted;
  }
}

export function verdictColor(theme: PluginTheme, verdict: Verdict): string {
  if (verdict === "green") return theme.colors.statusSuccess;
  if (verdict === "red") return theme.colors.statusDanger;
  if (verdict === "unknown") return theme.colors.statusWarning;
  return theme.colors.foregroundMuted;
}

export function claimStateColor(theme: PluginTheme, state: ClaimState): string {
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

export function outcomeColor(theme: PluginTheme, outcome: EvidenceOutcome): string {
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

export function formatTime(seconds: number): string {
  return `${new Date(seconds * 1000).toISOString().replace("T", " ").slice(0, 16)} UTC`;
}
