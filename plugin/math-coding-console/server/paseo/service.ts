import { isAbsolute } from "node:path";
import type { PluginHandlerContext, PluginSettings } from "@getpaseo/plugin/server";
import { preferencesDefinition, type Preferences } from "../../shared/schemas";
import {
  binaryFromPreferences,
  type OperationsHost,
  type RuntimeSettings,
  type WorkspaceInfo,
} from "../core/operations";

type Paseo = PluginHandlerContext["paseo"];
type Settings = PluginSettings<typeof preferencesDefinition.schema>;

async function resolveWorkspace(paseo: Paseo, workspaceId: string): Promise<WorkspaceInfo> {
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

/**
 * Resolves a Paseo workspace to a project on disk.
 *
 * The browser host resolves a project the same way, but from its own process
 * arguments instead of the workspace SDK.
 */
export class PaseoOperationsHost implements OperationsHost {
  constructor(
    private readonly paseo: Paseo,
    private readonly settings: Settings,
  ) {}

  async resolveWorkspace(workspaceId: string): Promise<WorkspaceInfo> {
    return resolveWorkspace(this.paseo, workspaceId);
  }

  async resolveRuntime(_workspace: WorkspaceInfo): Promise<RuntimeSettings> {
    const values = await preferenceValues(this.settings);
    return {
      binary: binaryFromPreferences(values),
      allowRunChecks: values.allowRunChecks,
    };
  }
}
