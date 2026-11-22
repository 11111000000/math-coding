import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test, type TestContext } from "node:test";
import type { PluginHandlerContext } from "@getpaseo/plugin/server";
import { ConsoleOperations } from "../server/core/operations";
import { PaseoOperationsHost } from "../server/paseo/service";
import { coded } from "./coded";
import { claim, map } from "./fixtures";
import type { MathMap } from "../shared/domain";

type Paseo = PluginHandlerContext["paseo"];

function paseoFor(directory: string | null): Paseo {
  return {
    workspaces: {
      ref: () => ({
        refresh: async () => directory === null ? null : {
          id: "workspace-1",
          name: "Fixture",
          workspaceDirectory: directory,
        },
      }),
    },
  } as unknown as Paseo;
}

function settings(binaryPath = "", allowRunChecks = true) {
  return {
    read: async () => ({
      status: "ready" as const,
      revision: "revision-1",
      values: { binaryPath, allowRunChecks, autoRefreshSeconds: 30 as const },
    }),
    subscribe: () => () => undefined,
  };
}

async function temp(t: TestContext): Promise<string> {
  const root = await mkdtemp(join(tmpdir(), "mathc-service-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  return root;
}

/**
 * The Paseo adapter resolves the project, the shared operations do the work.
 * The browser host resolves the project the same way and calls the same
 * operations, so these tests cover the shared behaviour.
 */
function consoleService(settingsValue: ReturnType<typeof settings>) {
  const operations = new ConsoleOperations();
  const host = (paseo: Paseo) => new PaseoOperationsHost(paseo, settingsValue as never);
  return {
    snapshot: async (paseo: Paseo, workspaceId: string) =>
      operations.snapshot(host(paseo), workspaceId),
    run: async (paseo: Paseo, input: { workspaceId: string; confirmation: "RUN_CHECKS" }) =>
      operations.run(host(paseo), input),
  };
}

test("an uninitialized workspace is not presented as a verdict", async (t) => {
  const root = await temp(t);
  const service = consoleService(settings("relative/mathc") as never);
  const result = await service.snapshot(paseoFor(root), "workspace-1");
  assert.equal(result.status, "not-initialized");
  if (result.status === "not-initialized") assert.equal(result.workspace.directory, root);
});

test("a missing workspace is an explicit error", async (t) => {
  const root = await temp(t);
  const service = consoleService(settings() as never);
  await assert.rejects(service.snapshot(paseoFor(null), "workspace-1"), /workspace is unavailable/);
});

test("a relative binary override is rejected before execution", async (t) => {
  const root = await temp(t);
  await writeFile(join(root, "spec.json"), JSON.stringify({ schema_version: 6, goal: map([claim()]).goal, claims: [claim()] }));
  const service = consoleService(settings("relative/mathc") as never);
  await assert.rejects(service.snapshot(paseoFor(root), "workspace-1"), coded("binary_path_not_absolute"));
});

test("run requires explicit confirmation", async (t) => {
  const root = await temp(t);
  const service = consoleService(settings() as never);
  await assert.rejects(
    service.run(paseoFor(root), { workspaceId: "workspace-1", confirmation: "NOPE" as "RUN_CHECKS" }),
    coded("run_checks_needs_confirmation"),
  );
});

test("run remains disabled until the host setting is enabled", async (t) => {
  const root = await temp(t);
  await writeFile(join(root, "spec.json"), JSON.stringify({ schema_version: 6, goal: map([claim()]).goal, claims: [claim()] }));
  const service = consoleService(settings("", false) as never);
  await assert.rejects(
    service.run(paseoFor(root), { workspaceId: "workspace-1", confirmation: "RUN_CHECKS" }),
    coded("run_checks_disabled"),
  );
});

test("map and run are serialized for one workspace and the queue is bounded", async (t) => {
  const root = await temp(t);
  await writeFile(join(root, "spec.json"), JSON.stringify({ schema_version: 6, goal: map([claim()]).goal, claims: [claim()] }));
  const green = map([claim()], "holds");
  const red = map([claim()], "refuted");
  const log = join(root, "operations.log");
  const binary = join(root, "fake-mathc.js");
  await writeFile(binary, `#!/usr/bin/env node
const fs = require("fs");
const log = ${JSON.stringify(log)};
const green = ${JSON.stringify(green)};
const red = ${JSON.stringify(red)};
if (process.argv[2] === "--version") { process.stdout.write("mathc 5\\n"); process.exit(0); }
const operation = process.argv[4];
fs.appendFileSync(log, operation + "-start\\n");
if (operation === "map") setTimeout(() => {
  fs.appendFileSync(log, "map-end\\n");
  process.stdout.write(JSON.stringify(green));
  process.exit(0);
}, 150);
else {
  process.stdout.write(JSON.stringify(red));
  process.exit(1);
}
`, { mode: 0o755 });
  const service = consoleService(settings(binary) as never);
  const snapshotPromise = service.snapshot(paseoFor(root), "workspace-1");
  await Promise.resolve();
  const runPromise = service.run(paseoFor(root), { workspaceId: "workspace-1", confirmation: "RUN_CHECKS" });
  await Promise.resolve();
  const extraPromise = service.snapshot(paseoFor(root), "workspace-1");
  await assert.rejects(extraPromise, /busy/);
  const [snapshot, run] = await Promise.all([snapshotPromise, runPromise]);
  assert.equal(snapshot.status, "ready");
  assert.equal(run.snapshot.map.verdict, "red");
  assert.deepEqual((await readFile(log, "utf8")).trim().split("\n"), [
    "map-start",
    "map-end",
    "run-start",
  ]);
});
