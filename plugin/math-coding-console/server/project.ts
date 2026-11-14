import { createHash } from "node:crypto";
import { join } from "node:path";
import {
  mapSchema,
  specSchema,
  type Claim,
  type MathMap,
  type EvidenceRecord,
} from "../shared/domain";
import { canonicalJson } from "../shared/requirements";
import { linkEvidence, parseTrail, revisionInput } from "./evidence";
import { parseJson, parseWith, readBounded, readOptionalBounded } from "./files";
import { runProcess, type ProcessResult } from "./process";

const MAP_TIMEOUT_MS = 120_000;
const RUN_TIMEOUT_MS = 15 * 60_000;
const MAX_MAP_BYTES = 16 * 1024 * 1024;
const MAX_SPEC_BYTES = 8 * 1024 * 1024;
const MAX_TRAIL_BYTES = 128 * 1024 * 1024;

export interface ProjectSnapshot {
  generatedAt: string;
  binary: { path: string; version: "mathc 5" };
  revision: string;
  map: MathMap;
  claims: Claim[];
  records?: EvidenceRecord[];
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

function parseMap(result: ProcessResult, operation: string): MathMap {
  if (result.timedOut || result.truncated || result.systemError) throw processError(result, operation);
  if (result.code === null || ![0, 1, 3].includes(result.code)) throw processError(result, operation);
  if (result.stdout.trim() === "") throw processError(result, operation);
  const map = parseWith(mapSchema, parseJson(result.stdout, `mathc ${operation} output`), "mathc map");
  if (map.exit !== result.code || expectedExit(map) !== result.code) {
    throw new Error("mathc returned an inconsistent verdict and exit code");
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
    throw new Error("mathc map and spec.json describe different claim sets");
  }
}

async function attempt(
  root: string,
  binary: string,
  operation: "map" | "run",
  includeTrail: boolean,
): Promise<ProjectSnapshot> {
  const specPath = join(root, "spec.json");
  const trailPath = join(root, ".math", "v5", "evidence.jsonl");
  const beforeSpec = await readBounded(specPath, MAX_SPEC_BYTES);
  const compareTrail = includeTrail && operation === "map";
  const beforeTrail = compareTrail ? await readOptionalBounded(trailPath, MAX_TRAIL_BYTES) : null;
  const version = await runProcess(binary, ["--version"], {
    cwd: root,
    timeoutMs: 10_000,
    maxBuffer: 64 * 1024,
  });
  const versionLines = version.stdout.trim().split("\n");
  const validVersion = versionLines[0] === "mathc 5" &&
    (versionLines.length === 1 ||
      (versionLines.length === 2 && /^build [0-9a-f]{64}$/.test(versionLines[1] ?? "")));
  if (version.code !== 0 || !validVersion) {
    if (version.code !== 0) throw processError(version, "--version");
    throw new Error("The configured binary is not mathc 5");
  }
  const result = await runProcess(binary, ["--root", root, operation, "--json"], {
    cwd: root,
    timeoutMs: operation === "run" ? RUN_TIMEOUT_MS : MAP_TIMEOUT_MS,
    maxBuffer: MAX_MAP_BYTES,
  });
  const map = parseMap(result, operation);
  const afterSpec = await readBounded(specPath, MAX_SPEC_BYTES);
  const afterTrail = includeTrail ? await readOptionalBounded(trailPath, MAX_TRAIL_BYTES) : null;
  if (beforeSpec !== afterSpec || (compareTrail && beforeTrail !== afterTrail)) throw new ChangedDuringRead();
  const spec = parseWith(specSchema, parseJson(afterSpec, "spec.json"), "spec.json");
  validateJoin(map, spec.claims);
  if (canonicalJson(map.goal) !== canonicalJson(spec.goal)) {
    throw new Error("mathc map and spec.json describe different goals");
  }
  return {
    generatedAt: new Date().toISOString(),
    binary: { path: binary, version: "mathc 5" },
    revision: createHash("sha256").update(revisionInput(map, spec.claims)).digest("hex"),
    map,
    claims: spec.claims,
    records: includeTrail ? linkEvidence(parseTrail(afterTrail ?? ""), spec.claims) : undefined,
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
      throw new Error("Project files changed while the snapshot was being read; refresh to retry");
    }
    throw error;
  }
}
