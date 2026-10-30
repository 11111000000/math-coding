import type { PluginTheme } from "@getpaseo/plugin";
import { Modal } from "@getpaseo/plugin/client/ui";
import { useMemo } from "react";
import { Text, View } from "react-native";
import type { MosaicCell } from "../shared/contracts";
import { Badge, Body, Card, Empty, KeyValue, Mono, Note } from "./parts";
import { CELL_LABEL } from "./mosaic";

/**
 * The chain, drawn once.
 *
 * Vertical, because the chain has a direction: a decision makes a promise,
 * a promise names a check, a check produces evidence, and the evidence is
 * bound to a tree. The gap hangs off the end that is broken.
 *
 * This is the proof; the mosaic is the overview. One promise at a time, with
 * the evidence's kind, its age and its materials digest on it, because
 * "bound to a digest of content that has since changed" is a fact a reader
 * of math-coding needs to see and cannot infer from a colour.
 */
export function ChainSheet({
  theme,
  cell,
  open,
  onOpenChange,
}: {
  theme: PluginTheme;
  cell: MosaicCell | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const styles = useMemo(
    () => ({
      stack: { gap: 10 },
      chain: { gap: 0, paddingLeft: 8, borderLeftWidth: 1, borderLeftColor: theme.colors.border },
      link: { paddingVertical: 6, gap: 2 },
      marker: { color: theme.colors.foregroundMuted, fontSize: 11, letterSpacing: 0.6 },
      title: { color: theme.colors.foreground, fontSize: 13, fontWeight: "600" as const },
      gap: {
        borderLeftWidth: 2,
        borderLeftColor: theme.colors.statusWarning,
        paddingLeft: 8,
        paddingVertical: 6,
        gap: 2,
      },
      gapTitle: { color: theme.colors.statusWarning, fontSize: 12, fontWeight: "700" as const },
      body: { color: theme.colors.foregroundMuted, fontSize: 12, lineHeight: 17 },
    }),
    [theme],
  );

  if (cell === null) {
    return (
      <Modal title="promise" open={open} onOpenChange={onOpenChange}>
        <Modal.Content>
          <Empty theme={theme}>No promise is selected.</Empty>
        </Modal.Content>
      </Modal>
    );
  }

  return (
    <Modal title={cell.obligation} open={open} onOpenChange={onOpenChange}>
      <Modal.Content>
        <View style={styles.stack}>
          <Card theme={theme}>
            <KeyValue theme={theme} label="decision" value={cell.decision} />
            <KeyValue theme={theme} label="obligation" value={cell.obligation} />
            <View style={{ flexDirection: "row", gap: 6, flexWrap: "wrap" }}>
              <Badge theme={theme} label={cell.state} tone="info" />
              <Badge theme={theme} label={`kernel says ${cell.verdict}`} />
              {cell.censusState !== null && (
                <Badge theme={theme} label={`census says ${cell.censusState}`} />
              )}
              {cell.censusClass !== null && (
                <Badge theme={theme} label={cell.censusClass} tone="warn" />
              )}
            </View>
            <Body theme={theme} muted>
              {CELL_LABEL[cell.state]}
            </Body>
          </Card>

          <Card theme={theme} title="The chain">
            <View style={styles.chain}>
              <View style={styles.link}>
                <Text style={styles.marker}>DECISION</Text>
                <Text style={styles.title}>{cell.decision}</Text>
              </View>

              <View style={styles.link}>
                <Text style={styles.marker}>OBLIGATION</Text>
                <Text style={styles.title}>{cell.obligation}</Text>
              </View>

              <View style={styles.link}>
                <Text style={styles.marker}>CHECK</Text>
                <Text style={styles.title}>{cell.verifier ?? "none named"}</Text>
              </View>

              <View style={styles.link}>
                <Text style={styles.marker}>EVIDENCE</Text>
                {cell.attestationId === null ? (
                  <Text style={styles.body}>none</Text>
                ) : (
                  <>
                    <Text style={styles.title}>
                      {cell.attestationKind ?? "unknown kind"} ·{" "}
                      {cell.attestationProducer ?? "unknown producer"}
                    </Text>
                    {cell.issuedAt !== null && (
                      <Mono theme={theme}>issued {cell.issuedAt}</Mono>
                    )}
                    {cell.expiresAt !== null && (
                      <Mono theme={theme}>expires {cell.expiresAt}</Mono>
                    )}
                    {cell.materialsDigest !== null && (
                      <Mono theme={theme}>bound to {cell.materialsDigest.slice(0, 26)}…</Mono>
                    )}
                  </>
                )}
              </View>

              {cell.disagreement ? (
                <View style={styles.gap}>
                  <Text style={styles.gapTitle}>TWO READINGS</Text>
                  <Text style={styles.body}>
                    The obligation index says {cell.verdict}; the promise census says{" "}
                    {cell.censusState}. The console shows both and does not pick a side.
                  </Text>
                </View>
              ) : (
                <View style={styles.gap}>
                  <Text style={styles.gapTitle}>THE GAP</Text>
                  <Text style={styles.body}>
                    {cell.state === "observed"
                      ? "The promise is discharged by a machine run that is current."
                      : cell.state === "declared"
                        ? "The promise is discharged by a person's word. A declaration is not an observation."
                        : cell.state === "uncheckable"
                          ? "The corpus names no check for this promise. It cannot be discharged by running anything."
                          : cell.state === "failed"
                            ? "A decisive failure. The remedy is in the decision's own acceptance."
                            : cell.state === "waived"
                              ? "Accepted by a named, in-force, expiring waiver. A waiver changes the disposition, not the result."
                              : "No current evidence. The evidence that once covered this promise is bound to content that has since changed."}
                  </Text>
                </View>
              )}
            </View>
          </Card>

          <Note theme={theme}>
            An attestation names the tree it was produced against. The digest on the evidence is
            the digest of the CONTENT of the scope; when the scope changes, the evidence no
            longer fits, and the promise reads open again.
          </Note>
        </View>
      </Modal.Content>
    </Modal>
  );
}
