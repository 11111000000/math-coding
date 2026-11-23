import assert from "node:assert/strict";
import { mkdir, mkdtemp, readFile, rm, stat, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test, type TestContext } from "node:test";
import { loadProject } from "../server/project";
import { coded } from "./coded";
import {
  claim,
  claimLegacyV4,
  evidenceV5,
  map,
  mapLegacy,
  mapV5,
  rawEvidence,
  specLegacy,
  specV5,
} from "./fixtures";
import type { MathMap } from "../shared/domain";

async function fixture(t: TestContext, initial = map([claim()])) {
  const root = await mkdtemp(join(tmpdir(), "mathc-plugin-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  const spec = { schema_version: 6, goal: initial.goal, claims: [claim()] };
  await writeFile(join(root, "spec.json"), JSON.stringify(spec));
  const binary = join(root, "fake-mathc.js");
  await setMap(binary, root, initial);
  return { root, binary };
}

/**
 * A project of a generation of its own.
 *
 * The specification, the map and the program are written the way that
 * generation writes them, so the reader of the generation is checked against
 * the files that exist in the world.
 */
async function fixtureOf(
  t: TestContext,
  spec: Record<string, unknown>,
  value: unknown,
  version = "mathc 5",
  stderr = "invalid trail\n",
  code = 3,
) {
  const root = await mkdtemp(join(tmpdir(), "mathc-plugin-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  await writeFile(join(root, "spec.json"), JSON.stringify(spec));
  const binary = join(root, "fake-mathc.js");
  await setMap(binary, root, value, version, stderr, code);
  return { root, binary };
}

async function setMap(
  binary: string,
  root: string,
  value: unknown,
  version = "mathc 5",
  stderr = "invalid trail\n",
  code = 3,
) {
  const marker = join(root, "run-marker");
  const source = `#!/usr/bin/env node
const fs = require("fs");
if (process.argv[2] === "--version") { process.stdout.write(${JSON.stringify(`${version}\n`)}); process.exit(0); }
if (process.argv[4] === "run") { fs.mkdirSync(${JSON.stringify(join(root, ".math", "v6"))}, { recursive: true }); fs.appendFileSync(${JSON.stringify(join(root, ".math", "v6", "evidence.jsonl"))}, JSON.stringify(${JSON.stringify(rawEvidence())}) + "\\n"); fs.appendFileSync(${JSON.stringify(marker)}, "run\\n"); }
if (${JSON.stringify(value)} === null) { process.stderr.write(${JSON.stringify(stderr)}); process.exit(${code}); }
process.stdout.write(JSON.stringify(${JSON.stringify(value)}));
process.exit(${(value as { exit?: number } | null)?.exit ?? 3});
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
  await assert.rejects(loadProject(root, binary), /schema_version/);
  await setMap(binary, root, { ...current, schema_version: 5 } as unknown as MathMap);
  await assert.rejects(loadProject(root, binary), /validation/);
  await setMap(binary, root, current, "mathc 4");
  await assert.rejects(loadProject(root, binary), coded("binary_not_mathc5"));
});

test("rejects map/spec claim mismatches and inconsistent exits", async (t) => {
  const current = map([claim()]);
  const { root, binary } = await fixture(t, current);
  await setMap(binary, root, { ...current, claims: 2 });
  await assert.rejects(loadProject(root, binary), coded("claim_sets_differ"));
  await setMap(binary, root, { ...current, exit: 1 });
  await assert.rejects(loadProject(root, binary), coded("map_inconsistent"));
});

test("a missing trail is empty and a corrupt trail rejects the whole detail", async (t) => {
  const current = map([claim()]);
  const { root, binary } = await fixture(t, current);
  assert.deepEqual((await loadProject(root, binary, "map", true)).records, []);
  const trail = join(root, ".math", "v6", "evidence.jsonl");
  await mkdir(join(root, ".math", "v6"), { recursive: true });
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

/**
 * A project of the previous line is read by the newest console.
 *
 * The project is written in the fifth generation: the specification names
 * the version, the map names no observer and the journal lies in the place
 * of that generation. The console reads all three and says which generation
 * it read.
 */
test("a project of the fifth generation is read", async (t) => {
  const { root, binary } = await fixtureOf(t, specV5(), mapV5());
  const project = await loadProject(root, binary, "map", true);
  assert.equal(project.map.schema_version, 5);
  assert.equal(project.map.tool.fingerprint, "");
  assert.equal(project.claims.length, 1);
  assert.equal(project.claims[0]?.text, "the command prints hello");
  assert.deepEqual(project.records, []);
});

test("the journal of the fifth generation is read from the place of that generation", async (t) => {
  const { root, binary } = await fixtureOf(t, specV5(), mapV5());
  const trail = join(root, ".math", "v5", "evidence.jsonl");
  await mkdir(join(root, ".math", "v5"), { recursive: true });
  await writeFile(trail, JSON.stringify(evidenceV5()) + "\n");
  const project = await loadProject(root, binary, "map", true);
  assert.equal(project.records?.length, 1);
  assert.equal(project.records?.[0]?.tool.fingerprint, "");
  assert.equal(project.records?.[0]?.schema_version, 5);
});

/**
 * A project of the generations before the fifth is read as well.
 *
 * Those generations did not number their files. The console reads the
 * specification and the map of such a project, keeps the words of that
 * generation and says that it does not know which program wrote the map.
 */
test("a project of the generations before the fifth is read", async (t) => {
  const { root, binary } = await fixtureOf(t, specLegacy([claimLegacyV4()]), mapLegacy());
  const project = await loadProject(root, binary, "map", true);
  assert.equal(project.map.schema_version, 4);
  assert.equal(project.map.tool.fingerprint, "");
  assert.equal(project.claims.length, 1);
  assert.equal(project.claims[0]?.text, "the command prints hello");
});

/**
 * A program that cannot map the project says so, and names the schema.
 *
 * The program of the current line refuses a project of a previous
 * generation. The console does not turn that refusal into a green map: it
 * names the generation of the project and repeats what the program said.
 */
test("a program that cannot map the project names the schema of the project", async (t) => {
  const refusal = "mathc: the standing specification is not readable\n";
  const { root, binary } = await fixtureOf(t, specV5(), null, "mathc 5", refusal, 2);
  await assert.rejects(loadProject(root, binary), coded("program_cannot_map_project"));
  await assert.rejects(loadProject(root, binary), /schema v5/);
});

/**
 * The program of a previous generation is allowed to answer.
 *
 * The programs of the generations before the current one do not report a
 * version at all. The console asks the program for the map and reads what it
 * says, instead of refusing a program that never promised a version.
 */
test("the program of a previous generation is allowed to answer", async (t) => {
  const { root, binary } = await fixtureOf(t, specLegacy([claimLegacyV4()]), mapLegacy(), "");
  const project = await loadProject(root, binary);
  assert.equal(project.map.schema_version, 4);
  assert.equal(project.binary.version, "");
});

/**
 * The program of the current line is still required to name itself.
 *
 * A project of the current generation is read by the program of that
 * generation, and that program reports its version. A program that does not
 * report it is refused before it runs against the project.
 */
test("the program of the current line is still required to name itself", async (t) => {
  const spec = { schema_version: 6, goal: null, claims: [claim()] };
  const { root, binary } = await fixtureOf(t, spec, map([claim()]), "mathc 4");
  await assert.rejects(loadProject(root, binary), coded("binary_not_mathc5"));
});
