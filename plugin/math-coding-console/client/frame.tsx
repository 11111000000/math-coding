import type { PluginTheme } from "@getpaseo/plugin";
import { useMemo } from "react";
import { Text, View } from "react-native";
import type { MathCodingState, Mosaic } from "../shared/contracts";
import { Badge, Mono, Note } from "./parts";

/**
 * The instrument's reading, always on screen.
 *
 * Two things live here, and they are NOT the same question:
 *
 *   - the CORPUS reading: what `mathc self-check` says about the corpus as
 *     a whole;
 *   - the JOIN: how much of the attestation store discharges a promise that
 *     is still live.
 *
 * The join is the one that was missing. The store's size and the corpus's
 * size sit in two panels and the reader adds them, and the sum reads like a
 * healthy corpus with a large store. The truth is the join, and the join is
 * a single number.
 */
export function InstrumentFrame({
  theme,
  state,
  mosaic,
}: {
  theme: PluginTheme;
  state: MathCodingState | undefined;
  mosaic: Mosaic | undefined;
}) {
  const styles = useMemo(
    () => ({
      frame: {
        backgroundColor: theme.colors.surface1,
        borderColor: theme.colors.border,
        borderWidth: 1,
        borderRadius: 10,
        padding: 12,
        gap: 6,
      },
      row: { flexDirection: "row" as const, alignItems: "center" as const, gap: 8, flexWrap: "wrap" as const },
      verdict: {
        color: theme.colors.foreground,
        fontSize: 20,
        fontWeight: "700" as const,
      },
      label: { color: theme.colors.foregroundMuted, fontSize: 11, letterSpacing: 0.6 },
      counts: { color: theme.colors.foregroundMuted, fontSize: 11 },
      join: { color: theme.colors.foreground, fontSize: 12, fontWeight: "600" as const },
    }),
    [theme],
  );

  const verdict = state?.verdict;
  const corpus = mosaic?.store;

  return (
    <View style={styles.frame}>
      <View style={styles.row}>
        <Text style={styles.label}>CORPUS</Text>
        <Text style={styles.verdict}>{verdict?.verdict ?? "—"}</Text>
        {verdict !== undefined && verdict !== null && (
          <Mono theme={theme}>
            exit {verdict.exitCode} · {verdict.subjects.pass} pass · {verdict.subjects.fail} fail ·{" "}
            {verdict.subjects.unknown} unknown
          </Mono>
        )}
      </View>

      {corpus !== undefined && (
        <View style={styles.row}>
          <Text style={styles.label}>THE JOIN</Text>
          <Text style={styles.join}>
            {corpus.discharging} of {corpus.total} attestations discharge a live promise
          </Text>
          {corpus.namingLivePromise > corpus.discharging && (
            <Badge
              theme={theme}
              label={`${corpus.namingLivePromise - corpus.discharging} reach none`}
              tone="warn"
            />
          )}
        </View>
      )}

      {state !== undefined && (
        <Mono theme={theme}>
          {state.coverage.decisions} decisions · {state.coverage.obligations} obligations ·{" "}
          {state.coverage.openPromises} open · {state.coverage.attestations} attestations
        </Mono>
      )}

      {mosaic !== undefined && mosaic.readings.disagreeing > 0 && (
        <Note theme={theme} tone="info">
          {mosaic.readings.disagreeing} promise(s) are read differently by `mathc packages` and
          `mathc gaps`. The console shows both.
        </Note>
      )}
    </View>
  );
}
