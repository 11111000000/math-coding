import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { ScrollView, Text, View } from "react-native";
import { preferencesDefinition, rpcSchemas } from "../shared/schemas";
import type { ConsoleTheme } from "../shared/theme";
import {
  emptyHumanActionValues,
  humanActionArgv,
  humanActions,
  type HumanAction,
  type HumanActionValues,
} from "../shared/human-actions";
import { attentionContext, buildAttentionModel, snapshotSeconds } from "./attention";
import { AttentionView } from "./attention-view";
import { ClaimsView } from "./claims";
import { CoverageView } from "./coverage";
import { ClaimDetailView } from "./detail";
import { EvidenceView } from "./evidence";
import { FilePreview } from "./file-preview";
import { InstrumentFrame } from "./frame";
import { PermissionsCard } from "./permissions";
import { GraphView, type GraphSelection } from "./graph";
import { useHost } from "./host/context";
import { HumanActionForm } from "./human-action";
import { buildHumanQueue, queueEvidenceComplete } from "./human-queue";
import { errorText, renderValue, useT } from "./i18n";
import { Body, Button, Card, Empty, Mono, Note, Segmented } from "./parts";
import { previewIsOpen } from "./preview-target";
import { QueueView } from "./queue-view";
import { RunConfirmation } from "./run-confirmation";
import { runScale } from "./run-scale";
import { verdictKey } from "./vocabulary";

const VIEWS = [
  { value: "attention", labelKey: "panel.tab_queue", icon: "UserRoundCheck" },
  { value: "explore", labelKey: "panel.tab_explore", icon: "Search" },
  { value: "evidence", labelKey: "panel.tab_evidence", icon: "History" },
] as const;

const EXPLORE_VIEWS = [
  { value: "claims", labelKey: "panel.tab_claims", icon: "Boxes" },
  { value: "proof", labelKey: "panel.tab_proof", icon: "Workflow" },
  { value: "scope", labelKey: "panel.tab_scope", icon: "FolderTree" },
] as const;

export interface ConsolePanelProps {
  theme: ConsoleTheme;
  layout: { compact: boolean };
  workspaceId: string;
}

