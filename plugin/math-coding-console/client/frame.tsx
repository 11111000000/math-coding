import type { PluginTheme } from "@getpaseo/plugin";
import { Text, View } from "react-native";
import type { SnapshotReady } from "../shared/contracts";
import { CLAIM_STATES } from "../shared/domain";
import { Badge, Body, Button, Card, Mono } from "./parts";
import { claimStateColor, claimStateIcon, verdictColor } from "./vocabulary";

export function InstrumentFrame({ theme, compact, snapshot, onRefresh, refreshing, onRun, running, runEnabled }: {
  theme: PluginTheme;
  compact: boolean;
  snapshot: SnapshotReady;
  onRefresh: () => void;
  refreshing: boolean;
  onRun: () => void;
  running: boolean;
  runEnabled: boolean | null;
}) {
  const counts = new Map(CLAIM_STATES.map((state) => [state, 0]));
  for (const state of snapshot.map.states) counts.set(state.state, (counts.get(state.state) ?? 0) + 1);
  const changed = snapshot.map.states.filter((state) => state.source_changed).length;
  return (
    <Card theme={theme} compact={compact}>
      <View style={{ flexDirection: compact ? "column" : "row", gap: 16, alignItems: compact ? "stretch" : "flex-start" }}>
        <View style={{ flex: 1, gap: 8 }}>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6, alignItems: "center" }}>
            <Badge theme={theme} label={snapshot.map.verdict.toUpperCase()} color={verdictColor(theme, snapshot.map.verdict)} icon={snapshot.map.verdict === "green" ? "Check" : snapshot.map.verdict === "red" ? "X" : "CircleHelp"} />
            <Badge theme={theme} label={`${snapshot.map.claims} claims`} icon="Boxes" />
            <Badge theme={theme} label={`${snapshot.map.uncovered.length} uncovered`} tone={snapshot.map.uncovered.length ? "warn" : "neutral"} icon="ScanSearch" />
            {changed > 0 && <Badge theme={theme} label={`${changed} source changed`} tone="warn" icon="FileClock" />}
          </View>
          <Text style={{ color: theme.colors.foreground, fontSize: compact ? 19 : 23, lineHeight: compact ? 25 : 30, fontWeight: "700" }}>
            {snapshot.map.goal?.text ?? "No goal declared"}
          </Text>
          {snapshot.map.goal && <Body theme={theme} muted>Owner: {snapshot.map.goal.by} · {snapshot.map.goal.scope.length} goal scope path(s)</Body>}
        </View>
        <View style={{ flexDirection: "row", gap: 7, alignItems: "center" }}>
          <Button theme={theme} compact label={refreshing ? "Refreshing" : "Refresh"} icon="RefreshCw" onPress={onRefresh} disabled={refreshing || running} />
          <Button theme={theme} compact label={running ? "Running" : "Run checks"} icon="Play" variant="primary" onPress={onRun} disabled={running || refreshing || runEnabled !== true} />
        </View>
      </View>
      {runEnabled === false && <Body theme={theme} muted>Run checks are disabled. Enable them in Settings → Math Coding before executing project-declared checks.</Body>}
      {runEnabled === null && <Body theme={theme} muted>Run checks availability will be known after the host settings finish loading.</Body>}
      <View style={{ gap: 8 }}>
        <View style={{ height: 9, borderRadius: 5, overflow: "hidden", flexDirection: "row", backgroundColor: theme.colors.surface2 }}>
          {CLAIM_STATES.filter((state) => (counts.get(state) ?? 0) > 0).map((state) => (
            <View key={state} style={{ flex: counts.get(state), backgroundColor: claimStateColor(theme, state) }} />
          ))}
        </View>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
          {CLAIM_STATES.filter((state) => (counts.get(state) ?? 0) > 0).map((state) => (
            <Badge key={state} theme={theme} label={`${state} ${counts.get(state)}`} color={claimStateColor(theme, state)} icon={claimStateIcon(state)} />
          ))}
        </View>
      </View>
      <View style={{ backgroundColor: theme.colors.surface2, borderRadius: 8, padding: 10, gap: 3 }}>
        <Text style={{ color: theme.colors.foregroundMuted, fontSize: 10, fontWeight: "700", textTransform: "uppercase" }}>Canonical next action</Text>
        <Text style={{ color: theme.colors.foreground, fontSize: 13, lineHeight: 19 }}>{snapshot.map.next}</Text>
      </View>
      {snapshot.map.verdict === "green" && (
        <Body theme={theme} muted>Green confirms the declared claims only. Uncovered paths and human acceptance remain separate.</Body>
      )}
      <View style={{ flexDirection: "row", flexWrap: "wrap", justifyContent: "space-between", gap: 8 }}>
        <Mono theme={theme}>snapshot {snapshot.generatedAt} · revision {snapshot.revision.slice(0, 12)}</Mono>
        <Mono theme={theme}>{snapshot.binary.path} · {snapshot.binary.version}</Mono>
      </View>
    </Card>
  );
}
