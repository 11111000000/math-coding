import type { PluginTheme } from "@getpaseo/plugin";
import { useMemo } from "react";
import { Pressable, Text, View } from "react-native";
import type { ReviewItem } from "../shared/contracts";
import { verdictTone } from "../shared/verdict";
import { Badge, Body, Card, Empty, Mono, type Tone } from "./parts";

/**
 * The human review queue.
 *
 * Two kinds of promise land here. One is explicit: the decision names a
 * `manual-` verifier, so no machine can close it. The other is implicit: the
 * kernel says the promise is open, which means the evidence was never
 * produced or it went out of date. A person signs the second kind by
 * declaring it satisfied.
 */
export function ReviewView({
  theme,
  queue,
  onReview,
  onOpenDecision,
}: {
  theme: PluginTheme;
  queue: ReviewItem[];
  onReview: (decisionId: string, obligationId: string) => void;
  onOpenDecision: (decisionId: string) => void;
}) {
  const styles = useMemo(
    () => ({
      stack: { gap: 10 },
      row: {
        borderBottomWidth: 1,
        borderBottomColor: theme.colors.border,
        paddingVertical: 8,
        gap: 4,
      },
      rowHeader: { flexDirection: "row" as const, alignItems: "center" as const, gap: 6 },
      id: { color: theme.colors.foreground, fontSize: 12, fontWeight: "600" as const },
      claim: { color: theme.colors.foregroundMuted, fontSize: 11, lineHeight: 16 },
    }),
    [theme],
  );

  const pending = queue.filter((item) => !item.reviewed);
  const done = queue.filter((item) => item.reviewed);

  return (
    <View style={styles.stack}>
      <Card
        theme={theme}
        title="Waiting for a human"
        subtitle={`${pending.length} of ${queue.length} promises`}
      >
        {pending.length === 0 && <Empty theme={theme}>Nothing is waiting for a signature.</Empty>}
      </Card>

      {pending.length > 0 && (
        <Card theme={theme} compact>
          {pending.slice(0, 150).map((item) => (
            <Pressable
              key={`${item.decision}/${item.obligation}`}
              accessibilityRole="button"
              accessibilityLabel={`Review ${item.decision} ${item.obligation}`}
              onPress={() => onReview(item.decision, item.obligation)}
              style={styles.row}
            >
              <View style={styles.rowHeader}>
                <Badge
                  theme={theme}
                  label={item.verdict}
                  tone={verdictTone(item.verdict) as Tone}
                />
                {item.manual && <Badge theme={theme} label="manual" tone="info" />}
                <Text style={styles.id}>{item.decision}</Text>
              </View>
              <Mono theme={theme}>{item.obligation}</Mono>
              <Body theme={theme} muted numberOfLines={3}>
                {item.claim}
              </Body>
              {item.verifier !== null && <Mono theme={theme}>{item.verifier}</Mono>}
            </Pressable>
          ))}
          {pending.length > 150 && (
            <Mono theme={theme}>…and {pending.length - 150} more</Mono>
          )}
        </Card>
      )}

      {done.length > 0 && (
        <Card theme={theme} title="Already reviewed" compact>
          {done.slice(0, 40).map((item) => (
            <Pressable
              key={`${item.decision}/${item.obligation}`}
              accessibilityRole="button"
              accessibilityLabel={`Open decision ${item.decision}`}
              onPress={() => onOpenDecision(item.decision)}
              style={styles.row}
            >
              <View style={styles.rowHeader}>
                <Badge theme={theme} label="signed" tone="good" />
                <Text style={styles.id}>{item.decision}</Text>
              </View>
              <Mono theme={theme}>{item.obligation}</Mono>
              {item.reviewedBy !== null && (
                <Mono theme={theme}>
                  {item.reviewedBy} · {item.reviewedAt ?? ""}
                </Mono>
              )}
              {item.rationale !== null && item.rationale !== "" && (
                <Body theme={theme} muted numberOfLines={2}>
                  {item.rationale}
                </Body>
              )}
            </Pressable>
          ))}
        </Card>
      )}
    </View>
  );
}
