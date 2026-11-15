import { Text, View } from "react-native";
import type { ConsoleTheme } from "../shared/theme";
import {
  attentionBrief,
  type AgentAttentionItem,
  type AttentionBriefContext,
  type AttentionModel,
  type HumanAttentionItem,
} from "./attention";
import type { GraphSelection } from "./graph";
import { useHost } from "./host/context";
import { Badge, Body, Button, Card, Empty, Mono } from "./parts";
import { claimStateColor, claimStateIcon, formatTime } from "./vocabulary";

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
  const toast = host.useToast();
  const copy = async (item: HumanAttentionItem | AgentAttentionItem, label: string) => {
    try {
      await host.copyText(attentionBrief(item, context));
      toast.show(`${label} copied for an agent`);
    } catch {
      toast.error("The brief could not be copied");
    }
  };
  return (
    <View style={{ gap: 10 }}>
      <Card
        theme={theme}
        compact={compact}
        title="Decide now"
        subtitle={model.needsHuman.length === 0 ? "No human-only decision is waiting" : `${model.needsHuman.length} decision(s) cannot be delegated to an agent`}
      >
        {model.needsHuman.length === 0 ? (
          <View style={{ flexDirection: "row", alignItems: "center", gap: 10 }}>
            <Badge theme={theme} label="clear" tone="good" icon="Check" />
            <View style={{ flex: 1, gap: 2 }}>
              <Body theme={theme}>Nothing needs your decision now.</Body>
              <Body theme={theme} muted>The remaining work can proceed within the declared claims and checks.</Body>
            </View>
          </View>
        ) : (
          <View style={{ gap: 10 }}>
            {model.needsHuman.map((item) => (
              <HumanCard key={item.id} theme={theme} compact={compact} item={item} onSelect={onSelect} onCopy={() => void copy(item, "Decision brief")} />
            ))}
          </View>
        )}
      </Card>
      <Card
        theme={theme}
        compact={compact}
        title="Agent can act"
        subtitle={model.agentTaskCount === 0 ? "No delegated work is visible" : `${model.agentTaskCount} grouped task(s) · ${model.agentClaimCount} claim(s) with machine-verifiable work`}
      >
        {model.agentCanAct.length === 0 ? (
          <Empty theme={theme} title="No delegated work" detail="There is no machine-verifiable work that can proceed without a human decision." icon="Bot" />
        ) : (
          <View style={{ gap: 10 }}>
            {model.agentCanAct.map((item) => (
              <AgentCard key={item.id} theme={theme} compact={compact} item={item} onCopy={() => void copy(item, "Agent task brief")} onRun={onRun} runEnabled={runEnabled} />
            ))}
          </View>
        )}
      </Card>
      {model.acceptedRisks.length > 0 && (
        <Card theme={theme} compact={compact} title="Accepted risk" subtitle="A human decision already stands until its stated expiry">
          <View style={{ gap: 10 }}>
            {model.acceptedRisks.map((risk) => (
              <View key={risk.id} style={{ borderWidth: 1, borderColor: theme.colors.statusWarning, borderRadius: 9, padding: 12, gap: 7 }}>
                <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
                  <Badge theme={theme} label="accepted risk" tone="warn" icon="ShieldCheck" />
                  <Badge theme={theme} label={`expires ${formatTime(risk.expiresAt)}`} icon="Clock3" />
                </View>
                <Text style={{ color: theme.colors.foreground, fontSize: 14, fontWeight: "700" }}>{risk.title}</Text>
                <Body theme={theme} muted>{risk.gap}</Body>
                <Mono theme={theme}>issuer: {risk.issuer}</Mono>
                <Mono theme={theme}>reason: {risk.reason}</Mono>
                <Mono theme={theme}>recovery: {risk.recovery}</Mono>
                {risk.compensatingControls.length > 0 && <Mono theme={theme}>controls: {risk.compensatingControls.join(", ")}</Mono>}
                <Button theme={theme} compact label="Inspect claim" icon="Search" onPress={() => onSelect({ claimId: risk.claimId })} />
              </View>
            ))}
          </View>
        </Card>
      )}
    </View>
  );
}

function HumanCard({ theme, compact, item, onSelect, onCopy }: {
  theme: ConsoleTheme;
  compact: boolean;
  item: HumanAttentionItem;
  onSelect: (selection: GraphSelection) => void;
  onCopy: () => void;
}) {
  return (
    <View style={{ borderWidth: 1, borderColor: theme.colors.statusWarning, borderRadius: 10, padding: compact ? 12 : 14, gap: 9 }}>
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
        <Badge theme={theme} label="needs you" tone="warn" icon="UserRoundCheck" />
        {item.states.map((state) => <Badge key={state} theme={theme} label={state} color={claimStateColor(theme, state)} icon={claimStateIcon(state)} />)}
      </View>
      <Text style={{ color: theme.colors.foreground, fontSize: 15, fontWeight: "700" }}>{item.title}</Text>
      <DecisionText theme={theme} label="Why this needs you">{item.why}</DecisionText>
      <DecisionText theme={theme} label="Your decision" emphasis>{item.humanQuestion}</DecisionText>
      <DecisionText theme={theme} label="Agent may">{item.agentMay}</DecisionText>
      <DecisionText theme={theme} label="Agent must not">{item.agentMustNot}</DecisionText>
      <DecisionText theme={theme} label="Next safe step">{item.suggestedAction}</DecisionText>
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 7 }}>
        {item.claimIds[0] && <Button theme={theme} compact label="Inspect" icon="Search" onPress={() => onSelect({ claimId: item.claimIds[0]! })} />}
        <Button theme={theme} compact label="Copy brief for agent" icon="Clipboard" onPress={onCopy} />
      </View>
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
  return (
    <View style={{ borderWidth: 1, borderColor: theme.colors.accent, borderRadius: 10, padding: compact ? 12 : 14, gap: 9 }}>
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
        <Badge theme={theme} label="agent can act" tone="info" icon="Bot" />
        {item.claimIds.length > 0 && <Badge theme={theme} label={`${item.claimIds.length} claim(s)`} icon="Boxes" />}
        {item.states.map((state) => <Badge key={state} theme={theme} label={state} color={claimStateColor(theme, state)} icon={claimStateIcon(state)} />)}
      </View>
      <Text style={{ color: theme.colors.foreground, fontSize: 15, fontWeight: "700" }}>{item.title}</Text>
      <DecisionText theme={theme} label="Why">{item.why}</DecisionText>
      <DecisionText theme={theme} label="Human boundary">{item.humanBoundary}</DecisionText>
      <DecisionText theme={theme} label="Agent may">{item.agentMay}</DecisionText>
      <DecisionText theme={theme} label="Agent must not">{item.agentMustNot}</DecisionText>
      <DecisionText theme={theme} label="Next safe step">{item.suggestedAction}</DecisionText>
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 7 }}>
        {item.kind === "refresh-evidence" && <Button theme={theme} compact label="Run checks" icon="Play" variant="primary" onPress={onRun} disabled={!runEnabled} />}
        <Button theme={theme} compact label="Copy task brief" icon="Clipboard" onPress={onCopy} />
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
