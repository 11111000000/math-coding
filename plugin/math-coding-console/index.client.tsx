import type { PluginClientContext } from "@getpaseo/plugin/client";
import { ConsolePanel } from "./client/console";
import { HostProvider } from "./client/host/context";
import { createPaseoHost, messages } from "./client/host/paseo";
import { LocaleProvider } from "./client/i18n";
import { SettingsScreen } from "./client/settings";

const PANEL_ID = "math-coding-console";
const SETTINGS_ID = "math-coding";

export default function contribute(client: PluginClientContext) {
  /**
   * The host of the console.
   *
   * The permissions of the console live in the settings screen of the plugin,
   * so the host opens that screen for the human who has to change them.
   */
  const paseoHost = createPaseoHost({ openSettings: () => client.openSettings(SETTINGS_ID) });
  /**
   * The labels the host draws.
   *
   * The title of the panel, the entry of the command center, the description of
   * the slash command and the title of the settings screen belong to the host,
   * so the host draws them and resolves them in the language of the
   * application. The interface the plugin draws itself follows the preference
   * of the human instead.
   */
  client.addWorkspacePanel({
    id: PANEL_ID,
    title: messages.message("host.panel_title"),
    icon: "UserRoundCheck",
    locations: ["workspace", "explorer"],
    Component: (props) => (
      <HostProvider value={paseoHost}>
        <LocaleProvider>
          <ConsolePanel {...props} />
        </LocaleProvider>
      </HostProvider>
    ),
  });
  client.addCommandCenterItem({
    id: "open-math-coding-map",
    title: messages.message("host.command_center_title"),
    icon: "UserRoundCheck",
    keywords: ["mathc", "attention", "decisions", "agent", "evidence", "claims", "coverage", "proof"],
    context: "workspace",
    onSelect({ openPanel }) {
      openPanel(PANEL_ID);
    },
  });
  client.addSlashCommand({
    name: "mc",
    description: messages.message("host.slash_description"),
    argumentHint: "",
    context: "workspace",
    onSubmit({ openPanel }) {
      openPanel(PANEL_ID);
    },
  });
  client.addSettingsScreen({
    id: SETTINGS_ID,
    title: messages.message("host.settings_title"),
    icon: "UserRoundCheck",
    Component: (props) => (
      <HostProvider value={paseoHost}>
        <LocaleProvider>
          <SettingsScreen {...props} />
        </LocaleProvider>
      </HostProvider>
    ),
  });
  return () => {};
}
