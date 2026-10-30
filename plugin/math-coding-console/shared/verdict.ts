/**
 * The kernel's verdict vocabulary, and the tone the console paints it in.
 *
 * The vocabulary is deliberately open. The OCaml side emits `pass | fail |
 * unknown | stale | missing | no_store | waived` for obligations and
 * `inconclusive | skipped | setup_fail | timeout` for verifiers, and it grows
 * over time. A closed enum here would make the console crash on the day the
 * kernel learns a new word, so verdicts travel as plain strings and the
 * console maps them onto a tone it knows how to paint.
 */

export const VERDICT_TONES = ["good", "warn", "bad", "info", "neutral"] as const;

export type VerdictTone = (typeof VERDICT_TONES)[number];

/**
 * Severity order, worst first. The console sorts the promise worklist with
 * this, so the thing that breaks a gate comes before the thing that merely
 * needs a refresh.
 */
const SEVERITY: Record<string, number> = {
  fail: 0,
  stale: 1,
  missing: 2,
  unknown: 3,
  no_store: 4,
  inconclusive: 5,
  waived: 6,
  skipped: 7,
  setup_fail: 8,
  timeout: 9,
  pass: 10,
};

export function verdictSeverity(verdict: string): number {
  return SEVERITY[verdict] ?? 5;
}

export function worstVerdict(verdicts: readonly string[]): string {
  if (verdicts.length === 0) return "unknown";
  return verdicts.reduce((worst, current) =>
    verdictSeverity(current) < verdictSeverity(worst) ? current : worst,
  );
}

export function verdictTone(verdict: string): VerdictTone {
  switch (verdict) {
    case "pass":
      return "good";
    case "fail":
      return "bad";
    case "stale":
    case "missing":
    case "unknown":
    case "no_store":
    case "inconclusive":
    case "setup_fail":
    case "timeout":
      return "warn";
    case "waived":
      return "info";
    default:
      return "neutral";
  }
}

/**
 * Is this verdict a promise that is still open?
 *
 * The words that mean "not settled" live here and nowhere else. A second
 * place that names them is a second vocabulary, and two vocabularies drift:
 * one of them will call a state settled while the kernel calls it open, and
 * the console will show a green light over an open promise.
 */
export function isOpen(verdict: string): boolean {
  return verdict !== "pass" && verdict !== "waived";
}

/** A one-line human label. The kernel's words are kept; they are the contract. */
export function verdictLabel(verdict: string): string {
  switch (verdict) {
    case "pass":
      return "pass";
    case "fail":
      return "fail";
    case "stale":
      return "stale";
    case "missing":
      return "missing";
    case "unknown":
      return "unknown";
    case "no_store":
      return "no store";
    case "waived":
      return "waived";
    case "inconclusive":
      return "inconclusive";
    case "skipped":
      return "skipped";
    case "setup_fail":
      return "setup failed";
    case "timeout":
      return "timed out";
    default:
      return verdict;
  }
}
