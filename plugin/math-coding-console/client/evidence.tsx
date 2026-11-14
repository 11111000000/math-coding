import type { PluginTheme } from "@getpaseo/plugin";
import { useRpc } from "@getpaseo/plugin/client";
import { useQuery } from "@tanstack/react-query";
import { useEffect, useMemo, useState } from "react";
import { Pressable, Text, View } from "react-native";
import type { SnapshotReady } from "../shared/contracts";
import { EVIDENCE_OUTCOMES, INDEPENDENCE_LEVELS, type EvidenceRecord } from "../shared/domain";
import { evidencePageRpc } from "../shared/contracts";
import { EvidenceRecordCard } from "./evidence-record";
import { Badge, Body, Button, Card, Empty, FilterRow, Note, Select } from "./parts";
import { outcomeColor } from "./vocabulary";

export function EvidenceView({ theme, compact, snapshot }: {
  theme: PluginTheme;
  compact: boolean;
  snapshot: SnapshotReady;
}) {
  const fetchPage = useRpc(evidencePageRpc);
  const [cursor, setCursor] = useState(0);
  const [outcome, setOutcome] = useState("all");
  const [claim, setClaim] = useState("all");
  const [producer, setProducer] = useState("all");
  const [independence, setIndependence] = useState("all");
  const [expanded, setExpanded] = useState<number | null>(null);
  useEffect(() => { setCursor(0); setExpanded(null); }, [snapshot.revision]);
  const query = useQuery({
    queryKey: ["mathcoding-evidence", snapshot.workspace.id, snapshot.revision, snapshot.generatedAt, cursor],
    queryFn: () => fetchPage({ workspaceId: snapshot.workspace.id, cursor, limit: 120 }),
    retry: false,
  });
  const records = useMemo(() => (query.data?.records ?? []).filter((record) =>
    (outcome === "all" || record.outcome === outcome) &&
    (claim === "all" || record.claim_id === claim) &&
    (producer === "all" || record.producer.identity === producer) &&
    (independence === "all" || record.independence === independence),
  ), [query.data, outcome, claim, producer, independence]);
  const allRecords = query.data?.records ?? [];
  const claimOptions = [...new Set([...snapshot.claims.map((item) => item.id), ...allRecords.map((item) => item.claim_id)])].sort();
  const producerOptions = [...new Set(allRecords.map((item) => item.producer.identity))].sort();
  const stateByClaim = new Map(snapshot.map.states.map((item) => [item.id, item.state]));
  return (
    <View style={{ gap: 10 }}>
      <Card theme={theme} compact={compact} title="Observation history" subtitle="Evidence outcomes describe observations, not current claim states">
        {query.isPending ? <Empty theme={theme} title="Reading the evidence trail" icon="History" /> : query.isError ? (
          <Note theme={theme} tone="bad">{String(query.error).includes("busy") ? "The workspace is busy with another operation. Retry shortly." : `The evidence trail could not be read: ${String(query.error)}`}</Note>
        ) : (
          <>
            <FilterRow>
              <Select theme={theme} label="outcome" value={outcome} options={["all", ...EVIDENCE_OUTCOMES]} onChange={setOutcome} />
              <Select theme={theme} label="claim" value={claim} options={["all", ...claimOptions]} onChange={setClaim} />
              <Select theme={theme} label="producer" value={producer} options={["all", ...producerOptions]} onChange={setProducer} />
              <Select theme={theme} label="independence" value={independence} options={["all", ...INDEPENDENCE_LEVELS]} onChange={setIndependence} />
            </FilterRow>
            {allRecords.length > 0 && (
              <View style={{ gap: 8 }}>
                <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
                  {EVIDENCE_OUTCOMES.map((item) => {
                    const count = allRecords.filter((record) => record.outcome === item).length;
                    return count > 0 ? <Badge key={item} theme={theme} label={`${item} ${count}`} color={outcomeColor(theme, item)} /> : null;
                  })}
                </View>
                <View style={{ flexDirection: "row", alignItems: "flex-end", gap: 2, height: 42, paddingVertical: 5 }}>
                  {allRecords.slice(0, 100).map((record) => (
                    <Pressable
                      key={record.sequence}
                      accessibilityRole="button"
                      accessibilityLabel={`${record.claim_id}, ${record.outcome}, observation ${record.sequence + 1}`}
                      onPress={() => setExpanded(record.sequence)}
                      style={{ width: 7, height: 30, borderRadius: 2, backgroundColor: outcomeColor(theme, record.outcome), opacity: records.includes(record) ? 1 : 0.15 }}
                    />
                  ))}
                </View>
                <Body theme={theme} muted>One bar per observation on this page. Colour is evidence outcome only.</Body>
              </View>
            )}
            <View style={{ flexDirection: "row", flexWrap: "wrap", alignItems: "center", justifyContent: "space-between", gap: 6 }}>
              <Body theme={theme} muted>{records.length} shown from this page · {query.data?.total ?? 0} records in the trail</Body>
              <View style={{ flexDirection: "row", gap: 5 }}>
                {cursor > 0 && <Button theme={theme} compact label="Newest" icon="ChevronsUp" onPress={() => setCursor(0)} />}
                {query.data?.nextCursor !== null && query.data?.nextCursor !== undefined && <Button theme={theme} compact label="Older" icon="ChevronDown" onPress={() => setCursor(query.data?.nextCursor ?? 0)} />}
              </View>
            </View>
            {query.data && query.data.revision !== snapshot.revision && <Note theme={theme} tone="warn">The map changed while this page was open. Refresh the workspace snapshot before drawing conclusions.</Note>}
          </>
        )}
      </Card>
      {query.data && records.length === 0 ? (
        <Card theme={theme} compact={compact}><Empty theme={theme} title="No matching observations" detail="The trail may be empty, or the current filters exclude this page." icon="FilterX" /></Card>
      ) : (
        <View style={{ gap: 8 }}>
          {records.map((record: EvidenceRecord) => (
            <EvidenceRecordCard key={record.sequence} theme={theme} record={record} claimState={stateByClaim.get(record.claim_id)} expanded={expanded === record.sequence} onToggle={() => setExpanded((value) => value === record.sequence ? null : record.sequence)} />
          ))}
        </View>
      )}
    </View>
  );
}
