import { existsSync, readFileSync, readdirSync } from "node:fs";
import { basename, join } from "node:path";
import { parse as parseYaml } from "yaml";
import type { ProjectLayout } from "./layout";

/**
 * A reader over the corpus files. It answers the questions the console asks
 * about the TEXT of a decision — what it promises, what it covers, what risk it
 * declares — and nothing else.
 *
 * The rule this module lives by: it never produces a verdict. A verdict is a
 * claim about evidence, and the only thing entitled to make it is the kernel.
 * What this module reads is joined with the kernel's answer elsewhere; when
 * the two disagree, the kernel wins and the console says so.
 */

export interface CorpusObligation {
  id: string;
  outcome: string | null;
  claim: string;
  verifiers: string[];
  /** The verifier names a human, so only a person can close this promise. */
  manual: boolean;
}

export interface CorpusDecision {
  id: string;
  revision: string | null;
  state: string;
  intent: string;
  commitment: string;
  axiomLinks: string[];
  scopePaths: string[];
  file: string;
  path: string;
  outcomes: { id: string; statement: string }[];
  obligations: CorpusObligation[];
  assumptions: {
    id: string;
    state: string;
    statement: string;
    owner: string | null;
    consequenceIfFalse: string | null;
  }[];
  relations: Record<string, string[]>;
  riskTriggers: string[];
  counterexample: string | null;
  antithesis: string | null;
  negativeControl: string | null;
  requiredAttestations: { kind: string; producer: string; scopePaths: string[] }[];
}

export interface CorpusAttestation {
  id: string;
  decision: string;
  obligation: string;
  kind: string;
  result: string;
  producer: string;
  producerClass: string;
  run: string | null;
  issuedAt: string;
  expiresAt: string | null;
  materialsDigest: string;
  evidenceDigest: string | null;
  signature: string | null;
}

export interface CorpusPolicy {
  policyId: string;
  parent: string | null;
  scopePaths: string[];
  modeFloor: string;
  overrideProbability: number;
}

/**
 * A `manual-` verifier names a human. The kernel has no way to know that a
 * person checked anything, so only a person can close such an obligation.
 */
export function isManualVerifier(verifier: string | null): boolean {
  if (!verifier) return false;
  const scheme = verifier.trim().split(/\s+/)[0] ?? "";
  return scheme.startsWith("manual-");
}

export function listDecisionFiles(layout: ProjectLayout): string[] {
  const dir = layout.decisionsDir;
  if (!existsSync(dir)) return [];
  let names: string[];
  try {
    names = readdirSync(dir);
  } catch {
    return [];
  }
  return names
    .filter((name) => name.endsWith(".yaml") || name.endsWith(".yml"))
    .filter((name) => !name.endsWith(".waiver.yaml") && !name.endsWith(".waiver.yml"))
    .sort()
    .map((name) => join(dir, name));
}

