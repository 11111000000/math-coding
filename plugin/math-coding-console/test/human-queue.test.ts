import assert from "node:assert/strict";
import { test } from "node:test";
import { attentionContext, buildAttentionModel } from "../client/attention";
import { buildHumanQueue, claimConditions, claimFiles, queueEvidenceComplete } from "../client/human-queue";
import { claim, evidence, snapshot } from "./fixtures";

function record(overrides: Parameters<typeof evidence>[0] = {}) {
  return evidence(overrides);
}

test("the queue names the decision, the expectation and the files of a claim", () => {
  const changed = claim({
    id: "changed",
    text: "the changed source stays reviewed",
    scope: ["docs/adr.md", "lib/"],
    source: { kind: "madr", path: "docs/adr.md", section: null, digest: "a".repeat(64), review: null },
  });
  const data = snapshot([changed]);
  data.map.states = [{ id: "changed", state: "outdated", source_changed: true }];
  const attention = buildAttentionModel(data, 1_000);
  const queue = buildHumanQueue(data, attention, []);
  assert.equal(queue.items.length, 1);
  const item = queue.items[0]!;
  assert.equal(item.claimIds[0], "changed");
  assert.equal(item.expectation, "the changed source stays reviewed");
  assert.deepEqual(item.files, ["docs/adr.md", "lib/"]);
  assert.equal(item.attention.humanQuestion.length > 0, true);
  assert.equal(item.conditions.length, 1);
  assert.equal(item.conditions[0]!.label, "sh test/check.sh");
});

test("the queue shows the expectation of every declared claim", () => {
  const first = claim({ id: "first", text: "the first claim holds" });
  const second = claim({ id: "second", text: "the second claim holds" });
  const data = snapshot([first, second]);
  const attention = buildAttentionModel(data, 1_000);
  const queue = buildHumanQueue(data, attention, []);
  assert.deepEqual(queue.obligations.map((item) => item.claimId), ["first", "second"]);
  assert.deepEqual(queue.obligations.map((item) => item.expectation), ["the first claim holds", "the second claim holds"]);
  assert.deepEqual(queue.obligations.map((item) => item.state), ["holds", "holds"]);
});

test("the queue names the third outcome and what the map still leaves open", () => {
  const data = snapshot([claim()]);
  data.map.uncovered = ["src/uncovered.ts"];
  const attention = buildAttentionModel(data, 1_000);
  const queue = buildHumanQueue(data, attention, []);
  assert.equal(queue.acceptance.title, "Accept the result on the basis of the map");
  assert.equal(queue.acceptance.obligationsConfirmed, true);
  assert.equal(queue.acceptance.areaResolved, false);
  assert.deepEqual(queue.acceptance.uncovered, ["src/uncovered.ts"]);
  assert.equal(queue.acceptance.owner, "owner");
});

test("an area that the project never declared is not resolved", () => {
  const data = snapshot([claim()]);
  data.map.goal = { ...data.map.goal!, scope: [] };
  const attention = buildAttentionModel(data, 1_000);
  const queue = buildHumanQueue(data, attention, []);
  assert.equal(queue.acceptance.uncovered.length, 0);
  assert.equal(queue.acceptance.areaResolved, false);
});

test("the queue keeps the state of the map and never reads a state from the evidence", () => {
  const data = snapshot([claim({ id: "hello" })]);
  data.map.states = [{ id: "hello", state: "refuted", source_changed: false }];
  const attention = buildAttentionModel(data, 1_000);
  const queue = buildHumanQueue(data, attention, [record({ outcome: "pass", issued_at: 2_000 })]);
  const obligation = queue.obligations[0]!;
  assert.equal(obligation.state, "refuted", "the state comes from the map");
  assert.equal(obligation.conditions[0]!.outcome, "pass", "the recorded outcome is shown as it was recorded");
});

test("a condition without a record has no evidence", () => {
  const data = snapshot([claim()]);
  const attention = buildAttentionModel(data, 1_000);
  const queue = buildHumanQueue(data, attention, []);
  assert.equal(queue.obligations[0]!.conditions[0]!.outcome, "not-run");
  assert.equal(queue.obligations[0]!.conditions[0]!.issuedAt, 0);
  assert.equal(queue.obligations[0]!.conditions[0]!.independence, null);
  assert.equal(queue.obligations[0]!.conditions[0]!.controlReach, null);
});

test("the newest record of a condition wins", () => {
  const one = claim({ id: "hello" });
  const conditions = claimConditions(one, [
    record({ issued_at: 1_000, outcome: "fail", sequence: 0 }),
    record({ issued_at: 2_000, outcome: "pass", sequence: 1 }),
    record({ issued_at: 1_500, outcome: "inconclusive", sequence: 2 }),
  ]);
  assert.equal(conditions.length, 1);
  assert.equal(conditions[0]!.outcome, "pass");
});

test("the trail is complete only when every condition has a record", () => {
  const one = claim({ id: "hello" });
  assert.equal(queueEvidenceComplete([record()], [one]), true);
  assert.equal(queueEvidenceComplete([], [one]), false);
  const two = claim({
    id: "hello",
    requirements: [{
      all: [
        { kind: "verifier", spec: "sh test/check.sh" },
        { kind: "verifier", spec: "sh test/other.sh" },
      ],
    }],
  });
  assert.equal(queueEvidenceComplete([record()], [two]), false);
  assert.equal(
    queueEvidenceComplete(
      [record(), record({ requirement: { kind: "verifier", spec: "sh test/other.sh" } })],
      [two],
    ),
    true,
  );
});

test("the files of a claim are the declared scope and the linked source", () => {
  const withSource = claim({
    scope: ["lib/"],
    source: { kind: "madr", path: "docs/adr.md", section: null, digest: "b".repeat(64), review: null },
  });
  assert.deepEqual(claimFiles(withSource), ["lib/", "docs/adr.md"]);
  assert.deepEqual(claimFiles(claim({ scope: ["lib/"] })), ["lib/"]);
});

test("the brief of a queue item is the canonical brief of its decision", () => {
  const data = snapshot([claim({ id: "hello" })]);
  data.map.states = [{ id: "hello", state: "refuted", source_changed: false }];
  const attention = buildAttentionModel(data, 1_000);
  const context = attentionContext(data, attention);
  const queue = buildHumanQueue(data, attention, []);
  assert.equal(queue.items.length, 1);
  assert.ok(queue.items[0]!.attention.humanQuestion.length > 0);
  assert.equal(context.goal, "test the plugin");
});
