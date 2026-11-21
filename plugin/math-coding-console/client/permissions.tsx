import { View } from "react-native";
import type { ConsoleTheme } from "../shared/theme";
import { useT } from "./i18n";
import { Badge, Body, Button, Card } from "./parts";

export interface PermissionsCardProps {
  theme: ConsoleTheme;
  compact: boolean;
  /** Whether the host allows the console to run the checks of the project. */
  runEnabled: boolean | null;
  /** Whether the host allows the console to record a decision of the human. */
  decisionsEnabled: boolean | null;
  /** Opens the settings of the host, where the permissions live. */
  onOpenSettings: () => void;
}

/**
 * What the console can do right now.
 *
 * The console reads the project at any time. Two actions need a permission of
 * the host, and both permissions are closed by default. A closed button
 * without a reason is a button nobody can read, so the card names the switch
 * that opens it and offers the way to the settings of the host.
 */
export function PermissionsCard({ theme, compact, runEnabled, decisionsEnabled, onOpenSettings }: PermissionsCardProps) {
  const t = useT();
  const known = runEnabled !== null && decisionsEnabled !== null;
  if (known && runEnabled && decisionsEnabled) return null;
  return (
    <Card theme={theme} compact={compact} title={t("permissions.title")} subtitle={t("permissions.read_always")}>
      <View style={{ gap: 8 }}>
        <PermissionRow
          theme={theme}
          icon="Play"
          label={t("permissions.run")}
          enabled={runEnabled}
          switchLabel={t("settings.allow_run")}
        />
        <PermissionRow
          theme={theme}
          icon="Stamp"
          label={t("permissions.decisions")}
          enabled={decisionsEnabled}
          switchLabel={t("settings.allow_decisions")}
        />
        <Button theme={theme} compact label={t("permissions.open_settings")} icon="Settings" onPress={onOpenSettings} />
      </View>
    </Card>
  );
}

/**
 * One permission and the switch that opens it.
 *
 * The name of the switch is the name the settings screen gives it, so the
 * human reads the same words in the panel and in the settings.
 */
function PermissionRow({ theme, icon, label, enabled, switchLabel }: {
  theme: ConsoleTheme;
  icon: string;
  label: string;
  enabled: boolean | null;
  switchLabel: string;
}) {
  const t = useT();
  const state = enabled === null ? t("permissions.unknown") : enabled ? t("permissions.on") : t("permissions.off");
  const tone = enabled === null ? "neutral" : enabled ? "good" : "warn";
  return (
    <View style={{ gap: 3 }}>
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6, alignItems: "center" }}>
        <Badge theme={theme} label={label} icon={icon} />
        <Badge theme={theme} label={state} tone={tone} />
      </View>
      {enabled === false && <Body theme={theme} muted>{t("permissions.switch_off", { switch: switchLabel })}</Body>}
    </View>
  );
}
