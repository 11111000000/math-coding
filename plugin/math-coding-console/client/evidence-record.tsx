import type { ConsoleTheme } from "../shared/theme";
import { Pressable, Text, View } from "react-native";
import type { ClaimState, EvidenceRecord } from "../shared/domain";
import { requirementLabelRef } from "../shared/requirements";
import { useT } from "./i18n";
import { Badge, KeyValue, Mono } from "./parts";
import { claimStateColor, claimStateIcon, claimStateKey, formatTime, independenceKey, outcomeColor, outcomeIcon, outcomeKey } from "./vocabulary";

export function EvidenceRecordCard({ theme, record, claimState, latest = false, expanded, onToggle }: {
  theme: ConsoleTheme;
  record: EvidenceRecord;
  claimState?: ClaimState;
  latest?: boolean;
  expanded: boolean;
  onToggle: () => void;
}) {
  const t = useT();
  return (
    <View style={{ borderWidth: 1, borderColor: theme.colors.border, borderRadius: 9, backgroundColor: theme.colors.surface1, overflow: "hidden" }}>
      <Pressable accessibilityRole="button" accessibilityLabel={t("evidence.record_title", { sequence: record.sequence + 1, outcome: t(outcomeKey(record.outcome)) })} onPress={onToggle} style={{ padding: 11, gap: 7 }}>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5, alignItems: "center" }}>
          <Badge theme={theme} label={t(outcomeKey(record.outcome))} color={outcomeColor(theme, record.outcome)} icon={outcomeIcon(record.outcome)} />
          <Badge theme={theme} label={t(independenceKey(record.independence))} />
          {latest && <Badge theme={theme} label={t("evidence.field_latest_recorded")} tone="info" icon="History" />}
          {record.requirementPaths.length === 0 && <Badge theme={theme} label={t("evidence.field_historical_requirement")} tone="warn" />}
          {claimState && <Badge theme={theme} label={t("boundary.claim_state", { state: t(claimStateKey(claimState)) })} color={claimStateColor(theme, claimState)} icon={claimStateIcon(claimState)} />}
        </View>
        <Text style={{ color: theme.colors.foreground, fontSize: 12, fontWeight: "600" }}>{record.claim_id} · {formatTime(record.issued_at)}</Text>
        <Mono theme={theme} lines={2}>{t(requirementLabelRef(record.requirement))}</Mono>
        <Mono theme={theme}>{t("evidence.trail_line", { sequence: record.sequence + 1, class: record.producer.class, identity: record.producer.identity })}</Mono>
      </Pressable>
      {expanded && (
        <View style={{ borderTopWidth: 1, borderTopColor: theme.colors.border, padding: 11, gap: 10 }}>
          <KeyValue theme={theme} label={t("evidence.field_requirement_paths")} value={record.requirementPaths.length ? record.requirementPaths.join(", ") : t("evidence.field_requirement_absent")} />
          <KeyValue theme={theme} label={t("evidence.field_candidate_tree")} value={record.candidate_tree} />
          <KeyValue theme={theme} label={t("evidence.field_materials_digest")} value={record.materials_digest} />
          <KeyValue theme={theme} label={t("evidence.field_definition_digest")} value={record.definition_digest} />
          <KeyValue theme={theme} label={t("evidence.field_verifier_digest")} value={record.verifier_digest} />
          <KeyValue theme={theme} label={t("evidence.environment")} value={`${record.environment.class} · ${record.environment.fingerprint}`} />
          <KeyValue theme={theme} label={t("evidence.field_producer_run")} value={record.producer.run ?? t("common.none")} />
          <KeyValue theme={theme} label={t("evidence.field_valid_until")} value={record.valid_until === null ? t("evidence.field_no_expiry") : formatTime(record.valid_until)} />
          <KeyValue theme={theme} label={t("evidence.field_control_reach")} value={record.control_reach ?? t("evidence.field_not_recorded")} />
          <KeyValue theme={theme} label={t("evidence.field_evidence_ref")} value={record.evidence_ref ?? t("common.none")} />
        </View>
      )}
    </View>
  );
}
