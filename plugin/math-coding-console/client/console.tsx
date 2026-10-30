import type { PluginTheme } from "@getpaseo/plugin";
import { useRpc } from "@getpaseo/plugin/client";
import { ScrollView, TextInput, useToast } from "@getpaseo/plugin/client/ui";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { Text, View } from "react-native";
import { changeRpc, mosaicRpc, stateRpc, type Change } from "../shared/contracts";
import { ActionsView } from "./actions-view";
import { ChainSheet } from "./chain";
import { DecisionSheet } from "./decision-sheet";
import { DecisionsView } from "./decisions-view";
import { InstrumentFrame } from "./frame";
import { MosaicView } from "./mosaic";
import { PromisesView } from "./promises-view";
import { ReviewSheet } from "./review-sheet";
import { ReviewView } from "./review-view";
import { Badge, Body, Button, Card, Empty, KeyValue, Mono, Note, Segmented } from "./parts";

/**
 * The console.
 *
 * The frame carries the instrument's reading and is always visible. The four
 * views answer the methodology's questions: the corpus at a glance, this
 * change, the commitments and what still stands of them, and what a person
 * must stand behind.
 *
 * The kernel's subcommands are NOT a view. They are verbs, and a navigation
 * of verbs says the kernel is a bag of commands; they live behind the
 * Actions button, which is where an instrument's controls belong.
 */
