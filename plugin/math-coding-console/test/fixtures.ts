import type { PluginTheme } from "@getpaseo/plugin";
import type { SnapshotReady } from "../shared/contracts";
import type { Claim, ClaimState, Evidence, EvidenceRecord, MathMap, Requirement } from "../shared/domain";

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
    kind: "acceptance",
    phase: "pre-merge",
    owner: "owner",
    review_on: [],
    requirements: [{ kind: "verifier", spec: "sh test/check.sh" }],
    falsifier: "another text is accepted",
    register: "fact",
    control: "sed -i s/hello/broken/ scripts/hello.sh",
    waiver: null,
    ...overrides,
  };
}

export function map(claims: Claim[], state: ClaimState = "holds"): MathMap {
  const verdict = claims.length === 0 ? "vacant" : state === "refuted" ? "red" : state === "holds" ? "green" : "unknown";
  return {
    schema_version: 5,
    verdict,
    exit: verdict === "green" ? 0 : verdict === "red" ? 1 : 3,
    claims: claims.length,
    goal: { text: "test the plugin", scope: ["scripts/", "test/"], by: "owner", at: 1_790_000_000, reason: null },
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
  };
}

export function rawEvidence(overrides: Partial<Evidence> = {}): Evidence {
  return {
    schema_version: 5,
    claim_id: "hello",
    requirement: { kind: "verifier", spec: "sh test/check.sh" },
    candidate_tree: "a".repeat(40),
    materials_digest: "a".repeat(64),
    definition_digest: "b".repeat(64),
    verifier_digest: "c".repeat(64),
    environment: { class: "local", fingerprint: "d".repeat(64) },
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
