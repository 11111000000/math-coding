import { isAbsolute, join } from "node:path";
import type { PluginHandlerContext, PluginSettings } from "@getpaseo/plugin/server";
import type { ClaimDetail, EvidencePage, Preferences, Snapshot, SnapshotReady } from "../shared/contracts";
import { evidencePage, newestFirst } from "./evidence";
import { pathExists } from "./files";
import { loadProject, type ProjectSnapshot } from "./project";

type Paseo = PluginHandlerContext["paseo"];
type Settings = PluginSettings<typeof import("../shared/contracts").preferences.schema>;

interface Workspace {
  id: string;
  name: string | null;
  directory: string;
}

async function resolveWorkspace(paseo: Paseo, workspaceId: string): Promise<Workspace> {
  const workspace = await paseo.workspaces.ref(workspaceId).refresh();
  if (!workspace || !workspace.workspaceDirectory || !isAbsolute(workspace.workspaceDirectory)) {
    throw new Error("The workspace is unavailable or has no absolute project directory");
  }
  return { id: workspace.id, name: workspace.name, directory: workspace.workspaceDirectory };
}

async function preferenceValues(settings: Settings): Promise<Preferences> {
  const state = await settings.read();
  if (state.status !== "ready") throw new Error(`Math Coding settings are invalid: ${state.error}`);
  return state.values;
}

function binaryFromPreferences(values: Preferences): string {
  const configured = values.binaryPath.trim();
  if (configured === "") return "mathc";
  if (!isAbsolute(configured)) throw new Error("The mathc binary override must be an absolute path");
  return configured;
}

function readySnapshot(workspace: Workspace, project: ProjectSnapshot): SnapshotReady {
  return {
    status: "ready",
    workspace,
    generatedAt: project.generatedAt,
    binary: project.binary,
    revision: project.revision,
    map: project.map,
    claims: project.claims,
  };
}

function page(records: import("../shared/domain").EvidenceRecord[], cursor: number | undefined, limit: number) {
  return evidencePage(newestFirst(records), cursor, limit);
}

export class ProjectService {
  private readonly tails = new Map<string, Promise<void>>();
  private readonly depths = new Map<string, number>();

  constructor(private readonly settings: Settings) {}

  private async exclusive<T>(key: string, operation: () => Promise<T>): Promise<T> {
    const depth = this.depths.get(key) ?? 0;
    if (depth >= 2) throw new Error("Math Coding workspace is busy; try again after the current operation");
    this.depths.set(key, depth + 1);
    const previous = this.tails.get(key) ?? Promise.resolve();
    const result = previous.catch(() => undefined).then(operation);
    const tail = result.then(() => undefined, () => undefined);
    this.tails.set(key, tail);
    try {
      return await result;
    } finally {
      const remaining = (this.depths.get(key) ?? 1) - 1;
      if (remaining <= 0) this.depths.delete(key);
      else this.depths.set(key, remaining);
      if (this.tails.get(key) === tail) this.tails.delete(key);
    }
  }

  async snapshot(paseo: Paseo, workspaceId: string): Promise<Snapshot> {
    const workspace = await resolveWorkspace(paseo, workspaceId);
    return this.exclusive(workspace.directory, async () => {
      if (!(await pathExists(join(workspace.directory, "spec.json")))) {
        return { status: "not-initialized", workspace, generatedAt: new Date().toISOString() };
      }
      const values = await preferenceValues(this.settings);
      const project = await loadProject(workspace.directory, binaryFromPreferences(values));
      return readySnapshot(workspace, project);
    });
  }

  async claimDetail(
    paseo: Paseo,
    input: { workspaceId: string; claimId: string; cursor?: number; limit: number },
  ): Promise<ClaimDetail> {
    const workspace = await resolveWorkspace(paseo, input.workspaceId);
    return this.exclusive(workspace.directory, async () => {
      const values = await preferenceValues(this.settings);
      const project = await loadProject(workspace.directory, binaryFromPreferences(values), "map", true);
      const claim = project.claims.find((item) => item.id === input.claimId);
      if (!claim) throw new Error(`Unknown claim: ${input.claimId}`);
      const records = (project.records ?? []).filter((record) => record.claim_id === input.claimId);
      const selected = page(records, input.cursor, input.limit);
      return {
        revision: project.revision,
        generatedAt: project.generatedAt,
        map: project.map,
        claim,
        total: records.length,
        nextCursor: selected.nextCursor,
        records: selected.records,
      };
    });
  }

  async evidence(
    paseo: Paseo,
    input: { workspaceId: string; cursor?: number; limit: number },
  ): Promise<EvidencePage> {
    const workspace = await resolveWorkspace(paseo, input.workspaceId);
    return this.exclusive(workspace.directory, async () => {
      const values = await preferenceValues(this.settings);
      const project = await loadProject(workspace.directory, binaryFromPreferences(values), "map", true);
      const selected = page(project.records ?? [], input.cursor, input.limit);
      return {
        revision: project.revision,
        generatedAt: project.generatedAt,
        map: project.map,
        total: project.records?.length ?? 0,
        nextCursor: selected.nextCursor,
        records: selected.records,
      };
    });
  }

  async run(
    paseo: Paseo,
    input: { workspaceId: string; confirmation: "RUN_CHECKS" },
  ): Promise<{ snapshot: SnapshotReady; durationMs: number }> {
    if (input.confirmation !== "RUN_CHECKS") throw new Error("Run checks requires explicit confirmation");
    const workspace = await resolveWorkspace(paseo, input.workspaceId);
    return this.exclusive(workspace.directory, async () => {
      const values = await preferenceValues(this.settings);
      if (!values.allowRunChecks) {
        throw new Error("Run checks are disabled; enable them in the Math Coding plugin settings");
      }
      const project = await loadProject(workspace.directory, binaryFromPreferences(values), "run");
      return { snapshot: readySnapshot(workspace, project), durationMs: project.durationMs };
    });
  }
}
