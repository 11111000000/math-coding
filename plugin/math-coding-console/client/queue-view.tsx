import { useState } from "react";
import { Text, View } from "react-native";
import type { AttentionBriefContext } from "./attention";
import { attentionBrief, attentionReasonCodes, attentionReasonText } from "./attention";
import type { ConsoleTheme } from "../shared/theme";
import {
  humanActionKindRef,
  primaryActionForClaim,
  type HumanAction,
} from "../shared/human-actions";
import type { ConditionEvidence, HumanQueue, HumanQueueItem, StandingObligation } from "./human-queue";
import type { GraphSelection } from "./graph";
import { useHost } from "./host/context";
import { useT, type Translate } from "./i18n";
import { Badge, Body, Button, Card, Empty, Mono, Note } from "./parts";
import { claimStateColor, claimStateIcon, claimStateKey, formatTime, independenceKey, outcomeKey, stateReasonKey } from "./vocabulary";

export interface QueueViewProps {
  theme: ConsoleTheme;
  compact: boolean;
  queue: HumanQueue;
  context: AttentionBriefContext;
  onOpenFile: (path: string) => void;
  onSelect: (selection: GraphSelection) => void;
  /**
   * The manual steps the method allows for the current map.
   *
   * The steps come from the canonical map and from the declared
   * specification. The console performs them by asking the program, never on
   * its own.
   */
  actions: HumanAction[];
  /** Whether the host allows the console to record a decision at all. */
  decisionsEnabled: boolean;
  onTakeAction: (action: HumanAction) => void;
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
 * cannot be delegated, the manual steps the method allows, the obligations
 * the owner keeps true, and the result the owner still has to accept. Every
 * line comes from the canonical map, the declared specification and the
 * evidence trail.
 */
export function QueueView({ theme, compact, queue, context, onOpenFile, onSelect, actions, decisionsEnabled, onTakeAction, trailComplete = true, trailExhausted = true }: QueueViewProps) {
  const { copyText, useToast } = useHost();
  const t = useT();
  const toast = useToast();
  const [showAll, setShowAll] = useState(false);
  const visible = showAll ? queue.obligations : queue.obligations.slice(0, 5);
  const copyBrief = async (item: HumanQueueItem) => {
    try {
      await copyText(attentionBrief(item.attention, context));
      toast.show(t("toast.brief_copied"));
    } catch {
      toast.error(t("toast.brief_not_copied"));
    }
  };
  return (
    <View style={{ gap: 10 }}>
      {!trailComplete && (
        <Note theme={theme} tone="warn">
          {trailExhausted
            ? t("queue.trail_partial_detail")
            : t("queue.trail_partial_long")}
        </Note>
      )}
      <Card
        theme={theme}
        compact={compact}
        title={t("queue.title")}
        subtitle={queue.items.length === 0
          ? t("queue.empty_detail")
          : t("queue.count_decisions", { count: queue.items.length })}
      >
        {queue.items.length === 0 ? (
          <View style={{ flexDirection: "row", alignItems: "center", gap: 10 }}>
            <Badge theme={theme} label={t("queue.clear_badge")} tone="good" icon="Check" />
            <View style={{ flex: 1, gap: 2 }}>
              <Body theme={theme}>{t("queue.nothing_now")}</Body>
              <Body theme={theme} muted>{t("queue.remaining_proceed")}</Body>
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
                action={primaryActionForClaim(actions, item.claimIds[0] ?? "")}
                decisionsEnabled={decisionsEnabled}
                onOpenFile={onOpenFile}
                onSelect={onSelect}
                onTakeAction={onTakeAction}
                onCopyBrief={() => void copyBrief(item)}
              />
            ))}
          </View>
        )}
      </Card>
      <ManualStepsCard
        theme={theme}
        compact={compact}
        actions={actions}
        decisionsEnabled={decisionsEnabled}
        onTakeAction={onTakeAction}
      />
      <Card
        theme={theme}
        compact={compact}
        title={t("queue.obligations_title")}
        subtitle={t("queue.count_obligations", { count: queue.obligations.length })}
      >
        {queue.obligations.length === 0 ? (
          <Empty theme={theme} title={t("queue.obligations_empty_title")} detail={t("queue.obligations_empty_detail")} icon="ListX" />
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
              <Button theme={theme} compact label={t("queue.show_all", { count: queue.obligations.length })} icon="List" onPress={() => setShowAll(true)} />
            )}
            {showAll && queue.obligations.length > 5 && (
              <Button theme={theme} compact label={t("queue.show_fewer")} icon="ChevronUp" onPress={() => setShowAll(false)} />
            )}
          </View>
        )}
      </Card>
      <Card
        theme={theme}
        compact={compact}
        title={t("queue.accept_title")}
        subtitle={t("queue.accept_detail_long")}
      >
        <View style={{ gap: 7 }}>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6 }}>
            <Badge
              theme={theme}
              label={queue.acceptance.obligationsConfirmed ? t("queue.obligations_hold") : t("queue.obligations_not_hold")}
              tone={queue.acceptance.obligationsConfirmed ? "good" : "warn"}
              icon={queue.acceptance.obligationsConfirmed ? "Check" : "CircleHelp"}
            />
            <Badge
              theme={theme}
              label={queue.acceptance.areaResolved ? t("queue.area_resolved") : t("queue.count_uncovered", { count: queue.acceptance.uncovered.length })}
              tone={queue.acceptance.areaResolved ? "good" : "warn"}
              icon={queue.acceptance.areaResolved ? "Check" : "FolderSearch"}
            />
            {queue.acceptance.owner && <Badge theme={theme} label={t("queue.owner_label", { owner: queue.acceptance.owner })} icon="User" />}
          </View>
          <Body theme={theme} muted>{t("queue.accept_body_note")}</Body>
          {queue.acceptance.uncovered.length > 0 && (
            <View style={{ gap: 4 }}>
              {queue.acceptance.uncovered.slice(0, 6).map((path) => (
                <View key={path} style={{ flexDirection: "row", gap: 6, alignItems: "center" }}>
                  <Mono theme={theme} lines={1}>{path}</Mono>
                  <Button theme={theme} compact label={t("queue.open_file")} icon="FileText" onPress={() => onOpenFile(path)} />
                </View>
              ))}
            </View>
          )}
        </View>
      </Card>
    </View>
  );
}

