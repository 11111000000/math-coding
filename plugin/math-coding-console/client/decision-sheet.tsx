import type { PluginTheme } from "@getpaseo/plugin";
import { useRpc } from "@getpaseo/plugin/client";
import { Modal } from "@getpaseo/plugin/client/ui";
import { useQuery } from "@tanstack/react-query";
import { useMemo } from "react";
import { Text, View } from "react-native";
import { decisionRpc } from "../shared/contracts";
import { verdictTone } from "../shared/verdict";
import { Badge, Body, Button, Card, Empty, KeyValue, Label, Mono, Note, type Tone } from "./parts";

/**
 * One decision, in full.
 *
 * The intent and the commitment come first, because they are what the
 * obligations are about. The kernel's verdict on each obligation comes next,
 * with its remedies. The dialectical parts — the counterexample and the
 * antithesis — are last, because they are the arguments against the
 * decision, and the reader wants the decision first.
 */
export function DecisionSheet({
  theme,
  root,
  decisionId,
  open,
  onOpenChange,
  onReview,
}: {
  theme: PluginTheme;
  root: string | null;
  decisionId: string | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onReview: (decisionId: string, obligationId: string) => void;
}) {
  const fetchDecisionRpc = useRpc(decisionRpc);
  const fetchDecision = useQuery({
    queryKey: ["mc-decision", root, decisionId],
    queryFn: () => fetchDecisionRpc({ root: root ?? undefined, decisionId: decisionId ?? "" }),
    enabled: open && decisionId !== null,
  });

  const decision = fetchDecision.data;
  const styles = useMemo(
    () => ({
      stack: { gap: 10 },
      prose: { gap: 6 },
      obligation: {
        borderTopWidth: 1,
        borderTopColor: theme.colors.border,
        paddingTop: 8,
        gap: 4,
      },
      row: { flexDirection: "row" as const, alignItems: "center" as const, gap: 6, flexWrap: "wrap" as const },
      relation: { color: theme.colors.foregroundMuted, fontSize: 11 },
    }),
    [theme],
  );

  return (
    <Modal
      title={decisionId ?? "decision"}
      open={open}
      onOpenChange={onOpenChange}
    >
      <Modal.Content>
        {fetchDecision.isPending && <Empty theme={theme}>Reading the decision…</Empty>}
        {fetchDecision.isError && (
          <Note theme={theme} tone="bad">
            {String(fetchDecision.error)}
          </Note>
        )}
        {decision !== undefined && decision.error !== null && (
          <Note theme={theme} tone="warn">
            {decision.error}
          </Note>
        )}
        {decision !== undefined && decision.error === null && (
          <View style={styles.stack}>
            <Card theme={theme}>
              <KeyValue theme={theme} label="id" value={decision.id} />
              <KeyValue theme={theme} label="state" value={decision.state} />
              <KeyValue theme={theme} label="revision" value={decision.revision ?? "—"} />
              <KeyValue theme={theme} label="file" value={decision.file} />
              {decision.axiomLinks.length > 0 && (
                <KeyValue theme={theme} label="axioms" value={decision.axiomLinks.join(", ")} />
              )}
              {decision.scopePaths.length > 0 && (
                <>
                  <Label theme={theme}>scope</Label>
                  <Mono theme={theme}>{decision.scopePaths.join("  ·  ")}</Mono>
                </>
              )}
            </Card>

            <Card theme={theme} title="Intent">
              <Body theme={theme}>{decision.intent}</Body>
            </Card>

            <Card theme={theme} title="Commitment">
              <Body theme={theme}>{decision.commitment}</Body>
            </Card>

            {decision.outcomes.length > 0 && (
              <Card theme={theme} title="Outcomes">
                {decision.outcomes.map((outcome) => (
                  <View key={outcome.id} style={styles.prose}>
                    <Mono theme={theme}>{outcome.id}</Mono>
                    <Body theme={theme}>{outcome.statement}</Body>
                  </View>
                ))}
              </Card>
            )}

            <Card
              theme={theme}
              title="Obligations"
              subtitle={`${decision.obligations.length} promises, with the kernel's verdict on each`}
            >
              {decision.obligations.length === 0 && <Empty theme={theme}>No obligation.</Empty>}
              {decision.obligations.map((obligation) => (
                <View key={obligation.id} style={styles.obligation}>
                  <View style={styles.row}>
                    <Badge
                      theme={theme}
                      label={obligation.verdict}
                      tone={verdictTone(obligation.verdict) as Tone}
                    />
                    <Mono theme={theme}>{obligation.id}</Mono>
                    {obligation.manual && <Badge theme={theme} label="manual" tone="info" />}
                  </View>
                  <Body theme={theme}>{obligation.claim}</Body>
                  {obligation.verifiers.length > 0 && (
                    <Mono theme={theme}>{obligation.verifiers.join("  ·  ")}</Mono>
                  )}
                  {obligation.remedies.map((remedy) => (
                    <Note key={remedy} theme={theme} tone="warn">
                      {remedy}
                    </Note>
                  ))}
                  <Button
                    theme={theme}
                    label="Review this obligation"
                    onPress={() => onReview(decision.id, obligation.id)}
                  />
                </View>
              ))}
            </Card>

            {decision.assumptions.length > 0 && (
              <Card theme={theme} title="Assumptions">
                {decision.assumptions.map((assumption) => (
                  <View key={assumption.id} style={styles.prose}>
                    <View style={styles.row}>
                      <Badge
                        theme={theme}
                        label={assumption.state}
                        tone={assumption.state === "assumed" ? "warn" : "bad"}
                      />
                      <Mono theme={theme}>{assumption.id}</Mono>
                    </View>
                    <Body theme={theme}>{assumption.statement}</Body>
                    {assumption.owner !== null && (
                      <Mono theme={theme}>owner: {assumption.owner}</Mono>
                    )}
                    {assumption.consequenceIfFalse !== null && (
                      <Note theme={theme} tone="warn">
                        If false: {assumption.consequenceIfFalse}
                      </Note>
                    )}
                  </View>
                ))}
              </Card>
            )}

            {decision.riskTriggers.length > 0 && (
              <Card theme={theme} title="Declared risk triggers">
                {decision.riskTriggers.map((trigger) => (
                  <Body key={trigger} theme={theme} muted>
                    · {trigger}
                  </Body>
                ))}
              </Card>
            )}

            {Object.keys(decision.relations).length > 0 && (
              <Card theme={theme} title="Relations">
                {Object.entries(decision.relations).map(([kind, targets]) => (
                  <Text key={kind} style={styles.relation}>
                    {kind}: {targets.join(", ")}
                  </Text>
                ))}
              </Card>
            )}

            {decision.attestations.length > 0 && (
              <Card theme={theme} title="Attestations on this decision">
                {decision.attestations.map((attestation) => (
                  <View key={attestation.id} style={styles.prose}>
                    <View style={styles.row}>
                      <Badge theme={theme} label={attestation.kind} />
                      <Mono theme={theme}>{attestation.obligation}</Mono>
                      <Badge
                        theme={theme}
                        label={attestation.result}
                        tone={attestation.result === "pass" ? "good" : "bad"}
                      />
                    </View>
                    <Mono theme={theme}>
                      {attestation.producer} · {attestation.issuedAt}
                    </Mono>
                  </View>
                ))}
              </Card>
            )}

            {decision.diagnostics.length > 0 && (
              <Card theme={theme} title="Kernel diagnostics">
                {decision.diagnostics.map((diagnostic) => (
                  <Note
                    key={diagnostic.code}
                    theme={theme}
                    tone={diagnostic.severity === "error" ? "bad" : "warn"}
                  >
                    {diagnostic.code}: {diagnostic.message}
                  </Note>
                ))}
              </Card>
            )}

            {!decision.proseReadable && (
              <Card theme={theme} title="Prose unavailable">
                <Note theme={theme} tone="warn">
                  The console could not read this file's prose. Its obligations and verdicts
                  are the kernel's, and they are shown above; what the decision SAYS is not.
                  The kernel's parser reads more than this console's does — and no less —
                  so anything the kernel could not read is outside the gate as well.
                </Note>
              </Card>
            )}

            {decision.counterexample !== null && (
              <Card theme={theme} title="Counterexample">
                <Body theme={theme}>{decision.counterexample}</Body>
              </Card>
            )}

            {decision.antithesis !== null && (
              <Card theme={theme} title="Antithesis">
                <Body theme={theme}>{decision.antithesis}</Body>
              </Card>
            )}
          </View>
        )}
      </Modal.Content>
    </Modal>
  );
}
