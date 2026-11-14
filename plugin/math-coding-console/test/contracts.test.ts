import assert from "node:assert/strict";
import { test } from "node:test";
import { mapSchema, specSchema } from "../shared/domain";
import { preferences, snapshotRpc } from "../shared/contracts";
import { linkEvidence, parseTrail } from "../server/evidence";
import { claim, evidence, map, nestedClaim, rawEvidence } from "./fixtures";

test("accepts the v5 requirement tree and codec defaults", () => {
  const current = nestedClaim();
  const { kind: _kind, phase: _phase, ...withoutDefaults } = current;
  const raw = {
    ...withoutDefaults,
    source: { ...current.source, review: undefined },
    requirements: current.requirements,
  };
  const parsed = specSchema.parse({ schema_version: 5, goal: null, claims: [raw] });
  assert.equal(parsed.claims[0]?.kind, "invariant");
  assert.equal(parsed.claims[0]?.phase, "pre-merge");
  assert.equal(parsed.claims[0]?.source?.review, null);
  assert.deepEqual(parsed.claims[0]?.requirements, current.requirements);
});

test("rejects unknown fields and unsupported schema versions", () => {
  assert.throws(() => specSchema.parse({ schema_version: 4, goal: null, claims: [] }));
  assert.throws(() => specSchema.parse({ schema_version: 5, goal: null, claims: [], unexpected: true }));
  assert.throws(() => mapSchema.parse({ ...map([claim()]), extra: "laundering" }));
});

test("version one settings migrate with Run checks disabled", () => {
  const migrated = preferences.migrate?.({ binaryPath: "", autoRefreshSeconds: 30 }, 1);
  assert.deepEqual(migrated, { binaryPath: "", autoRefreshSeconds: 30, allowRunChecks: false });
});

test("RPC inputs reject a client-supplied project root", () => {
  assert.equal(snapshotRpc.input.safeParse({ workspaceId: "workspace-1" }).success, true);
  assert.equal(snapshotRpc.input.safeParse({ workspaceId: "workspace-1", root: "/tmp/other" }).success, false);
  assert.equal(snapshotRpc.input.safeParse({ workspaceId: "workspace-1", workspaceDirectory: "/tmp/other" }).success, false);
});

test("rejects a malformed JSONL line instead of dropping it", () => {
  const valid = JSON.stringify(rawEvidence());
  assert.equal(parseTrail(`${valid}\n`).length, 1);
  assert.throws(() => parseTrail(`${valid}\nnot-json\n`), /line 2/);
  assert.throws(() => parseTrail(`${valid}\n${JSON.stringify({ ...rawEvidence(), outcome: "success" })}\n`));
});

test("evidence joins do not turn pass into holds or hide historical requirements", () => {
  const current = claim();
  const historical = evidence({ requirement: { kind: "verifier", spec: "sh test/old.sh" }, outcome: "pass" });
  const linked = linkEvidence([evidence(), historical], [current]);
  assert.deepEqual(linked[0]?.requirementPaths, ["0"]);
  assert.deepEqual(linked[1]?.requirementPaths, []);
  assert.equal(map([current], "refuted").states[0]?.state, "refuted");
  assert.equal(historical.outcome, "pass");
});

test("canonical requirement matching ignores object key order but not array order", () => {
  const current = nestedClaim();
  const requirement = current.requirements[0];
  assert.ok(requirement && "all" in requirement);
  const record = evidence({ claim_id: current.id, requirement });
  assert.deepEqual(linkEvidence([record], [current])[0]?.requirementPaths, ["0"]);
  assert.deepEqual(linkEvidence([{ ...record, requirement: { all: [] } }], [current])[0]?.requirementPaths, []);
});

test("an identical requirement in two branches keeps both paths", () => {
  const requirement = { kind: "verifier", spec: "sh test/shared.sh" } as const;
  const current = claim({ requirements: [{ all: [requirement, requirement] }] });
  const record = evidence({ requirement });
  assert.deepEqual(linkEvidence([record], [current])[0]?.requirementPaths, ["0/0", "0/1"]);
});
