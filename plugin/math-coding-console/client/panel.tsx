import {
  type PluginWorkspacePanelProps,
  useSettings,
  useWorkspace,
} from "@getpaseo/plugin/client";
import { useMemo } from "react";
import { ConsoleView } from "./console";
import { preferences } from "../shared/settings";

/**
 * The workspace panel.
 *
 * The panel is scoped to the workspace it lives in, so the repository is the
 * workspace's own directory. The host setting is the fallback for a workspace
 * that holds no corpus of its own.
 */
export function ConsolePanel({ theme, layout, workspaceId }: PluginWorkspacePanelProps) {
  const workspaceDirectory = useWorkspace(workspaceId, (workspace) => workspace.directory);
  const settings = useSettings(preferences);

  const root = useMemo(() => {
    const configured = settings.status === "ready" ? settings.values.repoRoot.trim() : "";
    if (configured !== "") return configured;
    return workspaceDirectory ?? null;
  }, [settings.status, workspaceDirectory]);

  const reviewProducer =
    settings.status === "ready" && settings.values.reviewProducer.trim() !== ""
      ? settings.values.reviewProducer.trim()
      : "human:reviewer";
  const attestRunCommand = settings.status === "ready" ? settings.values.attestRunCommand : "";

  return (
    <ConsoleView
      theme={theme}
      compact={layout.compact}
      root={root}
      reviewProducer={reviewProducer}
      attestRunCommand={attestRunCommand}
    />
  );
}
