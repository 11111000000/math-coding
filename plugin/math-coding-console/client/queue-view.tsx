import { useState } from "react";
import { Text, View } from "react-native";
import type { AttentionBriefContext } from "./attention";
import { attentionBrief, attentionReasonCodes, attentionReasonText } from "./attention";
import type { ConsoleTheme } from "../shared/theme";
import type { ConditionEvidence, HumanQueue, HumanQueueItem, StandingObligation } from "./human-queue";
import type { GraphSelection } from "./graph";
import { useHost } from "./host/context";
import { Badge, Body, Button, Card, Empty, Mono, Note } from "./parts";
import { claimStateColor, claimStateIcon, formatTime } from "./vocabulary";

export interface QueueViewProps {
  theme: ConsoleTheme;
  compact: boolean;
  queue: HumanQueue;
  context: AttentionBriefContext;
  onOpenFile: (path: string) => void;
  onSelect: (selection: GraphSelection) => void;
  /**
   * Whether every condition of the queue has a record in the trail, and
   * whether the trail was read to its end. When it was not, the panel says so
   * instead of letting an unread page look like a condition without evidence.
   */
  trailComplete?: boolean;
  trailExhausted?: boolean;
}

/**
 * The first screen of the console.
 *
 * It answers what the human has to do in this repository: the decisions that
 * cannot be delegated, the obligations the owner keeps true, and the result
 * the owner still has to accept. Every line comes from the canonical map, the
 * declared specification and the evidence trail.
 */
export function QueueView({ theme, compact, queue, context, onOpenFile, onSelect, trailComplete = true, trailExhausted = true }: QueueViewProps) {
  const { copyText, useToast } = useHost();
  const toast = useToast();
  const [showAll, setShowAll] = useState(false);
  const visible = showAll ? queue.obligations : queue.obligations.slice(0, 5);
  const copyBrief = async (item: HumanQueueItem) => {
    try {
      await copyText(attentionBrief(item.attention, context));
      toast.show("Brief copied for the agent");
    } catch {
      toast.error("The brief could not be copied");
    }
  };
  return (
    <View style={{ gap: 10 }}>
      {!trailComplete && (
        <Note theme={theme} tone="warn">
          {trailExhausted
            ? "Some conditions have no record in the trail yet."
            : "The trail was not read to the end: some conditions may still have older evidence."}
        </Note>
      )}
      <Card
        theme={theme}
        compact={compact}
        title="Your queue"
        subtitle={queue.items.length === 0
          ? "No decision waits for you; the obligations below stay yours"
          : `${queue.items.length} decision(s) cannot be delegated to an agent`}
      >
        {queue.items.length === 0 ? (
          <View style={{ flexDirection: "row", alignItems: "center", gap: 10 }}>
            <Badge theme={theme} label="clear" tone="good" icon="Check" />
            <View style={{ flex: 1, gap: 2 }}>
              <Body theme={theme}>Nothing needs your decision now.</Body>
              <Body theme={theme} muted>The remaining work can proceed within the declared claims and checks.</Body>
            </View>
          </View>
        ) : (
          <View style={{ gap: 10 }}>
            {queue.items.map((item) => (
              <QueueItemCard
                key={item.id}
                theme={theme}
                compact={compact}
                item={item}
                onOpenFile={onOpenFile}
                onSelect={onSelect}
                onCopyBrief={() => void copyBrief(item)}
              />
            ))}
          </View>
        )}
      </Card>
      <Card
        theme={theme}
        compact={compact}
        title="Your standing obligations"
        subtitle={`${queue.obligations.length} claim(s) of this goal stay the responsibility of their owner`}
      >
        {queue.obligations.length === 0 ? (
          <Empty theme={theme} title="No declared obligations" detail="The project declares no claim yet." icon="ListX" />
        ) : (
          <View style={{ gap: 8 }}>
            {visible.map((obligation) => (
              <ObligationRow
                key={obligation.claimId}
                theme={theme}
                compact={compact}
                obligation={obligation}
                onOpenFile={onOpenFile}
                onSelect={onSelect}
              />
            ))}
            {queue.obligations.length > visible.length && (
              <Button theme={theme} compact label={`Show all ${queue.obligations.length} obligations`} icon="List" onPress={() => setShowAll(true)} />
            )}
            {showAll && queue.obligations.length > 5 && (
              <Button theme={theme} compact label="Show fewer" icon="ChevronUp" onPress={() => setShowAll(false)} />
            )}
          </View>
        )}
      </Card>
      <Card
        theme={theme}
        compact={compact}
        title="Accept the result"
        subtitle="The third outcome of the method: the owner accepts the result on the basis of the map"
      >
        <View style={{ gap: 7 }}>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6 }}>
            <Badge
              theme={theme}
              label={queue.acceptance.obligationsConfirmed ? "all obligations hold" : "not all obligations hold"}
              tone={queue.acceptance.obligationsConfirmed ? "good" : "warn"}
              icon={queue.acceptance.obligationsConfirmed ? "Check" : "CircleHelp"}
            />
            <Badge
              theme={theme}
              label={queue.acceptance.areaResolved ? "declared area resolved" : `${queue.acceptance.uncovered.length} uncovered path(s)`}
              tone={queue.acceptance.areaResolved ? "good" : "warn"}
              icon={queue.acceptance.areaResolved ? "Check" : "FolderSearch"}
            />
            {queue.acceptance.owner && <Badge theme={theme} label={`owner ${queue.acceptance.owner}`} icon="User" />}
          </View>
          <Body theme={theme} muted>
            The tool keeps no record of that acceptance. The owner accepts the result separately, on the basis of the map.
          </Body>
          {queue.acceptance.uncovered.length > 0 && (
            <View style={{ gap: 4 }}>
              {queue.acceptance.uncovered.slice(0, 6).map((path) => (
                <View key={path} style={{ flexDirection: "row", gap: 6, alignItems: "center" }}>
                  <Mono theme={theme} lines={1}>{path}</Mono>
                  <Button theme={theme} compact label="Open" icon="FileText" onPress={() => onOpenFile(path)} />
                </View>
              ))}
            </View>
          )}
        </View>
      </Card>
    </View>
  );
}

