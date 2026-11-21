import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test, type TestContext } from "node:test";
import type { PluginHandlerContext } from "@getpaseo/plugin/server";
import { ConsoleOperations } from "../server/core/operations";
import { PaseoOperationsHost } from "../server/paseo/service";
import {
  emptyHumanActionValues,
  humanActionArgv,
  humanActionCommand,
  humanActions,
  type HumanAction,
} from "../shared/human-actions";
import type { Claim, ClaimState } from "../shared/domain";
import { coded } from "./coded";
import { claim, map } from "./fixtures";

type Paseo = PluginHandlerContext["paseo"];

/**
 * The manual steps of the method.
 *
 * These fixtures hold two things at once: that the console offers the steps
 * the method declares, and that it performs them by asking the program. The
 * program in the fixtures is a fake that writes down what it was asked to do,
 * so the argument list of the program is the evidence.
 */

function reviewedClaim(overrides: Partial<Claim> = {}): Claim {
  return claim({
    id: "hello",
    requirements: [
      { kind: "verifier", spec: "sh test/check.sh" },
      { kind: "review", spec: "owner", minimum_independence: "external" },
    ],
    source: { kind: "madr", path: "docs/adr.md", section: null, digest: "a".repeat(64), review: null },
    ...overrides,
  });
}

function stepsOf(claims: Claim[], state: ClaimState, options: { sourceChanged?: boolean; policy?: boolean; now?: number } = {}) {
  const canonical = map(claims, state);
  canonical.states = claims.map((item) => ({
    id: item.id,
    state,
    source_changed: options.sourceChanged ?? false,
  }));
  return humanActions(
    { claims, states: canonical.states, policyConfigured: options.policy ?? false },
    options.now ?? 1_000,
  );
}

function paseoFor(directory: string): Paseo {
  return {
    workspaces: {
      ref: () => ({
        refresh: async () => ({
          id: "workspace-1",
          name: "Fixture",
          workspaceDirectory: directory,
        }),
      }),
    },
  } as unknown as Paseo;
}

function settingsFor(binaryPath: string, allowHumanDecisions: boolean) {
  return {
    read: async () => ({
      status: "ready" as const,
      revision: "revision-1",
      values: { binaryPath, allowRunChecks: false, allowHumanDecisions, autoRefreshSeconds: 30 as const },
    }),
    subscribe: () => () => undefined,
  };
}

interface Fake {
  root: string;
  binary: string;
  log: string;
}

/**
 * A project with a fake program.
 *
 * The fake answers `--version`, answers `map` with the map of the fixture and
 * records every argument list it was given.
 */
