import { isAbsolute, join } from "node:path";
import type {
  ClaimDetail,
  EvidencePage,
  FilePreview,
  HumanDecisionInput,
  HumanDecisionOutput,
  Preferences,
  Snapshot,
  SnapshotReady,
} from "../../shared/schemas";
import { evidencePage, newestFirst } from "../evidence";
import { pathExists } from "../files";
import { applyHumanDecision } from "./human-decision";
import { loadProject, type ProjectSnapshot } from "../project";
import { readWorkspaceEntry } from "../workspace-file";

export interface WorkspaceInfo {
  id: string;
  name: string | null;
  directory: string;
}

export interface RuntimeSettings {
  binary: string;
  allowRunChecks: boolean;
  /**
   * Whether the console may record a decision of the human.
   *
   * A decision of the human writes into the project. The permission is closed
   * by default and opened by the human in the settings of the host.
   */
  allowHumanDecisions: boolean;
}

/**
 * A host resolves a request to a concrete project on disk.
 *
 * Resolution is split in two on purpose. The workspace is resolved first, so
 * an uninitialised project is reported as such without reading settings; the
 * runtime settings are resolved afterwards, inside the operation, so an
 * invalid binary override never hides the project state.
 *
 * The Paseo host resolves the workspace through the SDK, the browser host
 * resolves the project it was started for. The operations below are identical
 * for both.
 */
export interface OperationsHost {
  resolveWorkspace(workspaceId: string): Promise<WorkspaceInfo>;
  resolveRuntime(workspace: WorkspaceInfo): Promise<RuntimeSettings>;
}

export function binaryFromPreferences(values: Preferences): string {
  const configured = values.binaryPath.trim();
  if (configured === "") return "mathc";
  if (!isAbsolute(configured)) throw new Error("The mathc binary override must be an absolute path");
  return configured;
}

function readySnapshot(workspace: WorkspaceInfo, project: ProjectSnapshot): SnapshotReady {
  return {
    status: "ready",
    workspace,
    generatedAt: project.generatedAt,
    binary: project.binary,
    revision: project.revision,
    map: project.map,
    claims: project.claims,
    policyConfigured: project.policyConfigured,
  };
}

function page(records: import("../../shared/domain").EvidenceRecord[], cursor: number | undefined, limit: number) {
  return evidencePage(newestFirst(records), cursor, limit);
}

export class ConsoleOperations {
  private readonly tails = new Map<string, Promise<void>>();
  private readonly depths = new Map<string, number>();

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

  async snapshot(host: OperationsHost, workspaceId: string): Promise<Snapshot> {
    const workspace = await host.resolveWorkspace(workspaceId);
    return this.exclusive(workspace.directory, async () => {
      if (!(await pathExists(join(workspace.directory, "spec.json")))) {
        return { status: "not-initialized", workspace, generatedAt: new Date().toISOString() };
      }
      const runtime = await host.resolveRuntime(workspace);
      const project = await loadProject(workspace.directory, runtime.binary);
      return readySnapshot(workspace, project);
    });
  }

  async claimDetail(
    host: OperationsHost,
    input: { workspaceId: string; claimId: string; cursor?: number; limit: number },
  ): Promise<ClaimDetail> {
    const workspace = await host.resolveWorkspace(input.workspaceId);
    return this.exclusive(workspace.directory, async () => {
      const runtime = await host.resolveRuntime(workspace);
      const project = await loadProject(workspace.directory, runtime.binary, "map", true);
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
    host: OperationsHost,
    input: { workspaceId: string; cursor?: number; limit: number },
  ): Promise<EvidencePage> {
    const workspace = await host.resolveWorkspace(input.workspaceId);
    return this.exclusive(workspace.directory, async () => {
      const runtime = await host.resolveRuntime(workspace);
      const project = await loadProject(workspace.directory, runtime.binary, "map", true);
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
    host: OperationsHost,
    input: { workspaceId: string; confirmation: "RUN_CHECKS" },
  ): Promise<{ snapshot: SnapshotReady; durationMs: number }> {
    if (input.confirmation !== "RUN_CHECKS") throw new Error("Run checks requires explicit confirmation");
    const workspace = await host.resolveWorkspace(input.workspaceId);
    return this.exclusive(workspace.directory, async () => {
      const runtime = await host.resolveRuntime(workspace);
      if (!runtime.allowRunChecks) {
        throw new Error("Run checks are disabled; enable them in Math Coding settings");
      }
      const project = await loadProject(workspace.directory, runtime.binary, "run");
      return { snapshot: readySnapshot(workspace, project), durationMs: project.durationMs };
    });
  }

  /**
   * The read-only preview of one entry of the workspace.
   *
   * The console shows the subject of a claim so the human can read it without
   * leaving the panel. The read is bounded and stays inside the workspace.
   */
  async filePreview(
    host: OperationsHost,
    input: { workspaceId: string; path: string; maxBytes: number },
  ): Promise<FilePreview> {
    const workspace = await host.resolveWorkspace(input.workspaceId);
    return this.exclusive(workspace.directory, async () => {
      return readWorkspaceEntry(workspace.directory, input.path, input.maxBytes);
    });
  }

  /**
   * Record one decision of the human.
   *
   * The decision is performed by the program, never by the console. The
   * console checks three things before it runs anything: the explicit
   * agreement of the human, the permission of the host, and the presence of
   * the step in the current canonical map. The state after the decision is the
   * one the program reports.
   */
  async humanDecision(host: OperationsHost, input: HumanDecisionInput): Promise<HumanDecisionOutput> {
    if (input.confirmation !== "APPLY_HUMAN_DECISION") {
      throw new Error("A human decision requires explicit confirmation");
    }
    const workspace = await host.resolveWorkspace(input.workspaceId);
    return this.exclusive(workspace.directory, async () => {
      const runtime = await host.resolveRuntime(workspace);
      if (!runtime.allowHumanDecisions) {
        throw new Error("Human decisions are disabled; enable them in Math Coding settings");
      }
      const result = await applyHumanDecision(workspace.directory, runtime.binary, input);
      return { snapshot: readySnapshot(workspace, result.snapshot), message: result.message };
    });
  }
}
