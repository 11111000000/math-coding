import { runMathc, runMathcJson } from "./mathc";

/**
 * Typed readers over the kernel's JSON output.
 *
 * Every function here asks the kernel a question and returns the answer. None
 * of them re-derives a verdict, counts a promise, or decides whether a
 * promise is satisfied — that is the kernel's job, and a second measurer in
 * the console would be a second opinion nobody asked for.
 *
 * The parsers are deliberately tolerant: a kernel that grows a field must not
 * break the console, and a kernel that lacks a subcommand must degrade to a
 * warning rather than an exception.
 */

/* ---------------------------------------------------------------- counters */

export interface KernelCounters {
  decisionsTotal: number;
  decisionsActive: number;
  obligationsTotal: number;
  obligationsByVerdict: Record<string, number>;
  attestations: number;
  cramTests: number;
  cliSubcommands: number;
  selfCheckVerdict: string;
}

export async function readCounters(root: string): Promise<{ value: KernelCounters | null; error: string | null }> {
  const result = await runMathcJson<Record<string, unknown>>(root, ["counters"]);
  if (!result.ok) return { value: null, error: result.error };

  const root_ = result.value;
  const decisions = asObject(root_.decisions);
  const obligations = asObject(root_.obligations);
  const attestations = asObject(root_.attestations);
  const tests = asObject(root_.tests);
  const cli = asObject(root_.cli);
  const selfCheck = asObject(root_.self_check);

  const byVerdict: Record<string, number> = {};
  for (const [key, value] of Object.entries(obligations)) {
    if (typeof value === "number" && key !== "total" && key !== "decision_count") {
      byVerdict[key] = value;
    }
  }

  return {
    value: {
      decisionsTotal: asNumber(decisions.total),
      decisionsActive: asNumber(decisions.active),
      obligationsTotal: asNumber(obligations.total),
      obligationsByVerdict: byVerdict,
      attestations: asNumber(attestations.live_store),
      cramTests: asNumber(tests.cram_count),
      cliSubcommands: asNumber(cli.subcommand_count),
      selfCheckVerdict: asString(selfCheck.verdict),
    },
    error: null,
  };
}

/* ------------------------------------------------------------------- gaps */

export interface KernelPromise {
  decision: string;
  obligation: string;
  class: string;
  state: string;
  verifiers: string[];
  cause: string;
  action: string;
}

export interface KernelGaps {
  counts: {
    declared: number;
    open: number;
    waived: number;
    byClass: Record<string, number>;
    byState: Record<string, number>;
  };
  open: KernelPromise[];
}

export async function readGaps(root: string): Promise<{ value: KernelGaps | null; error: string | null }> {
  const result = await runMathcJson<Record<string, unknown>>(root, ["gaps", "--format=json"]);
  if (!result.ok) {
    // A kernel older than the promise census does not know the command. The
    // usage text it prints is not a diagnostic; the first line is.
    const firstLine = result.error.split("\n")[0]?.trim() ?? result.error;
    return { value: null, error: firstLine.slice(0, 300) };
  }

  const counts = asObject(result.value.counts);
  const open: KernelPromise[] = [];
  for (const entry of asArray(result.value.open)) {
    const record = asObject(entry);
    open.push({
      decision: asString(record.decision),
      obligation: asString(record.obligation),
      class: asString(record.class),
      state: asString(record.state),
      verifiers: asArray(record.verifiers).map(asString).filter((item) => item !== ""),
      cause: asString(record.cause),
      action: asString(record.action),
    });
  }

  return {
    value: {
      counts: {
        declared: asNumber(counts.declared),
        open: asNumber(counts.open),
        waived: asNumber(counts.waived),
        byClass: numberRecord(counts.by_class),
        byState: numberRecord(counts.by_state),
      },
      open,
    },
    error: null,
  };
}

/**
 * The promise worklist, derived from the kernel's own index when the kernel
 * has no `gaps` subcommand.
 *
 * This is NOT a second measure of the verdicts: the verdict of every
 * obligation is copied from `mathc packages`, and the cause and the remedy
 * are the kernel's own words for that verdict. What is missing is the
 * promise's CLASS (checkable or not), which only the census knows.
 */
export function promisesFromPackages(packages: KernelPackages): KernelPromise[] {
  const promises: KernelPromise[] = [];
  for (const decision of packages.decisions) {
    for (const obligation of decision.obligations) {
      if (obligation.verdict === "pass" || obligation.verdict === "waived") continue;
      promises.push({
        decision: decision.id,
        obligation: obligation.id,
        class: "unidentified",
        state: obligation.verdict,
        verifiers: obligation.verifier === null ? [] : [obligation.verifier],
        cause:
          obligation.remedies.length > 0
            ? obligation.remedies[0] ?? ""
            : `obligation ${obligation.id} of decision ${decision.id} reads as ${obligation.verdict}`,
        action:
          obligation.remedies.length > 0
            ? (obligation.remedies[1] ?? obligation.remedies[0] ?? "")
            : "run the decision's own verifier",
      });
    }
  }
  return promises;
}

/* ------------------------------------------------------------------- gate */

export interface KernelGateGap {
  kind: string;
  obligationId: string;
  causes: string[];
  remedies: string[];
}

export interface KernelGate {
  verdict: string;
  base: string;
  head: string;
  obligations: number;
  gaps: KernelGateGap[];
}

