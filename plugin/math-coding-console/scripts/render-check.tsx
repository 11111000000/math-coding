import assert from "node:assert/strict";
import { createElement, type ReactNode } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import mock from "mock-require";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { attentionBrief, attentionContext, buildAttentionModel } from "../client/attention";
import type {
  HostContextValue,
  HostIconProps,
  HostModalProps,
  HostSettingsActionProps,
  HostSettingsCardProps,
  HostSettingsInputProps,
  HostSettingsSectionProps,
  HostSettingsSelectProps,
  HostSettingsSwitchProps,
  HostTextInputProps,
} from "../client/host/contract";
import { HostProvider } from "../client/host/context";
import { theme, snapshot, claim } from "../test/fixtures";

const React = createElement;

/**
 * The host stub.
 *
 * The shared interface reaches the host through the contract only, so the
 * check builds a stub implementation of that contract instead of replacing
 * host modules.
 */
const Icon = ({ name }: HostIconProps) => React("span", { "data-icon": name });
const Modal = Object.assign(
  // The stub always renders the body, so the confirmation text is part of the checked markup.
  ({ children }: HostModalProps) => children,
  { Content: ({ children }: { children?: ReactNode }) => children },
);
const TextInput = (props: HostTextInputProps) => React("input", {
  readOnly: true,
  defaultValue: props.value,
  "aria-label": props.accessibilityLabel ?? props.placeholder,
});
const SettingsSection = ({ children }: HostSettingsSectionProps) => React("div", null, children);
const SettingsCard = ({ children }: HostSettingsCardProps) => React("div", null, children);
const SettingsInput = ({ label, initialValue }: HostSettingsInputProps) => React("input", {
  readOnly: true,
  defaultValue: initialValue,
  "aria-label": label,
});
const SettingsSelect = ({ label }: HostSettingsSelectProps) => React("select", { readOnly: true, "aria-label": label });
const SettingsAction = ({ actionLabel }: HostSettingsActionProps) => React("button", { type: "button" }, actionLabel);
const SettingsSwitch = ({ label, value }: HostSettingsSwitchProps) => React("div", null, label, React("input", { type: "checkbox", readOnly: true, checked: value }));

const host: HostContextValue = {
  Icon,
  Modal,
  TextInput,
  SettingsSection,
  SettingsCard,
  SettingsInput,
  SettingsSelect,
  SettingsAction,
  SettingsSwitch,
  copyText: async () => undefined,
  useToast: () => ({ show: () => undefined, error: () => undefined }),
  useRpc: ((contract: never) => async () => snapshot()) as unknown as HostContextValue["useRpc"],
  useSettings: ((definition: never) => ({
    status: "ready",
    values: { binaryPath: "", allowRunChecks: false, autoRefreshSeconds: 30 },
    revision: "revision",
    saving: false,
    saveError: null,
    save: async () => true,
    reset: async () => true,
    reload: async () => undefined,
  })) as unknown as HostContextValue["useSettings"],
};

mock("react-native", "react-native-web");

