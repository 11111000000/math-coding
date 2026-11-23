import assert from "node:assert/strict";
import { test } from "node:test";
import { journalPath, readEvidence, readMap, readSpec } from "../shared/schema";
import {
  claim,
  claimLegacyV3,
  claimLegacyV4,
  claimV5,
  evidenceLegacyV3,
  evidenceLegacyV4,
  evidenceV5,
  map,
  mapLegacy,
  mapV5,
  rawEvidence,
  specLegacy,
  specV5,
} from "./fixtures";

/**
 * The console reads the generations that exist.
 *
 * A project on disk is written in the schema of its own generation. The
 * console reads the current generation and the ones before it, so a project
 * of a previous line is shown instead of being refused. Every reader is
 * strict about the format it reads: a field of another generation is an
 * error, not silence.
 */

test("the specification of the current generation is read", () => {
  const read = readSpec({ schema_version: 6, goal: null, claims: [claim()] });
  assert.equal(read.generation, 6);
  assert.equal(read.value.claims.length, 1);
  assert.equal(read.value.claims[0]?.id, "hello");
});

test("the specification of the fifth generation is read and its dead fields are dropped", () => {
  const read = readSpec(specV5());
  assert.equal(read.generation, 5);
  assert.equal(read.value.claims.length, 1);
  const claim5 = read.value.claims[0];
  assert.equal(claim5?.text, "the command prints hello");
  assert.deepEqual(claim5?.requirements, [{ kind: "verifier", spec: "sh test/check.sh" }]);
  assert.equal("kind" in (claim5 ?? {}), false);
  assert.equal("phase" in (claim5 ?? {}), false);
  assert.equal("review_on" in (claim5 ?? {}), false);
});

test("the specification of the third generation is read as the claim it declared", () => {
  const read = readSpec(specLegacy([claimLegacyV3()]));
  assert.equal(read.generation, 3);
  const claim3 = read.value.claims[0];
  assert.equal(claim3?.text, "the command prints hello");
  assert.deepEqual(claim3?.requirements, [{ kind: "verifier", spec: "sh test/check.sh" }]);
  // The only person that generation named for a claim is the person who
  // accepted it.
  assert.equal(claim3?.owner, "owner");
  assert.equal(claim3?.source, null);
  assert.equal(claim3?.waiver, null);
});

test("the specification of the fourth generation is read as a tree of conditions", () => {
  const read = readSpec(specLegacy([claimLegacyV4()]));
  assert.equal(read.generation, 4);
  assert.deepEqual(read.value.claims[0]?.requirements, [{ kind: "verifier", spec: "sh test/check.sh" }]);
});

test("a specification of the generations before the fifth without claims is the fourth", () => {
  const read = readSpec(specLegacy([]));
  assert.equal(read.generation, 4);
  assert.deepEqual(read.value.claims, []);
});

test("a specification of a generation the console does not know is refused", () => {
  assert.throws(() => readSpec({ schema_version: 7, goal: null, claims: [] }), /unsupported schema_version 7/);
  assert.throws(() => readSpec({ schema_version: 2, goal: null, claims: [] }), /unsupported schema_version 2/);
});

test("a field of another generation is refused instead of ignored", () => {
  assert.throws(() => readSpec({ schema_version: 6, goal: null, claims: [], uncertainty_budget: 3 }), /validation/);
  assert.throws(() => readSpec({ schema_version: 5, goal: null, claims: [claim()], kind: "invariant" }), /validation/);
  assert.throws(() => readSpec({ ...specLegacy(), surprise: true }), /validation/);
});

test("the map of the current generation is read with the observer it names", () => {
  const read = readMap(map([claim()]));
  assert.equal(read.generation, 6);
  assert.equal(read.value.tool.class, "mathc");
  assert.equal(read.value.tool.fingerprint.length, 64);
});

test("a map of the current generation without the digest of the program is refused", () => {
  const { tool: _tool, ...withoutTool } = map([claim()]);
  assert.throws(() => readMap(withoutTool), /validation/);
  assert.throws(() => readMap({ ...map([claim()]), tool: { class: "mathc", fingerprint: "" } }), /validation/);
});

