import { Text, View } from "react-native";
import type { ConsoleTheme } from "../shared/theme";
import {
  attentionBrief,
  attentionReasonCodes,
  attentionReasonText,
  type AgentAttentionItem,
  type AttentionBriefContext,
  type AttentionModel,
} from "./attention";
import type { GraphSelection } from "./graph";
import { useHost } from "./host/context";
import { useT } from "./i18n";
import { Badge, Body, Button, Card, Empty, Mono } from "./parts";
import { claimStateColor, claimStateIcon, claimStateKey, formatTime, stateReasonKey, stateReasonTone } from "./vocabulary";

export interface AttentionViewProps {
  theme: ConsoleTheme;
  compact: boolean;
  model: AttentionModel;
  context: AttentionBriefContext;
  onSelect: (selection: GraphSelection) => void;
  onRun: () => void;
  runEnabled: boolean;
}

export function AttentionView({ theme, compact, model, context, onSelect, onRun, runEnabled }: AttentionViewProps) {
  const host = useHost();
  const t = useT();
  const toast = host.useToast();
  const copy = async (item: AgentAttentionItem, label: string) => {
    try {
      await host.copyText(attentionBrief(item, context));
      toast.show(t("toast.brief_copied_for", { label }));
    } catch {
      toast.error(t("toast.brief_not_copied"));
    }
  };
  return (
    <View style={{ gap: 10 }}>
      <Card
        theme={theme}
        compact={compact}
        title={t("attention.title_agent_can_act")}
        subtitle={model.agentTaskCount === 0
          ? t("attention.empty_delegated_visible")
          : `${t("attention.grouped_task_count", { count: model.agentTaskCount })} · ${t("attention.grouped_claim_count", { count: model.agentClaimCount })}`}
      >
        {model.agentCanAct.length === 0 ? (
          <Empty theme={theme} title={t("attention.empty_delegated")} detail={t("attention.empty_delegated_detail")} icon="Bot" />
        ) : (
          <View style={{ gap: 10 }}>
            {model.agentCanAct.map((item) => (
              <AgentCard key={item.id} theme={theme} compact={compact} item={item} onCopy={() => void copy(item, t("attention.agent_task_brief"))} onRun={onRun} runEnabled={runEnabled} />
            ))}
          </View>
        )}
      </Card>
      {model.acceptedRisks.length > 0 && (
        <Card theme={theme} compact={compact} title={t("attention.title_accepted_risk")} subtitle={t("attention.accepted_risk_detail")}>
          <View style={{ gap: 10 }}>
            {model.acceptedRisks.map((risk) => (
              <View key={risk.id} style={{ borderWidth: 1, borderColor: theme.colors.statusWarning, borderRadius: 9, padding: 12, gap: 7 }}>
                <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
                  <Badge theme={theme} label={t("attention.kind_accepted_risk")} tone="warn" icon="ShieldCheck" />
                  <Badge theme={theme} label={t("attention.expires_at", { time: formatTime(risk.expiresAt) })} icon="Clock3" />
                </View>
                <Text style={{ color: theme.colors.foreground, fontSize: 14, fontWeight: "700" }}>{t(risk.title)}</Text>
                <Body theme={theme} muted>{risk.gap}</Body>
                <Mono theme={theme}>{t("attention.issuer_label")}: {risk.issuer}</Mono>
                <Mono theme={theme}>{t("attention.reason_label")}: {risk.reason}</Mono>
                <Mono theme={theme}>{t("attention.recovery_label")}: {risk.recovery}</Mono>
                {risk.compensatingControls.length > 0 && <Mono theme={theme}>{t("attention.controls_label")}: {risk.compensatingControls.join(", ")}</Mono>}
                <Button theme={theme} compact label={t("queue.inspect_claim")} icon="Search" onPress={() => onSelect({ claimId: risk.claimId })} />
              </View>
            ))}
          </View>
        </Card>
      )}
    </View>
  );
}

function AgentCard({ theme, compact, item, onCopy, onRun, runEnabled }: {
  theme: ConsoleTheme;
  compact: boolean;
  item: AgentAttentionItem;
  onCopy: () => void;
  onRun: () => void;
  runEnabled: boolean;
}) {
  const t = useT();
  return (
    <View style={{ borderWidth: 1, borderColor: theme.colors.accent, borderRadius: 10, padding: compact ? 12 : 14, gap: 9 }}>
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
        <Badge theme={theme} label={t("attention.kind_agent_can_act")} tone="info" icon="Bot" />
        {item.claimIds.length > 0 && <Badge theme={theme} label={t("attention.item_claim_count", { count: item.claimIds.length })} icon="Boxes" />}
        {item.states.map((state) => <Badge key={state} theme={theme} label={t(claimStateKey(state))} color={claimStateColor(theme, state)} icon={claimStateIcon(state)} />)}
        {attentionReasonCodes(item.reasons).map((reason) => <Badge key={reason} theme={theme} label={t(stateReasonKey(reason))} tone={stateReasonTone(reason)} />)}
      </View>
      <Text style={{ color: theme.colors.foreground, fontSize: 15, fontWeight: "700" }}>{t(item.title)}</Text>
      {item.reasons.length > 0 && <DecisionText theme={theme} label={t("state.reason_title")}>{attentionReasonText(item.reasons, t)}</DecisionText>}
      <DecisionText theme={theme} label={t("queue.why")}>{t(item.why)}</DecisionText>
      <DecisionText theme={theme} label={t("queue.human_boundary")}>{t(item.humanBoundary)}</DecisionText>
      <DecisionText theme={theme} label={t("queue.agent_may")}>{t(item.agentMay)}</DecisionText>
      <DecisionText theme={theme} label={t("queue.agent_must_not")}>{t(item.agentMustNot)}</DecisionText>
      <DecisionText theme={theme} label={t("queue.next_safe_step")}>{t(item.suggestedAction)}</DecisionText>
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 7 }}>
        {item.kind === "refresh-evidence" && (
          <View style={{ gap: 4 }}>
            <Button theme={theme} compact label={t("attention.run_checks")} icon="Play" variant="primary" onPress={onRun} disabled={!runEnabled} />
            {!runEnabled && <Body theme={theme} muted>{t("permissions.run_closed")}</Body>}
          </View>
        )}
        <Button theme={theme} compact label={t("attention.copy_task_brief")} icon="Clipboard" onPress={onCopy} />
      </View>
    </View>
  );
}

function DecisionText({ theme, label, emphasis = false, children }: {
  theme: ConsoleTheme;
  label: string;
  emphasis?: boolean;
  children: string;
}) {
  return (
    <View style={{ gap: 2 }}>
      <Text style={{ color: emphasis ? theme.colors.foreground : theme.colors.foregroundMuted, fontSize: 10, fontWeight: "700", textTransform: "uppercase" }}>{label}</Text>
      <Text style={{ color: emphasis ? theme.colors.foreground : theme.colors.foregroundMuted, fontSize: 12, lineHeight: 18 }}>{children}</Text>
    </View>
  );
}
