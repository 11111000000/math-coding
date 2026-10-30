#!/usr/bin/env tsx
/**
 * The render check: every view of the console, rendered with REAL data.
 *
 * The state comes from the kernel, through the same handler the daemon
 * runs. So this is not a snapshot of a shape someone imagined: it is the
 * corpus's own state, rendered by the console's own components.
 *
 * What it proves: each view renders without throwing, and renders the data
 * it is given. What it does NOT prove: how the console looks, and how it
 * behaves under the host's gestures. Those are checked by opening the
 * console in Paseo.
 *
 *   npx tsx scripts/render-check.ts <repository-root>
 */
import { renderToStaticMarkup } from "react-dom/server";
import { createElement, type ReactNode } from "react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { buildState } from "../server/handlers";
import { ActionsView } from "../client/actions-view";
import { DecisionSheet } from "../client/decision-sheet";
import { DecisionsView } from "../client/decisions-view";
import { EvidenceView } from "../client/evidence-view";
import { PromisesView } from "../client/promises-view";
import { ReviewSheet } from "../client/review-sheet";
import { ReviewView } from "../client/review-view";
import { VerdictView } from "../client/verdict-view";
import type { PluginTheme } from "@getpaseo/plugin";

const root = process.argv[2];
if (root === undefined) {
  console.error("usage: render-check.ts <repository-root>");
  process.exit(2);
}

const theme: PluginTheme = {
  colors: {
    surface0: "#111111",
    surface1: "#1a1a1a",
    surface2: "#222222",
    border: "#333333",
    foreground: "#eeeeee",
    foregroundMuted: "#999999",
    accent: "#4a9eff",
    accentForeground: "#ffffff",
    statusSuccess: "#3fb950",
    statusWarning: "#d29922",
    statusDanger: "#f85149",
  },
};

async function main() {
  const state = await buildState(root);
  if (state.root === null) {
    console.error(`render-check: ${state.rootError}`);
    process.exit(1);
  }

  const noop = () => undefined;
  const views: [string, () => ReactNode][] = [
    ["Verdict", () => createElement(VerdictView, { theme, state, onOpenDecision: noop })],
    [
      "Promises",
      () => createElement(PromisesView, { theme, promises: state.promises, onOpenDecision: noop }),
    ],
    [
      "Decisions",
      () => createElement(DecisionsView, { theme, decisions: state.decisions, onOpenDecision: noop }),
    ],
    [
      "Review",
      () =>
        createElement(ReviewView, {
          theme,
          queue: state.reviewQueue,
          onReview: noop,
          onOpenDecision: noop,
        }),
    ],
    ["Evidence", () => createElement(EvidenceView, { theme, state })],
    [
      "Actions",
      () => createElement(ActionsView, { theme, root: state.root, attestRunCommand: "", onRefresh: noop }),
    ],
    [
      "Decision sheet",
      () =>
        createElement(DecisionSheet, {
          theme,
          root: state.root,
          decisionId: state.decisions[0]?.id ?? null,
          open: false,
          onOpenChange: noop,
          onReview: noop,
        }),
    ],
    [
      "Review sheet",
      () =>
        createElement(ReviewSheet, {
          theme,
          root: state.root,
          producer: "human:render-check",
          decisionId: state.decisions[0]?.id ?? null,
          obligationId: state.decisions[0]?.id === undefined ? null : "the-obligation",
          agentId: null,
          open: false,
          onOpenChange: noop,
        }),
    ],
  ];

  // The Paseo app owns the query client; the views that fetch through it
  // need one to render at all.
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false, enabled: false } },
  });

  let failed = 0;
  for (const [name, render] of views) {
    try {
      const markup = renderToStaticMarkup(
        createElement(
          QueryClientProvider,
          { client: queryClient },
          createElement("div", null, render()),
        ),
      );
      if (markup.length === 0) {
        console.log(`FAIL: ${name} rendered nothing`);
        failed += 1;
        continue;
      }
      console.log(`ok: ${name} rendered ${markup.length} bytes`);
    } catch (error) {
      console.log(`FAIL: ${name} threw: ${String(error).split("\n")[0]}`);
      failed += 1;
    }
  }

  console.log();
  if (failed === 0) {
    console.log("render-check: PASS");
    return;
  }
  console.log(`render-check: FAIL (${failed} view(s))`);
  process.exit(1);
}

void main();
