import type { PluginTheme } from "@getpaseo/plugin";
import { useRpc } from "@getpaseo/plugin/client";
import { Modal, TextInput, useToast } from "@getpaseo/plugin/client/ui";
import { useMutation, useQuery } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { View } from "react-native";
import { decisionRpc, reviewSubmitRpc } from "../shared/contracts";
import { verdictTone } from "../shared/verdict";
import { Badge, Body, Button, Card, Empty, KeyValue, Label, Mono, Note, Segmented, type Tone } from "./parts";

/**
 * Sign a human review.
 *
 * The console shows what is about to change before the reviewer changes it:
 * the claim, the verifier, the kernel's current verdict, and the attestation
 * that this signature replaces. A review that silently discards a machine
 * check is not a review.
 */
export function ReviewSheet({
  theme,
  root,
  producer,
  decisionId,
  obligationId,
  agentId,
  open,
  onOpenChange,
}: {
  theme: PluginTheme;
  root: string | null;
  producer: string;
  decisionId: string | null;
  obligationId: string | null;
  agentId?: string | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const toast = useToast();
  const [result, setResult] = useState<"pass" | "fail">("pass");
  const [rationale, setRationale] = useState("");
  const [identity, setIdentity] = useState(producer);

  const submitReview = useRpc(reviewSubmitRpc);
  const fetchDecisionRpc = useRpc(decisionRpc);
  const fetchDecision = useQuery({
    queryKey: ["mc-decision", root, decisionId],
    queryFn: () => fetchDecisionRpc({ root: root ?? undefined, decisionId: decisionId ?? "" }),
    enabled: open && decisionId !== null,
  });

  const decision = fetchDecision.data;
  const obligation =
    decision?.obligations.find((item) => item.id === obligationId) ?? null;
  const existing = (decision?.attestations ?? []).filter(
    (item) => item.obligation === obligationId,
  );

  const mutation = useMutation({
    mutationFn: async () => {
      if (decisionId === null || obligationId === null) throw new Error("no obligation selected");
      return submitReview({
        root: root ?? undefined,
        decisionId,
        obligationId,
        result,
        producer: identity.trim(),
        rationale: rationale.trim(),
        agentId: agentId ?? undefined,
      });
    },
    onSuccess: (answer) => {
      if (answer.ok) {
        toast.show(answer.detail, { variant: "success" });
        onOpenChange(false);
        setRationale("");
      } else {
        toast.error(answer.detail || answer.error || "the review was not signed");
      }
    },
    onError: (error) => {
      toast.error(String(error));
    },
  });

  const styles = useMemo(
    () => ({
      stack: { gap: 10 },
      field: { gap: 4 },
      input: {
        borderWidth: 1,
        borderColor: theme.colors.border,
        borderRadius: 8,
        paddingHorizontal: 10,
        paddingVertical: 8,
        color: theme.colors.foreground,
        fontSize: 13,
        minHeight: 72,
        textAlignVertical: "top" as const,
      },
      identity: {
        borderWidth: 1,
        borderColor: theme.colors.border,
        borderRadius: 8,
        paddingHorizontal: 10,
        paddingVertical: 8,
        color: theme.colors.foreground,
        fontSize: 13,
      },
      row: { flexDirection: "row" as const, alignItems: "center" as const, gap: 6, flexWrap: "wrap" as const },
    }),
    [theme],
  );

  return (
    <Modal
      title={obligationId ? `review ${obligationId}` : "review"}
      open={open}
      onOpenChange={onOpenChange}
    >
      <Modal.Content>
        <View style={styles.stack}>
          {fetchDecision.isPending && <Empty theme={theme}>Reading the decision…</Empty>}
          {obligation === null && !fetchDecision.isPending && (
            <Note theme={theme} tone="warn">
              The obligation was not found in the decision.
            </Note>
          )}

          {obligation !== null && (
            <>
              <Card theme={theme} title="What you are signing">
                <KeyValue theme={theme} label="decision" value={obligation.id === "" ? "" : decision?.id ?? ""} />
                <KeyValue theme={theme} label="obligation" value={obligation.id} />
                <KeyValue theme={theme} label="kernel verdict" value={obligation.verdict} />
                {obligation.verifiers.length > 0 && (
                  <>
                    <Label theme={theme}>verifiers</Label>
                    <Mono theme={theme}>{obligation.verifiers.join("  ·  ")}</Mono>
                  </>
                )}
                <Label theme={theme}>claim</Label>
                <Body theme={theme}>{obligation.claim}</Body>
              </Card>

              {existing.length > 0 && (
                <Card theme={theme} title="This signature replaces">
                  {existing.map((attestation) => (
                    <View key={attestation.id} style={styles.row}>
                      <Badge
                        theme={theme}
                        label={attestation.kind}
                        tone={verdictTone(attestation.result) as Tone}
                      />
                      <Mono theme={theme}>
                        {attestation.producer} · {attestation.issuedAt}
                      </Mono>
                    </View>
                  ))}
                  <Note theme={theme} tone="warn">
                    The kernel keeps one attestation per obligation. Signing replaces the
                    attestation above, not adds to it.
                  </Note>
                </Card>
              )}

              <Card theme={theme} title="Your verdict">
                <Segmented
                  theme={theme}
                  value={result}
                  onChange={(value) => setResult(value === "fail" ? "fail" : "pass")}
                  options={[
                    { value: "pass", label: "pass" },
                    { value: "fail", label: "fail" },
                  ]}
                />
                <View style={styles.field}>
                  <Label theme={theme}>signed as</Label>
                  <TextInput
                    style={styles.identity}
                    value={identity}
                    onChangeText={setIdentity}
                    placeholder="human:<name>"
                    accessibilityLabel="Producer identity"
                  />
                  <Note theme={theme}>
                    The attestation schema requires a class-tagged identity: human:, agent: or
                    ci:. An untagged identity is rejected at issuance.
                  </Note>
                </View>
                <View style={styles.field}>
                  <Label theme={theme}>rationale</Label>
                  <TextInput
                    style={styles.input}
                    value={rationale}
                    onChangeText={setRationale}
                    placeholder="Why this verdict? What did you check?"
                    multiline
                    accessibilityLabel="Rationale"
                  />
                  <Note theme={theme}>
                    The rationale is not evidence. It goes to the console's ledger under .local/
                    and, when a session is selected, into that session.
                  </Note>
                </View>
                <Button
                  theme={theme}
                  label={mutation.isPending ? "signing…" : "sign the review"}
                  variant="primary"
                  disabled={mutation.isPending || identity.trim() === ""}
                  onPress={() => mutation.mutate()}
                />
                {agentId ? (
                  <Mono theme={theme}>the verdict will also be sent to the session {agentId}</Mono>
                ) : (
                  <Mono theme={theme}>
                    no session is selected; open this from a session to have the verdict
                    challenged there
                  </Mono>
                )}
              </Card>
            </>
          )}
        </View>
      </Modal.Content>
    </Modal>
  );
}
