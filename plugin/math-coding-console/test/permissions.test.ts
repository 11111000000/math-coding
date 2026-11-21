import assert from "node:assert/strict";
import { createElement } from "react";
import { act } from "react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import TestRenderer from "react-test-renderer";
import test from "node:test";
// The stub is loaded first: it draws the interface with react-native-web, so
// the component must be read after the stub replaced react-native.
import { host, renderWithHost } from "./host-stub";
import { claim, snapshot, theme } from "./fixtures";
import { Pressable } from "react-native";
import { HostProvider } from "../client/host/context";
import { LocaleProvider } from "../client/i18n";
import { ConsolePanel } from "../client/console";
import { PermissionsCard } from "../client/permissions";
import { InstrumentFrame } from "../client/frame";
import { QueueView } from "../client/queue-view";
import { attentionContext, buildAttentionModel } from "../client/attention";
import { buildHumanQueue } from "../client/human-queue";
import { humanActions } from "../shared/human-actions";
import type { HostContextValue } from "../client/host/contract";

const React = createElement;

// React asks the environment to announce that it supports act().
(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;

/**
 * The console explains what it can do.
 *
 * Two permissions of the host are closed by default: the run of the checks and
 * the record of a decision of the human. A button that is closed without a
 * reason is a button nobody can read, so the console names the switch that
 * opens it and offers the way to the settings of the host. The check draws the
 * panel with the permissions closed, as the host keeps them, and asks the
 * panel to name both switches and to open the settings when the human says
 * so.
 */

/** The panel of the console with the permissions of the host closed. */
function drawPanel(hostValue: HostContextValue = host) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false, enabled: false } } });
  client.setQueryData(["mathcoding-snapshot", "workspace-1"], snapshot());
  let renderer: TestRenderer.ReactTestRenderer | undefined;
  act(() => {
    renderer = TestRenderer.create(
      React(
        QueryClientProvider,
        { client },
        React(
          HostProvider,
          { value: hostValue, children: React(LocaleProvider, { children: React(ConsolePanel, { theme, layout: { compact: false }, workspaceId: "workspace-1" }) }) },
        ),
      ),
    );
  });
  return {
    renderer: renderer!,
    markup: () => JSON.stringify(renderer!.toJSON()),
  };
}

test("the panel names the switch that opens every closed permission", () => {
  const panel = drawPanel();
  const markup = panel.markup();
  assert.ok(markup.includes("Allow Run checks"), "the panel does not name the switch of the run");
  assert.ok(markup.includes("Allow human decisions"), "the panel does not name the switch of the decisions");
});


test("the card names the switch that opens a closed permission", () => {
  const markup = renderWithHost(
    React(PermissionsCard, {
      theme,
      compact: false,
      runEnabled: false,
      decisionsEnabled: false,
      onOpenSettings: () => undefined,
    }),
  );
  assert.ok(markup.includes("Allow Run checks"), "the card does not name the switch of the run");
  assert.ok(markup.includes("Allow human decisions"), "the card does not name the switch of the decisions");
});

test("the panel says what works while a permission is closed", () => {
  const panel = drawPanel();
  assert.ok(
    panel.markup().includes("Reading the map, the evidence, the briefs and the navigation always works"),
    "the panel does not say what it can do",
  );
});

test("the panel opens the settings of the host when the human asks for them", () => {
  let opened = 0;
  const panel = drawPanel({ ...host, openSettings: () => { opened += 1; } });
  const buttons = panel.renderer.root.findAllByType(Pressable);
  const settings = buttons.find((button) => button.props.accessibilityLabel === "Open the Math Coding settings");
  assert.ok(settings, "the panel does not offer the settings of the host");
  act(() => {
    settings!.props.onPress();
  });
  assert.equal(opened, 1, "the panel did not open the settings of the host");
});


test("the frame names the switch that opens a closed run", () => {
  const data = snapshot();
  const attention = buildAttentionModel(data, 1_000);
  const markup = renderWithHost(
    React(InstrumentFrame, {
      theme,
      compact: false,
      snapshot: data,
      attention,
      onRefresh: () => undefined,
      refreshing: false,
      onRun: () => undefined,
      running: false,
      runEnabled: false,
    }),
  );
  assert.ok(markup.includes("Run checks are closed."), "the frame does not say that the run is closed");
});

test("the queue names the switch that opens a closed decision", () => {
  const changed = claim({
    id: "changed",
    source: { kind: "madr", path: "docs/adr.md", section: null, digest: "a".repeat(64), review: null },
  });
  const data = snapshot([changed]);
  data.map.states = [{ id: changed.id, state: "outdated", source_changed: true }];
  const attention = buildAttentionModel(data, 1_000);
  const context = attentionContext(data, attention);
  const queue = buildHumanQueue(data, attention, []);
  const actions = humanActions({ claims: data.claims, states: data.map.states, policyConfigured: false }, 1_000);
  const markup = renderWithHost(
    React(QueueView, {
      theme,
      compact: false,
      queue,
      context,
      actions,
      decisionsEnabled: false,
      onTakeAction: () => undefined,
      onOpenFile: () => undefined,
      onSelect: () => undefined,
    }),
  );
  assert.ok(markup.includes("Human decisions are closed."), "the queue does not say that the decisions are closed");
});

test("the card of the permissions is absent when every permission is open", () => {
  const markup = renderWithHost(
    React(PermissionsCard, {
      theme,
      compact: false,
      runEnabled: true,
      decisionsEnabled: true,
      onOpenSettings: () => undefined,
    }),
  );
  assert.equal(markup, "", "the panel draws the card of the permissions for an open console");
});

test("the card of the permissions says that the settings are still loading", () => {
  const markup = renderWithHost(
    React(PermissionsCard, {
      theme,
      compact: false,
      runEnabled: null,
      decisionsEnabled: null,
      onOpenSettings: () => undefined,
    }),
  );
  assert.ok(markup.includes("the settings are still loading"), "the card does not wait for the settings");
});