function QueueItemCard({ theme, compact, item, onOpenFile, onSelect, onCopyBrief }: {
  theme: ConsoleTheme;
  compact: boolean;
  item: HumanQueueItem;
  onOpenFile: (path: string) => void;
  onSelect: (selection: GraphSelection) => void;
  onCopyBrief: (item: HumanQueueItem) => void;
}) {
  return (
    <View style={{ borderWidth: 1, borderColor: theme.colors.statusWarning, borderRadius: 10, padding: compact ? 12 : 14, gap: 9 }}>
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
        <Badge theme={theme} label="needs you" tone="warn" icon="UserRoundCheck" />
        {item.attention.states.map((state) => <Badge key={state} theme={theme} label={state} color={claimStateColor(theme, state)} icon={claimStateIcon(state)} />)}
        {attentionReasonCodes(item.attention.reasons).map((reason) => <Badge key={reason} theme={theme} label={reason} />)}
      </View>
      <Text style={{ color: theme.colors.foreground, fontSize: 15, fontWeight: "700" }}>{item.title}</Text>
      {item.expectation.length > 0 && <QueueLine theme={theme} label="Expected">{item.expectation}</QueueLine>}
      {item.conditions.length > 0 && (
        <View style={{ gap: 3 }}>
          <Text style={{ color: theme.colors.foregroundMuted, fontSize: 10, fontWeight: "700", textTransform: "uppercase" }}>How it is checked</Text>
          {item.conditions.map((condition) => <ConditionLine key={condition.path} theme={theme} condition={condition} />)}
        </View>
      )}
      {item.attention.reasons.length > 0 && <QueueLine theme={theme} label="Reason">{attentionReasonText(item.attention.reasons)}</QueueLine>}
      {item.attention.humanQuestion.length > 0 && <QueueLine theme={theme} label="Your decision" emphasis>{item.attention.humanQuestion}</QueueLine>}
      {item.attention.why.length > 0 && <QueueLine theme={theme} label="Why this needs you">{item.attention.why}</QueueLine>}
      {item.attention.agentMay.length > 0 && <QueueLine theme={theme} label="Agent may">{item.attention.agentMay}</QueueLine>}
      {item.attention.agentMustNot.length > 0 && <QueueLine theme={theme} label="Agent must not">{item.attention.agentMustNot}</QueueLine>}
      {item.attention.suggestedAction.length > 0 && <QueueLine theme={theme} label="Next safe step">{item.attention.suggestedAction}</QueueLine>}
      <FileButtons theme={theme} paths={item.files} onOpenFile={onOpenFile} />
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 7 }}>
        {item.claimIds[0] && <Button theme={theme} compact label="Inspect" icon="Search" onPress={() => onSelect({ claimId: item.claimIds[0]! })} />}
        <Button theme={theme} compact label="Copy brief for agent" icon="Clipboard" onPress={() => onCopyBrief(item)} />
      </View>
    </View>
  );
}

