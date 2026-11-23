import assert from "node:assert/strict";
import { test } from "node:test";
import { claimSchema, evidenceSchema, mapSchema, specSchema } from "../shared/domain";
import { preferences, snapshotRpc } from "../shared/contracts";
import { readMap, readSpec } from "../shared/schema";
import { linkEvidence, parseTrail } from "../server/evidence";
import { claim, evidence, map, nestedClaim, rawEvidence, unknownTool } from "./fixtures";

/**
 * A waiver as the specification carries it.
 *
 * The waiver has no review trigger any more: the fields the method does not
 * use are gone from the format, and the consumer refuses them like the program.
 */
function waiver() {
  return {
    gap: "temporary limitation",
    scope: ["src/"],
    issuer: "owner",
    issued_at: 900,
    expires_at: 1_100,
    reason: "accepted until the migration",
    compensating_controls: [],
    recovery: "finish the migration",
  };
}

test("accepts the v6 requirement tree and codec defaults", () => {
  const current = nestedClaim();
  const raw = {
    ...current,
    source: { ...current.source, review: undefined },
    requirements: current.requirements,
  };
  const parsed = specSchema.parse({ schema_version: 6, goal: null, claims: [raw] });
  assert.equal(parsed.claims[0]?.source?.review, null);
  assert.deepEqual(parsed.claims[0]?.requirements, current.requirements);
});

test("rejects unknown fields and unsupported schema versions", () => {
  assert.throws(() => specSchema.parse({ schema_version: 6, goal: null, claims: [], unexpected: true }));
  assert.throws(() => mapSchema.parse({ ...map([claim()]), extra: "laundering" }));
});

/**
 * A generation the console does not know is refused.
 *
 * The format version is the contract between the program and its readers. The
 * console reads the generations that exist and refuses the ones it does not
 * know: a reader that accepts an unknown version without saying so turns a
 * stale map into a fresh conclusion, and nothing else in the checks would
 * notice.
 */
test("a generation the console does not know is refused", () => {
  assert.throws(() => readMap({ ...map([claim()]), schema_version: 7 }), /unsupported schema_version 7/);
  assert.throws(() => readSpec({ schema_version: 7, goal: null, claims: [] }), /unsupported schema_version 7/);
});

/**
 * The map of a previous generation is read, and its observer is unknown.
 *
 * The map of the fifth generation names no observer. The console reads the map
 * and says that it does not know which build wrote it, instead of refusing
 * the project or naming a build of its own.
 */
test("the map of a previous generation is read with an unknown observer", () => {
  const { tool: _tool, ...withoutTool } = map([claim()]);
  const parsed = readMap({ ...withoutTool, schema_version: 5 });
  assert.equal(parsed.generation, 5);
  assert.equal(parsed.value.tool.fingerprint, "");
});

/**
 * The fields the specification no longer carries are refused.
 *
 * The program writes the fields it uses and no others, and the consumer
 * refuses the same ones. A field that only one side knows would be a field
 * that the reader believes and the writer never said.
 */
test("the fields the specification no longer carries are refused", () => {
  const base = { schema_version: 6, goal: null };
  assert.equal(specSchema.safeParse({ ...base, claims: [{ ...claim(), kind: "acceptance" }] }).success, false);
  assert.equal(specSchema.safeParse({ ...base, claims: [{ ...claim(), phase: "pre-merge" }] }).success, false);
  assert.equal(specSchema.safeParse({ ...base, claims: [{ ...claim(), review_on: [] }] }).success, false);
  assert.equal(specSchema.safeParse({ ...base, claims: [{ ...claim(), waiver: { ...waiver(), review_on: [] } }] }).success, false);
  assert.equal(specSchema.safeParse({ ...base, claims: [claim()], uncertainty_budget: {} }).success, false);
  assert.equal(specSchema.safeParse({ ...base, claims: [claim()], closed_waves: [] }).success, false);
  assert.equal(specSchema.safeParse({ ...base, claims: [claim()] }).success, true);
});

/**
 * The map names the program that produced it.
 *
 * The digest tells the reader which observer wrote the map. A map of the
 * current generation without it cannot be compared with the evidence it
 * carries, so the reader of that generation refuses it.
 */
test("the map names the program that produced it", () => {
  const parsed = mapSchema.parse(map([claim()]));
  assert.equal(parsed.tool.class, "mathc");
  assert.equal(parsed.tool.fingerprint.length, 64);
  assert.equal(mapSchema.safeParse({ ...map([claim()]), tool: undefined }).success, false);
  assert.throws(() => readMap({ ...map([claim()]), tool: undefined }), /validation/);
});

