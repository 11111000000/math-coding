import type {
  PluginClientContext,
  PluginCommandCenterItemContribution,
  PluginSidebarItemProps,
} from "@getpaseo/plugin/client";
import { SidebarRow } from "@getpaseo/plugin/client/ui";
import { ConsolePanel } from "./client/panel";
import { ConsoleScreen } from "./client/screen";
import { ReviewTimelineRow } from "./client/review-timeline";
import { SettingsScreen } from "./client/settings-screen";
import { reviewTimelineDataSchema } from "./shared/contracts";

const PANEL_ID = "math-coding-console";

function ConsoleItem({ currentScreen, openScreen }: PluginSidebarItemProps) {
  return (
    <SidebarRow
      icon="Sigma"
      label="math-coding"
      active={currentScreen?.screenId === PANEL_ID}
      onPress={() => openScreen({ screenId: PANEL_ID })}
    />
  );
}

/**
 * The console's contributions.
 *
 * The workspace panel is the main surface. The screen is the same console
 * without a workspace, for a host that wants it standalone. The Command
 * Center entries reach the same console from anywhere, including from an
 * agent, where the review knows which session to challenge.
 */
export default function contribute(client: PluginClientContext) {
  client.addWorkspacePanel({
    id: PANEL_ID,
    title: "math-coding",
    icon: "Sigma",
    locations: ["workspace", "explorer"],
    Component: ConsolePanel,
  });

  client.addScreen({
    id: PANEL_ID,
    title: "math-coding",
    Component: ConsoleScreen,
  });

  client.addSidebarHeaderItem({
    id: PANEL_ID,
    title: "math-coding",
    Component: ConsoleItem,
  });

  const openWorkspaceConsole: PluginCommandCenterItemContribution = {
    id: "open-math-coding-console",
    title: "Open the math-coding console",
    icon: "Sigma",
    keywords: [
      "math-coding",
      "matcoding",
      "kernel",
      "obligations",
      "obligations",
      "attestation",
      "attestations",
      "waiver",
      "decision",
      "decisions",
    ],
    context: "workspace",
    onSelect({ openPanel }) {
      openPanel(PANEL_ID);
    },
  };
  client.addCommandCenterItem(openWorkspaceConsole);

  const openAgentConsole: PluginCommandCenterItemContribution = {
    id: "review-math-coding",
    title: "Review the math-coding promises",
    icon: "Stamp",
    keywords: ["math-coding", "review", "sign", "attestation", "обещания", "ревью"],
    context: "agent",
    onSelect({ openScreen, agent }) {
      // The panel API carries no agent, so the review reaches the session
      // through the screen's parameters instead.
      openScreen({ screenId: PANEL_ID, params: { agentId: agent.id } });
    },
  };
  client.addCommandCenterItem(openAgentConsole);

  client.addSlashCommand({
    name: "mc",
    description: "Show the state of the math-coding corpus",
    argumentHint: "[decision id]",
    context: "workspace",
    async onSubmit({ args, openPanel }) {
      const decisionId = args.trim();
      void openPanel(PANEL_ID);
      if (decisionId !== "") {
        // The panel reads the decision from its own catalogue; the argument
        // only says which one the reader had in mind.
        console.log(`math-coding console: open decision ${decisionId}`);
      }
    },
  });

  client.addSettingsScreen({
    id: PANEL_ID,
    title: "math-coding",
    icon: "Sigma",
    Component: SettingsScreen,
  });

  client.addTimelineRenderer({
    kind: "math-coding-review",
    version: 1,
    schema: reviewTimelineDataSchema,
    Component: ReviewTimelineRow,
  });

  return () => {};
}
