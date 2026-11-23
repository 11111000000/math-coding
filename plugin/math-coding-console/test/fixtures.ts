import type { PluginTheme } from "@getpaseo/plugin";
import type { SnapshotReady } from "../shared/contracts";
import type { Claim, ClaimState, Evidence, EvidenceRecord, MathMap, Requirement } from "../shared/domain";

/**
 * The claim of the fifth generation.
 *
 * The fifth generation carried three fields the current one does not read:
 * the kind of the claim, its phase and the moments of its review. The reader
 * of that generation drops them, exactly as the program of that generation
 * dropped them when it wrote the next format.
 */
export function claimV5(): Record<string, unknown> {
  return {
    ...claim(),
    kind: "invariant",
    phase: "pre-merge",
    review_on: ["docs/adr.md"],
  };
}

/** The specification of the fifth generation. */
export function specV5(claims: Record<string, unknown>[] = [claimV5()]): Record<string, unknown> {
  return {
    schema_version: 5,
    goal: map([claim()]).goal,
    uncertainty_budget: 3,
    closed_waves: [],
    claims,
  };
}

/**
 * The claim of the third generation.
 *
 * The third generation named one check per claim and wrote the text of the
 * claim as its subject. It had no source, no owner and no waiver.
 */
export function claimLegacyV3(): Record<string, unknown> {
  return {
    id: "hello",
    subject: "the command prints hello",
    scope: ["scripts/", "test/"],
    check: "sh test/check.sh",
    falsifier: "another text is accepted",
    register: "fact",
    accepted: { by: "owner", reason: "the check is enough" },
  };
}

/** The claim of the fourth generation: a tree of conditions. */
export function claimLegacyV4(): Record<string, unknown> {
  return {
    id: "hello",
    subject: "the command prints hello",
    scope: ["scripts/", "test/"],
    requirements: [{ kind: "verifier", spec: "sh test/check.sh" }],
    falsifier: "another text is accepted",
    register: "fact",
    accepted: null,
  };
}

/** The specification of the generations before the fifth. */
export function specLegacy(claims: Record<string, unknown>[] = [claimLegacyV4()]): Record<string, unknown> {
  return {
    goal: { text: "test the plugin", scope: ["scripts/"], by: "owner", at: 1_790_000_000 },
    uncertainty_budget: 3,
    claims,
  };
}

export const theme: PluginTheme = {
  colors: {
    surface0: "#101010",
    surface1: "#181818",
    surface2: "#242424",
    border: "#3a3a3a",
    foreground: "#eeeeee",
    foregroundMuted: "#aaaaaa",
    accent: "#739dff",
    accentForeground: "#ffffff",
    statusSuccess: "#4cba68",
    statusWarning: "#d9a23f",
    statusDanger: "#ef6461",
  },
};

export function claim(overrides: Partial<Claim> = {}): Claim {
  return {
    id: "hello",
    text: "the command prints hello",
    scope: ["scripts/", "test/"],
    source: null,
    owner: "owner",
    requirements: [{ kind: "verifier", spec: "sh test/check.sh" }],
    falsifier: "another text is accepted",
    register: "fact",
    control: "sed -i s/hello/broken/ scripts/hello.sh",
    waiver: null,
    ...overrides,
  };
}

/** The digest of the program that produced the map or the record. */
export const tool = { class: "mathc", fingerprint: "e".repeat(64) };

/**
 * The digest of an unknown program.
 *
 * A record carried over from the previous format does not know the program
 * that wrote it. The migration names the class and leaves the fingerprint
 * empty rather than inventing one.
 */
export const unknownTool = { class: "mathc", fingerprint: "" };

export function map(claims: Claim[], state: ClaimState = "holds"): MathMap {
  const verdict = claims.length === 0 ? "vacant" : state === "refuted" ? "red" : state === "holds" ? "green" : "unknown";
  return {
    schema_version: 6,
    verdict,
    exit: verdict === "green" ? 0 : verdict === "red" ? 1 : 3,
    claims: claims.length,
    goal: { text: "test the plugin", scope: ["scripts/", "test/"], by: "owner", at: 1_790_000_000, reason: null },
    tool,
    states: claims.map((item) => ({ id: item.id, state, source_changed: false })),
    uncovered: [],
    next: verdict === "green" ? "next: scope covered" : "next: check the claim",
  };
}