function ObligationRow({ theme, compact, obligation, onOpenFile, onSelect }: {
  theme: ConsoleTheme;
  compact: boolean;
  obligation: StandingObligation;
  onOpenFile: (path: string) => void;
  onSelect: (selection: GraphSelection) => void;
}) {
  return (
    <View style={{ borderWidth: 1, borderColor: theme.colors.border, borderRadius: 9, padding: compact ? 9 : 11, gap: 6 }}>
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5, alignItems: "center" }}>
        <Badge theme={theme} label={obligation.state} color={claimStateColor(theme, obligation.state)} icon={claimStateIcon(obligation.state)} />
        <Text style={{ color: theme.colors.foreground, fontSize: 13, fontWeight: "700" }}>{obligation.claimId}</Text>
        {obligation.owner && <Badge theme={theme} label={`owner ${obligation.owner}`} icon="User" />}
      </View>
      <Body theme={theme} lines={2}>{obligation.expectation}</Body>
      {obligation.conditions.length > 0 && (
        <View style={{ gap: 2 }}>
          {obligation.conditions.map((condition) => <ConditionLine key={condition.path} theme={theme} condition={condition} />)}
        </View>
      )}
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 7, alignItems: "center" }}>
        <Button theme={theme} compact label="Inspect" icon="Search" onPress={() => onSelect({ claimId: obligation.claimId })} />
        <FileButtons theme={theme} paths={obligation.files} onOpenFile={onOpenFile} />
      </View>
    </View>
  );
}

/**
 * One condition of a claim and the newest evidence of that condition.
 *
 * The outcome is the one the trail recorded; the console does not read a
 * state from it.
 */
function ConditionLine({ theme, condition }: { theme: ConsoleTheme; condition: ConditionEvidence }) {
  const tone = condition.outcome === "pass" ? "good" : condition.outcome === "fail" ? "bad" : "neutral";
  return (
    <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6, alignItems: "center" }}>
      <Badge theme={theme} label={`${condition.path}: ${condition.label}`} />
      <Badge theme={theme} label={condition.outcome} tone={tone} />
      {condition.issuedAt > 0 && <Mono theme={theme}>{formatTime(condition.issuedAt)}</Mono>}
      {condition.issuedAt > 0 && condition.independence && <Mono theme={theme}>{condition.independence}</Mono>}
      {condition.controlReach && <Mono theme={theme}>control: {condition.controlReach}</Mono>}
    </View>
  );
}

function FileButtons({ theme, paths, onOpenFile }: {
  theme: ConsoleTheme;
  paths: string[];
  onOpenFile: (path: string) => void;
}) {
  if (paths.length === 0) return null;
  return (
    <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6, alignItems: "center" }}>
      {paths.slice(0, 4).map((path) => (
        <Button key={path} theme={theme} compact label={path} icon="FileText" onPress={() => onOpenFile(path)} />
      ))}
      {paths.length > 4 && <Mono theme={theme}>{paths.length - 4} more path(s)</Mono>}
    </View>
  );
}

function QueueLine({ theme, label, emphasis = false, children }: {
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
