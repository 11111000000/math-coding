import type { PluginTheme } from "@getpaseo/plugin";
import { useMemo } from "react";
import { Text, View } from "react-native";
import type { MathCodingState } from "../shared/contracts";
import { verdictTone } from "../shared/verdict";
import {
  Badge,
  Body,
  Card,
  Empty,
  KeyValue,
  Label,
  Mono,
  Note,
  SectionTitle,
  type Tone,
} from "./parts";

/**
 * What the kernel says about the repository, right now.
 *
 * The verdict is the kernel's word, not the console's: the console shows the
 * exit code, the digests and the remedies the kernel printed, and it does not
 * soften them.
 */
export function VerdictView({
  theme,
  state,
  onOpenDecision,
}: {
  theme: PluginTheme;
  state: MathCodingState;
  onOpenDecision: (decisionId: string) => void;
}) {
  const styles = useMemo(
    () => ({
      stack: { gap: 10 },
      grid: { flexDirection: "row" as const, flexWrap: "wrap" as const, gap: 8 },
      metric: { minWidth: 88, gap: 2 },
      metricValue: { color: theme.colors.foreground, fontSize: 20, fontWeight: "700" as const },
      metricLabel: { color: theme.colors.foregroundMuted, fontSize: 11 },
      subject: { gap: 3, paddingVertical: 5 },
      subjectName: { color: theme.colors.foreground, fontSize: 12, fontWeight: "600" as const },
      cause: { color: theme.colors.foregroundMuted, fontSize: 11, lineHeight: 16 },
      remedy: { color: theme.colors.foreground, fontSize: 11, lineHeight: 16 },
    }),
    [theme],
  );

  const verdict = state.verdict;
  const coverage = state.coverage;

  return (
    <View style={styles.stack}>
      <Card theme={theme} title="Verdict" subtitle={state.root ?? undefined}>
        {verdict === null ? (
          <Note theme={theme} tone="warn">
            The kernel did not answer. self-check produced no verdict.
          </Note>
        ) : (
          <>
            <View style={styles.grid}>
              <View style={styles.metric}>
                <Text style={styles.metricValue}>{verdict.verdict}</Text>
                <Text style={styles.metricLabel}>self-check verdict</Text>
              </View>
              <View style={styles.metric}>
                <Text style={styles.metricValue}>{verdict.subjects.pass}</Text>
                <Text style={styles.metricLabel}>subjects pass</Text>
              </View>
              <View style={styles.metric}>
                <Text style={styles.metricValue}>{verdict.subjects.fail}</Text>
                <Text style={styles.metricLabel}>subjects fail</Text>
              </View>
              <View style={styles.metric}>
                <Text style={styles.metricValue}>{verdict.subjects.unknown}</Text>
                <Text style={styles.metricLabel}>subjects unknown</Text>
              </View>
            </View>
            <KeyValue
              theme={theme}
              label="exit code"
              value={String(verdict.exitCode)}
              tone={verdict.exitCode === 0 ? "good" : "bad"}
            />
            <KeyValue theme={theme} label="kernel digest" value={short(verdict.kernelDigest)} />
            <KeyValue theme={theme} label="repo digest" value={short(verdict.repositoryDigest)} />
            <KeyValue theme={theme} label="measured at" value={verdict.now} />
            {verdict.error !== null && (
              <Note theme={theme} tone="warn">
                {verdict.error}
              </Note>
            )}
          </>
        )}
      </Card>

      <Card theme={theme} title="Coverage">
        <View style={styles.grid}>
          <Metric theme={theme} label="decisions" value={coverage.decisions} />
          <Metric theme={theme} label="active" value={coverage.activeDecisions} />
          <Metric theme={theme} label="obligations" value={coverage.obligations} />
          <Metric theme={theme} label="attestations" value={coverage.attestations} />
          <Metric theme={theme} label="open promises" value={coverage.openPromises} />
          <Metric theme={theme} label="declared" value={coverage.declaredPromises} />
          <Metric theme={theme} label="waived" value={coverage.waivedPromises} />
          <Metric theme={theme} label="cram tests" value={coverage.cramTests} />
        </View>
        {Object.keys(coverage.byVerdict).length > 0 && (
          <>
            <SectionTitle theme={theme}>obligations by verdict</SectionTitle>
            <View style={styles.grid}>
              {Object.entries(coverage.byVerdict)
                .sort((a, b) => b[1] - a[1])
                .map(([verdictName, count]) => (
                  <Badge
                    key={verdictName}
                    theme={theme}
                    label={`${verdictName} ${count}`}
                    tone={verdictTone(verdictName) as Tone}
                  />
                ))}
            </View>
          </>
        )}
      </Card>

      {verdict !== null && verdict.failures.length > 0 && (
        <Card
          theme={theme}
          title="Subjects that are not green"
          subtitle={`${verdict.failures.length} of ${verdict.subjects.total}`}
        >
          {verdict.failures.slice(0, 20).map((subject) => (
            <View key={subject.name} style={styles.subject}>
              <View style={styles.grid}>
                <Badge
                  theme={theme}
                  label={subject.verdict}
                  tone={verdictTone(subject.verdict) as Tone}
                />
                <Body theme={theme}>{subject.name}</Body>
              </View>
              {subject.causes.slice(0, 4).map((cause) => (
                <Text key={cause} style={styles.cause}>
                  · {cause}
                </Text>
              ))}
              {subject.remedies.slice(0, 4).map((remedy) => (
                <Text key={remedy} style={styles.remedy}>
                  → {remedy}
                </Text>
              ))}
            </View>
          ))}
          {verdict.failures.length > 20 && (
            <Mono theme={theme}>…and {verdict.failures.length - 20} more</Mono>
          )}
        </Card>
      )}

      {state.doctor !== null && (
        <Card theme={theme} title="Install diagnostic" subtitle={`mathc doctor`}>
          {state.doctor.sections.map((section) => (
            <KeyValue
              key={section.id}
              theme={theme}
              label={section.label}
              value={section.verdict}
              tone={
                section.verdict === "pass"
                  ? "good"
                  : section.verdict === "fail"
                    ? "bad"
                    : section.verdict === "warn"
                      ? "warn"
                      : "neutral"
              }
            />
          ))}
        </Card>
      )}

      {state.git !== null && (
        <Card theme={theme} title="Repository">
          <KeyValue theme={theme} label="branch" value={state.git.branch} />
          <KeyValue theme={theme} label="head" value={short(state.git.head)} />
          <KeyValue
            theme={theme}
            label="working tree"
            value={state.git.dirty ? `${state.git.dirtyPaths.length} changed` : "clean"}
            tone={state.git.dirty ? "warn" : "good"}
          />
          <KeyValue
            theme={theme}
            label="ahead / behind"
            value={`${state.git.ahead} / ${state.git.behind}`}
          />
          {state.git.lastCommitSubject !== null && (
            <KeyValue theme={theme} label="last commit" value={state.git.lastCommitSubject} />
          )}
        </Card>
      )}

      {state.policies.length > 0 && (
        <Card theme={theme} title="Policy">
          {state.policies.map((policy) => (
            <View key={policy.policyId} style={styles.subject}>
              <Body theme={theme}>{policy.policyId}</Body>
              <Mono theme={theme}>
                floor {policy.modeFloor}
                {policy.parent ? ` · parent ${policy.parent}` : ""}
                {` · ${policy.scopePaths.length} scope paths`}
              </Mono>
            </View>
          ))}
        </Card>
      )}

      {state.warnings.length > 0 && (
        <Card theme={theme} title="Warnings">
          {state.warnings.map((warning) => (
            <Note key={warning} theme={theme} tone="warn">
              {warning}
            </Note>
          ))}
        </Card>
      )}

      {state.rootError !== null && (
        <Card theme={theme} title="No repository">
          <Empty theme={theme}>{state.rootError}</Empty>
        </Card>
      )}
    </View>
  );
}

function Metric({
  theme,
  label,
  value,
}: {
  theme: PluginTheme;
  label: string;
  value: number;
}) {
  const styles = useMemo(
    () => ({
      metric: { minWidth: 88, gap: 2 },
      value: { color: theme.colors.foreground, fontSize: 18, fontWeight: "700" as const },
      label: { color: theme.colors.foregroundMuted, fontSize: 11 },
    }),
    [theme],
  );
  return (
    <View style={styles.metric}>
      <Text style={styles.value}>{value}</Text>
      <Text style={styles.label}>{label}</Text>
    </View>
  );
}

function short(digest: string): string {
  if (digest === "") return "—";
  const bare = digest.startsWith("sha256:") ? digest.slice(7) : digest;
  return bare.slice(0, 12);
}
