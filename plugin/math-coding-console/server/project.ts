import { CodedError } from "../shared/errors";
import { createHash } from "node:crypto";
import { join } from "node:path";
import {
  type Claim,
  type MathMap,
  type EvidenceRecord,
  type Spec,
} from "../shared/domain";
import { canonicalJson } from "../shared/requirements";
import { generationName, journalPath, readMap, readSpec, type Generation } from "../shared/schema";
import { linkEvidence, parseTrail, revisionInput } from "./evidence";
import { parseJson, pathExists, readBounded, readOptionalBounded } from "./files";
import { runProcess, type ProcessResult } from "./process";

const MAP_TIMEOUT_MS = 120_000;
const RUN_TIMEOUT_MS = 15 * 60_000;
const MAX_MAP_BYTES = 16 * 1024 * 1024;
const MAX_SPEC_BYTES = 8 * 1024 * 1024;
const MAX_TRAIL_BYTES = 128 * 1024 * 1024;

export interface ProjectSnapshot {
  generatedAt: string;
  binary: { path: string; version: string };
  revision: string;
  map: MathMap;
  claims: Claim[];
  records?: EvidenceRecord[];
  /** Whether the project declares protected transitions. */
  policyConfigured: boolean;
  durationMs: number;
}

class ChangedDuringRead extends Error {}

function expectedExit(map: MathMap): number {
  if (map.verdict === "green") return 0;
  if (map.verdict === "red") return 1;
  return 3;
}

function processError(result: ProcessResult, operation: string): Error {
  if (result.timedOut) return new Error(`mathc ${operation} timed out`);
  if (result.truncated) return new Error(`mathc ${operation} output exceeded its limit`);
  if (result.systemError) return new Error(`Cannot execute mathc: ${result.systemError}`);
  const detail = result.stderr.trim().slice(0, 4000);
  return new Error(`mathc ${operation} failed with exit ${String(result.code)}${detail ? `: ${detail}` : ""}`);
}

function parseMap(result: ProcessResult, operation: string, generation: Generation): MathMap {
  if (result.timedOut || result.truncated || result.systemError) throw processError(result, operation);
  if (result.code === null || ![0, 1, 3].includes(result.code)) {
    // The program did not answer with a map. The project is of a generation
    // the console knows, so the console names it: the human sees which
    // schema the project speaks and what the program said about it.
    throw new CodedError(
      "program_cannot_map_project",
      `schema ${generationName(generation)}: ${processError(result, operation).message}`,
    );
  }
  if (result.stdout.trim() === "") throw processError(result, operation);
  const map = readMap(parseJson(result.stdout, `mathc ${operation} output`)).value;
  if (map.exit !== result.code || expectedExit(map) !== result.code) {
    throw new CodedError("map_inconsistent");
  }
  return map;
}

function validateJoin(map: MathMap, claims: Claim[]): void {
  const claimIds = claims.map((claim) => claim.id);
  const stateIds = map.states.map((state) => state.id);
  if (
    map.claims !== claims.length ||
    new Set(claimIds).size !== claimIds.length ||
    new Set(stateIds).size !== stateIds.length ||
    claimIds.length !== stateIds.length ||
    claimIds.some((id) => !stateIds.includes(id))
  ) {
    throw new CodedError("claim_sets_differ");
  }
}

/**
 * The map and the specification describe the same aim.
 *
 * The map of the generations before the fifth does not name the moment the
 * aim was declared, so the moment is compared only where both report it. The
 * text, the owner and the scope of the aim are compared always: they are
 * what makes it the same aim.
 */
function sameGoal(map: MathMap, spec: Spec): boolean {
  const fromMap = map.goal;
  const fromSpec = spec.goal;
  if (fromMap === null || fromSpec === null) return fromMap === fromSpec;
  return fromMap.text === fromSpec.text &&
    fromMap.by === fromSpec.by &&
    canonicalJson(fromMap.scope) === canonicalJson(fromSpec.scope) &&
    (fromMap.at === null || fromSpec.at === null || fromMap.at === fromSpec.at) &&
    (fromMap.reason ?? null) === (fromSpec.reason ?? null);
}