export function parseDecisionFile(path: string): CorpusDecision | null {
  let raw: string;
  try {
    raw = readFileSync(path, "utf8");
  } catch {
    return null;
  }

  let doc: unknown;
  try {
    doc = parseYaml(raw, { uniqueKeys: false });
  } catch {
    return null;
  }
  const root = asObject(doc);
  const id = asString(root.id);
  if (id === "") return null;

  const obligations: CorpusObligation[] = [];
  for (const entry of asArray(root.obligations)) {
    const obligation = asObject(entry);
    const obligationId = asString(obligation.id);
    if (obligationId === "") continue;
    const acceptance = asObject(obligation.acceptance);
    const verifiers = asArray(acceptance.all)
      .map((item) => asString(asObject(item).verifier))
      .filter((item) => item !== "");
    obligations.push({
      id: obligationId,
      outcome: asString(obligation.outcome) || null,
      // The YAML form may spell the claim `statement`; the JSON form uses
      // `claim`. The kernel accepts both as the same field, so the console
      // does too.
      claim: asString(obligation.claim) || asString(obligation.statement),
      verifiers,
      manual: verifiers.length > 0 && verifiers.every((item) => isManualVerifier(item)),
    });
  }

  const outcomes: CorpusDecision["outcomes"] = [];
  for (const entry of asArray(root.outcomes)) {
    const outcome = asObject(entry);
    const outcomeId = asString(outcome.id);
    if (outcomeId === "") continue;
    outcomes.push({ id: outcomeId, statement: asString(outcome.statement) });
  }

  const assumptions: CorpusDecision["assumptions"] = [];
  for (const entry of asArray(root.assumptions)) {
    const assumption = asObject(entry);
    const assumptionId = asString(assumption.id);
    if (assumptionId === "") continue;
    assumptions.push({
      id: assumptionId,
      state: asString(assumption.state) || "assumed",
      statement: asString(assumption.statement),
      owner: asString(assumption.owner) || null,
      consequenceIfFalse: asString(assumption.consequence_if_false) || null,
    });
  }

  const relations: Record<string, string[]> = {};
  for (const [key, value] of Object.entries(asObject(root.relations))) {
    const items = asArray(value).map(asString).filter((item) => item !== "");
    if (items.length > 0) relations[key] = items;
  }

  const risk = asObject(root.risk);
  // `declared_triggers` is a list of strings, per schemas/decision.json.
  const triggers = asArray(risk.declared_triggers).map(asString).filter((item) => item !== "");

  const requiredAttestations: CorpusDecision["requiredAttestations"] = [];
  for (const entry of asArray(root.required_attestations)) {
    const record = asObject(entry);
    const kind = asString(record.kind_);
    const producer = asString(record.producer);
    if (kind === "" || producer === "") continue;
    requiredAttestations.push({
      kind,
      producer,
      scopePaths: asArray(record.scope_paths).map(asString).filter((item) => item !== ""),
    });
  }

  const scope = asObject(root.scope);

  return {
    id,
    revision: asString(root.revision) || null,
    state: asString(root.state) || "unknown",
    intent: asString(root.intent),
    commitment: asString(root.commitment),
    axiomLinks: asStringArray(root.axiom_link),
    scopePaths: asStringArray(scope.paths),
    file: basename(path),
    path,
    outcomes,
    obligations,
    assumptions,
    relations,
    riskTriggers: triggers,
    counterexample: asString(root.counterexample) || null,
    antithesis: asString(root.antithesis) || null,
    negativeControl: asString(root.negative_control) || null,
    requiredAttestations,
  };
}

/**
 * Every decision file the console can read, keyed by id, plus the files it
 * could not read.
 *
 * The unreadable ones are returned rather than dropped: a decision whose
 * prose the console cannot show is a fact the reader is entitled to.
 */
export function readProse(layout: ProjectLayout): {
  decisions: Map<string, CorpusDecision>;
  unreadable: string[];
} {
  const decisions = new Map<string, CorpusDecision>();
  const unreadable: string[] = [];
  for (const path of listDecisionFiles(layout)) {
    const decision = parseDecisionFile(path);
    if (decision) decisions.set(decision.id, decision);
    else unreadable.push(basename(path));
  }
  return { decisions, unreadable };
}

/** The file a decision lives in, found by convention or by what was read. */
export function findDecisionFile(
  layout: ProjectLayout,
  decisionId: string,
  prose: Map<string, CorpusDecision>,
): string | null {
  const known = prose.get(decisionId);
  if (known) return known.path;
  for (const suffix of [".yaml", ".yml"]) {
    const candidate = join(layout.decisionsDir, `${decisionId}${suffix}`);
    if (existsSync(candidate)) return candidate;
  }
  return null;
}

export function readAttestations(layout: ProjectLayout): CorpusAttestation[] {
  const dir = layout.attestationsDir;
  if (!existsSync(dir)) return [];
  let names: string[];
  try {
    names = readdirSync(dir);
  } catch {
    return [];
  }
  const attestations: CorpusAttestation[] = [];
  for (const name of names) {
    if (!name.endsWith(".json")) continue;
    let parsed: unknown;
    try {
      parsed = JSON.parse(readFileSync(join(dir, name), "utf8"));
    } catch {
      continue;
    }
    const record = asObject(parsed);
    if (asString(record.kind) !== "attestation") continue;
    const subject = asObject(record.subject);
    const producer = asObject(record.producer);
    const identity = asString(producer.identity);
    const signature = asObject(record.signature);
    attestations.push({
      id: asString(record.id),
      decision: asString(subject.decision),
      obligation: asString(subject.obligation),
      kind: asString(record.kind_),
      result: asString(record.result),
      producer: identity,
      producerClass: identity.includes(":") ? (identity.split(":")[0] ?? "") : "untagged",
      run: asString(producer.run) || null,
      issuedAt: asString(record.issued_at),
      expiresAt: asString(record.valid_until) || null,
      materialsDigest: asString(subject.materials_digest),
      evidenceDigest: asString(record.evidence_digest) || null,
      signature: asString(signature.key_id) || null,
    });
  }
  return attestations;
}

