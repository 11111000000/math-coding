import type { ConsoleTheme } from "../shared/theme";
import { Text, View } from "react-native";
import type { SnapshotReady } from "../shared/schemas";
import type { AttentionModel } from "./attention";
import { Badge, Body, Button, Card, Mono } from "./parts";
import { verdictColor } from "./vocabulary";

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
  const agentLabel = attention.agentOnlyClaimCount > 0
    ? `${attention.agentOnlyClaimCount} can move without you`
    : attention.agentClaimCount > 0
      ? `${attention.agentClaimCount} machine part(s) can proceed`
      : attention.agentTaskCount > 0
        ? `${attention.agentTaskCount} agent task(s)`
        : "no delegated work";
  return (
    <Card theme={theme} compact={compact}>
      <View style={{ flexDirection: compact ? "column" : "row", gap: 16, alignItems: compact ? "stretch" : "flex-start" }}>
        <View style={{ flex: 1, gap: 8 }}>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6, alignItems: "center" }}>
            <Badge theme={theme} label={snapshot.map.verdict.toUpperCase()} color={verdictColor(theme, snapshot.map.verdict)} icon={snapshot.map.verdict === "green" ? "Check" : snapshot.map.verdict === "red" ? "X" : "CircleHelp"} />
            <Badge theme={theme} label={`${snapshot.map.claims} claims`} icon="Boxes" />
            <Badge theme={theme} label={`${attention.humanDecisionCount} need your decision`} tone={attention.humanDecisionCount > 0 ? "warn" : "neutral"} icon="UserRoundCheck" />
            <Badge theme={theme} label={agentLabel} tone={attention.agentTaskCount > 0 ? "info" : "neutral"} icon="Bot" />
            {attention.acceptedRisks.length > 0 && <Badge theme={theme} label={`${attention.acceptedRisks.length} accepted risk(s)`} tone="warn" icon="ShieldCheck" />}
          </View>
          <Text style={{ color: theme.colors.foreground, fontSize: compact ? 19 : 23, lineHeight: compact ? 25 : 30, fontWeight: "700" }}>
            {snapshot.map.goal?.text ?? "No goal declared"}
          </Text>
          {snapshot.map.goal && <Body theme={theme} muted>Owner: {snapshot.map.goal.by} · {snapshot.map.goal.scope.length} goal scope path(s) · {snapshot.map.uncovered.length} uncovered</Body>}
        </View>
        <View style={{ flexDirection: "row", gap: 7, alignItems: "center" }}>
          <Button theme={theme} compact label={refreshing ? "Refreshing" : "Refresh"} icon="RefreshCw" onPress={onRefresh} disabled={refreshing || running} />
          <Button theme={theme} compact label={running ? "Running" : "Run checks"} icon="Play" variant="primary" onPress={onRun} disabled={running || refreshing || runEnabled !== true} />
        </View>
      </View>
      {runEnabled === false && <Body theme={theme} muted>Run checks are disabled. Enable them in the settings of the host before executing project-declared checks.</Body>}
      {runEnabled === null && <Body theme={theme} muted>Run checks availability will be known after the host settings finish loading.</Body>}
      <View style={{ backgroundColor: theme.colors.surface2, borderRadius: 8, padding: 10, gap: 3 }}>
        <Text style={{ color: theme.colors.foregroundMuted, fontSize: 10, fontWeight: "700", textTransform: "uppercase" }}>Canonical next action</Text>
        <Text style={{ color: theme.colors.foreground, fontSize: 13, lineHeight: 19 }}>{snapshot.map.next}</Text>
      </View>
      <View style={{ flexDirection: "row", flexWrap: "wrap", justifyContent: "space-between", gap: 8 }}>
        <Mono theme={theme}>snapshot {snapshot.generatedAt} · revision {snapshot.revision.slice(0, 12)}</Mono>
        <Mono theme={theme}>{snapshot.binary.path} · {snapshot.binary.version}</Mono>
      </View>
    </Card>
  );
}