function QueueItemCard({ theme, compact, item, action, decisionsEnabled, onOpenFile, onSelect, onTakeAction, onCopyBrief }: {
  theme: ConsoleTheme;
  compact: boolean;
  item: HumanQueueItem;
  action: HumanAction | undefined;
  decisionsEnabled: boolean;
  onOpenFile: (path: string) => void;
  onSelect: (selection: GraphSelection) => void;
  onTakeAction: (action: HumanAction) => void;
  onCopyBrief: (item: HumanQueueItem) => void;
}) {
  const t = useT();
  return (
    <View style={{ borderWidth: 1, borderColor: theme.colors.statusWarning, borderRadius: 10, padding: compact ? 12 : 14, gap: 9 }}>
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
        <Badge theme={theme} label={t("queue.needs_you")} tone="warn" icon="UserRoundCheck" />
        {item.attention.states.map((state) => <Badge key={state} theme={theme} label={t(claimStateKey(state))} color={claimStateColor(theme, state)} icon={claimStateIcon(state)} />)}
        {attentionReasonCodes(item.attention.reasons).map((reason) => <Badge key={reason} theme={theme} label={t(stateReasonKey(reason))} />)}
      </View>
      <Text style={{ color: theme.colors.foreground, fontSize: 15, fontWeight: "700" }}>{t(item.title)}</Text>
      {item.expectation.length > 0 && <QueueLine theme={theme} label={t("queue.expected")}>{item.expectation}</QueueLine>}
      {item.conditions.length > 0 && (
        <View style={{ gap: 3 }}>
          <Text style={{ color: theme.colors.foregroundMuted, fontSize: 10, fontWeight: "700", textTransform: "uppercase" }}>{t("queue.how_checked")}</Text>
          {item.conditions.map((condition) => <ConditionLine key={condition.path} theme={theme} condition={condition} />)}
        </View>
      )}
      <QueueLine theme={theme} label={t("queue.reason")}>{attentionReasonText(item.attention.reasons, t)}</QueueLine>
      <QueueLine theme={theme} label={t("queue.your_decision")} emphasis>{t(item.attention.humanQuestion)}</QueueLine>
      <QueueLine theme={theme} label={t("queue.why_needs_you")}>{t(item.attention.why)}</QueueLine>
      <QueueLine theme={theme} label={t("queue.agent_may")}>{t(item.attention.agentMay)}</QueueLine>
      <QueueLine theme={theme} label={t("queue.agent_must_not")}>{t(item.attention.agentMustNot)}</QueueLine>
      <QueueLine theme={theme} label={t("queue.next_safe_step")}>{t(item.attention.suggestedAction)}</QueueLine>
      {action ? (
        <View style={{ gap: 4 }}>
          <Button
            theme={theme}
            compact
            label={t("queue.take_step", { step: t(humanActionKindRef(action.kind)) })}
            icon="Stamp"
            onPress={() => onTakeAction(action)}
            disabled={!decisionsEnabled}
          />
          {!decisionsEnabled && (
            <Body theme={theme} muted>{t("permissions.decisions_closed")}</Body>
          )}
        </View>
      ) : (
        <Note theme={theme} tone="neutral">{manualNote(item, t)}</Note>
      )}
      <FileButtons theme={theme} paths={item.files} onOpenFile={onOpenFile} />
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 7 }}>
        {item.claimIds[0] && <Button theme={theme} compact label={t("common.inspect")} icon="Search" onPress={() => onSelect({ claimId: item.claimIds[0]! })} />}
        <Button theme={theme} compact label={t("queue.copy_brief")} icon="Clipboard" onPress={() => onCopyBrief(item)} />
      </View>
    </View>
  );
}

