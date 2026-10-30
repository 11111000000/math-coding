import type { PluginTheme } from "@getpaseo/plugin";
import { useMemo } from "react";
import { View } from "react-native";
import type { MathCodingState } from "../shared/contracts";
import { verdictTone } from "../shared/verdict";
import { Badge, Body, Card, Empty, KeyValue, Mono, Note, type Tone } from "./parts";

/**
 * The attestation store.
 *
 * The store is the evidence the kernel reads. What matters here is not the
 * count but the SHAPE: which kinds of evidence exist, who produced them, and
 * whether any of it has expired. A store full of `review` attestations is a
 * store of declarations, not of observations, and the console says so.
 */
export function EvidenceView({ theme, state }: { theme: PluginTheme; state: MathCodingState }) {
  const styles = useMemo(
    () => ({
      stack: { gap: 10 },
      badges: { flexDirection: "row" as const, flexWrap: "wrap" as const, gap: 4 },
      entry: {
        borderTopWidth: 1,
        borderTopColor: theme.colors.border,
        paddingTop: 6,
        gap: 2,
      },
    }),
    [theme],
  );

  const store = state.attestations;
  const declarationShare =
    store.total > 0 ? Math.round(((store.byKind.review ?? 0) / store.total) * 100) : 0;

  return (
    <View style={styles.stack}>
      <Card theme={theme} title="The store" subtitle={`${store.total} attestations`}>
        <KeyValue theme={theme} label="by kind" value={formatCounts(store.byKind)} />
        <KeyValue theme={theme} label="by result" value={formatCounts(store.byResult)} />
        <KeyValue theme={theme} label="by producer" value={formatCounts(store.byProducerClass)} />
        <KeyValue
          theme={theme}
          label="expired"
          value={String(store.expired)}
          tone={store.expired > 0 ? "warn" : "good"}
        />
        {declarationShare > 0 && (
          <Note theme={theme} tone="info">
            {declarationShare}% of the store is `review` class: a person's declaration, not a
            machine observation. The verdict that follows from a review says every obligation
            has a signature, not that every signature came from a run.
          </Note>
        )}
      </Card>

      <Card theme={theme} title="Latest" compact>
        {store.latest.length === 0 && <Empty theme={theme}>The store is empty.</Empty>}
        {store.latest.map((attestation) => (
          <View key={attestation.id} style={styles.entry}>
            <View style={styles.badges}>
              <Badge
                theme={theme}
                label={attestation.result}
                tone={verdictTone(attestation.result) as Tone}
              />
              <Badge theme={theme} label={attestation.kind} />
              {attestation.stale && <Badge theme={theme} label="expired" tone="warn" />}
            </View>
            <Body theme={theme}>
              {attestation.decision} / {attestation.obligation}
            </Body>
            <Mono theme={theme}>
              {attestation.producer} · {attestation.issuedAt}
            </Mono>
            {attestation.run !== null && <Mono theme={theme}>run: {attestation.run}</Mono>}
          </View>
        ))}
      </Card>
    </View>
  );
}

function formatCounts(counts: Record<string, number>): string {
  const entries = Object.entries(counts).sort((a, b) => b[1] - a[1]);
  if (entries.length === 0) return "—";
  return entries.map(([key, value]) => `${key} ${value}`).join("  ·  ");
}
