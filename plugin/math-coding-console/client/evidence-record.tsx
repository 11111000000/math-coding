import type { PluginTheme } from "@getpaseo/plugin";
import { Pressable, Text, View } from "react-native";
import type { ClaimState, EvidenceRecord } from "../shared/domain";
import { requirementLabel } from "../shared/requirements";
import { Badge, KeyValue, Mono } from "./parts";
import { claimStateColor, claimStateIcon, formatTime, outcomeColor, outcomeIcon } from "./vocabulary";

export function EvidenceRecordCard({ theme, record, claimState, latest = false, expanded, onToggle }: {
  theme: PluginTheme;
  record: EvidenceRecord;
  claimState?: ClaimState;
  latest?: boolean;
  expanded: boolean;
  onToggle: () => void;
}) {
  return (
    <View style={{ borderWidth: 1, borderColor: theme.colors.border, borderRadius: 9, backgroundColor: theme.colors.surface1, overflow: "hidden" }}>
      <Pressable accessibilityRole="button" accessibilityLabel={`Evidence ${record.sequence + 1}, ${record.outcome}`} onPress={onToggle} style={{ padding: 11, gap: 7 }}>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5, alignItems: "center" }}>
          <Badge theme={theme} label={record.outcome} color={outcomeColor(theme, record.outcome)} icon={outcomeIcon(record.outcome)} />
          <Badge theme={theme} label={record.independence} />
          {latest && <Badge theme={theme} label="latest recorded" tone="info" icon="History" />}
          {record.requirementPaths.length === 0 && <Badge theme={theme} label="historical requirement" tone="warn" />}
          {claimState && <Badge theme={theme} label={`claim: ${claimState}`} color={claimStateColor(theme, claimState)} icon={claimStateIcon(claimState)} />}
        </View>
        <Text style={{ color: theme.colors.foreground, fontSize: 12, fontWeight: "600" }}>{record.claim_id} · {formatTime(record.issued_at)}</Text>
        <Mono theme={theme} lines={2}>{requirementLabel(record.requirement)}</Mono>
        <Mono theme={theme}>trail #{record.sequence + 1} · {record.producer.class} / {record.producer.identity}</Mono>
      </Pressable>
      {expanded && (
        <View style={{ borderTopWidth: 1, borderTopColor: theme.colors.border, padding: 11, gap: 10 }}>
          <KeyValue theme={theme} label="requirement paths" value={record.requirementPaths.length ? record.requirementPaths.join(", ") : "not present in the current spec"} />
          <KeyValue theme={theme} label="candidate tree" value={record.candidate_tree} />
          <KeyValue theme={theme} label="materials digest" value={record.materials_digest} />
          <KeyValue theme={theme} label="definition digest" value={record.definition_digest} />
          <KeyValue theme={theme} label="verifier digest" value={record.verifier_digest} />
          <KeyValue theme={theme} label="environment" value={`${record.environment.class} · ${record.environment.fingerprint}`} />
          <KeyValue theme={theme} label="producer run" value={record.producer.run ?? "none"} />
          <KeyValue theme={theme} label="valid until" value={record.valid_until === null ? "no expiry recorded" : formatTime(record.valid_until)} />
          <KeyValue theme={theme} label="control reach" value={record.control_reach ?? "not recorded"} />
          <KeyValue theme={theme} label="evidence ref" value={record.evidence_ref ?? "none"} />
        </View>
      )}
    </View>
  );
}
