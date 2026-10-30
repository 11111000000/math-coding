import type { PluginTheme } from "@getpaseo/plugin";
import { useMemo, useState } from "react";
import { Pressable, Text, View } from "react-native";
import type { Promise_ } from "../shared/contracts";
import { verdictTone } from "../shared/verdict";
import { Badge, Body, Card, Empty, Mono, Note, Segmented, type Tone } from "./parts";

/**
 * The promise worklist.
 *
 * Every row is one open promise, as the kernel reports it: what it promised,
 * why it is open, and what the kernel says would close it. The console adds
 * nothing to that story except a filter and a way to jump to the decision.
 */
export function PromisesView({
  theme,
  promises,
  onOpenDecision,
}: {
  theme: PluginTheme;
  promises: Promise_[];
  onOpenDecision: (decisionId: string) => void;
}) {
  const [stateFilter, setStateFilter] = useState("all");
  const [classFilter, setClassFilter] = useState("all");

  const states = useMemo(() => {
    const seen = new Set<string>();
    for (const promise of promises) seen.add(promise.state);
    return ["all", ...Array.from(seen).sort()];
  }, [promises]);

  const classes = useMemo(() => {
    const seen = new Set<string>();
    for (const promise of promises) seen.add(promise.class);
    return ["all", ...Array.from(seen).sort()];
  }, [promises]);

  const filtered = useMemo(
    () =>
      promises.filter((promise) => {
        if (stateFilter !== "all" && promise.state !== stateFilter) return false;
        if (classFilter !== "all" && promise.class !== classFilter) return false;
        return true;
      }),
    [promises, stateFilter, classFilter],
  );

  const styles = useMemo(
    () => ({
      stack: { gap: 10 },
      filters: { gap: 6 },
      row: {
        borderBottomWidth: 1,
        borderBottomColor: theme.colors.border,
        paddingVertical: 8,
        gap: 4,
      },
      rowHeader: { flexDirection: "row" as const, alignItems: "center" as const, gap: 6 },
      title: { color: theme.colors.foreground, fontSize: 12, fontWeight: "600" as const, flex: 1 },
      cause: { color: theme.colors.foregroundMuted, fontSize: 11, lineHeight: 16 },
      action: { color: theme.colors.foreground, fontSize: 11, lineHeight: 16 },
    }),
    [theme],
  );

  return (
    <View style={styles.stack}>
      <Card theme={theme} title="Open promises" subtitle={`${filtered.length} of ${promises.length}`}>
        <View style={styles.filters}>
          <Segmented
            theme={theme}
            value={stateFilter}
            onChange={setStateFilter}
            options={states.map((state) => ({ value: state, label: state }))}
          />
          {classes.length > 1 && (
            <Segmented
              theme={theme}
              value={classFilter}
              onChange={setClassFilter}
              options={classes.map((item) => ({ value: item, label: item }))}
            />
          )}
        </View>
      </Card>

      {filtered.length === 0 ? (
        <Card theme={theme}>
          <Empty theme={theme}>
            {promises.length === 0 ? "The kernel reports no open promise." : "No promise matches the filter."}
          </Empty>
        </Card>
      ) : (
        <Card theme={theme} compact>
          {filtered.slice(0, 200).map((promise) => (
            <View key={`${promise.decision}/${promise.obligation}`} style={styles.row}>
              <View style={styles.rowHeader}>
                <Badge
                  theme={theme}
                  label={promise.state}
                  tone={verdictTone(promise.state) as Tone}
                />
                <Pressable
                  accessibilityRole="button"
                  accessibilityLabel={`Open decision ${promise.decision}`}
                  onPress={() => onOpenDecision(promise.decision)}
                >
                  <Text style={styles.title}>{promise.decision}</Text>
                </Pressable>
              </View>
              <Mono theme={theme}>{promise.obligation}</Mono>
              <Text style={styles.cause}>{promise.cause}</Text>
              <Text style={styles.action}>→ {promise.action}</Text>
              {promise.verifiers.length > 0 && (
                <Mono theme={theme}>{promise.verifiers.join(" · ")}</Mono>
              )}
            </View>
          ))}
          {filtered.length > 200 && (
            <Note theme={theme}>Showing the first 200 of {filtered.length}.</Note>
          )}
        </Card>
      )}
    </View>
  );
}
