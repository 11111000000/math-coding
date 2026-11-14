import assert from "node:assert/strict";
import { test } from "node:test";
import { buildProofGraph, buildScopeGraph, layoutGraph } from "../client/graph-layout";
import { claim, nestedClaim, snapshot } from "./fixtures";

test("proof graph follows source and requirement links only", () => {
  const current = nestedClaim();
  const data = snapshot([current]);
  const collapsed = buildProofGraph(data, new Set());
  assert.ok(collapsed.nodes.some((node) => node.id === "source:madr:docs/adr.md:Decision"));
  assert.ok(collapsed.edges.some((edge) => edge.to === "claim:nested"));
  assert.equal(collapsed.nodes.some((node) => node.kind === "requirement"), false);
  const expanded = buildProofGraph(data, new Set(["nested"]));
  assert.ok(expanded.nodes.some((node) => node.requirementPath === "0/1/0"));
  assert.ok(expanded.edges.every((edge) => edge.kind === "proof"));
  assert.equal(expanded.edges.some((edge) => edge.from.startsWith("claim:") && edge.to.startsWith("claim:")), false);
});

test("scope graph labels shared declarations without inventing dependencies", () => {
  const a = claim({ id: "a", scope: ["src/"] });
  const b = claim({ id: "b", scope: ["src/"] });
  const data = snapshot([a, b]);
  data.map.uncovered = ["README.md"];
  const graph = buildScopeGraph(data);
  const shared = graph.nodes.find((node) => node.id === "scope:src/");
  assert.match(shared?.subtitle ?? "", /shared declared scope/);
  assert.ok(graph.edges.filter((edge) => edge.to === "scope:src/").every((edge) => edge.kind === "shared-scope"));
  assert.equal(graph.edges.some((edge) => edge.from === "claim:a" && edge.to === "claim:b"), false);
  assert.ok(graph.nodes.some((node) => node.id === "uncovered:README.md"));
});

test("layout is deterministic and compact mode produces a readable vertical order", () => {
  const model = buildProofGraph(snapshot([nestedClaim()]), new Set(["nested"]));
  const first = layoutGraph(model, false);
  assert.deepEqual(first, layoutGraph(model, false));
  assert.ok(first.edges.every((edge) => edge.segments.length > 0));
  const compact = layoutGraph(model, true);
  assert.deepEqual(compact, layoutGraph(model, true));
  const positions = new Map(compact.nodes.map((node) => [node.id, node]));
  const parent = positions.get("claim:nested");
  const child = positions.get("requirement:nested:0");
  assert.ok(parent && child && child.y > parent.y && child.x > parent.x);
});

test("large claim sets are bounded and reported as truncated", () => {
  const claims = Array.from({ length: 150 }, (_, index) => claim({ id: `claim-${index}` }));
  const graph = buildProofGraph(snapshot(claims), new Set());
  assert.equal(graph.nodes.filter((node) => node.kind === "claim").length, 120);
  assert.equal(graph.truncated, 30);
});