/**
 * The decision the method has no verb for.
 *
 * Some decisions belong to the owner and are not recorded by the program: the
 * direction of a refuted claim and the acceptance criterion of a claim
 * without a checkable condition. The console names them instead of leaving
 * the human without an answer.
 */
function manualNote(item: HumanQueueItem, t: Translate): string {
  if (item.kind === "refutation") {
    return t("queue.no_verb_refuted");
  }
  if (item.kind === "acceptance-criterion") {
    return t("queue.no_verb_criterion");
  }
  return t("queue.no_step_detail");
}

/**
 * Every manual step the method allows for the current map.
 *
 * The list is complete: it holds the steps of every claim and the step of the
 * project itself. Each of them is performed by the program, with the
 * confirmation of the human.
 */
function ManualStepsCard({ theme, compact, actions, decisionsEnabled, onTakeAction }: {
  theme: ConsoleTheme;
  compact: boolean;
  actions: HumanAction[];
  decisionsEnabled: boolean;
  onTakeAction: (action: HumanAction) => void;
}) {
  const t = useT();
  return (
    <Card
      theme={theme}
      compact={compact}
      title={t("queue.manual_title")}
      subtitle={actions.length === 0
        ? t("queue.no_step_title")
        : t("queue.count_steps", { count: actions.length })}
    >
      {actions.length === 0 ? (
        <Body theme={theme} muted>{t("queue.manual_empty_body")}</Body>
      ) : (
        <View style={{ gap: 8 }}>
          {!decisionsEnabled && (
            <Note theme={theme} tone="warn">
              {t("permissions.switch_off", { switch: t("settings.allow_decisions") })}
            </Note>
          )}
          {actions.map((action) => (
            <View key={action.id} style={{ borderWidth: 1, borderColor: theme.colors.border, borderRadius: 9, padding: compact ? 9 : 11, gap: 6 }}>
              <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5, alignItems: "center" }}>
                <Badge theme={theme} label={t(humanActionKindRef(action.kind))} icon="Stamp" />
                {action.claimId && <Badge theme={theme} label={action.claimId} icon="Target" />}
                {action.authority && <Badge theme={theme} label={t("queue.review_authority", { authority: action.authority })} />}
              </View>
              <Text style={{ color: theme.colors.foreground, fontSize: 13, fontWeight: "700" }}>{t(action.title)}</Text>
              <Body theme={theme} muted lines={4}>{t(action.detail)}</Body>
              <Button
                theme={theme}
                compact
                label={t("queue.take_step_label")}
                icon="Stamp"
                onPress={() => onTakeAction(action)}
                disabled={!decisionsEnabled}
              />
            </View>
          ))}
        </View>
      )}
    </Card>
  );
}

