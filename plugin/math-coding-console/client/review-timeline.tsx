import type { PluginTimelineItemProps } from "@getpaseo/plugin/client";
import { useMemo } from "react";
import { Text, View } from "react-native";
import type { ReviewTimelineData } from "../shared/contracts";

/**
 * A signed review, shown in the session it was signed from.
 *
 * The row says what was signed, by whom, and why. The rationale matters as
 * much as the verdict: a verdict without a reason is not reviewable.
 */
export function ReviewTimelineRow({
  theme,
  item,
}: PluginTimelineItemProps<ReviewTimelineData>) {
  const data = item.data;
  const styles = useMemo(
    () => ({
      row: {
        borderLeftWidth: 3,
        borderLeftColor:
          data.verdict === "pass" ? theme.colors.statusSuccess : theme.colors.statusDanger,
        paddingLeft: 10,
        paddingVertical: 4,
        gap: 2,
      },
      header: { flexDirection: "row" as const, alignItems: "center" as const, gap: 6 },
      verdict: {
        color:
          data.verdict === "pass" ? theme.colors.statusSuccess : theme.colors.statusDanger,
        fontSize: 12,
        fontWeight: "700" as const,
      },
      subject: { color: theme.colors.foreground, fontSize: 12, fontWeight: "600" as const },
      meta: { color: theme.colors.foregroundMuted, fontSize: 11 },
      rationale: { color: theme.colors.foreground, fontSize: 12, lineHeight: 17 },
    }),
    [theme, data.verdict],
  );

  return (
    <View style={styles.row}>
      <View style={styles.header}>
        <Text style={styles.verdict}>review {data.verdict}</Text>
        <Text style={styles.subject}>
          {data.decisionId} / {data.obligationId}
        </Text>
      </View>
      <Text style={styles.meta}>
        {data.producer} · {data.at}
      </Text>
      {data.rationale !== "" && <Text style={styles.rationale}>{data.rationale}</Text>}
    </View>
  );
}