export function snapshot(claims: Claim[] = [claim()], state: ClaimState = "holds"): SnapshotReady {
  return {
    status: "ready",
    workspace: { id: "workspace-1", name: "Fixture", directory: "/tmp/fixture" },
    generatedAt: "2026-11-14T00:00:00.000Z",
    binary: { path: "mathc", version: "mathc 5" },
    revision: "a".repeat(64),
    map: map(claims, state),
    claims,
    policyConfigured: false,
  };
}

export function rawEvidence(overrides: Partial<Evidence> = {}): Evidence {
  return {
    schema_version: 6,
    claim_id: "hello",
    requirement: { kind: "verifier", spec: "sh test/check.sh" },
    candidate_tree: "a".repeat(40),
    materials_digest: "a".repeat(64),
    definition_digest: "b".repeat(64),
    verifier_digest: "c".repeat(64),
    environment: { class: "local", fingerprint: "d".repeat(64) },
    tool,
    producer: { class: "process", identity: "fixture", run: "run-1" },
    independence: "fresh-context",
    outcome: "pass",
    issued_at: 1_790_000_100,
    valid_until: null,
    evidence_ref: null,
    control_reach: "subject",
    ...overrides,
  };
}

export function evidence(overrides: Partial<EvidenceRecord> = {}): EvidenceRecord {
  return {
    ...rawEvidence(),
    sequence: 0,
    requirementPaths: ["0"],
    ...overrides,
  };
}

export function nestedClaim(): Claim {
  const requirements: Requirement[] = [{
    all: [
      { kind: "verifier", spec: "sh test/a.sh" },
      { any: [{ kind: "review", spec: "owner", minimum_independence: "external" }, { kind: "verifier", spec: "sh test/b.sh" }] },
    ],
  }];
  return claim({ id: "nested", requirements, source: { kind: "madr", path: "docs/adr.md", section: "Decision", digest: "e".repeat(64), review: null } });
}

/**
 * The map of the fifth generation.
 *
 * That map names no observer: the program of that generation did not put
 * its own digest into the map it wrote.
 */
export function mapV5(claims: Claim[] = [claim()], state: ClaimState = "holds"): Record<string, unknown> {
  const current = map(claims, state);
  const { tool: _tool, ...withoutTool } = current;
  return { ...withoutTool, schema_version: 5 };
}

/**
 * The map of the fourth generation.
 *
 * That map names no observer, no reason of a state and no next step, and it
 * counts the uncovered paths instead of naming them one by one.
 */
export function mapLegacy(claims: Claim[] = [claim()]): Record<string, unknown> {
  return {
    verdict: "green",
    exit: 0,
    claims: claims.length,
    uncertainty_consumed: 0,
    uncertainty_budget: 3,
    uncovered: 1,
    uncovered_paths: ["docs/other.md"],
    goal: { text: "test the plugin", scope: ["scripts/"], by: "owner" },
    states: claims.map((item) => ({ id: item.id, state: "holds" })),
  };
}

/** The record of the fifth generation: it names no producer. */
export function evidenceV5(): Record<string, unknown> {
  const { tool: _tool, ...withoutTool } = rawEvidence();
  return { ...withoutTool, schema_version: 5 };
}

/** The record of the third generation. */
export function evidenceLegacyV3(): Record<string, unknown> {
  return {
    claim: "hello",
    outcome: "verified",
    bound_to: "a".repeat(40),
    reason: null,
    at: "1790000100",
  };
}

/** The record of the fourth generation. */
export function evidenceLegacyV4(): Record<string, unknown> {
  return {
    claim: "hello",
    kind: "verifier",
    requirement: "sh test/check.sh",
    outcome: "falsified",
    bound_to: "a".repeat(40),
    producer: "sh test/check.sh",
    reason: null,
    at_commit: "b".repeat(40),
    at: "1790000200",
    valid_until: null,
    control: "falsified",
    reach: "subject",
  };
}
