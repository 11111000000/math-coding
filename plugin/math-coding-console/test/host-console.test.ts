import assert from "node:assert/strict";
import { test } from "node:test";
import { runScale } from "../client/run-scale";
import type { Claim } from "../shared/domain";
import { claim, snapshot } from "./fixtures";

test("the run scale counts the claims and the commands of the canonical snapshot", () => {
  const claims: Claim[] = [
    claim({ id: "one" }),
    claim({ id: "two", requirements: [{ kind: "verifier", spec: "sh test/a.sh" }, { kind: "verifier", spec: "sh test/b.sh" }], control: null }),
    claim({ id: "three", requirements: [{ kind: "review", spec: "owner", minimum_independence: "external" }], control: null }),
  ];
  const scale = runScale(snapshot(claims));
  assert.equal(scale.claimCount, 3);
  // one verifier and one control for the first claim, two verifiers for the
  // second, and no command for the review-only claim
  assert.equal(scale.commandCount, 4);
});

test("the run scale of an empty map is zero", () => {
  const scale = runScale(snapshot([]));
  assert.equal(scale.claimCount, 0);
  assert.equal(scale.commandCount, 0);
});