test("the map of the fifth generation is read with an unknown observer", () => {
  const read = readMap(mapV5());
  assert.equal(read.generation, 5);
  assert.equal(read.value.tool.class, "mathc");
  assert.equal(read.value.tool.fingerprint, "");
  assert.equal(read.value.states[0]?.state, "holds");
});

test("the map of the fifth generation keeps the reason of that generation", () => {
  const read = readMap({
    ...mapV5(),
    states: [{ id: "hello", state: "not-checkable", source_changed: false, reason: "not-checkable" }],
  });
  assert.equal(read.value.states[0]?.state, "not-checkable");
  assert.equal(read.value.states[0]?.reason, "not-checkable");
});

test("the map of the fourth generation keeps the words of that generation", () => {
  const read = readMap({
    ...mapLegacy(),
    states: [{ id: "hello", state: "not checkable" }],
  });
  assert.equal(read.generation, 4);
  assert.equal(read.value.tool.fingerprint, "");
  assert.equal(read.value.states[0]?.state, "not-checkable");
  // That map does not say whether the source of a claim changed.
  assert.equal(read.value.states[0]?.source_changed, null);
  assert.equal(read.value.next, "");
  assert.deepEqual(read.value.uncovered, ["docs/other.md"]);
});

test("a map of a generation the console does not know is refused", () => {
  assert.throws(() => readMap({ ...map([claim()]), schema_version: 7 }), /unsupported schema_version 7/);
});

test("the record of the current generation is read with the producer it names", () => {
  const read = readEvidence(rawEvidence(), [claim()]);
  assert.equal(read.generation, 6);
  assert.equal(read.value.tool.fingerprint.length, 64);
  assert.equal(read.value.independence, "fresh-context");
});

test("the record of the fifth generation is read with an unknown producer", () => {
  const read = readEvidence(evidenceV5(), [claim()]);
  assert.equal(read.generation, 5);
  assert.equal(read.value.tool.class, "mathc");
  assert.equal(read.value.tool.fingerprint, "");
});

test("the record of the third generation takes the condition from the claim it speaks about", () => {
  const read = readEvidence(evidenceLegacyV3(), [claim()]);
  assert.equal(read.generation, 3);
  assert.equal(read.value.claim_id, "hello");
  assert.deepEqual(read.value.requirement, { kind: "verifier", spec: "sh test/check.sh" });
  assert.equal(read.value.outcome, "pass");
  assert.equal(read.value.issued_at, 1_790_000_100);
  // That record binds itself to nothing it does not name.
  assert.equal(read.value.materials_digest, "");
  assert.equal(read.value.environment, null);
  assert.equal(read.value.independence, null);
  assert.equal(read.value.tool.fingerprint, "");
});

test("the record of the fourth generation names its condition and its reach", () => {
  const read = readEvidence(evidenceLegacyV4(), [claim()]);
  assert.equal(read.generation, 4);
  assert.deepEqual(read.value.requirement, { kind: "verifier", spec: "sh test/check.sh" });
  assert.equal(read.value.outcome, "fail");
  assert.equal(read.value.control_reach, "subject");
  assert.equal(read.value.producer.class, "process");
});

test("a record of a generation the console does not know is refused", () => {
  assert.throws(() => readEvidence({ ...rawEvidence(), schema_version: 7 }, [claim()]), /unsupported evidence schema_version 7/);
});

test("the journal of a project is read in the place of its generation", () => {
  assert.equal(journalPath("/project", 6), "/project/.math/v6/evidence.jsonl");
  assert.equal(journalPath("/project", 5), "/project/.math/v5/evidence.jsonl");
  assert.equal(journalPath("/project", 4), "/project/.math/trail.jsonl");
  assert.equal(journalPath("/project", 3), "/project/.math/trail.jsonl");
});

test("the claim of the fifth generation keeps the fields the current one reads", () => {
  const read = readSpec({
    schema_version: 5,
    goal: null,
    claims: [{
      ...claimV5(),
      owner: "owner",
      source: { kind: "madr", path: "docs/adr.md", section: null, digest: "e".repeat(64), review: null },
    }],
  });
  assert.equal(read.value.claims[0]?.owner, "owner");
  assert.equal(read.value.claims[0]?.source?.path, "docs/adr.md");
});
