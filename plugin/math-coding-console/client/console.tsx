import type { PluginTheme } from "@getpaseo/plugin";
import { useRpc } from "@getpaseo/plugin/client";
import { ScrollView } from "@getpaseo/plugin/client/ui";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { View } from "react-native";
import { stateRpc } from "../shared/contracts";
import { ActionsView } from "./actions-view";
import { DecisionSheet } from "./decision-sheet";
import { DecisionsView } from "./decisions-view";
import { EvidenceView } from "./evidence-view";
import { PromisesView } from "./promises-view";
import { ReviewSheet } from "./review-sheet";
import { ReviewView } from "./review-view";
import { VerdictView } from "./verdict-view";
import { Button, Empty, Note, Segmented } from "./parts";

/**
 * The console.
 *
 * One screen, six views over one repository. The panel and the standalone
 * screen are the same thing with different chrome, so what a reader learns in
 * one place is available in the other.
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
  const fetchState = useRpc(stateRpc);

  const [tab, setTab] = useState(initialTab ?? "verdict");
  const [decisionId, setDecisionId] = useState<string | null>(null);
  const [reviewTarget, setReviewTarget] = useState<{ decisionId: string; obligationId: string } | null>(
    null,
  );

  const query = useQuery({
    queryKey: ["mc-state", root],
    queryFn: () => fetchState({ root: root ?? undefined }),
    enabled: root !== null,
    retry: false,
  });

  const state = query.data;
  const refresh = () => {
    void queryClient.invalidateQueries({ queryKey: ["mc-state", root] });
    void queryClient.invalidateQueries({ queryKey: ["mc-decision"] });
  };

  const styles = useMemo(
    () => ({
      screen: { flex: 1, backgroundColor: theme.colors.surface0 },
      inner: { padding: compact ? 12 : 20, gap: 12 },
      header: { gap: 6 },
      loading: { padding: 24 },
    }),
    [theme, compact],
  );

  const tabs = [
    { value: "verdict", label: "Verdict" },
    { value: "promises", label: "Promises" },
    { value: "decisions", label: "Decisions" },
    { value: "review", label: "Review" },
    { value: "evidence", label: "Evidence" },
    { value: "actions", label: "Actions" },
  ];
  const active = tabs.some((item) => item.value === tab) ? tab : "verdict";

  return (
    <View style={styles.screen}>
      <ScrollView>
        <View style={styles.inner}>
          <Segmented theme={theme} value={active} onChange={setTab} options={tabs} />

          {root === null && (
            <Note theme={theme} tone="warn">
              No math-coding repository is selected. Set the repository root in Settings →
              math-coding, or open the console from a workspace that holds one.
            </Note>
          )}

          {root !== null && query.isPending && (
            <View style={styles.loading}>
              <Empty theme={theme}>Asking the kernel…</Empty>
            </View>
          )}

          {root !== null && query.isError && (
            <Note theme={theme} tone="bad">
              The kernel did not answer: {String(query.error)}
            </Note>
          )}

          {state !== undefined && active === "verdict" && (
            <VerdictView theme={theme} state={state} onOpenDecision={setDecisionId} />
          )}

          {state !== undefined && active === "promises" && (
            <PromisesView
              theme={theme}
              promises={state.promises}
              onOpenDecision={setDecisionId}
            />
          )}

          {state !== undefined && active === "decisions" && (
            <DecisionsView
              theme={theme}
              decisions={state.decisions}
              onOpenDecision={setDecisionId}
            />
          )}

          {state !== undefined && active === "review" && (
            <ReviewView
              theme={theme}
              queue={state.reviewQueue}
              onReview={(decision, obligation) => setReviewTarget({ decisionId: decision, obligationId: obligation })}
              onOpenDecision={setDecisionId}
            />
          )}

          {state !== undefined && active === "evidence" && (
            <EvidenceView theme={theme} state={state} />
          )}

          {state !== undefined && active === "actions" && (
            <ActionsView
              theme={theme}
              root={root}
              attestRunCommand={attestRunCommand}
              onRefresh={refresh}
            />
          )}

          {state !== undefined && state.root !== null && (
            <Button theme={theme} label="refresh" onPress={refresh} />
          )}
        </View>
      </ScrollView>

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
