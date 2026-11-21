import assert from "node:assert/strict";
import { createElement, type ReactNode } from "react";
import { QueryClient } from "@tanstack/react-query";
import { attentionBrief, attentionContext, buildAttentionModel } from "../client/attention";
import { emptyHumanActionValues, humanActions } from "../shared/human-actions";
import { buildHumanQueue } from "../client/human-queue";
import { translate } from "../client/i18n/translate";
import { renderWithHost, host } from "../test/host-stub";
import type { HostContextValue } from "../client/host/contract";
import type { MessageKey } from "../shared/message";
import { runScale } from "../client/run-scale";
import { theme, snapshot, claim } from "../test/fixtures";

const React = createElement;

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
    { QueueView },
    { RunConfirmation },
    { FilePreview },
    { HumanActionForm },
    { PermissionsCard },
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
    import("../client/queue-view"),
    import("../client/run-confirmation"),
    import("../client/file-preview"),
    import("../client/human-action"),
    import("../client/permissions"),
  ]);
  const data = snapshot();
  data.map.states = [{ id: "hello", state: "outdated", source_changed: false, reason: "environment-changed" }];
  data.map.verdict = "unknown";
  data.map.exit = 3;
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
  const humanQueue = buildHumanQueue(humanData, humanAttention, []);
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false, enabled: false } } });
  queryClient.setQueryData(["mathcoding-snapshot", "workspace-1"], attentionData);
  const render = (element: ReactNode) => renderWithHost(element, queryClient);
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
  const humanActionsForFixture = humanActions(
    { claims: humanData.claims, states: humanData.map.states, policyConfigured: false },
    1_000,
  );
  const views: [string, ReactNode][] = [
    ["instrument frame", React(InstrumentFrame, frameProps)],
    ["attention agent branch", React(AttentionView, { theme, compact: false, model: humanAttention, context: humanContext, onSelect: () => undefined, onRun: () => undefined, runEnabled: true })],
    ["human queue", React(QueueView, { theme, compact: false, queue: humanQueue, context: humanContext, actions: humanActionsForFixture, decisionsEnabled: true, onTakeAction: () => undefined, onOpenFile: () => undefined, onSelect: () => undefined })],
    ["proof graph", React(GraphView, { theme, compact: false, snapshot: data, mode: "proof", expanded: new Set<string>(["hello"]), onToggleClaim: () => undefined, selected: null, onSelect: () => undefined })],
    ["scope graph", React(GraphView, { theme, compact: true, snapshot: data, mode: "scope", expanded: new Set<string>(), onToggleClaim: () => undefined, selected: null, onSelect: () => undefined })],
    ["claims", React(ClaimsView, { theme, compact: false, snapshot: data, onSelect: () => undefined })],
    ["coverage", React(CoverageView, { theme, compact: true, snapshot: data, onSelect: () => undefined, onOpenScope: () => undefined })],
    ["claim detail", React(ClaimDetailView, { theme, compact: false, snapshot: data, selection: { claimId: "hello" }, onClose: () => undefined, onSelect: () => undefined, onRefresh: () => undefined, onOpenFile: () => undefined })],
    ["claim detail in the sheet of the host", React(ClaimDetailView, { theme, compact: true, snapshot: data, selection: { claimId: "hello" }, onClose: () => undefined, onSelect: () => undefined, onRefresh: () => undefined, onOpenFile: () => undefined })],
    ["evidence", React(EvidenceView, { theme, compact: false, snapshot: data })],
    ["run confirmation", React(RunConfirmation, { theme, scale: runScale(attentionData), running: false, error: null, onCancel: () => undefined, onRun: () => undefined })],
    ["file preview", React(FilePreview, { theme, compact: false, workspaceId: "workspace-1", path: "docs/adr.md", onClose: () => undefined })],
    ["human action form", React(HumanActionForm, {
      theme,
      action: humanActionsForFixture[0] ?? { id: "none", kind: "authorize", claimId: null, authority: null, title: "none", detail: "none", expectation: "", owner: "", fields: [] },
      values: { ...emptyHumanActionValues(), by: "owner" },
      onChange: () => undefined,
      running: false,
      error: null,
      onCancel: () => undefined,
      onConfirm: () => undefined,
    })],
    ["console panel", React(ConsolePanel, { theme, layout: { compact: false }, workspaceId: "workspace-1" })],
    ["permissions card", React(PermissionsCard, { theme, compact: false, runEnabled: false, decisionsEnabled: false, onOpenSettings: () => undefined })],
    ["settings screen", React(SettingsScreen, { theme })],
  ];
  for (const [name, element] of views) {
    const markup = render(element);
    assert.ok(markup.length > 100, `${name} rendered too little content`);
    if (name === "human queue") {
      assert.ok(markup.includes("Your queue"), "the queue names the human");
      assert.ok(markup.includes("Review the changed source for changed"), "the queue names the decision");
      assert.ok(markup.includes("Decide the direction of refuted claim refuted"), "the queue names the second decision");
      assert.ok(markup.includes("How it is checked"), "the queue says how the claim is checked");
      assert.ok(markup.includes("Expected"), "the queue says what is expected");
      assert.ok(markup.includes("Your decision"), "the queue asks the human for a decision");
      assert.ok(markup.includes("Next safe step"), "the queue names the next safe step");
      assert.ok(markup.includes("This version does not report a reason for this state."), "the queue keeps the canonical reason");
      assert.ok(markup.includes("Your standing obligations"), "the queue lists the standing obligations");
      assert.ok(markup.includes("Accept the result"), "the queue names the third outcome");
      assert.ok(markup.includes("docs/adr.md"), "the queue offers the source of the claim to open");
    }
    if (name === "attention agent branch") {
      assert.ok(markup.includes("Accepted risk for waived"));
      assert.ok(markup.includes("Next safe step"));
    }
    if (name === "instrument frame") {
      assert.ok(markup.includes("tool mathc"), "the frame does not name the program that produced the map");
    }
    if (name === "claim detail") {
      assert.ok(markup.includes("The environment changed after the evidence was recorded"), "the claim card does not explain the reason");
    }
    if (name === "claim detail in the sheet of the host") {
      assert.ok(markup.includes("hello"), "the claim card of the sheet does not show the claim");
      assert.ok(markup.includes("the command prints hello"), "the claim card of the sheet does not show the text of the claim");
    }
    if (name === "console panel") {
      assert.ok(markup.includes("test the plugin"));
      assert.ok(markup.includes("0 need your decision"));
      assert.ok(markup.includes("15 can move without you"));
      assert.ok(markup.includes("Nothing needs your decision now"));
      assert.ok(markup.includes("Refresh evidence for 15 claims"));
      assert.ok(markup.includes("What the console can do now"), "the panel does not say what it can do");
      assert.ok(markup.includes("Allow Run checks"), "the panel does not name the switch of the run");
      assert.ok(markup.includes("Allow human decisions"), "the panel does not name the switch of the decisions");
      assert.ok(markup.includes("Open the Math Coding settings"), "the panel does not offer the settings of the host");
    }
    if (name === "permissions card") {
      assert.ok(markup.includes("Reading the map, the evidence, the briefs and the navigation always works"), "the card does not say what always works");
      assert.ok(markup.includes("in the settings of the plugin"), "the card does not name the place of the switch");
    }
    if (name === "run confirmation") {
      assert.ok(markup.includes("Scale: 15 claim(s) and 30 check command(s) will run"), "the confirmation does not name the scale of the run");
      assert.ok(markup.includes("Run checks"), "the confirmation does not offer the run");
    }
    if (name === "file preview") {
      assert.ok(markup.includes("docs/adr.md"), "the preview does not show the requested file");
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
  assert.ok(brief.includes("Reason: This version does not report a reason for this state."), "the brief carries the reason of the state");
  process.stdout.write(`ok: attention brief carries goal, verdict, coverage, risks and next action (${brief.length} bytes)\n`);
  const light = { ...theme, colors: { ...theme.colors, surface0: "#ffffff", surface1: "#f7f7f7", surface2: "#eeeeee", border: "#cccccc", foreground: "#111111", foregroundMuted: "#555555" } };
  const lightMarkup = render(React(InstrumentFrame, { ...frameProps, theme: light, compact: true }));
  assert.ok(lightMarkup.includes("test the plugin"));
  process.stdout.write(`ok: light compact frame rendered ${lightMarkup.length} bytes\n`);

  /**
   * The same interface in Russian.
   *
   * The language of the host decides the language of the interface when the
   * human has not chosen one. The check draws the screens again with a host
   * that speaks Russian and asks for the Russian text of the labels: the
   * English text of the same label must be gone.
   */
  const russianHost: HostContextValue = { ...host, useAppLocale: () => "ru" };
  const russian = (element: ReactNode) => renderWithHost(element, queryClient, russianHost);
  const ru = (key: MessageKey) => translate("ru", key);
  const en = (key: MessageKey) => translate("en", key);
  const russianScreens: [string, ReactNode, MessageKey[]][] = [
    ["console panel", React(ConsolePanel, { theme, layout: { compact: false }, workspaceId: "workspace-1" }), ["panel.tab_queue", "panel.tab_explore", "panel.tab_evidence"]],
    ["human queue", React(QueueView, { theme, compact: false, queue: humanQueue, context: humanContext, actions: humanActionsForFixture, decisionsEnabled: true, onTakeAction: () => undefined, onOpenFile: () => undefined, onSelect: () => undefined }), ["queue.title", "queue.accept_title", "queue.next_safe_step"]],
    ["claim detail", React(ClaimDetailView, { theme, compact: false, snapshot: data, selection: { claimId: "hello" }, onClose: () => undefined, onSelect: () => undefined, onRefresh: () => undefined, onOpenFile: () => undefined }), ["detail.requirements_title", "detail.proof_title", "detail.evidence_title"]],
    ["proof graph", React(GraphView, { theme, compact: false, snapshot: data, mode: "proof", expanded: new Set<string>(["hello"]), onToggleClaim: () => undefined, selected: null, onSelect: () => undefined }), ["graph.links_note", "graph.kind_goal"]],
    ["settings screen", React(SettingsScreen, { theme }), ["settings.locale_label", "settings.locale_ru"]],
    ["permissions card", React(PermissionsCard, { theme, compact: false, runEnabled: false, decisionsEnabled: false, onOpenSettings: () => undefined }), ["permissions.title", "permissions.open_settings"]],
  ];
  for (const [name, element, keys] of russianScreens) {
    const markup = russian(element);
    for (const key of keys) {
      assert.ok(markup.includes(ru(key)), `the Russian ${name} does not show ${key}`);
      // A name that both languages spell alike — the name of a language itself —
      // is the same word in either language, so only a different word is missing.
      if (en(key) !== ru(key)) {
        assert.ok(!markup.includes(en(key)), `the Russian ${name} still shows the English text of ${key}`);
      }
    }
    process.stdout.write(`ok: ${name} rendered in Russian (${markup.length} bytes)\n`);
  }
  assert.ok(!brief.includes(ru("queue.accept_title")), "the brief of the agent stays in the language of the method");
  process.stdout.write("ok: the brief of the agent stays in English\n");
  process.stdout.write("render-check: PASS\n");
}

void main().catch((error) => {
  process.stderr.write(`render-check: FAIL ${String(error)}\n`);
  process.exitCode = 1;
});
