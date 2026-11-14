import type { PluginTheme } from "@getpaseo/plugin";
import { useRpc } from "@getpaseo/plugin/client";
import { Modal } from "@getpaseo/plugin/client/ui";
import { useQuery } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { Pressable, ScrollView, Text, View } from "react-native";
import type { SnapshotReady } from "../shared/contracts";
import { claimDetailRpc } from "../shared/contracts";
import type { Claim, ClaimState, EvidenceRecord } from "../shared/domain";
import { flattenRequirements, requirementKey, requirementLabel } from "../shared/requirements";
import { EvidenceRecordCard } from "./evidence-record";
import type { GraphSelection } from "./graph";
import { Badge, Body, Button, Card, Empty, KeyValue, Mono, Note } from "./parts";
import { claimStateColor, claimStateIcon, formatTime } from "./vocabulary";

export function ClaimDetailView({ theme, compact, snapshot, selection, onClose, onSelect, onRefresh }: {
  theme: PluginTheme;
  compact: boolean;
  snapshot: SnapshotReady;
  selection: GraphSelection;
  onClose: () => void;
  onSelect: (selection: GraphSelection) => void;
  onRefresh: () => void;
}) {
  const body = <DetailBody theme={theme} compact={compact} snapshot={snapshot} selection={selection} onClose={onClose} onSelect={onSelect} onRefresh={onRefresh} />;
  if (compact) {
    return (
      <Modal title={selection.claimId} open onOpenChange={(open) => { if (!open) onClose(); }}>
        <Modal.Content>{body}</Modal.Content>
      </Modal>
    );
  }
  return (
    <View style={{ width: 390, flexShrink: 0, borderLeftWidth: 1, borderLeftColor: theme.colors.border, backgroundColor: theme.colors.surface0 }}>
      <ScrollView nestedScrollEnabled contentContainerStyle={{ padding: 12 }}>{body}</ScrollView>
    </View>
  );
}

function DetailBody({ theme, compact, snapshot, selection, onClose, onSelect, onRefresh }: {
  theme: PluginTheme;
  compact: boolean;
  snapshot: SnapshotReady;
  selection: GraphSelection;
  onClose: () => void;
  onSelect: (selection: GraphSelection) => void;
  onRefresh: () => void;
}) {
  const fetchDetail = useRpc(claimDetailRpc);
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
  if (!claim) return <Empty theme={theme} title="Claim is no longer in the map" detail="Refresh the snapshot to reconcile the selection." icon="CircleOff" />;
  return (
    <View style={{ gap: 10 }}>
      <Card theme={theme} compact={compact}>
        <View style={{ flexDirection: "row", alignItems: "flex-start", gap: 8 }}>
          <View style={{ flex: 1, gap: 5 }}>
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
              {state && <Badge theme={theme} label={state.state} color={claimStateColor(theme, state.state)} icon={claimStateIcon(state.state)} />}
              <Badge theme={theme} label={claim.register} />
              {state?.source_changed && <Badge theme={theme} label="source changed" tone="warn" />}
            </View>
            <Text style={{ color: theme.colors.foreground, fontSize: 20, fontWeight: "700" }}>{claim.id}</Text>
            <Body theme={theme}>{claim.text}</Body>
          </View>
          <Button theme={theme} compact label="Close" icon="X" onPress={onClose} />
        </View>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
          <Badge theme={theme} label={claim.kind} />
          <Badge theme={theme} label={claim.phase} />
          <Badge theme={theme} label={claim.owner ?? "no owner"} icon="User" />
        </View>
      </Card>
      <ProofChain theme={theme} compact={compact} claim={claim} state={state?.state} requirementPath={selection.requirementPath} evidenceCount={records.length} />
      <ClaimFacts theme={theme} compact={compact} claim={claim} />
      <Card theme={theme} compact={compact} title="Requirements" subtitle="The actual all/any tree. Select a branch to filter observations.">
        {flattenRequirements(claim).map((node) => {
          const selected = selection.requirementPath === node.path;
          return (
            <Pressable
              key={node.path}
              accessibilityRole="button"
              accessibilityLabel={`Requirement ${node.path}: ${requirementLabel(node.requirement)}`}
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
              <Text style={{ color: theme.colors.foregroundMuted, fontSize: 9, fontWeight: "700" }}>{node.path} · {node.parentPath === null ? "root" : `child of ${node.parentPath}`}</Text>
              <Mono theme={theme}>{requirementLabel(node.requirement)}</Mono>
            </Pressable>
          );
        })}
        {claim.requirements.length === 0 && <Empty theme={theme} title="No requirements" detail="The claim has no confirmation conditions." icon="ListX" />}
      </Card>
      <Card theme={theme} compact={compact} title="Evidence" subtitle={selection.requirementPath ? `Filtered to requirement ${selection.requirementPath}` : `${query.data?.total ?? 0} observation(s) for this claim`}>
        {query.isPending ? <Empty theme={theme} title="Loading linked observations" icon="History" /> : query.isError ? (
          <Note theme={theme} tone="bad">{String(query.error).includes("busy") ? "The workspace is busy with another operation. Retry shortly." : `Evidence could not be loaded: ${String(query.error)}`}</Note>
        ) : (
          <>
            {query.data && query.data.revision !== snapshot.revision && (
              <View style={{ gap: 7 }}>
                <Note theme={theme} tone="warn">This detail belongs to a newer project revision than the frame.</Note>
                <Button theme={theme} compact label="Refresh snapshot" icon="RefreshCw" onPress={onRefresh} />
              </View>
            )}
            {records.length === 0 ? <Empty theme={theme} title="No linked observations" detail="Absence of evidence is not confirmation or refutation." icon="FileQuestion" /> : (
              <View style={{ gap: 8 }}>
                {records.map((record: EvidenceRecord) => (
                  <EvidenceRecordCard key={record.sequence} theme={theme} record={record} claimState={state?.state} latest={latest.has(record.sequence)} expanded={expandedEvidence === record.sequence} onToggle={() => setExpandedEvidence((value) => value === record.sequence ? null : record.sequence)} />
                ))}
              </View>
            )}
            {query.data && query.data.nextCursor !== null && <Body theme={theme} muted>Showing the newest {query.data.records.length} of {query.data.total}; older records remain in the trail.</Body>}
          </>
        )}
      </Card>
    </View>
  );
}

