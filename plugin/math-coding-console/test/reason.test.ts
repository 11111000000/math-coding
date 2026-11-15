import assert from "node:assert/strict";
import { test } from "node:test";
import { createElement } from "react";
import { attentionBrief, attentionContext, buildAttentionModel } from "../client/attention";
import { mapSchema, type StateReason } from "../shared/domain";
import { rpcSchemas } from "../shared/schemas";
import { claim, map, snapshot, theme } from "./fixtures";
import { renderWithHost } from "./host-stub";

/**
 * The reason of a state.
 *
 * The reason comes from the canonical map. The console explains it, and it
 * never invents one when the program does not report it.
 */

function stateSnapshot(reason?: StateReason, sourceChanged = false) {
  const data = snapshot();
  data.map.states = [{ id: "hello", state: "outdated", source_changed: sourceChanged, ...(reason === undefined ? {} : { reason }) }];
  data.map.verdict = "unknown";
  data.map.exit = 3;
  return data;
}

test("the map state accepts the canonical reason", () => {
  const parsed = mapSchema.parse({
    ...map([claim()]),
    states: [{ id: "hello", state: "outdated", source_changed: false, reason: "environment-changed" }],
  });
  assert.equal(parsed.states[0]?.reason, "environment-changed");
});

test("the map state rejects an unknown reason", () => {
  assert.throws(() => mapSchema.parse({
    ...map([claim()]),
    states: [{ id: "hello", state: "outdated", source_changed: false, reason: "because" }],
  }));
});

test("the map state may omit the reason", () => {
  const parsed = mapSchema.parse({
    ...map([claim()]),
    states: [{ id: "hello", state: "outdated", source_changed: false }],
  });
  assert.equal(parsed.states[0]?.reason, undefined);
});

test("the snapshot contract keeps the reason of a state", () => {
  const data = stateSnapshot("materials-changed");
  const parsed = rpcSchemas.snapshot.output.parse(data);
  assert.equal(parsed.status, "ready");
  assert.equal(parsed.status === "ready" ? parsed.map.states[0]?.reason : undefined, "materials-changed");
});

test("the claim card explains the reason of the state", async () => {
  const { ClaimDetailView } = await import("../client/detail");
  const data = stateSnapshot("environment-changed");
  const markup = renderWithHost(createElement(ClaimDetailView, {
    theme,
    compact: false,
    snapshot: data,
    selection: { claimId: "hello" },
    onClose: () => undefined,
    onSelect: () => undefined,
    onRefresh: () => undefined,
  }));
  assert.ok(
    markup.includes("The environment changed after the evidence was recorded"),
    "the claim card does not explain the reason of the state",
  );
});

test("the claim card says when the program does not report a reason", async () => {
  const { ClaimDetailView } = await import("../client/detail");
  const data = stateSnapshot();
  const markup = renderWithHost(createElement(ClaimDetailView, {
    theme,
    compact: false,
    snapshot: data,
    selection: { claimId: "hello" },
    onClose: () => undefined,
    onSelect: () => undefined,
    onRefresh: () => undefined,
  }));
  assert.ok(
    markup.includes("This version does not report a reason for this state."),
    "the claim card does not admit that the reason is unknown",
  );
});

test("the attention card names the reason of the state", async () => {
  const { AttentionView } = await import("../client/attention-view");
  const data = stateSnapshot("verifier-changed");
  const model = buildAttentionModel(data, 1_000);
  const markup = renderWithHost(createElement(AttentionView, {
    theme,
    compact: false,
    model,
    context: attentionContext(data, model),
    onSelect: () => undefined,
    onRun: () => undefined,
    runEnabled: true,
  }));
  assert.ok(
    markup.includes("The verifier changed after the evidence was recorded"),
    "the attention card does not name the reason of the state",
  );
});

test("the brief of the agent carries the reason of the state", () => {
  const data = stateSnapshot("inconclusive");
  const model = buildAttentionModel(data, 1_000);
  const brief = attentionBrief(model.agentCanAct[0]!, attentionContext(data, model));
  assert.match(brief, /Reason: The check ran, but the observation neither established nor refuted the claim\./);
});

test("the brief of the human carries the reason of the state", () => {
  const data = stateSnapshot("source-changed", true);
  data.claims[0]!.source = { kind: "madr", path: "docs/adr.md", section: null, digest: "a".repeat(64), review: null };
  const model = buildAttentionModel(data, 1_000);
  assert.equal(model.needsHuman.length, 1);
  const brief = attentionBrief(model.needsHuman[0]!, attentionContext(data, model));
  assert.match(brief, /Reason: The linked source changed after the evidence was recorded\./);
});

test("the brief of a group lists the reason of every claim", () => {
  const claims = [claim({ id: "one" }), claim({ id: "two" })];
  const data = snapshot(claims);
  data.map.states = [
    { id: "one", state: "outdated", source_changed: false, reason: "expired" },
    { id: "two", state: "outdated", source_changed: false, reason: "not-run" },
  ];
  const model = buildAttentionModel(data, 1_000);
  const brief = attentionBrief(model.agentCanAct[0]!, attentionContext(data, model));
  assert.match(brief, /Reasons:/);
  assert.match(brief, /- one: The recorded evidence passed its validity period and no current result replaced it\./);
  assert.match(brief, /- two: The declared check did not run, so the claim has no current observation\./);
});