export async function readGate(
  root: string,
  base: string,
  head: string,
): Promise<{ value: KernelGate | null; error: string | null }> {
  const result = await runMathc(root, ["gate", base, head], { timeoutMs: 300_000 });
  try {
    const parsed = JSON.parse(result.stdout) as Record<string, unknown>;
    const gaps: KernelGateGap[] = [];
    for (const entry of asArray(parsed.gaps)) {
      const record = asObject(entry);
      gaps.push({
        kind: asString(record.kind),
        obligationId: asString(record.obligation_id),
        causes: asArray(record.causes).map(asString).filter((item) => item !== ""),
        remedies: asArray(record.remedies).map(asString).filter((item) => item !== ""),
      });
    }
    return {
      value: {
        verdict: asString(parsed.verdict),
        base: asString(parsed.base),
        head: asString(parsed.head),
        obligations: asNumber(parsed.obligations),
        gaps,
      },
      error: null,
    };
  } catch (error) {
    return {
      value: null,
      error: `the gate did not answer with JSON: ${String(error)}`,
    };
  }
}

/* --------------------------------------------------------------- packages */

export interface KernelObligation {
  id: string;
  verdict: string;
  verifier: string | null;
  attestationId: string | null;
  attestationExpiresAt: string | null;
  remedies: string[];
}

export interface KernelPackages {
  counts: Record<string, number>;
  decisions: { id: string; revision: string | null; obligations: KernelObligation[] }[];
}

export async function readPackages(
  root: string,
): Promise<{ value: KernelPackages | null; error: string | null }> {
  const result = await runMathcJson<Record<string, unknown>>(root, ["packages", "--format=json"]);
  if (!result.ok) return { value: null, error: result.error };

  const decisions: KernelPackages["decisions"] = [];
  for (const entry of asArray(result.value.decisions)) {
    const record = asObject(entry);
    const obligations: KernelObligation[] = [];
    for (const obligationEntry of asArray(record.obligations)) {
      const obligation = asObject(obligationEntry);
      obligations.push({
        id: asString(obligation.id),
        verdict: asString(obligation.verdict),
        verifier: asString(obligation.verifier) || null,
        attestationId: asString(obligation.attestation_id) || null,
        attestationExpiresAt: asString(obligation.attestation_expires) || null,
        remedies: asArray(obligation.remedies).map(asString).filter((item) => item !== ""),
      });
    }
    decisions.push({
      id: asString(record.decision_id),
      revision: asString(record.decision_revision) || null,
      obligations,
    });
  }

  return { value: { counts: numberRecord(result.value.counts), decisions }, error: null };
}

/* ------------------------------------------------------------- self-check */

export interface KernelSubject {
  name: string;
  verdict: string;
  causes: string[];
  remedies: string[];
  waivers: string[];
}

export interface KernelSelfCheck {
  verdict: string;
  kernelDigest: string;
  repositoryDigest: string;
  now: string;
  subjects: KernelSubject[];
}

export async function readSelfCheck(
  root: string,
): Promise<{ value: KernelSelfCheck | null; error: string | null; exitCode: number; detail: string }> {
  const result = await runMathc(root, ["self-check"], { timeoutMs: 300_000 });
  let parsed: Record<string, unknown> | null = null;
  try {
    parsed = JSON.parse(result.stdout) as Record<string, unknown>;
  } catch {
    parsed = null;
  }

  if (!parsed) {
    return {
      value: null,
      error: result.code === 0 ? null : `mathc self-check exited ${result.code}`,
      exitCode: result.code,
      detail: (result.stderr.trim() || result.stdout.trim()).slice(0, 4000),
    };
  }

  const subjects: KernelSubject[] = [];
  for (const entry of asArray(parsed.subjects)) {
    const record = asObject(entry);
    subjects.push({
      name: asString(record.name),
      verdict: asString(record.verdict),
      causes: asArray(record.causes).map(asString).filter((item) => item !== ""),
      remedies: asArray(record.remedies).map(asString).filter((item) => item !== ""),
      waivers: asArray(record.waivers).map(asString).filter((item) => item !== ""),
    });
  }

  return {
    value: {
      verdict: asString(parsed.verdict),
      kernelDigest: asString(parsed.kernel_digest),
      repositoryDigest: asString(parsed.repository_digest),
      now: asString(parsed.now),
      subjects,
    },
    error: null,
    exitCode: result.code,
    detail: result.stderr.trim().slice(0, 4000),
  };
}

/* ----------------------------------------------------------------- doctor */

export interface KernelDoctorSection {
  id: string;
  label: string;
  verdict: string;
  details: Record<string, unknown>;
}

export interface KernelDoctor {
  exitCode: number;
  sections: KernelDoctorSection[];
}

export async function readDoctor(root: string): Promise<{ value: KernelDoctor | null; error: string | null }> {
  const result = await runMathcJson<Record<string, unknown>>(root, ["doctor", "--json"]);
  if (!result.ok) return { value: null, error: result.error };

  const sections: KernelDoctorSection[] = [];
  for (const entry of asArray(result.value.sections)) {
    const record = asObject(entry);
    sections.push({
      id: asString(record.id),
      label: asString(record.label),
      verdict: asString(record.verdict),
      details: asObject(record.details),
    });
  }

  return { value: { exitCode: asNumber(result.value.exit_code), sections }, error: null };
}

/* --------------------------------------------------------------- version */

export async function readKernelVersion(root: string): Promise<string | null> {
  const result = await runMathc(root, ["version"]);
  if (result.code !== 0) return null;
  const line = result.stdout.split("\n")[0]?.trim() ?? "";
  return line === "" ? null : line;
}

/* --------------------------------------------------------------- helpers */

function asObject(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function asString(value: unknown): string {
  if (typeof value === "string") return value;
  if (typeof value === "number" || typeof value === "boolean") return String(value);
  return "";
}

function asNumber(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

function numberRecord(value: unknown): Record<string, number> {
  const record: Record<string, number> = {};
  for (const [key, entry] of Object.entries(asObject(value))) {
    if (typeof entry === "number") record[key] = entry;
  }
  return record;
}