async function fakeProject(
  t: TestContext,
  options: { state?: ClaimState; sourceChanged?: boolean; policy?: boolean; refusal?: string } = {},
): Promise<Fake> {
  const root = await mkdtemp(join(tmpdir(), "mathc-decision-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  const log = join(root, "operations.log");
  const claims = [reviewedClaim()];
  const canonical = map(claims, options.state ?? "outdated");
  canonical.states = [{ id: "hello", state: options.state ?? "outdated", source_changed: options.sourceChanged ?? false }];
  await writeFile(
    join(root, "spec.json"),
    JSON.stringify({ schema_version: 6, goal: canonical.goal, claims }),
  );
  if (options.policy) {
    await writeFile(join(root, "policy.json"), JSON.stringify({ protected_paths: ["src/"], authorized_by: "owner" }));
  }
  const binary = join(root, "fake-mathc.js");
  await writeFile(
    binary,
    `#!/usr/bin/env node
const fs = require("fs");
const log = ${JSON.stringify(log)};
const args = process.argv.slice(2);
fs.appendFileSync(log, JSON.stringify(args) + "\\n");
if (args[0] === "--version") { process.stdout.write("mathc 5\\n"); process.exit(0); }
const verb = args[2];
if (verb === "map") {
  process.stdout.write(JSON.stringify(${JSON.stringify(canonical)}));
  process.exit(${canonical.exit});
}
if (${JSON.stringify(options.refusal ?? "")} !== "") {
  process.stderr.write("mathc: " + ${JSON.stringify(options.refusal ?? "")} + "\\n");
  process.exit(2);
}
process.stdout.write("recorded\\n");
process.exit(0);
`,
    { mode: 0o755 },
  );
  return { root, binary, log };
}

/**
 * Every call the program received.
 *
 * A missing log means the program was never called at all, which is what the
 * refusing fixtures check.
 */
async function callsOf(log: string): Promise<string[][]> {
  let content: string;
  try {
    content = await readFile(log, "utf8");
  } catch {
    return [];
  }
  return content.trim().split("\n").filter((line) => line.length > 0).map((line) => JSON.parse(line) as string[]);
}

function operationsFor(binary: string, allowHumanDecisions: boolean) {
  const operations = new ConsoleOperations();
  const host = (paseo: Paseo) => new PaseoOperationsHost(paseo, settingsFor(binary, allowHumanDecisions) as never);
  return {
    humanDecision: (paseo: Paseo, input: Parameters<ConsoleOperations["humanDecision"]>[1]) =>
      operations.humanDecision(host(paseo), input),
  };
}

test("the steps of the method are offered for the claims that need them", () => {
  const actions = stepsOf([reviewedClaim()], "outdated", { sourceChanged: true });
  assert.deepEqual(actions.map((action) => action.kind), ["review-source", "record", "waive"]);
  const record = actions.find((action) => action.kind === "record");
  assert.equal(record?.authority, "owner");
  assert.equal(record?.claimId, "hello");
});

test("a settled claim asks for nothing", () => {
  assert.deepEqual(stepsOf([reviewedClaim()], "holds"), []);
  assert.deepEqual(stepsOf([reviewedClaim()], "waived"), []);
});

test("a refuted claim cannot be waived", () => {
  const actions = stepsOf([reviewedClaim()], "refuted");
  assert.equal(actions.some((action) => action.kind === "waive"), false);
});

test("a review the program cannot satisfy is not offered", () => {
  const weak = reviewedClaim({
    requirements: [{ kind: "review", spec: "owner", minimum_independence: "self" }],
  });
  assert.equal(stepsOf([weak], "outdated").some((action) => action.kind === "record"), false);
});

test("the authorization step exists only when the project declares a policy", () => {
  assert.equal(stepsOf([reviewedClaim()], "holds", { policy: true }).some((action) => action.kind === "authorize"), true);
  assert.equal(stepsOf([reviewedClaim()], "holds", { policy: false }).some((action) => action.kind === "authorize"), false);
});

test("the command of a step is the command of the program", () => {
  const action = stepsOf([reviewedClaim()], "outdated").find((item) => item.kind === "record") as HumanAction;
  const argv = humanActionArgv(action, { ...emptyHumanActionValues(), by: "az", outcome: "pass" });
  assert.deepEqual(argv, ["record", "hello", "owner", "--by", "az", "--outcome", "pass"]);
  assert.equal(humanActionCommand(argv), "mathc record hello owner --by az --outcome pass");
});

test("an incomplete decision is refused before anything runs", () => {
  const action = stepsOf([reviewedClaim()], "outdated").find((item) => item.kind === "record") as HumanAction;
  assert.throws(
    () => humanActionArgv(action, { ...emptyHumanActionValues(), by: "az" }),
    coded("decision_needs_outcome"),
  );
  assert.throws(
    () => humanActionArgv(action, { ...emptyHumanActionValues(), outcome: "pass" }),
    coded("decision_needs_by"),
  );
});

test("an accepted risk needs a positive interval", () => {
  const action = stepsOf([reviewedClaim()], "outdated").find((item) => item.kind === "waive") as HumanAction;
  const base = { ...emptyHumanActionValues(), by: "az", reason: "the migration is late", recovery: "finish the migration" };
  assert.throws(() => humanActionArgv(action, { ...base, validForDays: "0" }), coded("validity_positive"));
  assert.throws(() => humanActionArgv(action, { ...base, validForDays: "" }), coded("days_required"));
  assert.deepEqual(
    humanActionArgv(action, { ...base, validForDays: "7" }),
    ["waive", "hello", "--by", "az", "--reason", "the migration is late", "--valid-for", "7", "--recovery", "finish the migration"],
  );
});

test("the console performs the step with the program", async (t) => {
  const project = await fakeProject(t, { state: "outdated" });
  const service = operationsFor(project.binary, true);
  const result = await service.humanDecision(paseoFor(project.root), {
    workspaceId: "workspace-1",
    confirmation: "APPLY_HUMAN_DECISION",
    kind: "record",
    claimId: "hello",
    authority: "owner",
    by: "az",
    outcome: "pass",
  });
  const calls = await callsOf(project.log);
  const decision = calls.find((call) => call[2] === "record");
  assert.deepEqual(decision, ["--root", project.root, "record", "hello", "owner", "--by", "az", "--outcome", "pass"]);
  assert.equal(result.snapshot.map.states[0]?.state, "outdated");
  assert.equal(result.message, "recorded");
});

test("a decision needs the explicit confirmation of the human", async (t) => {
  const project = await fakeProject(t, { state: "outdated" });
  const service = operationsFor(project.binary, true);
  await assert.rejects(
    service.humanDecision(paseoFor(project.root), {
      workspaceId: "workspace-1",
      confirmation: "NOPE" as "APPLY_HUMAN_DECISION",
      kind: "record",
      claimId: "hello",
      authority: "owner",
      by: "az",
      outcome: "pass",
    }),
    coded("human_decision_needs_confirmation"),
  );
  const calls = await callsOf(project.log);
  assert.equal(calls.some((call) => call[2] === "record"), false);
});

test("the decision stays closed until the host allows it", async (t) => {
  const project = await fakeProject(t, { state: "outdated" });
  const service = operationsFor(project.binary, false);
  await assert.rejects(
    service.humanDecision(paseoFor(project.root), {
      workspaceId: "workspace-1",
      confirmation: "APPLY_HUMAN_DECISION",
      kind: "record",
      claimId: "hello",
      authority: "owner",
      by: "az",
      outcome: "pass",
    }),
    /disabled/,
  );
  const calls = await callsOf(project.log);
  assert.equal(calls.some((call) => call[2] === "record"), false);
});

test("the refusal of the program is the refusal of the console", async (t) => {
  const project = await fakeProject(t, { state: "outdated", refusal: "only the claim owner can review its source" });
  const service = operationsFor(project.binary, true);
  await assert.rejects(
    service.humanDecision(paseoFor(project.root), {
      workspaceId: "workspace-1",
      confirmation: "APPLY_HUMAN_DECISION",
      kind: "record",
      claimId: "hello",
      authority: "owner",
      by: "someone",
      outcome: "pass",
    }),
    /only the claim owner can review its source/,
  );
});

test("a step the map does not offer never reaches the program", async (t) => {
  const project = await fakeProject(t, { state: "refuted" });
  const service = operationsFor(project.binary, true);
  await assert.rejects(
    service.humanDecision(paseoFor(project.root), {
      workspaceId: "workspace-1",
      confirmation: "APPLY_HUMAN_DECISION",
      kind: "waive",
      claimId: "hello",
      by: "az",
      reason: "the failure is not understood yet",
      validForDays: 7,
      recovery: "investigate the failure",
    }),
    coded("decision_not_available"),
  );
  const calls = await callsOf(project.log);
  assert.equal(calls.some((call) => call[2] === "waive"), false);
});

test("the authorization of a project without a policy never reaches the program", async (t) => {
  const project = await fakeProject(t, { state: "holds" });
  const service = operationsFor(project.binary, true);
  await assert.rejects(
    service.humanDecision(paseoFor(project.root), {
      workspaceId: "workspace-1",
      confirmation: "APPLY_HUMAN_DECISION",
      kind: "authorize",
      by: "owner",
      reason: "the protected change is reviewed",
    }),
    coded("decision_not_available"),
  );
  const calls = await callsOf(project.log);
  assert.equal(calls.some((call) => call[2] === "authorize"), false);
});

test("the state after the decision is the state the program reports", async (t) => {
  const project = await fakeProject(t, { state: "outdated", sourceChanged: true });
  const service = operationsFor(project.binary, true);
  const result = await service.humanDecision(paseoFor(project.root), {
    workspaceId: "workspace-1",
    confirmation: "APPLY_HUMAN_DECISION",
    kind: "review-source",
    claimId: "hello",
    by: "owner",
    reason: "the source still justifies the claim",
  });
  const calls = await callsOf(project.log);
  const decision = calls.find((call) => call[2] === "review-source");
  assert.deepEqual(decision, [
    "--root",
    project.root,
    "review-source",
    "hello",
    "--by",
    "owner",
    "--reason",
    "the source still justifies the claim",
  ]);
  assert.equal(result.snapshot.map.states[0]?.source_changed, true);
});
