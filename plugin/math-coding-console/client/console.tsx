import type { PluginWorkspacePanelProps } from "@getpaseo/plugin/client";
import { useRpc, useSettings } from "@getpaseo/plugin/client";
import { Modal, useToast } from "@getpaseo/plugin/client/ui";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { ScrollView, Text, View } from "react-native";
import { preferences, runChecksRpc, snapshotRpc, type SnapshotReady } from "../shared/contracts";
import { ClaimsView } from "./claims";
import { CoverageView } from "./coverage";
import { ClaimDetailView } from "./detail";
import { EvidenceView } from "./evidence";
import { InstrumentFrame } from "./frame";
import { GraphView, type GraphSelection } from "./graph";
import { Body, Button, Card, Empty, Mono, Note, Segmented } from "./parts";

const VIEWS = [
  { value: "map", label: "Map", icon: "Workflow" },
  { value: "claims", label: "Claims", icon: "Boxes" },
  { value: "evidence", label: "Evidence", icon: "History" },
  { value: "coverage", label: "Coverage", icon: "ScanSearch" },
] as const;

export function ConsolePanel({ theme, layout, workspaceId }: PluginWorkspacePanelProps) {
  const compact = layout.compact;
  const queryClient = useQueryClient();
  const toast = useToast();
  const fetchSnapshot = useRpc(snapshotRpc);
  const runChecks = useRpc(runChecksRpc);
  const settings = useSettings(preferences);
  const [view, setView] = useState("map");
  const [mapMode, setMapMode] = useState<"proof" | "scope">("proof");
  const [expanded, setExpanded] = useState<ReadonlySet<string>>(new Set());
  const [selected, setSelected] = useState<GraphSelection | null>(null);
  const [confirmRun, setConfirmRun] = useState(false);
  const run = useMutation({
    mutationFn: () => runChecks({ workspaceId, confirmation: "RUN_CHECKS" }),
    onSuccess: ({ snapshot }) => {
      queryClient.setQueryData(["mathcoding-snapshot", workspaceId], snapshot);
      setConfirmRun(false);
      setView("evidence");
      const counts = snapshot.map.states.reduce<Record<string, number>>((result, state) => {
        result[state.state] = (result[state.state] ?? 0) + 1;
        return result;
      }, {});
      toast.show(`Checks finished: ${snapshot.map.verdict} · ${counts.holds ?? 0} holds`, {
        variant: snapshot.map.verdict === "green" ? "success" : snapshot.map.verdict === "red" ? "error" : "warning",
      });
      void queryClient.invalidateQueries({ queryKey: ["mathcoding-claim", workspaceId] });
      void queryClient.invalidateQueries({ queryKey: ["mathcoding-evidence", workspaceId] });
    },
  });
  const snapshotQuery = useQuery({
    queryKey: ["mathcoding-snapshot", workspaceId],
    queryFn: () => fetchSnapshot({ workspaceId }),
    retry: false,
    refetchOnWindowFocus: true,
    refetchInterval: !run.isPending && settings.status === "ready" && settings.values.autoRefreshSeconds > 0
      ? settings.values.autoRefreshSeconds * 1000
      : false,
  });
  const refresh = () => {
    void queryClient.invalidateQueries({ queryKey: ["mathcoding-snapshot", workspaceId] });
    void queryClient.invalidateQueries({ queryKey: ["mathcoding-claim", workspaceId] });
    void queryClient.invalidateQueries({ queryKey: ["mathcoding-evidence", workspaceId] });
  };
  const toggleClaim = (claimId: string) => {
    setExpanded((current) => {
      const next = new Set(current);
      if (next.has(claimId)) next.delete(claimId);
      else next.add(claimId);
      return next;
    });
  };
  const snapshot = snapshotQuery.data?.status === "ready" ? snapshotQuery.data : undefined;
  const runEnabled = settings.status === "ready" ? settings.values.allowRunChecks : null;
  const snapshotError = snapshotQuery.error ? String(snapshotQuery.error) : null;
  const workspaceBusy = snapshotError?.includes("busy") ?? false;
  return (
    <View style={{ flex: 1, backgroundColor: theme.colors.surface0 }}>
      {snapshotQuery.isPending ? (
        <Empty theme={theme} title="Reading the canonical map" detail="This is read-only. No project checks are running." icon="Workflow" />
      ) : snapshotQuery.isError && !snapshotQuery.data ? (
        <View style={{ padding: compact ? 14 : 22, gap: 12 }}>
          <Empty theme={theme} title={workspaceBusy ? "Math Coding workspace is busy" : "Math Coding is unavailable"} detail={workspaceBusy ? "A longer operation is active. Retry after it finishes." : "The plugin did not accept a fallback verdict."} icon={workspaceBusy ? "Clock3" : "ShieldX"} />
          <Note theme={theme} tone="bad">{snapshotError}</Note>
          <Button theme={theme} label="Retry read-only snapshot" icon="RefreshCw" onPress={refresh} />
        </View>
      ) : snapshotQuery.data?.status === "not-initialized" ? (
        <View style={{ padding: compact ? 14 : 22 }}>
          <Card theme={theme} compact={compact}>
            <Empty theme={theme} title="Math Coding is not initialized here" detail={snapshotQuery.data.workspace.directory} icon="Map" />
            <Body theme={theme} muted>A spec.json is required before the plugin can show a canonical map. The empty state is not presented as a verdict.</Body>
            <Mono theme={theme}>mathc init</Mono>
          </Card>
        </View>
      ) : snapshot ? (
        <View style={{ flex: 1, flexDirection: compact ? "column" : "row" }}>
          <View style={{ flex: 1 }}>
            <ScrollView nestedScrollEnabled contentContainerStyle={{ padding: compact ? 10 : 16, gap: 10 }}>
              {snapshotQuery.isError && (
                <Note theme={theme} tone="bad">Refresh failed. The visible data is the last successful snapshot from {snapshot.generatedAt}: {String(snapshotQuery.error)}</Note>
              )}
              <InstrumentFrame theme={theme} compact={compact} snapshot={snapshot} onRefresh={refresh} refreshing={snapshotQuery.isFetching} onRun={() => setConfirmRun(true)} running={run.isPending} runEnabled={runEnabled} />
              <Segmented theme={theme} options={VIEWS} value={view} onChange={(value) => { setView(value); if (value !== "map") setSelected(null); }} />
              {view === "map" && (
                <>
                  <Segmented
                    theme={theme}
                    options={[{ value: "proof", label: "Proof structure", icon: "ListTree" }, { value: "scope", label: "Scope links", icon: "FolderTree" }]}
                    value={mapMode}
                    onChange={(value) => setMapMode(value as "proof" | "scope")}
                  />
                  <GraphView theme={theme} compact={compact} snapshot={snapshot} mode={mapMode} expanded={expanded} onToggleClaim={toggleClaim} selected={selected} onSelect={setSelected} />
                </>
              )}
              {view === "claims" && <ClaimsView theme={theme} compact={compact} snapshot={snapshot} onSelect={setSelected} />}
              {view === "evidence" && <EvidenceView theme={theme} compact={compact} snapshot={snapshot} />}
              {view === "coverage" && <CoverageView theme={theme} compact={compact} snapshot={snapshot} onSelect={setSelected} onOpenScope={() => { setView("map"); setMapMode("scope"); }} />}
            </ScrollView>
          </View>
          {selected && (
            <ClaimDetailView theme={theme} compact={compact} snapshot={snapshot} selection={selected} onClose={() => setSelected(null)} onSelect={setSelected} onRefresh={refresh} />
          )}
        </View>
      ) : null}
      <Modal title="Run project checks?" open={confirmRun} onOpenChange={(open) => { if (!run.isPending) setConfirmRun(open); }}>
        <Modal.Content>
          <View style={{ gap: 14 }}>
            <Body theme={theme}>This executes the verifier and negative-control commands declared by the project and appends evidence to .math/v5/. Controls use isolated copies; verifiers still execute project code.</Body>
            <Body theme={theme} muted>Refresh, graph navigation and automatic polling never perform this action. The server also requires Run checks to be enabled in plugin settings.</Body>
            {run.isError && <Note theme={theme} tone="bad">Run failed: {String(run.error)}</Note>}
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8, justifyContent: "flex-end" }}>
              <Button theme={theme} label="Cancel" onPress={() => setConfirmRun(false)} disabled={run.isPending} />
              <Button theme={theme} label={run.isPending ? "Running checks" : "Run checks"} icon="Play" variant="danger" onPress={() => run.mutate()} disabled={run.isPending} />
            </View>
          </View>
        </Modal.Content>
      </Modal>
    </View>
  );
}
