import assert from "node:assert/strict";
import { mkdir, mkdtemp, readFile, rm, stat, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test, type TestContext } from "node:test";
import { loadProject } from "../server/project";
import { claim, map, rawEvidence } from "./fixtures";
import type { MathMap } from "../shared/domain";

async function fixture(t: TestContext, initial = map([claim()])) {
  const root = await mkdtemp(join(tmpdir(), "mathc-plugin-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  const spec = { schema_version: 5, goal: initial.goal, claims: [claim()] };
  await writeFile(join(root, "spec.json"), JSON.stringify(spec));
  const binary = join(root, "fake-mathc.js");
  await setMap(binary, root, initial);
  return { root, binary };
}

async function setMap(binary: string, root: string, value: MathMap | null, version = "mathc 5") {
  const marker = join(root, "run-marker");
  const source = `#!/usr/bin/env node
const fs = require("fs");
if (process.argv[2] === "--version") { process.stdout.write(${JSON.stringify(`${version}\n`)}); process.exit(0); }
if (process.argv[4] === "run") { fs.mkdirSync(${JSON.stringify(join(root, ".math", "v5"))}, { recursive: true }); fs.appendFileSync(${JSON.stringify(join(root, ".math", "v5", "evidence.jsonl"))}, JSON.stringify(${JSON.stringify(rawEvidence())}) + "\\n"); fs.appendFileSync(${JSON.stringify(marker)}, "run\\n"); }
if (${JSON.stringify(value)} === null) { process.stderr.write("invalid trail\\n"); process.exit(3); }
process.stdout.write(JSON.stringify(${JSON.stringify(value)}));
process.exit(${value?.exit ?? 3});
`;
  await writeFile(binary, source, { mode: 0o755 });
}

test("accepts canonical green, red and unknown maps with their domain exit codes", async (t) => {
  for (const state of ["holds", "refuted", "never-checked"] as const) {
    const expected = map([claim()], state);
    const { root, binary } = await fixture(t, expected);
    const actual = await loadProject(root, binary);
    assert.equal(actual.map.verdict, expected.verdict);
    assert.equal(actual.map.exit, expected.exit);
  }
});

test("accepts the installed version format with a build digest", async (t) => {
  const current = map([claim()]);
  const { root, binary } = await fixture(t, current);
  await setMap(binary, root, current, `mathc 5\nbuild ${"a".repeat(64)}`);
  const actual = await loadProject(root, binary);
  assert.equal(actual.binary.version, "mathc 5");
});

test("rejects invocation errors, missing maps, malformed maps and wrong versions", async (t) => {
  const current = map([claim()]);
  const { root, binary } = await fixture(t, current);
  await setMap(binary, root, null);
  await assert.rejects(loadProject(root, binary), /invalid trail/);
  await setMap(binary, root, { ...current, exit: 2 });
  await assert.rejects(loadProject(root, binary), /exit 2/);
  await setMap(binary, root, { ...current, schema_version: 4 } as unknown as MathMap);
  await assert.rejects(loadProject(root, binary), /validation/);
  await setMap(binary, root, current, "mathc 4");
  await assert.rejects(loadProject(root, binary), /not mathc 5/);
});

test("rejects map/spec claim mismatches and inconsistent exits", async (t) => {
  const current = map([claim()]);
  const { root, binary } = await fixture(t, current);
  await setMap(binary, root, { ...current, claims: 2 });
  await assert.rejects(loadProject(root, binary), /different claim sets/);
  await setMap(binary, root, { ...current, exit: 1 });
  await assert.rejects(loadProject(root, binary), /inconsistent verdict and exit/);
});

test("a missing trail is empty and a corrupt trail rejects the whole detail", async (t) => {
  const current = map([claim()]);
  const { root, binary } = await fixture(t, current);
  assert.deepEqual((await loadProject(root, binary, "map", true)).records, []);
  const trail = join(root, ".math", "v5", "evidence.jsonl");
  await mkdir(join(root, ".math", "v5"), { recursive: true });
  await writeFile(trail, `${JSON.stringify(rawEvidence())}\nbroken\n`, { flag: "w" });
  await assert.rejects(loadProject(root, binary, "map", true), /line 2/);
  await writeFile(trail, `${JSON.stringify(rawEvidence())}\n`);
  assert.equal((await loadProject(root, binary, "map", true)).records?.length, 1);
});

test("map has no run side effect; explicit run invokes the run verb", async (t) => {
  const current = map([claim()]);
  const { root, binary } = await fixture(t, current);
  const marker = join(root, "run-marker");
  await loadProject(root, binary, "map");
  await assert.rejects(stat(marker), /ENOENT/);
  await loadProject(root, binary, "run");
  assert.equal(await readFile(marker, "utf8"), "run\n");
});

test("run returns the post-run evidence trail instead of treating it as a concurrent edit", async (t) => {
  const current = map([claim()]);
  const { root, binary } = await fixture(t, current);
  const project = await loadProject(root, binary, "run", true);
  assert.equal(project.records?.length, 1);
  assert.equal(project.records?.[0]?.outcome, "pass");
});
