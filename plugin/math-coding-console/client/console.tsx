import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { ScrollView, Text, View } from "react-native";
import { preferencesDefinition, rpcSchemas } from "../shared/schemas";
import type { ConsoleTheme } from "../shared/theme";
import { attentionContext, buildAttentionModel, snapshotSeconds } from "./attention";
import { AttentionView } from "./attention-view";
import { ClaimsView } from "./claims";
import { CoverageView } from "./coverage";
import { ClaimDetailView } from "./detail";
import { EvidenceView } from "./evidence";
import { InstrumentFrame } from "./frame";
import { GraphView, type GraphSelection } from "./graph";
import { useHost } from "./host/context";
import { Body, Button, Card, Empty, Mono, Note, Segmented } from "./parts";
import { runScale } from "./run-scale";

const VIEWS = [
  { value: "attention", label: "Attention", icon: "UserRoundCheck" },
  { value: "explore", label: "Explore", icon: "Search" },
  { value: "evidence", label: "Evidence", icon: "History" },
] as const;

const EXPLORE_VIEWS = [
  { value: "claims", label: "Claims", icon: "Boxes" },
  { value: "proof", label: "Proof graph", icon: "Workflow" },
  { value: "scope", label: "Scope", icon: "FolderTree" },
] as const;

export interface ConsolePanelProps {
  theme: ConsoleTheme;
  layout: { compact: boolean };
  workspaceId: string;
}

export function ConsolePanel({ theme, layout, workspaceId }: ConsolePanelProps) {
  const compact = layout.compact;
  const { Modal, useRpc, useSettings, useToast } = useHost();
  const queryClient = useQueryClient();
  const toast = useToast();
  const fetchSnapshot = useRpc(rpcSchemas.snapshot);
  const runChecks = useRpc(rpcSchemas.run);
  const settings = useSettings(preferencesDefinition);
  const [view, setView] = useState("attention");
  const [exploreView, setExploreView] = useState("claims");
  const [showScopeGraph, setShowScopeGraph] = useState(false);
  const [expanded, setExpanded] = useState<ReadonlySet<string>>(new Set());
  const [selected, setSelected] = useState<GraphSelection | null>(null);
  const [confirmRun, setConfirmRun] = useState(false);
  const autoRefreshSeconds = settings.status === "ready" ? settings.values?.autoRefreshSeconds ?? 0 : 0;
  const run = useMutation({
    mutationFn: () => runChecks({ workspaceId, confirmation: "RUN_CHECKS" }),
    onSuccess: ({ snapshot }) => {
      queryClient.setQueryData(["mathcoding-snapshot", workspaceId], snapshot);
      setConfirmRun(false);
      setView("attention");
      const holds = snapshot.map.states.filter((state) => state.state === "holds").length;
      toast.show(`Checks finished: ${snapshot.map.verdict} · ${holds} holds`, {
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
    refetchInterval: !run.isPending && autoRefreshSeconds > 0 ? autoRefreshSeconds * 1000 : false,
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
  const canonicalNow = snapshot ? snapshotSeconds(snapshot) : 0;
  const attention = useMemo(() => snapshot ? buildAttentionModel(snapshot, canonicalNow) : undefined, [snapshot, canonicalNow]);
  const briefContext = useMemo(() => snapshot && attention ? attentionContext(snapshot, attention) : undefined, [snapshot, attention]);
  const scale = useMemo(() => snapshot ? runScale(snapshot) : undefined, [snapshot]);
  const runEnabled = settings.status === "ready" ? settings.values?.allowRunChecks ?? null : null;
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
      ) : snapshot && attention && briefContext ? (
        <View style={{ flex: 1, flexDirection: compact ? "column" : "row" }}>
          <View style={{ flex: 1 }}>
            <ScrollView nestedScrollEnabled contentContainerStyle={{ padding: compact ? 10 : 16, gap: 10 }}>
              {snapshotQuery.isError && (
                <Note theme={theme} tone="bad">Refresh failed. The visible data is the last successful snapshot from {snapshot.generatedAt}: {String(snapshotQuery.error)}</Note>
              )}
              <InstrumentFrame theme={theme} compact={compact} snapshot={snapshot} attention={attention} onRefresh={refresh} refreshing={snapshotQuery.isFetching} onRun={() => setConfirmRun(true)} running={run.isPending} runEnabled={runEnabled} />
              <Segmented theme={theme} options={VIEWS} value={view} onChange={(value) => { setView(value); if (value !== "explore") setShowScopeGraph(false); }} />
              {view === "attention" && (
                <AttentionView theme={theme} compact={compact} model={attention} context={briefContext} onSelect={setSelected} onRun={() => setConfirmRun(true)} runEnabled={runEnabled === true} />
              )}
              {view === "explore" && (
                <>
                  <Segmented
                    theme={theme}
                    options={EXPLORE_VIEWS}
                    value={exploreView}
                    onChange={(value) => { setExploreView(value); setShowScopeGraph(false); }}
                  />
                  {exploreView === "claims" && <ClaimsView theme={theme} compact={compact} snapshot={snapshot} onSelect={setSelected} />}
                  {exploreView === "proof" && <GraphView theme={theme} compact={compact} snapshot={snapshot} mode="proof" expanded={expanded} onToggleClaim={toggleClaim} selected={selected} onSelect={setSelected} />}
                  {exploreView === "scope" && (
                    showScopeGraph
                      ? <GraphView theme={theme} compact={compact} snapshot={snapshot} mode="scope" expanded={expanded} onToggleClaim={toggleClaim} selected={selected} onSelect={setSelected} onClose={() => setShowScopeGraph(false)} />
                      : <CoverageView theme={theme} compact={compact} snapshot={snapshot} onSelect={setSelected} onOpenScope={() => setShowScopeGraph(true)} />
                  )}
                </>
              )}
              {view === "evidence" && <EvidenceView theme={theme} compact={compact} snapshot={snapshot} />}
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
            <Body theme={theme} muted>Scale: {scale?.claimCount ?? 0} claim(s) and {scale?.commandCount ?? 0} check command(s) will run for this workspace.</Body>
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