async function attempt(
  root: string,
  binary: string,
  operation: "map" | "run",
  includeTrail: boolean,
): Promise<ProjectSnapshot> {
  const specPath = join(root, "spec.json");
  const beforeSpec = await readBounded(specPath, MAX_SPEC_BYTES);
  /**
   * The generation of the project.
   *
   * The specification is read before the map, because it says which
   * generation the project is written in: the journal of that generation is
   * read in its own place, and the program of an earlier generation is
   * allowed to answer.
   */
  const generation = readSpec(parseJson(beforeSpec, "spec.json")).generation;
  const trailPath = journalPath(root, generation);
  const compareTrail = includeTrail && operation === "map";
  const beforeTrail = compareTrail ? await readOptionalBounded(trailPath, MAX_TRAIL_BYTES) : null;
  const version = await runProcess(binary, ["--version"], {
    cwd: root,
    timeoutMs: 10_000,
    maxBuffer: 64 * 1024,
  });
  const versionLines = version.stdout.trim().split("\n");
  const reportsMathc5 = versionLines[0] === "mathc 5" &&
    (versionLines.length === 1 ||
      (versionLines.length === 2 && /^build [0-9a-f]{64}$/.test(versionLines[1] ?? "")));
  if (!reportsMathc5 && generation === 6) {
    // The program of the current line reports its version. A program that
    // does not report it is not that program, and the console refuses it
    // before it runs it against the project.
    if (version.code !== 0) throw processError(version, "--version");
    throw new CodedError("binary_not_mathc5");
  }
  /**
   * The version of the program, as far as it reports one.
   *
   * The programs of the generations before the current one do not report a
   * version at all. The console carries that as unknown instead of naming a
   * version the program never said.
   */
  const programVersion = reportsMathc5 ? "mathc 5" : "";
  const result = await runProcess(binary, ["--root", root, operation, "--json"], {
    cwd: root,
    timeoutMs: operation === "run" ? RUN_TIMEOUT_MS : MAP_TIMEOUT_MS,
    maxBuffer: MAX_MAP_BYTES,
  });
  const map = parseMap(result, operation, generation);
  if (map.schema_version !== generation) {
    // The program answered in another generation than the project it read.
    // The console does not mix the two: it says that the generations differ.
    throw new CodedError(
      "schema_generations_differ",
      `the project is of schema ${generationName(generation)}, the program answered with schema ${generationName(map.schema_version as Generation)}`,
    );
  }
  const afterSpec = await readBounded(specPath, MAX_SPEC_BYTES);
  const afterTrail = includeTrail ? await readOptionalBounded(trailPath, MAX_TRAIL_BYTES) : null;
  if (beforeSpec !== afterSpec || (compareTrail && beforeTrail !== afterTrail)) throw new ChangedDuringRead();
  const spec = readSpec(parseJson(afterSpec, "spec.json")).value;
  validateJoin(map, spec.claims);
  if (!sameGoal(map, spec)) {
    throw new CodedError("goals_differ");
  }
  return {
    generatedAt: new Date().toISOString(),
    binary: { path: binary, version: programVersion },
    revision: createHash("sha256").update(revisionInput(map, spec.claims)).digest("hex"),
    map,
    claims: spec.claims,
    records: includeTrail ? linkEvidence(parseTrail(afterTrail ?? "", spec.claims), spec.claims) : undefined,
    policyConfigured: await pathExists(join(root, "policy.json")),
    durationMs: result.durationMs,
  };
}

export async function loadProject(
  root: string,
  binary: string,
  operation: "map" | "run" = "map",
  includeTrail = false,
): Promise<ProjectSnapshot> {
  try {
    return await attempt(root, binary, operation, includeTrail);
  } catch (error) {
    if (!(error instanceof ChangedDuringRead)) throw error;
  }
  try {
    return await attempt(root, binary, operation, includeTrail);
  } catch (error) {
    if (error instanceof ChangedDuringRead) {
      throw new CodedError("project_changed");
    }
    throw error;
  }
}
