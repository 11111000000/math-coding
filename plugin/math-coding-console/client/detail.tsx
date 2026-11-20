import { useQuery } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { Pressable, ScrollView, Text, View } from "react-native";
import type { Claim, ClaimState, EvidenceRecord } from "../shared/domain";
import { flattenRequirements, requirementKey, requirementLabelRef } from "../shared/requirements";
import { rpcSchemas, type SnapshotReady } from "../shared/schemas";
import type { ConsoleTheme } from "../shared/theme";
import { DecisionBoundary } from "./decision-boundary";
import { EvidenceRecordCard } from "./evidence-record";
import type { GraphSelection } from "./graph";
import { useHost } from "./host/context";
import { HostModalContent } from "./host/sheet";
import { useT } from "./i18n";
import { Badge, Body, Button, Card, Empty, KeyValue, Mono, Note, ReasonBlock } from "./parts";
import { claimStateColor, claimStateIcon, claimStateKey, formatTime, stateReasonKey } from "./vocabulary";

export function ClaimDetailView({ theme, compact, snapshot, selection, onClose, onSelect, onRefresh, onOpenFile }: {
  theme: ConsoleTheme;
  compact: boolean;
  snapshot: SnapshotReady;
  selection: GraphSelection;
  onClose: () => void;
  onSelect: (selection: GraphSelection) => void;
  onRefresh: () => void;
  onOpenFile: (path: string) => void;
}) {
  const { Modal } = useHost();
  const body = <DetailBody theme={theme} compact={compact} snapshot={snapshot} selection={selection} onClose={onClose} onSelect={onSelect} onRefresh={onRefresh} onOpenFile={onOpenFile} />;
  if (compact) {
    return (
      <Modal title={selection.claimId} open onOpenChange={(open) => { if (!open) onClose(); }}>
        <HostModalContent>{body}</HostModalContent>
      </Modal>
    );
  }
  return (
    <View style={{ width: 390, flexShrink: 0, borderLeftWidth: 1, borderLeftColor: theme.colors.border, backgroundColor: theme.colors.surface0 }}>
      <ScrollView nestedScrollEnabled contentContainerStyle={{ padding: 12 }}>{body}</ScrollView>
    </View>
  );
}