async function main() {
  const [
    { InstrumentFrame },
    { AttentionView },
    { GraphView },
    { ClaimsView },
    { CoverageView },
    { ClaimDetailView },
    { EvidenceView },
    { ConsolePanel },
    { SettingsScreen },
  ] = await Promise.all([
    import("../client/frame"),
    import("../client/attention-view"),
    import("../client/graph"),
    import("../client/claims"),
    import("../client/coverage"),
    import("../client/detail"),
    import("../client/evidence"),
    import("../client/console"),
    import("../client/settings"),
  ]);
  const data = snapshot();
  const attentionData = snapshot(Array.from({ length: 15 }, (_, index) => claim({ id: `claim-${index}` })));
  attentionData.map.claims = 15;
  attentionData.map.verdict = "unknown";
  attentionData.map.exit = 3;
  attentionData.map.next = "next: check the claim claim-0";
  attentionData.map.states = attentionData.claims.map((item) => ({ id: item.id, state: "outdated", source_changed: false }));
  const attention = buildAttentionModel(attentionData, 1_000);
  const changed = claim({
    id: "changed",
    source: { kind: "madr", path: "docs/adr.md", section: null, digest: "a".repeat(64), review: null },
  });
  const refuted = claim({ id: "refuted" });
  const waived = claim({
    id: "waived",
    waiver: {
      gap: "temporary limitation",
      scope: ["src/"],
      issuer: "owner",
      issued_at: 900,
      expires_at: 1_100,
      reason: "accepted until migration",
      compensating_controls: [],
      recovery: "finish migration",
      review_on: [],
    },
  });
  const humanData = snapshot([changed, refuted, waived]);
  humanData.map.verdict = "red";
  humanData.map.exit = 1;
  humanData.map.next = "next: review the changed source for changed";
  humanData.map.uncovered = ["src/uncovered.ts"];
  humanData.map.states = [
    { id: changed.id, state: "outdated", source_changed: true },
    { id: refuted.id, state: "refuted", source_changed: false },
    { id: waived.id, state: "waived", source_changed: false },
  ];
  const humanAttention = buildAttentionModel(humanData, 1_000);
  const humanContext = attentionContext(humanData, humanAttention);
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false, enabled: false } } });
  queryClient.setQueryData(["mathcoding-snapshot", "workspace-1"], attentionData);
  const render = (element: ReactNode) => renderToStaticMarkup(
    React(QueryClientProvider, { client: queryClient }, React(HostProvider, { value: host, children: element })),
  );
  const frameProps = {
    theme,
    compact: false,
    snapshot: attentionData,
    attention,
    onRefresh: () => undefined,
    refreshing: false,
    onRun: () => undefined,
    running: false,
    runEnabled: true,
  };
  const views: [string, ReactNode][] = [
    ["instrument frame", React(InstrumentFrame, frameProps)],
    ["attention human branch", React(AttentionView, { theme, compact: false, model: humanAttention, context: humanContext, onSelect: () => undefined, onRun: () => undefined, runEnabled: true })],
    ["proof graph", React(GraphView, { theme, compact: false, snapshot: data, mode: "proof", expanded: new Set<string>(["hello"]), onToggleClaim: () => undefined, selected: null, onSelect: () => undefined })],
    ["scope graph", React(GraphView, { theme, compact: true, snapshot: data, mode: "scope", expanded: new Set<string>(), onToggleClaim: () => undefined, selected: null, onSelect: () => undefined })],
    ["claims", React(ClaimsView, { theme, compact: false, snapshot: data, onSelect: () => undefined })],
    ["coverage", React(CoverageView, { theme, compact: true, snapshot: data, onSelect: () => undefined, onOpenScope: () => undefined })],
    ["claim detail", React(ClaimDetailView, { theme, compact: false, snapshot: data, selection: { claimId: "hello" }, onClose: () => undefined, onSelect: () => undefined, onRefresh: () => undefined })],
    ["evidence", React(EvidenceView, { theme, compact: false, snapshot: data })],
    ["console panel", React(ConsolePanel, { theme, layout: { compact: false }, workspaceId: "workspace-1" })],
    ["settings screen", React(SettingsScreen, { theme })],
  ];
  for (const [name, element] of views) {
    const markup = render(element);
    assert.ok(markup.length > 100, `${name} rendered too little content`);
    if (name === "attention human branch") {
      assert.ok(markup.includes("Review the changed source for changed"));
      assert.ok(markup.includes("Decide the direction of refuted claim refuted"));
      assert.ok(markup.includes("Accepted risk for waived"));
      assert.ok(markup.includes("Next safe step"));
    }
    if (name === "console panel") {
      assert.ok(markup.includes("test the plugin"));
      assert.ok(markup.includes("0 need your decision"));
      assert.ok(markup.includes("15 can move without you"));
      assert.ok(markup.includes("Nothing needs your decision now"));
      assert.ok(markup.includes("Refresh evidence for 15 claims"));
      assert.ok(markup.includes("Run checks are disabled"));
      assert.ok(markup.includes("Scale: 15 claim(s) and 30 check command(s) will run"));
    }
    process.stdout.write(`ok: ${name} rendered ${markup.length} bytes\n`);
  }
  const brief = attentionBrief(humanAttention.needsHuman[0]!, humanContext);
  assert.ok(brief.includes("Goal: test the plugin"), "the brief carries the goal");
  assert.ok(brief.includes("Canonical verdict: red"), "the brief carries the verdict");
  assert.ok(brief.includes("Goal scope uncovered: 1 path(s)"), "the brief carries the uncovered count");
  assert.ok(brief.includes("src/uncovered.ts"), "the brief carries the uncovered paths");
  assert.ok(brief.includes("Accepted risks: 1"), "the brief carries the accepted risks");
  assert.ok(brief.includes("Canonical next action: next: review the changed source for changed"), "the brief carries the canonical next action");
  assert.ok(brief.includes("Human decision (the agent must not make it)"), "the brief keeps the human boundary");
  process.stdout.write(`ok: attention brief carries goal, verdict, coverage, risks and next action (${brief.length} bytes)\n`);
  const light = { ...theme, colors: { ...theme.colors, surface0: "#ffffff", surface1: "#f7f7f7", surface2: "#eeeeee", border: "#cccccc", foreground: "#111111", foregroundMuted: "#555555" } };
  const lightMarkup = render(React(InstrumentFrame, { ...frameProps, theme: light, compact: true }));
  assert.ok(lightMarkup.includes("test the plugin"));
  process.stdout.write(`ok: light compact frame rendered ${lightMarkup.length} bytes\n`);
  process.stdout.write("render-check: PASS\n");
}

void main().catch((error) => {
  process.stderr.write(`render-check: FAIL ${String(error)}\n`);
  process.exitCode = 1;
});
