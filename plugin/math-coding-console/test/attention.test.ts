import assert from "node:assert/strict";
import { test } from "node:test";
import { attentionBrief, attentionContext, buildAttentionModel, snapshotSeconds } from "../client/attention";
import type { Claim, ClaimState } from "../shared/domain";
import { claim, snapshot } from "./fixtures";

function stateSnapshot(claims: Claim[], states: Array<{ state: ClaimState; sourceChanged?: boolean }>, uncovered: string[] = []) {
  const result = snapshot(claims);
  result.map.states = claims.map((item, index) => ({
    id: item.id,
    state: states[index]?.state ?? "holds",
    source_changed: states[index]?.sourceChanged ?? false,
  }));
  result.map.verdict = result.map.states.some((item) => item.state === "refuted")
    ? "red"
    : result.map.states.every((item) => item.state === "holds") ? "green" : "unknown";
  result.map.exit = result.map.verdict === "green" ? 0 : result.map.verdict === "red" ? 1 : 3;
  result.map.uncovered = uncovered;
  return result;
}

test("a changed source requires a human review and is not delegated to the agent", () => {
  const current = claim({ id: "changed", source: { kind: "madr", path: "docs/adr.md", section: null, digest: "a".repeat(64), review: null } });
  const model = buildAttentionModel(stateSnapshot([current], [{ state: "outdated", sourceChanged: true }]), 1_000);
  assert.equal(model.needsHuman.length, 1);
  assert.equal(model.needsHuman[0]?.kind, "source-review");
  assert.equal(model.agentCanAct.length, 0);
  assert.match(model.needsHuman[0]?.humanQuestion ?? "", /still justify/);
});

test("a refutation requires a human contract decision while the agent may repair the subject", () => {
  const current = claim({ id: "broken" });
  const model = buildAttentionModel(stateSnapshot([current], [{ state: "refuted" }]), 1_000);
  assert.equal(model.needsHuman[0]?.kind, "refutation");
  assert.match(model.needsHuman[0]?.agentMay ?? "", /repair/i);
  assert.match(model.needsHuman[0]?.agentMustNot ?? "", /contract direction/i);
});

test("an unmet human review requirement cannot be assigned to an agent", () => {
  const current = claim({
    id: "judgment",
    requirements: [{ kind: "review", spec: "product-owner", minimum_independence: "external" }],
  });
  const model = buildAttentionModel(stateSnapshot([current], [{ state: "never-checked" }]), 1_000);
  assert.equal(model.needsHuman[0]?.kind, "human-review");
  assert.match(model.needsHuman[0]?.why ?? "", /product-owner \(external\)/);
  assert.equal(model.agentCanAct.length, 0);
});

test("a not-checkable claim asks the human for an acceptance criterion", () => {
  const current = claim({ id: "criterion" });
  const model = buildAttentionModel(stateSnapshot([current], [{ state: "not-checkable" }]), 1_000);
  assert.equal(model.needsHuman[0]?.kind, "acceptance-criterion");
  assert.match(model.needsHuman[0]?.humanQuestion ?? "", /observable condition/i);
});

test("outdated without a source change is agent work", () => {
  const current = claim({ id: "stale" });
  const model = buildAttentionModel(stateSnapshot([current], [{ state: "outdated" }]), 1_000);
  assert.equal(model.needsHuman.length, 0);
  assert.equal(model.agentCanAct.length, 1);
  assert.equal(model.agentCanAct[0]?.kind, "refresh-evidence");
  assert.equal(model.agentClaimCount, 1);
});

test("never-checked and inconclusive claims are grouped as agent work", () => {
  const claims = [claim({ id: "never" }), claim({ id: "unknown" })];
  const model = buildAttentionModel(stateSnapshot(claims, [{ state: "never-checked" }, { state: "inconclusive" }]), 1_000);
  assert.equal(model.needsHuman.length, 0);
  assert.deepEqual(model.agentCanAct.map((item) => item.kind), ["refresh-evidence", "investigate-unknown"]);
});

test("uncovered paths are a coverage proposal for the agent, not a scope change", () => {
  const model = buildAttentionModel(stateSnapshot([claim()], [{ state: "holds" }], ["src/uncovered.ts"]), 1_000);
  assert.equal(model.agentCanAct.length, 1);
  assert.equal(model.agentCanAct[0]?.kind, "coverage");
  assert.match(model.agentCanAct[0]?.humanBoundary ?? "", /human decides/i);
});