export function ConsoleView({
  theme,
  compact,
  root,
  reviewProducer,
  attestRunCommand,
  agentId,
  initialTab,
}: {
  theme: PluginTheme;
  compact: boolean;
  root: string | null;
  reviewProducer: string;
  attestRunCommand: string;
  agentId?: string | null;
  /** Which view to open on. A link may name one. */
  initialTab?: string | null;
}) {
  const queryClient = useQueryClient();
  const toast = useToast();
  const fetchState = useRpc(stateRpc);
  const fetchMosaic = useRpc(mosaicRpc);
  const fetchChange = useRpc(changeRpc);

  const [tab, setTab] = useState(initialTab ?? "corpus");
  const [decisionId, setDecisionId] = useState<string | null>(null);
  const [chainCell, setChainCell] = useState<Parameters<typeof ChainSheet>[0]["cell"]>(null);
  const [reviewTarget, setReviewTarget] = useState<{ decisionId: string; obligationId: string } | null>(
    null,
  );
  const [showActions, setShowActions] = useState(false);
  const [base, setBase] = useState("HEAD~1");
  const [head, setHead] = useState("HEAD");

  const stateQuery = useQuery({
    queryKey: ["mc-state", root],
    queryFn: () => fetchState({ root: root ?? undefined }),
    enabled: root !== null,
    retry: false,
  });

  const mosaicQuery = useQuery({
    queryKey: ["mc-mosaic", root],
    queryFn: () => fetchMosaic({ root: root ?? undefined }),
    enabled: root !== null,
    retry: false,
  });

  const changeQuery = useQuery({
    queryKey: ["mc-change", root, base, head],
    queryFn: () => fetchChange({ root: root ?? undefined, base, head }),
    enabled: root !== null && tab === "change",
    retry: false,
  });

  const state = stateQuery.data;
  const mosaic = mosaicQuery.data;

  const refresh = () => {
    void queryClient.invalidateQueries({ queryKey: ["mc-state", root] });
    void queryClient.invalidateQueries({ queryKey: ["mc-mosaic", root] });
    void queryClient.invalidateQueries({ queryKey: ["mc-change"] });
  };

  const styles = useMemo(
    () => ({
      screen: { flex: 1, backgroundColor: theme.colors.surface0 },
      inner: { padding: compact ? 12 : 20, gap: 12 },
      loading: { padding: 24 },
      inputRow: { flexDirection: "row" as const, gap: 8, alignItems: "center" as const },
      input: {
        borderWidth: 1,
        borderColor: theme.colors.border,
        borderRadius: 8,
        paddingHorizontal: 10,
        paddingVertical: 6,
        color: theme.colors.foreground,
        fontSize: 12,
        minWidth: 90,
        flex: 1,
      },
    }),
    [theme, compact],
  );

  const tabs = [
    { value: "corpus", label: "Corpus" },
    { value: "change", label: "This change" },
    { value: "gaps", label: "Gaps" },
    { value: "commitments", label: "Commitments" },
    { value: "reviews", label: "Reviews" },
  ];
  const active = tabs.some((item) => item.value === tab) ? tab : "corpus";

  return (
    <View style={styles.screen}>
      <ScrollView>
        <View style={styles.inner}>
          <InstrumentFrame theme={theme} state={state} mosaic={mosaic} />

          <View style={{ flexDirection: "row", gap: 8, alignItems: "center" }}>
            <View style={{ flex: 1 }}>
              <Segmented theme={theme} value={active} onChange={setTab} options={tabs} />
            </View>
            <Button
              theme={theme}
              label={showActions ? "close" : "kernel"}
              onPress={() => setShowActions((value) => !value)}
            />
          </View>

          {root === null && (
            <Note theme={theme} tone="warn">
              No math-coding repository is selected. Set the repository root in Settings →
              math-coding, or open the console from a workspace that holds one.
            </Note>
          )}

          {root !== null && stateQuery.isPending && (
            <View style={styles.loading}>
              <Empty theme={theme}>Asking the kernel…</Empty>
            </View>
          )}

          {root !== null && stateQuery.isError && (
            <Note theme={theme} tone="bad">
              The kernel did not answer: {String(stateQuery.error)}
            </Note>
          )}

          {showActions && state !== undefined && (
            <ActionsView
              theme={theme}
              root={root}
              attestRunCommand={attestRunCommand}
              onRefresh={refresh}
            />
          )}

          {active === "corpus" && mosaicQuery.isPending && (
            <Empty theme={theme}>Drawing the corpus…</Empty>
          )}
          {active === "corpus" && mosaic !== undefined && (
            <MosaicView
              theme={theme}
              compact={compact}
              mosaic={mosaic}
              onOpenCell={setChainCell}
              onOpenDecision={setDecisionId}
            />
          )}

          {active === "change" && (
            <ChangeView
              theme={theme}
              base={base}
              head={head}
              onBase={setBase}
              onHead={setHead}
              change={changeQuery.data}
              pending={changeQuery.isPending}
            />
          )}

          {state !== undefined && active === "gaps" && (
            <PromisesView
              theme={theme}
              promises={state.promises}
              onOpenDecision={setDecisionId}
            />
          )}

          {state !== undefined && active === "commitments" && (
            <DecisionsView
              theme={theme}
              decisions={state.decisions}
              onOpenDecision={setDecisionId}
            />
          )}

          {state !== undefined && active === "reviews" && (
            <ReviewView
              theme={theme}
              queue={state.reviewQueue}
              onReview={(decision, obligation) =>
                setReviewTarget({ decisionId: decision, obligationId: obligation })
              }
              onOpenDecision={setDecisionId}
            />
          )}

          {state !== undefined && state.root !== null && (
            <Button theme={theme} label="refresh" onPress={refresh} />
          )}
        </View>
      </ScrollView>

      <ChainSheet
        theme={theme}
        cell={chainCell}
        open={chainCell !== null}
        onOpenChange={(open) => {
          if (!open) setChainCell(null);
        }}
      />

      <DecisionSheet
        theme={theme}
        root={root}
        decisionId={decisionId}
        open={decisionId !== null}
        onOpenChange={(open) => {
          if (!open) setDecisionId(null);
        }}
        onReview={(decision, obligation) => {
          setDecisionId(null);
          setReviewTarget({ decisionId: decision, obligationId: obligation });
        }}
      />

      <ReviewSheet
        theme={theme}
        root={root}
        producer={reviewProducer}
        decisionId={reviewTarget?.decisionId ?? null}
        obligationId={reviewTarget?.obligationId ?? null}
        agentId={agentId ?? null}
        open={reviewTarget !== null}
        onOpenChange={(open) => {
          if (!open) setReviewTarget(null);
        }}
      />
    </View>
  );
}

