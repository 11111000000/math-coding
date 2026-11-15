import type { PluginClientContext } from "@getpaseo/plugin/client";
import { ConsolePanel } from "./client/console";
import { HostProvider } from "./client/host/context";
import { createPaseoHost } from "./client/host/paseo";
import { SettingsScreen } from "./client/settings";

const PANEL_ID = "math-coding-console";
const paseoHost = createPaseoHost();

export default function contribute(client: PluginClientContext) {
  client.addWorkspacePanel({
    id: PANEL_ID,
    title: "Math Coding",
    icon: "UserRoundCheck",
    locations: ["workspace", "explorer"],
    Component: (props) => (
      <HostProvider value={paseoHost}>
        <ConsolePanel {...props} />
      </HostProvider>
    ),
  });
  client.addCommandCenterItem({
    id: "open-math-coding-map",
    title: "Open Math Coding attention desk",
    icon: "UserRoundCheck",
    keywords: ["mathc", "attention", "decisions", "agent", "evidence", "claims", "coverage", "proof"],
    context: "workspace",
    onSelect({ openPanel }) {
      openPanel(PANEL_ID);
    },
  });
  client.addSlashCommand({
    name: "mc",
    description: "Open the Math Coding attention desk",
    argumentHint: "",
    context: "workspace",
    onSubmit({ openPanel }) {
      openPanel(PANEL_ID);
    },
  });
  client.addSettingsScreen({
    id: "math-coding",
    title: "Attention and runtime",
    icon: "UserRoundCheck",
    Component: (props) => (
      <HostProvider value={paseoHost}>
        <SettingsScreen {...props} />
      </HostProvider>
    ),
  });
  return () => {};
}
