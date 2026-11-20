import type { ConsoleTheme } from "../shared/theme";
import { Text, View } from "react-native";
import type { SnapshotReady } from "../shared/schemas";
import type { AttentionModel } from "./attention";
import { useT } from "./i18n";
import { Badge, Body, Button, Card, Mono } from "./parts";
import { verdictColor, verdictKey } from "./vocabulary";

export function InstrumentFrame({ theme, compact, snapshot, attention, onRefresh, refreshing, onRun, running, runEnabled }: {
  theme: ConsoleTheme;
  compact: boolean;
  snapshot: SnapshotReady;
  attention: AttentionModel;
  onRefresh: () => void;
  refreshing: boolean;
  onRun: () => void;
  running: boolean;
  runEnabled: boolean | null;
}) {
  const t = useT();
  const agentLabel = attention.agentOnlyClaimCount > 0
    ? t("panel.can_move_without_you", { count: attention.agentOnlyClaimCount })
    : attention.agentClaimCount > 0
      ? t("attention.machine_parts", { count: attention.agentClaimCount })
      : attention.agentTaskCount > 0
        ? t("attention.agent_tasks", { count: attention.agentTaskCount })
        : t("attention.empty_delegated");
  return (
    <Card theme={theme} compact={compact}>
      <View style={{ flexDirection: compact ? "column" : "row", gap: 16, alignItems: compact ? "stretch" : "flex-start" }}>
        <View style={{ flex: 1, gap: 8 }}>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6, alignItems: "center" }}>
            <Badge theme={theme} label={t(verdictKey(snapshot.map.verdict)).toUpperCase()} color={verdictColor(theme, snapshot.map.verdict)} icon={snapshot.map.verdict === "green" ? "Check" : snapshot.map.verdict === "red" ? "X" : "CircleHelp"} />
            <Badge theme={theme} label={t("panel.claims_count", { count: snapshot.map.claims })} icon="Boxes" />
            <Badge theme={theme} label={t("panel.need_decision", { count: attention.humanDecisionCount })} tone={attention.humanDecisionCount > 0 ? "warn" : "neutral"} icon="UserRoundCheck" />
            <Badge theme={theme} label={agentLabel} tone={attention.agentTaskCount > 0 ? "info" : "neutral"} icon="Bot" />
            {attention.acceptedRisks.length > 0 && <Badge theme={theme} label={t("attention.accepted_risk_count", { count: attention.acceptedRisks.length })} tone="warn" icon="ShieldCheck" />}
          </View>
          <Text style={{ color: theme.colors.foreground, fontSize: compact ? 19 : 23, lineHeight: compact ? 25 : 30, fontWeight: "700" }}>
            {snapshot.map.goal?.text ?? t("state.no_goal_declared")}
          </Text>
          {snapshot.map.goal && (
            <Body theme={theme} muted>
              {t("panel.goal_summary", {
                owner: snapshot.map.goal.by,
                scope: snapshot.map.goal.scope.length,
                uncovered: snapshot.map.uncovered.length,
              })}
            </Body>
          )}
        </View>
        <View style={{ flexDirection: "row", gap: 7, alignItems: "center" }}>
          <Button theme={theme} compact label={refreshing ? t("panel.refreshing") : t("common.refresh")} icon="RefreshCw" onPress={onRefresh} disabled={refreshing || running} />
          <Button theme={theme} compact label={running ? t("panel.running") : t("attention.run_checks")} icon="Play" variant="primary" onPress={onRun} disabled={running || refreshing || runEnabled !== true} />
        </View>
      </View>
      {runEnabled === false && <Body theme={theme} muted>{t("panel.run_disabled_note")}</Body>}
      {runEnabled === null && <Body theme={theme} muted>{t("panel.run_pending_note")}</Body>}
      <View style={{ backgroundColor: theme.colors.surface2, borderRadius: 8, padding: 10, gap: 3 }}>
        <Text style={{ color: theme.colors.foregroundMuted, fontSize: 10, fontWeight: "700", textTransform: "uppercase" }}>{t("panel.next_action_title")}</Text>
        <Text style={{ color: theme.colors.foreground, fontSize: 13, lineHeight: 19 }}>{snapshot.map.next}</Text>
      </View>
      <View style={{ flexDirection: "row", flexWrap: "wrap", justifyContent: "space-between", gap: 8 }}>
        <Mono theme={theme}>{t("panel.snapshot_line", { time: snapshot.generatedAt, revision: snapshot.revision.slice(0, 12) })}</Mono>
        <Mono theme={theme}>{t("panel.binary_line", { path: snapshot.binary.path, version: snapshot.binary.version })}</Mono>
      </View>
    </Card>
  );
}