/**
 * The change view: the merge gate's own reading.
 *
 * The base and the head are inputs, not guesses. The console never picks a
 * base on the operator's behalf: a gate that answers a question nobody
 * asked is worse than no gate.
 */
function ChangeView({
  theme,
  base,
  head,
  onBase,
  onHead,
  change,
  pending,
}: {
  theme: PluginTheme;
  base: string;
  head: string;
  onBase: (value: string) => void;
  onHead: (value: string) => void;
  change: Change | undefined;
  pending: boolean;
}) {
  const styles = useMemo(
    () => ({
      stack: { gap: 10 },
      inputRow: { flexDirection: "row" as const, gap: 8, alignItems: "center" as const },
      input: {
        borderWidth: 1,
        borderColor: theme.colors.border,
        borderRadius: 8,
        paddingHorizontal: 10,
        paddingVertical: 6,
        color: theme.colors.foreground,
        fontSize: 12,
        flex: 1,
      },
      gap: { paddingVertical: 5, gap: 2 },
      kind: { color: theme.colors.foreground, fontSize: 12, fontWeight: "600" as const },
      cause: { color: theme.colors.foregroundMuted, fontSize: 11, lineHeight: 16 },
    }),
    [theme],
  );

  return (
    <View style={styles.stack}>
      <Card theme={theme} title="The merge gate" subtitle="the kernel's own reading">
        <View style={styles.inputRow}>
          <TextInput
            style={styles.input}
            value={base}
            onChangeText={onBase}
            placeholder="base"
            accessibilityLabel="Base ref"
          />
          <TextInput
            style={styles.input}
            value={head}
            onChangeText={onHead}
            placeholder="head"
            accessibilityLabel="Head ref"
          />
        </View>
        {pending && <Empty theme={theme}>Asking the gate…</Empty>}
        {change !== undefined && (
          <>
            <View style={{ flexDirection: "row", gap: 8, alignItems: "center" }}>
              <Text
                style={{
                  color: theme.colors.foreground,
                  fontSize: 20,
                  fontWeight: "700",
                }}
              >
                {change.verdict ?? "—"}
              </Text>
              <Badge theme={theme} label={`exit ${change.exitCode}`} tone="info" />
              <Mono theme={theme}>{change.obligations} obligations</Mono>
            </View>
            {change.error !== null && (
              <Note theme={theme} tone="bad">
                {change.error}
              </Note>
            )}
            <Mono theme={theme}>
              {change.changedFiles.length} file(s) changed between {change.base} and {change.head}
            </Mono>
          </>
        )}
      </Card>

      {change !== undefined && change.gaps.length > 0 && (
        <Card theme={theme} title="The gaps" subtitle={`${change.gaps.length} reported`}>
          {change.gaps.slice(0, 60).map((gap) => (
            <View key={`${gap.kind}/${gap.obligationId}`} style={styles.gap}>
              <View style={{ flexDirection: "row", gap: 6, alignItems: "center" }}>
                <Text style={styles.kind}>{gap.kind}</Text>
                <Mono theme={theme}>{gap.obligationId}</Mono>
                {gap.decision !== null && <Mono theme={theme}>· {gap.decision}</Mono>}
              </View>
              {gap.causes.slice(0, 2).map((cause) => (
                <Text key={cause} style={styles.cause}>
                  · {cause}
                </Text>
              ))}
              {gap.remedies.slice(0, 2).map((remedy) => (
                <Text key={remedy} style={styles.cause}>
                  → {remedy}
                </Text>
              ))}
            </View>
          ))}
          {change.gaps.length > 60 && (
            <Mono theme={theme}>…and {change.gaps.length - 60} more</Mono>
          )}
        </Card>
      )}

      {change !== undefined && change.limit !== null && (
        <Note theme={theme} tone="info">
          {change.limit}
        </Note>
      )}
    </View>
  );
}