function DetailBody({ theme, compact, snapshot, selection, onClose, onSelect, onRefresh, onOpenFile }: {
  theme: ConsoleTheme;
  compact: boolean;
  snapshot: SnapshotReady;
  selection: GraphSelection;
  onClose: () => void;
  onSelect: (selection: GraphSelection) => void;
  onRefresh: () => void;
  onOpenFile: (path: string) => void;
}) {
  const { useRpc } = useHost();
  const t = useT();
  const fetchDetail = useRpc(rpcSchemas.claim);
  const [expandedEvidence, setExpandedEvidence] = useState<number | null>(null);
  const query = useQuery({
    queryKey: ["mathcoding-claim", snapshot.workspace.id, snapshot.revision, snapshot.generatedAt, selection.claimId],
    queryFn: () => fetchDetail({ workspaceId: snapshot.workspace.id, claimId: selection.claimId, limit: 100 }),
    retry: false,
  });
  const claim = snapshot.claims.find((item) => item.id === selection.claimId);
  const state = snapshot.map.states.find((item) => item.id === selection.claimId);
  const records = useMemo(() => (query.data?.records ?? []).filter((record) =>
    selection.requirementPath === undefined || record.requirementPaths.includes(selection.requirementPath),
  ), [query.data, selection.requirementPath]);
  const latest = useMemo(() => {
    const seen = new Set<string>();
    const result = new Set<number>();
    for (const record of query.data?.records ?? []) {
      const key = requirementKey(record.requirement);
      if (!seen.has(key)) {
        seen.add(key);
        result.add(record.sequence);
      }
    }
    return result;
  }, [query.data]);
  if (!claim) return <Empty theme={theme} title={t("detail.missing_title")} detail={t("detail.missing_detail")} icon="CircleOff" />;
  return (
    <View style={{ gap: 10 }}>
      <Card theme={theme} compact={compact}>
        <View style={{ flexDirection: "row", alignItems: "flex-start", gap: 8 }}>
          <View style={{ flex: 1, gap: 5 }}>
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
              {state && <Badge theme={theme} label={t(claimStateKey(state.state))} color={claimStateColor(theme, state.state)} icon={claimStateIcon(state.state)} />}
              {state?.reason && <Badge theme={theme} label={t(stateReasonKey(state.reason))} icon="CircleHelp" />}
              <Badge theme={theme} label={claim.register} />
              {state?.source_changed && <Badge theme={theme} label={t("state.source_changed")} tone="warn" />}
            </View>
            <Text style={{ color: theme.colors.foreground, fontSize: 20, fontWeight: "700" }}>{claim.id}</Text>
            <Body theme={theme}>{claim.text}</Body>
            {state && <ReasonBlock theme={theme} reason={state.reason} />}
          </View>
          <Button theme={theme} compact label={t("detail.close")} icon="X" onPress={onClose} />
        </View>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
          <Badge theme={theme} label={claim.kind} />
          <Badge theme={theme} label={claim.phase} />
          <Badge theme={theme} label={claim.owner ?? t("state.no_owner")} icon="User" />
        </View>
      </Card>
      <ProofChain theme={theme} compact={compact} claim={claim} state={state?.state} requirementPath={selection.requirementPath} evidenceCount={records.length} />
      <DecisionBoundary theme={theme} compact={compact} claim={claim} state={state?.state} sourceChanged={state?.source_changed ?? false} />
      <ClaimFacts theme={theme} compact={compact} claim={claim} onOpenFile={onOpenFile} />
      <Card theme={theme} compact={compact} title={t("detail.requirements_title")} subtitle={t("detail.requirements_subtitle")}>
        {flattenRequirements(claim).map((node) => {
          const selected = selection.requirementPath === node.path;
          const label = t(requirementLabelRef(node.requirement));
          return (
            <Pressable
              key={node.path}
              accessibilityRole="button"
              accessibilityLabel={t("detail.requirement_label", { path: node.path, label })}
              accessibilityState={{ selected }}
              onPress={() => onSelect({ claimId: claim.id, requirementPath: selected ? undefined : node.path })}
              style={{
                marginLeft: Math.min(node.depth * 13, 52),
                padding: 8,
                borderRadius: 7,
                borderLeftWidth: 2,
                borderLeftColor: selected ? theme.colors.accent : theme.colors.border,
                backgroundColor: selected ? theme.colors.surface2 : "transparent",
                gap: 3,
              }}
            >
              <Text style={{ color: theme.colors.foregroundMuted, fontSize: 9, fontWeight: "700" }}>{node.path} · {node.parentPath === null ? t("detail.root_requirement") : t("detail.child_of", { path: node.parentPath })}</Text>
              <Mono theme={theme}>{label}</Mono>
            </Pressable>
          );
        })}
        {claim.requirements.length === 0 && <Empty theme={theme} title={t("detail.requirements_empty_title")} detail={t("detail.requirements_empty_detail")} icon="ListX" />}
      </Card>
      <Card theme={theme} compact={compact} title={t("detail.evidence_title")} subtitle={selection.requirementPath ? t("detail.evidence_filtered", { path: selection.requirementPath }) : t("detail.evidence_count", { count: query.data?.total ?? 0 })}>
        {query.isPending ? <Empty theme={theme} title={t("detail.evidence_loading")} icon="History" /> : query.isError ? (
          <Note theme={theme} tone="bad">{String(query.error).includes("busy") ? t("error.workspace_busy_short") : t("detail.evidence_error", { error: String(query.error) })}</Note>
        ) : (
          <>
            {query.data && query.data.revision !== snapshot.revision && (
              <View style={{ gap: 7 }}>
                <Note theme={theme} tone="warn">{t("detail.newer_revision")}</Note>
                <Button theme={theme} compact label={t("detail.refresh_snapshot")} icon="RefreshCw" onPress={onRefresh} />
              </View>
            )}
            {records.length === 0 ? <Empty theme={theme} title={t("detail.evidence_empty_title")} detail={t("detail.evidence_empty_detail")} icon="FileQuestion" /> : (
              <View style={{ gap: 8 }}>
                {records.map((record: EvidenceRecord) => (
                  <EvidenceRecordCard key={record.sequence} theme={theme} record={record} claimState={state?.state} latest={latest.has(record.sequence)} expanded={expandedEvidence === record.sequence} onToggle={() => setExpandedEvidence((value) => value === record.sequence ? null : record.sequence)} />
                ))}
              </View>
            )}
            {query.data && query.data.nextCursor !== null && <Body theme={theme} muted>{t("detail.showing_newest", { shown: query.data.records.length, total: query.data.total })}</Body>}
          </>
        )}
      </Card>
    </View>
  );
}