function ObligationRow({ theme, compact, obligation, onOpenFile, onSelect }: {
  theme: ConsoleTheme;
  compact: boolean;
  obligation: StandingObligation;
  onOpenFile: (path: string) => void;
  onSelect: (selection: GraphSelection) => void;
}) {
  const t = useT();
  return (
    <View style={{ borderWidth: 1, borderColor: theme.colors.border, borderRadius: 9, padding: compact ? 9 : 11, gap: 6 }}>
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5, alignItems: "center" }}>
        <Badge theme={theme} label={t(claimStateKey(obligation.state))} color={claimStateColor(theme, obligation.state)} icon={claimStateIcon(obligation.state)} />
        <Text style={{ color: theme.colors.foreground, fontSize: 13, fontWeight: "700" }}>{obligation.claimId}</Text>
        {obligation.owner && <Badge theme={theme} label={t("queue.owner_label", { owner: obligation.owner })} icon="User" />}
      </View>
      <Body theme={theme} lines={2}>{obligation.expectation}</Body>
      {obligation.conditions.length > 0 && (
        <View style={{ gap: 2 }}>
          {obligation.conditions.map((condition) => <ConditionLine key={condition.path} theme={theme} condition={condition} />)}
        </View>
      )}
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 7, alignItems: "center" }}>
        <Button theme={theme} compact label={t("common.inspect")} icon="Search" onPress={() => onSelect({ claimId: obligation.claimId })} />
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
  const t = useT();
  const tone = condition.outcome === "pass" ? "good" : condition.outcome === "fail" ? "bad" : "neutral";
  return (
    <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6, alignItems: "center" }}>
      <Badge theme={theme} label={`${condition.path}: ${t(condition.label)}`} />
      <Badge theme={theme} label={t(outcomeKey(condition.outcome))} tone={tone} />
      {condition.issuedAt > 0 && <Mono theme={theme}>{formatTime(condition.issuedAt)}</Mono>}
      {condition.issuedAt > 0 && condition.independence && <Mono theme={theme}>{t(independenceKey(condition.independence))}</Mono>}
      {condition.controlReach && <Mono theme={theme}>{t("queue.control_reach", { value: condition.controlReach })}</Mono>}
    </View>
  );
}

function FileButtons({ theme, paths, onOpenFile }: {
  theme: ConsoleTheme;
  paths: string[];
  onOpenFile: (path: string) => void;
}) {
  const t = useT();
  if (paths.length === 0) return null;
  return (
    <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6, alignItems: "center" }}>
      {paths.slice(0, 4).map((path) => (
        <Button key={path} theme={theme} compact label={path} icon="FileText" onPress={() => onOpenFile(path)} />
      ))}
      {paths.length > 4 && <Mono theme={theme}>{t("queue.more_paths", { count: paths.length - 4 })}</Mono>}
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
