import { View } from "react-native";
import type { ConsoleTheme } from "../shared/theme";
import type { RunScale } from "./run-scale";
import { HostModalContent } from "./host/sheet";
import { useT } from "./i18n";
import { Body, Button, Note } from "./parts";

/**
 * The confirmation of a run of the project checks.
 *
 * The body is a component of its own, so the checks can draw it without the
 * modal around it: the host draws a closed modal as nothing at all.
 */
export function RunConfirmation({ theme, scale, running, error, onCancel, onRun }: {
  theme: ConsoleTheme;
  scale: RunScale | undefined;
  running: boolean;
  error: unknown;
  onCancel: () => void;
  onRun: () => void;
}) {
  const t = useT();
  return (
    <HostModalContent>
      <View style={{ gap: 14 }}>
        <Body theme={theme}>{t("run.body")}</Body>
        <Body theme={theme} muted>{t("run.scale", { claims: scale?.claimCount ?? 0, commands: scale?.commandCount ?? 0 })}</Body>
        <Body theme={theme} muted>{t("run.never_automatic")}</Body>
        {error !== null && error !== undefined && <Note theme={theme} tone="bad">{t("run.failed", { error: String(error) })}</Note>}
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8, justifyContent: "flex-end" }}>
          <Button theme={theme} label={t("common.cancel")} onPress={onCancel} disabled={running} />
          <Button theme={theme} label={running ? t("common.running_checks") : t("run.run")} icon="Play" variant="danger" onPress={onRun} disabled={running} />
        </View>
      </View>
    </HostModalContent>
  );
}
