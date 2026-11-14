import type { PluginClientContext } from "@getpaseo/plugin/client";
import { ConsolePanel } from "./client/console";
import { SettingsScreen } from "./client/settings";

const PANEL_ID = "math-coding-console";

export default function contribute(client: PluginClientContext) {
  client.addWorkspacePanel({
    id: PANEL_ID,
    title: "Math Coding",
    icon: "Workflow",
    locations: ["workspace", "explorer"],
    Component: ConsolePanel,
  });
  client.addCommandCenterItem({
    id: "open-math-coding-map",
    title: "Open Math Coding map",
    icon: "Workflow",
    keywords: ["mathc", "evidence", "claims", "coverage", "proof"],
    context: "workspace",
    onSelect({ openPanel }) {
      openPanel(PANEL_ID);
    },
  });
  client.addSlashCommand({
    name: "mc",
    description: "Open the Math Coding evidence map",
    argumentHint: "",
    context: "workspace",
    onSubmit({ openPanel }) {
      openPanel(PANEL_ID);
    },
  });
  client.addSettingsScreen({
    id: "math-coding",
    title: "Map and runtime",
    icon: "Workflow",
    Component: SettingsScreen,
  });
  return () => {};
}
