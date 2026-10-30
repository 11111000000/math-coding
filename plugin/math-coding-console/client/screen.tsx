import { type PluginScreenProps, useSettings } from "@getpaseo/plugin/client";
import { useMemo } from "react";
import { ConsoleView } from "./console";
import { preferences } from "../shared/settings";

/**
 * The standalone screen.
 *
 * A screen has no workspace of its own, so it takes the repository from the
 * host setting — or from the parameters, when the screen was opened from a
 * session or a panel that knew which repository it meant.
 */
export function ConsoleScreen({ theme, layout, params }: PluginScreenProps) {
  const settings = useSettings(preferences);

  const root = useMemo(() => {
    const fromParams = params.root?.trim() ?? "";
    if (fromParams !== "") return fromParams;
    if (settings.status !== "ready") return null;
    const configured = settings.values.repoRoot.trim();
    return configured === "" ? null : configured;
  }, [params.root, settings.status]);

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
      agentId={params.agentId ?? null}
      initialTab={params.tab ?? null}
    />
  );
}