export function readPolicies(layout: ProjectLayout): CorpusPolicy[] {
  const path = layout.policyPath;
  if (!existsSync(path)) return [];
  let doc: unknown;
  try {
    doc = parseYaml(readFileSync(path, "utf8"), { uniqueKeys: false });
  } catch {
    return [];
  }
  const policies: CorpusPolicy[] = [];
  for (const entry of asArray(doc)) {
    const record = asObject(entry);
    const policyId = asString(record.policy_id);
    if (policyId === "") continue;
    policies.push({
      policyId,
      parent: asString(record.parent) || null,
      scopePaths: asStringArray(record.scope_paths),
      modeFloor: asString(record.mode_floor) || "standard",
      overrideProbability:
        typeof record.override_probability === "number" ? record.override_probability : 0,
    });
  }
  return policies;
}

export function readWaivers(layout: ProjectLayout): {
  id: string;
  rule: string;
  subject: string;
  unverifiedObligation: string | null;
  issuer: string;
  issuedAt: string;
  expiresAt: string;
  reason: string;
  compensatingControls: string[];
}[] {
  const dir = layout.waiversDir;
  if (!existsSync(dir)) return [];
  let names: string[];
  try {
    names = readdirSync(dir);
  } catch {
    return [];
  }
  const waivers: ReturnType<typeof readWaivers> = [];
  for (const name of names) {
    if (!name.endsWith(".yaml") && !name.endsWith(".yml")) continue;
    let doc: unknown;
    try {
      doc = parseYaml(readFileSync(join(dir, name), "utf8"), { uniqueKeys: false });
    } catch {
      continue;
    }
    const record = asObject(doc);
    const id = asString(record.id);
    if (id === "") continue;
    waivers.push({
      id,
      rule: asString(record.rule),
      subject: asString(record.subject),
      unverifiedObligation: asString(record.unverified_obligation) || null,
      issuer: asString(record.issuer),
      issuedAt: asString(record.issued_at),
      expiresAt: asString(record.expires_at),
      reason: asString(record.reason),
      compensatingControls: asArray(record.compensating_controls).map(asString),
    });
  }
  return waivers;
}

/* --------------------------------------------------------------- ledger */

/**
 * The review ledger.
 *
 * The verdict of a review is durable in the kernel's attestation store; the
 * RATIONALE is not, because the attestation schema has no field for it. The
 * console therefore keeps its own append-only record under `.local/`, which
 * the repository already ignores. It is a note, not evidence: the gate never
 * reads it.
 */
export interface ReviewLedgerEntry {
  decision: string;
  obligation: string;
  result: string;
  producer: string;
  rationale: string;
  at: string;
  agentId: string | null;
  attestationId: string | null;
}

export function readReviewLedger(root: string): ReviewLedgerEntry[] {
  const path = join(root, ".local", "reviews.jsonl");
  if (!existsSync(path)) return [];
  let raw: string;
  try {
    raw = readFileSync(path, "utf8");
  } catch {
    return [];
  }
  const entries: ReviewLedgerEntry[] = [];
  for (const line of raw.split("\n")) {
    const trimmed = line.trim();
    if (trimmed === "") continue;
    try {
      const record = asObject(JSON.parse(trimmed));
      entries.push({
        decision: asString(record.decision),
        obligation: asString(record.obligation),
        result: asString(record.result),
        producer: asString(record.producer),
        rationale: asString(record.rationale),
        at: asString(record.at),
        agentId: asString(record.agentId) || null,
        attestationId: asString(record.attestationId) || null,
      });
    } catch {
      continue;
    }
  }
  return entries;
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
  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    if (typeof record.text === "string") return record.text;
  }
  return "";
}

function asStringArray(value: unknown): string[] {
  if (Array.isArray(value)) return value.map(asString).filter((item) => item !== "");
  if (typeof value === "string" && value !== "") return [value];
  return [];
}
