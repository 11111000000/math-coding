import { useQuery } from "@tanstack/react-query";
import { useEffect, useMemo, useState } from "react";
import { Pressable, Text, View } from "react-native";
import { EVIDENCE_OUTCOMES, INDEPENDENCE_LEVELS, type EvidenceRecord } from "../shared/domain";
import { rpcSchemas, type SnapshotReady } from "../shared/schemas";
import type { ConsoleTheme } from "../shared/theme";
import { EvidenceRecordCard } from "./evidence-record";
import { useHost } from "./host/context";
import { useT } from "./i18n";
import { Badge, Body, Button, Card, Empty, FilterRow, Note, Select } from "./parts";
import { independenceKey, outcomeColor, outcomeKey } from "./vocabulary";

export function EvidenceView({ theme, compact, snapshot }: {
  theme: ConsoleTheme;
  compact: boolean;
  snapshot: SnapshotReady;
}) {
  const { useRpc } = useHost();
  const t = useT();
  const fetchPage = useRpc(rpcSchemas.evidence);
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
  const all = t("claims.filter_all");
  const outcomeLabels: Record<string, string> = {
    all,
    ...Object.fromEntries(EVIDENCE_OUTCOMES.map((item) => [item, t(outcomeKey(item))])),
  };
  const independenceLabels: Record<string, string> = {
    all,
    ...Object.fromEntries(INDEPENDENCE_LEVELS.map((item) => [item, t(independenceKey(item))])),
  };
  return (
    <View style={{ gap: 10 }}>
      <Card theme={theme} compact={compact} title={t("evidence.title")} subtitle={t("evidence.subtitle")}>
        {query.isPending ? <Empty theme={theme} title={t("evidence.loading")} icon="History" /> : query.isError ? (
          <Note theme={theme} tone="bad">
            {String(query.error).includes("busy")
              ? t("error.workspace_busy_short")
              : t("evidence.error_read", { error: String(query.error) })}
          </Note>
        ) : (
          <>
            <FilterRow>
              <Select theme={theme} label={t("evidence.filter_outcome")} value={outcome} options={["all", ...EVIDENCE_OUTCOMES]} optionLabels={outcomeLabels} onChange={setOutcome} />
              <Select theme={theme} label={t("evidence.filter_claim")} value={claim} options={["all", ...claimOptions]} optionLabels={{ all }} onChange={setClaim} />
              <Select theme={theme} label={t("evidence.filter_producer")} value={producer} options={["all", ...producerOptions]} optionLabels={{ all }} onChange={setProducer} />
              <Select theme={theme} label={t("evidence.filter_independence")} value={independence} options={["all", ...INDEPENDENCE_LEVELS]} optionLabels={independenceLabels} onChange={setIndependence} />
            </FilterRow>
            {allRecords.length > 0 && (
              <View style={{ gap: 8 }}>
                <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
                  {EVIDENCE_OUTCOMES.map((item) => {
                    const count = allRecords.filter((record) => record.outcome === item).length;
                    return count > 0 ? <Badge key={item} theme={theme} label={`${t(outcomeKey(item))} ${count}`} color={outcomeColor(theme, item)} /> : null;
                  })}
                </View>
                <View style={{ flexDirection: "row", alignItems: "flex-end", gap: 2, height: 42, paddingVertical: 5 }}>
                  {allRecords.slice(0, 100).map((record) => (
                    <Pressable
                      key={record.sequence}
                      accessibilityRole="button"
                      accessibilityLabel={t("evidence.record_line", { claim: record.claim_id, outcome: t(outcomeKey(record.outcome)), sequence: record.sequence + 1 })}
                      onPress={() => setExpanded(record.sequence)}
                      style={{ width: 7, height: 30, borderRadius: 2, backgroundColor: outcomeColor(theme, record.outcome), opacity: records.includes(record) ? 1 : 0.15 }}
                    />
                  ))}
                </View>
                <Body theme={theme} muted>{t("evidence.bar_note")}</Body>
              </View>
            )}
            <View style={{ flexDirection: "row", flexWrap: "wrap", alignItems: "center", justifyContent: "space-between", gap: 6 }}>
              <Body theme={theme} muted>{t("evidence.shown_from_page", { shown: records.length, total: query.data?.total ?? 0 })}</Body>
              <View style={{ flexDirection: "row", gap: 5 }}>
                {cursor > 0 && <Button theme={theme} compact label={t("evidence.newest")} icon="ChevronsUp" onPress={() => setCursor(0)} />}
                {query.data?.nextCursor !== null && query.data?.nextCursor !== undefined && <Button theme={theme} compact label={t("evidence.older")} icon="ChevronDown" onPress={() => setCursor(query.data?.nextCursor ?? 0)} />}
              </View>
            </View>
            {query.data && query.data.revision !== snapshot.revision && <Note theme={theme} tone="warn">{t("evidence.map_changed")}</Note>}
          </>
        )}
      </Card>
      {query.data && records.length === 0 ? (
        <Card theme={theme} compact={compact}><Empty theme={theme} title={t("evidence.empty_title")} detail={t("evidence.empty_detail")} icon="FilterX" /></Card>
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