function ProofChain({ theme, compact, claim, state, requirementPath, evidenceCount }: {
  theme: ConsoleTheme;
  compact: boolean;
  claim: Claim;
  state?: ClaimState;
  requirementPath?: string;
  evidenceCount: number;
}) {
  const t = useT();
  const items = [
    { icon: "FileText", label: t("detail.field_source"), value: claim.source?.path ?? t("detail.value_none") },
    { icon: "Box", label: t("detail.field_claim"), value: `${claim.id}${state ? ` · ${t(claimStateKey(state))}` : ""}` },
    { icon: "ListTree", label: t("detail.field_requirement"), value: requirementPath ?? t("detail.value_whole_tree") },
    { icon: "History", label: t("detail.field_evidence"), value: t("detail.linked_observations", { count: evidenceCount }) },
  ];
  return (
    <Card theme={theme} compact={compact} title={t("detail.proof_title")} subtitle={t("detail.proof_subtitle")}>
      <View style={{ gap: 4 }}>
        {items.map((item, index) => (
          <View key={item.label}>
            <View style={{ flexDirection: "row", alignItems: "center", gap: 8 }}>
              <Badge theme={theme} label={item.label} icon={item.icon} />
              <View style={{ flex: 1 }}><Mono theme={theme} lines={2}>{item.value}</Mono></View>
            </View>
            {index < items.length - 1 && <Text style={{ color: theme.colors.foregroundMuted, marginLeft: 12, marginTop: 2 }}>↓</Text>}
          </View>
        ))}
      </View>
    </Card>
  );
}

function ClaimFacts({ theme, compact, claim, onOpenFile }: {
  theme: ConsoleTheme;
  compact: boolean;
  claim: Claim;
  onOpenFile: (path: string) => void;
}) {
  const t = useT();
  return (
    <Card theme={theme} compact={compact} title={t("detail.definition_title")}>
      <KeyValue theme={theme} label={t("detail.field_scope")} value={claim.scope.length ? claim.scope.join(", ") : t("detail.value_empty")} />
      {claim.scope.length > 0 && (
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6 }}>
          {claim.scope.map((path) => (
            <Button key={path} theme={theme} compact label={path} icon="FileText" onPress={() => onOpenFile(path)} />
          ))}
        </View>
      )}
      {claim.source && (
        <Button theme={theme} compact label={t("detail.open_source", { path: claim.source.path })} icon="FileText" onPress={() => onOpenFile(claim.source!.path)} />
      )}
      <KeyValue theme={theme} label={t("detail.field_falsifier")} value={claim.falsifier || t("state.not_declared")} />
      <KeyValue theme={theme} label={t("detail.negative_control")} value={claim.control ?? t("detail.value_none")} />
      {claim.source && (
        <>
          <KeyValue theme={theme} label={t("detail.source_digest")} value={claim.source.digest} />
          {claim.source.review && <KeyValue theme={theme} label={t("detail.source_review")} value={`${claim.source.review.by} · ${formatTime(claim.source.review.at)} · ${claim.source.review.reason}`} />}
        </>
      )}
      {claim.review_on.length > 0 && <KeyValue theme={theme} label={t("detail.review_triggers")} value={claim.review_on.join(", ")} />}
      {claim.waiver && (
        <View style={{ gap: 8, borderTopWidth: 1, borderTopColor: theme.colors.border, paddingTop: 9 }}>
          <Badge theme={theme} label={t("state.waiver_recorded")} tone="warn" icon="ShieldAlert" />
          <KeyValue theme={theme} label={t("detail.field_gap")} value={claim.waiver.gap} />
          <KeyValue theme={theme} label={t("detail.issuer_interval")} value={`${claim.waiver.issuer} · ${formatTime(claim.waiver.issued_at)} → ${formatTime(claim.waiver.expires_at)}`} />
          <KeyValue theme={theme} label={t("detail.field_reason")} value={claim.waiver.reason} />
          <KeyValue theme={theme} label={t("detail.field_recovery")} value={claim.waiver.recovery} />
          {claim.waiver.compensating_controls.length > 0 && <KeyValue theme={theme} label={t("detail.compensating_controls")} value={claim.waiver.compensating_controls.join(", ")} />}
          <Body theme={theme} muted>{t("detail.waiver_note")}</Body>
        </View>
      )}
    </Card>
  );
}