function ProofChain({ theme, compact, claim, state, requirementPath, evidenceCount }: {
  theme: PluginTheme;
  compact: boolean;
  claim: Claim;
  state?: ClaimState;
  requirementPath?: string;
  evidenceCount: number;
}) {
  const items = [
    { icon: "FileText", label: "Source", value: claim.source?.path ?? "none" },
    { icon: "Box", label: "Claim", value: `${claim.id}${state ? ` · ${state}` : ""}` },
    { icon: "ListTree", label: "Requirement", value: requirementPath ?? "whole tree" },
    { icon: "History", label: "Evidence", value: `${evidenceCount} linked observation(s)` },
  ];
  return (
    <Card theme={theme} compact={compact} title="Proof chain" subtitle="Declared links and observations; freshness remains represented by the map state">
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

function ClaimFacts({ theme, compact, claim }: { theme: PluginTheme; compact: boolean; claim: Claim }) {
  return (
    <Card theme={theme} compact={compact} title="Claim definition">
      <KeyValue theme={theme} label="scope" value={claim.scope.length ? claim.scope.join(", ") : "empty"} />
      <KeyValue theme={theme} label="falsifier" value={claim.falsifier || "not declared"} />
      <KeyValue theme={theme} label="negative control" value={claim.control ?? "none"} />
      {claim.source && (
        <>
          <KeyValue theme={theme} label="source digest" value={claim.source.digest} />
          {claim.source.review && <KeyValue theme={theme} label="source review" value={`${claim.source.review.by} · ${formatTime(claim.source.review.at)} · ${claim.source.review.reason}`} />}
        </>
      )}
      {claim.review_on.length > 0 && <KeyValue theme={theme} label="review triggers" value={claim.review_on.join(", ")} />}
      {claim.waiver && (
        <View style={{ gap: 8, borderTopWidth: 1, borderTopColor: theme.colors.border, paddingTop: 9 }}>
          <Badge theme={theme} label="waiver recorded" tone="warn" icon="ShieldAlert" />
          <KeyValue theme={theme} label="gap" value={claim.waiver.gap} />
          <KeyValue theme={theme} label="issuer / interval" value={`${claim.waiver.issuer} · ${formatTime(claim.waiver.issued_at)} → ${formatTime(claim.waiver.expires_at)}`} />
          <KeyValue theme={theme} label="reason" value={claim.waiver.reason} />
          <KeyValue theme={theme} label="recovery" value={claim.waiver.recovery} />
          {claim.waiver.compensating_controls.length > 0 && <KeyValue theme={theme} label="compensating controls" value={claim.waiver.compensating_controls.join(", ")} />}
          <Body theme={theme} muted>A waiver is a risk decision. It does not turn a failed observation into a pass or green.</Body>
        </View>
      )}
    </Card>
  );
}