/**
 * The evidence record names the program that produced it.
 *
 * The digest of the producer travels with the record, so a reader can tell
 * that the observer changed without reading the journal again.
 */
test("the evidence record names the program that produced it", () => {
  const parsed = evidenceSchema.parse(rawEvidence());
  assert.equal(parsed.tool.class, "mathc");
  assert.equal(parsed.tool.fingerprint.length, 64);
  assert.equal(evidenceSchema.safeParse({ ...rawEvidence(), tool: undefined }).success, false);
});

/**
 * A record carried over from the previous format names an unknown program.
 *
 * The migration cannot know which program wrote a record of the previous
 * format. It says so honestly with an empty fingerprint, and the consumer
 * reads such a record instead of refusing it: the record is not broken, only
 * its producer is unknown.
 */
test("a record carried over from the previous format names an unknown program", () => {
  const migrated = evidenceSchema.parse({ ...rawEvidence(), tool: unknownTool });
  assert.equal(migrated.tool.class, "mathc");
  assert.equal(migrated.tool.fingerprint, "");
  assert.equal(
    evidenceSchema.safeParse({ ...rawEvidence(), tool: { class: "", fingerprint: "" } }).success,
    false,
  );
  assert.equal(
    evidenceSchema.safeParse({ ...rawEvidence(), tool: { class: "mathc", fingerprint: 42 } }).success,
    false,
  );
});

/**
 * The map of the current generation always names the program that wrote it.
 *
 * A map is written by the program that reads it, so it knows its own digest.
 * An empty digest there would name nothing, and the reader of that generation
 * refuses it. The maps of the previous generations carry no digest at all,
 * and the reader of those carries an unknown observer.
 */
test("the map refuses a digest of the program that names nothing", () => {
  assert.throws(() => readMap({ ...map([claim()]), tool: unknownTool }), /validation/);
  assert.throws(() => readMap({ ...map([claim()]), tool: { class: "", fingerprint: "e".repeat(64) } }), /validation/);
});

test("carries the declared environment of the specification", () => {
  const declared = specSchema.parse({
    schema_version: 6,
    environment: "nix develop -c",
    goal: null,
    claims: [],
  });
  assert.equal(declared.environment, "nix develop -c");
  const absent = specSchema.parse({ schema_version: 6, goal: null, claims: [] });
  assert.equal(absent.environment, undefined);
  assert.equal(
    specSchema.safeParse({ schema_version: 6, environment: 42, goal: null, claims: [] }).success,
    false,
  );
  assert.equal(
    specSchema.safeParse({
      schema_version: 6,
      environment: "x".repeat(513),
      goal: null,
      claims: [],
    }).success,
    false,
  );
});

test("version one settings migrate with Run checks disabled", () => {
  const migrated = preferences.migrate?.({ binaryPath: "", autoRefreshSeconds: 30 }, 1);
  assert.deepEqual(migrated, {
    binaryPath: "",
    autoRefreshSeconds: 30,
    allowRunChecks: false,
    allowHumanDecisions: false,
  });
});

test("version two settings keep the permission to run checks and close the decisions", () => {
  const migrated = preferences.migrate?.({ binaryPath: "", allowRunChecks: true, autoRefreshSeconds: 30 }, 2);
  assert.deepEqual(migrated, {
    binaryPath: "",
    allowRunChecks: true,
    allowHumanDecisions: false,
    autoRefreshSeconds: 30,
  });
});

test("the permission to record a human decision is closed by default", () => {
  const values = preferences.schema.parse({});
  assert.equal(values.allowHumanDecisions, false);
  assert.equal(values.allowRunChecks, false);
});

test("carries the environment a claim declares for itself", () => {
  const withEnvironment = claimSchema.parse({
    ...claim(),
    environment: "nix develop -c",
  });
  assert.equal(withEnvironment.environment, "nix develop -c");
  const without = claimSchema.parse(claim());
  assert.equal(without.environment, undefined);
  assert.equal(
    claimSchema.safeParse({ ...claim(), environment: null }).success,
    true,
  );
  assert.equal(
    claimSchema.safeParse({ ...claim(), environment: 42 }).success,
    false,
  );
  assert.equal(
    claimSchema.safeParse({ ...claim(), environment: "x".repeat(513) }).success,
    false,
  );
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