test("an active waiver is an accepted risk rather than a pending decision", () => {
  const current = claim({
    id: "waived",
    waiver: {
      gap: "temporary platform limitation",
      scope: ["src/"],
      issuer: "owner",
      issued_at: 900,
      expires_at: 1_100,
      reason: "migration is scheduled",
      compensating_controls: [],
      recovery: "finish the migration",
      review_on: [],
    },
  });
  const model = buildAttentionModel(stateSnapshot([current], [{ state: "waived" }]), 1_000);
  assert.equal(model.needsHuman.length, 0);
  assert.equal(model.acceptedRisks.length, 1);
  assert.equal(model.acceptedRisks[0]?.claimId, "waived");
});

test("an expired waiver requires a new human decision", () => {
  const current = claim({
    id: "expired",
    waiver: {
      gap: "temporary platform limitation",
      scope: ["src/"],
      issuer: "owner",
      issued_at: 900,
      expires_at: 1_000,
      reason: "migration was scheduled",
      compensating_controls: [],
      recovery: "finish the migration",
      review_on: [],
    },
  });
  const model = buildAttentionModel(stateSnapshot([current], [{ state: "inconclusive" }]), 1_000);
  assert.equal(model.needsHuman[0]?.kind, "expired-waiver");
  assert.equal(model.acceptedRisks.length, 0);
});

test("holds creates no attention item", () => {
  const model = buildAttentionModel(stateSnapshot([claim()], [{ state: "holds" }]), 1_000);
  assert.equal(model.needsHuman.length, 0);
  assert.equal(model.agentCanAct.length, 0);
  assert.equal(model.acceptedRisks.length, 0);
});

test("human items follow the canonical priority order", () => {
  const claims = [
    claim({ id: "criterion" }),
    claim({ id: "refuted" }),
    claim({ id: "changed", source: { kind: "madr", path: "docs/adr.md", section: null, digest: "a".repeat(64), review: null } }),
  ];
  const model = buildAttentionModel(stateSnapshot(claims, [
    { state: "not-checkable" },
    { state: "refuted" },
    { state: "outdated", sourceChanged: true },
  ]), 1_000);
  assert.deepEqual(model.needsHuman.map((item) => item.kind), ["source-review", "refutation", "acceptance-criterion"]);
});

test("fifteen equally outdated claims become one agent task", () => {
  const claims = Array.from({ length: 15 }, (_, index) => claim({ id: `claim-${index}` }));
  const states = claims.map(() => ({ state: "outdated" as const }));
  const model = buildAttentionModel(stateSnapshot(claims, states), 1_000);
  assert.equal(model.humanDecisionCount, 0);
  assert.equal(model.agentTaskCount, 1);
  assert.equal(model.agentClaimCount, 15);
  assert.equal(model.agentOnlyClaimCount, 15);
  assert.equal(model.agentCanAct[0]?.claimIds.length, 15);
});

test("only canonical waived state is an accepted risk", () => {
  const current = claim({
    id: "risk",
    waiver: {
      gap: "temporary platform limitation",
      scope: ["src/"],
      issuer: "owner",
      issued_at: 900,
      expires_at: 1_100,
      reason: "migration is scheduled",
      compensating_controls: [],
      recovery: "finish the migration",
      review_on: [],
    },
  });
  const waived = buildAttentionModel(stateSnapshot([current], [{ state: "waived" }]), 1_000);
  assert.equal(waived.acceptedRisks.length, 1);
  const refuted = buildAttentionModel(stateSnapshot([current], [{ state: "refuted" }]), 1_000);
  assert.equal(refuted.acceptedRisks.length, 0);
  assert.equal(refuted.needsHuman[0]?.kind, "refutation");
  const inconclusive = buildAttentionModel(stateSnapshot([current], [{ state: "inconclusive" }]), 1_000);
  assert.equal(inconclusive.acceptedRisks.length, 0);
});

test("a waived review requirement is not shown as a pending human decision", () => {
  const current = claim({
    id: "judged",
    requirements: [{ kind: "review", spec: "product-owner", minimum_independence: "external" }],
    waiver: {
      gap: "review is pending",
      scope: ["src/"],
      issuer: "owner",
      issued_at: 900,
      expires_at: 1_100,
      reason: "review is scheduled",
      compensating_controls: [],
      recovery: "complete the review",
      review_on: [],
    },
  });
  const model = buildAttentionModel(stateSnapshot([current], [{ state: "waived" }]), 1_000);
  assert.equal(model.needsHuman.length, 0);
  assert.equal(model.acceptedRisks.length, 1);
});