export function ConsolePanel({ theme, layout, workspaceId }: ConsolePanelProps) {
  const compact = layout.compact;
  const { Modal, openSettings, useRpc, useSettings, useToast } = useHost();
  const t = useT();
  const queryClient = useQueryClient();
  const toast = useToast();
  const fetchSnapshot = useRpc(rpcSchemas.snapshot);
  const fetchEvidence = useRpc(rpcSchemas.evidence);
  const runChecks = useRpc(rpcSchemas.run);
  const applyDecision = useRpc(rpcSchemas.humanDecision);
  const settings = useSettings(preferencesDefinition);
  const [view, setView] = useState("attention");
  const [exploreView, setExploreView] = useState("claims");
  const [showScopeGraph, setShowScopeGraph] = useState(false);
  const [expanded, setExpanded] = useState<ReadonlySet<string>>(new Set());
  const [selected, setSelected] = useState<GraphSelection | null>(null);
  const [confirmRun, setConfirmRun] = useState(false);
  const [decision, setDecision] = useState<{ action: HumanAction; values: HumanActionValues } | null>(null);
  const [previewPath, setPreviewPath] = useState<string | null>(null);
  const autoRefreshSeconds = settings.status === "ready" ? settings.values?.autoRefreshSeconds ?? 0 : 0;
  const decisionsEnabled = settings.status === "ready" ? settings.values?.allowHumanDecisions ?? null : null;
  const run = useMutation({
    mutationFn: () => runChecks({ workspaceId, confirmation: "RUN_CHECKS" }),
    onSuccess: ({ snapshot }) => {
      queryClient.setQueryData(["mathcoding-snapshot", workspaceId], snapshot);
      setConfirmRun(false);
      setView("attention");
      const holds = snapshot.map.states.filter((state) => state.state === "holds").length;
      toast.show(t("toast.checks_finished", { verdict: t(verdictKey(snapshot.map.verdict)), holds }), {
        variant: snapshot.map.verdict === "green" ? "success" : snapshot.map.verdict === "red" ? "error" : "warning",
      });
      void queryClient.invalidateQueries({ queryKey: ["mathcoding-claim", workspaceId] });
      void queryClient.invalidateQueries({ queryKey: ["mathcoding-evidence", workspaceId] });
      void queryClient.invalidateQueries({ queryKey: ["mathcoding-queue-evidence", workspaceId] });
    },
  });
  const decisionMutation = useMutation({
    mutationFn: (input: Parameters<typeof applyDecision>[0]) => applyDecision(input),
    onSuccess: ({ snapshot, message }) => {
      queryClient.setQueryData(["mathcoding-snapshot", workspaceId], snapshot);
      setDecision(null);
      toast.show(message.length > 0 ? message : t("toast.decision_recorded"), { variant: "success" });
      void queryClient.invalidateQueries({ queryKey: ["mathcoding-claim", workspaceId] });
      void queryClient.invalidateQueries({ queryKey: ["mathcoding-evidence", workspaceId] });
      void queryClient.invalidateQueries({ queryKey: ["mathcoding-queue-evidence", workspaceId] });
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
    void queryClient.invalidateQueries({ queryKey: ["mathcoding-queue-evidence", workspaceId] });
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
  /**
   * The newest evidence of every condition of every claim.
   *
   * The trail is read newest first. The console keeps reading pages until
   * every condition has a record, so a condition never looks untested
   * because a page ended too early. When the trail is longer than the pages
   * the console reads, it says so instead of showing an untested condition
   * as if it had no evidence at all.
   */
  const evidenceQuery = useQuery({
    queryKey: ["mathcoding-queue-evidence", workspaceId, snapshot?.revision],
    queryFn: async () => {
      const records = [] as Awaited<ReturnType<typeof fetchEvidence>>["records"];
      let cursor = 0;
      let exhausted = false;
      for (let page = 0; page < 10; page += 1) {
        const result = await fetchEvidence({ workspaceId, cursor, limit: 200 });
        records.push(...result.records);
        if (!snapshot || queueEvidenceComplete(records, snapshot.claims)) break;
        if (result.nextCursor === null) { exhausted = true; break; }
        cursor = result.nextCursor;
      }
      return {
        records,
        complete: snapshot ? queueEvidenceComplete(records, snapshot.claims) : true,
        exhausted,
      };
    },
    enabled: Boolean(snapshot),
    retry: false,
  });
  const queue = useMemo(
    () => snapshot && attention ? buildHumanQueue(snapshot, attention, evidenceQuery.data?.records ?? []) : undefined,
    [snapshot, attention, evidenceQuery.data],
  );
  /**
   * The manual steps of the method for the current map.
   *
   * The steps come from the canonical map and from the declared
   * specification. The console offers them; the program performs them.
   */
  const actions = useMemo(
    () => snapshot
      ? humanActions(
        {
          claims: snapshot.claims,
          states: snapshot.map.states,
          policyConfigured: snapshot.policyConfigured,
        },
        canonicalNow,
      )
      : [],
    [snapshot, canonicalNow],
  );
  const openDecision = (action: HumanAction) => {
    const owner = renderValue(t, action.owner);
    const by = owner !== "" ? owner : snapshot?.map.goal?.by ?? "";
    setDecision({ action, values: { ...emptyHumanActionValues(), by } });
  };
  const confirmDecision = () => {
    if (!decision) return;
    const action = decision.action;
    const values = decision.values;
    try {
      humanActionArgv(action, values);
    } catch (problem) {
      toast.error(errorText(t, problem));
      return;
    }
    const days = values.validForDays.trim();
    decisionMutation.mutate({
      workspaceId,
      confirmation: "APPLY_HUMAN_DECISION",
      kind: action.kind,
      claimId: action.claimId ?? undefined,
      authority: action.authority ?? undefined,
      by: values.by.trim(),
      reason: values.reason.trim() === "" ? undefined : values.reason.trim(),
      outcome: values.outcome === "" ? undefined : values.outcome,
      validForDays: days === "" ? undefined : Number(days),
      recovery: values.recovery.trim() === "" ? undefined : values.recovery.trim(),
    });
  };
  const runEnabled = settings.status === "ready" ? settings.values?.allowRunChecks ?? null : null;
  const snapshotError = snapshotQuery.error ? String(snapshotQuery.error) : null;
  const workspaceBusy = snapshotError?.includes("busy") ?? false;
  const views = VIEWS.map((option) => ({ value: option.value, label: t(option.labelKey), icon: option.icon }));
  const exploreViews = EXPLORE_VIEWS.map((option) => ({ value: option.value, label: t(option.labelKey), icon: option.icon }));
  return (
    <View style={{ flex: 1, backgroundColor: theme.colors.surface0 }}>
      {snapshotQuery.isPending ? (
        <Empty theme={theme} title={t("panel.loading_map")} detail={t("panel.loading_map_detail")} icon="Workflow" />
      ) : snapshotQuery.isError && !snapshotQuery.data ? (
        <View style={{ padding: compact ? 14 : 22, gap: 12 }}>
          <Empty theme={theme} title={workspaceBusy ? t("panel.busy_title") : t("panel.unavailable_title")} detail={workspaceBusy ? t("panel.busy_detail") : t("panel.unavailable_detail")} icon={workspaceBusy ? "Clock3" : "ShieldX"} />
          <Note theme={theme} tone="bad">{snapshotError}</Note>
          <Button theme={theme} label={t("panel.retry_snapshot")} icon="RefreshCw" onPress={refresh} />
        </View>
      ) : snapshotQuery.data?.status === "not-initialized" ? (
        <View style={{ padding: compact ? 14 : 22 }}>
          <Card theme={theme} compact={compact}>
            <Empty theme={theme} title={t("panel.not_initialized_title")} detail={snapshotQuery.data.workspace.directory} icon="Map" />
            <Body theme={theme} muted>{t("panel.not_initialized_body")}</Body>
            <Mono theme={theme}>mathc init</Mono>
          </Card>
        </View>
      ) : snapshot && attention && briefContext ? (
        <View style={{ flex: 1, flexDirection: compact ? "column" : "row" }}>
          <View style={{ flex: 1 }}>
            <ScrollView nestedScrollEnabled contentContainerStyle={{ padding: compact ? 10 : 16, gap: 10 }}>
              {snapshotQuery.isError && (
                <Note theme={theme} tone="bad">{t("panel.refresh_failed", { time: snapshot.generatedAt, error: String(snapshotQuery.error) })}</Note>
              )}
              <InstrumentFrame theme={theme} compact={compact} snapshot={snapshot} attention={attention} onRefresh={refresh} refreshing={snapshotQuery.isFetching} onRun={() => setConfirmRun(true)} running={run.isPending} runEnabled={runEnabled} />
              <PermissionsCard theme={theme} compact={compact} runEnabled={runEnabled} decisionsEnabled={decisionsEnabled} onOpenSettings={openSettings} />
              <Segmented theme={theme} options={views} value={view} onChange={(value) => { setView(value); if (value !== "explore") setShowScopeGraph(false); }} />
              {view === "attention" && queue && briefContext && (
                <>
                  <QueueView
                    theme={theme}
                    compact={compact}
                    queue={queue}
                    context={briefContext}
                    actions={actions}
                    decisionsEnabled={decisionsEnabled === true}
                    onTakeAction={openDecision}
                    onOpenFile={setPreviewPath}
                    onSelect={setSelected}
                    trailComplete={evidenceQuery.data?.complete ?? true}
                    trailExhausted={evidenceQuery.data?.exhausted ?? true}
                  />
                  <AttentionView theme={theme} compact={compact} model={attention} context={briefContext} onSelect={setSelected} onRun={() => setConfirmRun(true)} runEnabled={runEnabled === true} />
                </>
              )}
              {view === "explore" && (
                <>
                  <Segmented
                    theme={theme}
                    options={exploreViews}
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
            <ClaimDetailView theme={theme} compact={compact} snapshot={snapshot} selection={selected} onClose={() => setSelected(null)} onSelect={setSelected} onRefresh={refresh} onOpenFile={setPreviewPath} />
          )}
        </View>
      ) : null}
      {previewIsOpen(previewPath) && (
        <FilePreview theme={theme} compact={compact} workspaceId={workspaceId} path={previewPath} onClose={() => setPreviewPath(null)} />
      )}
      <Modal title={t("panel.run_modal_title")} open={confirmRun} onOpenChange={(open) => { if (!run.isPending) setConfirmRun(open); }}>
        <RunConfirmation
          theme={theme}
          scale={scale}
          running={run.isPending}
          error={run.isError ? run.error : null}
          onCancel={() => setConfirmRun(false)}
          onRun={() => run.mutate()}
        />
      </Modal>
      {decision && (
        <Modal title={t("panel.decision_modal_title")} open onOpenChange={(open) => { if (!open && !decisionMutation.isPending) setDecision(null); }}>
          <HumanActionForm
            theme={theme}
            action={decision.action}
            values={decision.values}
            onChange={(values) => setDecision({ action: decision.action, values })}
            running={decisionMutation.isPending}
            error={decisionMutation.isError ? decisionMutation.error : null}
            onCancel={() => setDecision(null)}
            onConfirm={confirmDecision}
          />
        </Modal>
      )}
    </View>
  );
}
