import type { PluginTheme } from "@getpaseo/plugin";
import { useMemo, useState } from "react";
import { Pressable, Text, View } from "react-native";
import type { DecisionSummary } from "../shared/contracts";
import { verdictTone } from "../shared/verdict";
import { Badge, Body, Card, Empty, Mono, Segmented, type Tone } from "./parts";

/**
 * The decision catalogue.
 *
 * The list is the corpus; the badges on each row are the kernel's verdicts
 * for that decision's obligations. A decision whose obligations are all green
 * says so, and one that is not says what is wrong with it.
 */
export function DecisionsView({
  theme,
  decisions,
  onOpenDecision,
}: {
  theme: PluginTheme;
  decisions: DecisionSummary[];
  onOpenDecision: (decisionId: string) => void;
}) {
  const [filter, setFilter] = useState("open");
  const [query, setQuery] = useState("");

  const styles = useMemo(
    () => ({
      stack: { gap: 10 },
      row: {
        borderBottomWidth: 1,
        borderBottomColor: theme.colors.border,
        paddingVertical: 8,
        gap: 3,
      },
      rowHeader: { flexDirection: "row" as const, alignItems: "center" as const, gap: 6 },
      id: { color: theme.colors.foreground, fontSize: 12, fontWeight: "600" as const, flex: 1 },
      intent: { color: theme.colors.foregroundMuted, fontSize: 11, lineHeight: 16 },
      badges: { flexDirection: "row" as const, flexWrap: "wrap" as const, gap: 4 },
    }),
    [theme],
  );

  const counts = useMemo(() => {
    let open = 0;
    for (const decision of decisions) {
      if (decision.topVerdict !== "pass") open += 1;
    }
    return { open, all: decisions.length };
  }, [decisions]);

  const filtered = useMemo(() => {
    const needle = query.trim().toLowerCase();
    return decisions.filter((decision) => {
      if (filter === "open" && decision.topVerdict === "pass") return false;
      if (filter === "manual" && decision.manualCount === 0) return false;
      if (needle !== "" && !`${decision.id} ${decision.intent}`.toLowerCase().includes(needle)) {
        return false;
      }
      return true;
    });
  }, [decisions, filter, query]);

  return (
    <View style={styles.stack}>
      <Card theme={theme} title="Decisions" subtitle={`${filtered.length} of ${counts.all}`}>
        <Segmented
          theme={theme}
          value={filter}
          onChange={setFilter}
          options={[
            { value: "open", label: `not green (${counts.open})` },
            { value: "manual", label: "needs a human" },
            { value: "all", label: `all (${counts.all})` },
          ]}
        />
      </Card>

      {filtered.length === 0 ? (
        <Card theme={theme}>
          <Empty theme={theme}>No decision matches this filter.</Empty>
        </Card>
      ) : (
        <Card theme={theme} compact>
          {filtered.slice(0, 200).map((decision) => (
            <Pressable
              key={decision.id}
              accessibilityRole="button"
              accessibilityLabel={`Open decision ${decision.id}`}
              onPress={() => onOpenDecision(decision.id)}
              style={styles.row}
            >
              <View style={styles.rowHeader}>
                <Badge
                  theme={theme}
                  label={decision.topVerdict}
                  tone={verdictTone(decision.topVerdict) as Tone}
                />
                <Text style={styles.id}>{decision.id}</Text>
              </View>
              <Body theme={theme} muted numberOfLines={2}>
                {decision.intent}
              </Body>
              <View style={styles.badges}>
                <Mono theme={theme}>
                  {decision.obligationCount} obligations · {decision.state}
                </Mono>
                {decision.manualCount > 0 && (
                  <Badge theme={theme} label={`${decision.manualCount} manual`} tone="info" />
                )}
                {decision.axiomLinks.map((axiom) => (
                  <Badge key={axiom} theme={theme} label={axiom} />
                ))}
              </View>
            </Pressable>
          ))}
          {filtered.length > 200 && (
            <Mono theme={theme}>…and {filtered.length - 200} more</Mono>
          )}
        </Card>
      )}
    </View>
  );
}