test("an expired waiver does not override a canonical holds state", () => {
  const current = claim({
    id: "expired",
    waiver: {
      gap: "temporary platform limitation",
      scope: ["src/"],
      issuer: "owner",
      issued_at: 800,
      expires_at: 900,
      reason: "migration was scheduled",
      compensating_controls: [],
      recovery: "finish the migration",
      review_on: [],
    },
  });
  const model = buildAttentionModel(stateSnapshot([current], [{ state: "holds" }]), 1_000);
  assert.equal(model.needsHuman.length, 0);
  assert.equal(model.acceptedRisks.length, 0);
});

test("a canonical waived claim does not disappear when its interval expires", () => {
  const current = claim({
    id: "expired-waived",
    waiver: {
      gap: "temporary platform limitation",
      scope: ["src/"],
      issuer: "owner",
      issued_at: 800,
      expires_at: 1_000,
      reason: "migration was scheduled",
      compensating_controls: [],
      recovery: "finish the migration",
      review_on: [],
    },
  });
  const model = buildAttentionModel(stateSnapshot([current], [{ state: "waived" }]), 1_000);
  assert.equal(model.needsHuman[0]?.kind, "expired-waiver");
  assert.equal(model.acceptedRisks.length, 0);
});

test("a mixed machine and human claim exposes both halves without conflating them", () => {
  const current = claim({
    id: "mixed",
    requirements: [{
      all: [
        { kind: "verifier", spec: "sh test/check.sh" },
        { kind: "review", spec: "product-owner", minimum_independence: "external" },
      ],
    }],
  });
  const model = buildAttentionModel(stateSnapshot([current], [{ state: "never-checked" }]), 1_000);
  assert.equal(model.needsHuman[0]?.kind, "human-review");
  assert.ok(model.agentCanAct.some((item) => item.claimIds.includes("mixed")));
  assert.equal(model.agentCanAct[0]?.kind, "refresh-evidence");
  assert.equal(model.agentClaimCount, 1);
  assert.equal(model.agentOnlyClaimCount, 0);
});

test("an agent brief preserves the human boundary and includes claim context", () => {
  const current = claim({ id: "changed", source: { kind: "madr", path: "docs/adr.md", section: null, digest: "a".repeat(64), review: null } });
  const data = stateSnapshot([current], [{ state: "outdated", sourceChanged: true }]);
  const model = buildAttentionModel(data, 1_000);
  const brief = attentionBrief(model.needsHuman[0]!, attentionContext(data, model));
  assert.match(brief, /Human decision \(the agent must not make it\)/);
  assert.match(brief, /Do not rewrite the source/);
  assert.match(brief, /Next safe step:\nPrepare the source diff/);
  assert.doesNotMatch(brief, /record the human review/);
  assert.match(brief, /Claim context:/);
  assert.match(brief, /scope: scripts\/, test\//);
  assert.match(brief, /falsifier:/);
});

test("an agent brief carries the goal, the verdict, the coverage gap, the accepted risks and the canonical next action", () => {
  const stale = claim({ id: "stale" });
  const waived = claim({
    id: "waived",
    waiver: {
      gap: "temporary platform limitation",
      scope: ["src/"],
      issuer: "owner",
      issued_at: 900,
      expires_at: 1_100,
      reason: "migration is scheduled",
      compensating_controls: [],
      recovery: "finish the migration",
      review_on: [],
    },
  });
  const data = stateSnapshot([stale, waived], [{ state: "outdated" }, { state: "waived" }], ["src/uncovered.ts"]);
  data.map.next = "next: refresh the outdated claim stale";
  const model = buildAttentionModel(data, 1_000);
  const brief = attentionBrief(model.agentCanAct[0]!, attentionContext(data, model));
  assert.match(brief, /Goal: test the plugin/);
  assert.match(brief, /Canonical verdict: unknown/);
  assert.match(brief, /Goal scope uncovered: 1 path\(s\)/);
  assert.match(brief, /src\/uncovered\.ts/);
  assert.match(brief, /Accepted risks: 1/);
  assert.match(brief, /Accepted risk for waived/);
  assert.match(brief, /Canonical next action: next: refresh the outdated claim stale/);
});

test("the canonical time of the snapshot decides whether a waiver is still accepted", () => {
  const data = snapshot([claim({ id: "waived" })]);
  const issued = snapshotSeconds(data) - 60;
  const expires = snapshotSeconds(data) + 60;
  data.claims[0]!.waiver = {
    gap: "temporary platform limitation",
    scope: ["src/"],
    issuer: "owner",
    issued_at: issued,
    expires_at: expires,
    reason: "migration is scheduled",
    compensating_controls: [],
    recovery: "finish the migration",
    review_on: [],
  };
  data.map.states = [{ id: "waived", state: "waived", source_changed: false }];
  const model = buildAttentionModel(data);
  assert.equal(model.acceptedRisks.length, 1);
  assert.equal(model.needsHuman.length, 0);
});
