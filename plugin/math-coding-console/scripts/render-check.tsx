import assert from "node:assert/strict";
import { createElement, type ComponentType, type ReactNode } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import mock from "mock-require";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { theme, snapshot } from "../test/fixtures";

const React = createElement;
const Icon = ({ name }: { name: string }) => React("span", { "data-icon": name });
const Modal = ({ children, open }: { children: ReactNode; open: boolean }) => open ? children : null;
Modal.Content = ({ children }: { children: ReactNode }) => children;
const TextInput = ({ accessibilityLabel, placeholderTextColor: _color, ...props }: Record<string, unknown>) => React("input", { ...props, readOnly: true, "aria-label": accessibilityLabel });
const PassThrough = ({ children }: { children?: ReactNode }) => React("div", null, children);
const SettingsInput = ({ accessibilityLabel, initialValue }: { accessibilityLabel?: string; initialValue?: string }) => React("input", { readOnly: true, defaultValue: initialValue, "aria-label": accessibilityLabel });
const SettingsSelect = ({ accessibilityLabel }: { accessibilityLabel?: string }) => React("select", { readOnly: true, "aria-label": accessibilityLabel });
const SettingsAction = ({ actionLabel }: { actionLabel: string }) => React("button", { type: "button" }, actionLabel);
const SettingsSwitch = ({ label, accessibilityLabel }: { label?: string; accessibilityLabel?: string }) => React("div", null, label, React("input", { type: "checkbox", readOnly: true, "aria-label": accessibilityLabel ?? label }));

mock("react-native", "react-native-web");
mock("@getpaseo/plugin/client/ui", {
  Icon,
  Modal,
  TextInput,
  useToast: () => ({ show: () => undefined, error: () => undefined }),
  SettingsSection: PassThrough,
  SettingsCard: PassThrough,
  SettingsInput,
  SettingsSelect,
  SettingsAction,
  SettingsSwitch,
});
mock("@getpaseo/plugin/client", {
  useRpc: () => async () => snapshot(),
  useSettings: () => ({
    status: "ready",
    values: { binaryPath: "", allowRunChecks: false, autoRefreshSeconds: 30 },
    revision: "revision",
    saving: false,
    saveError: null,
    save: async () => true,
    reset: async () => true,
    reload: async () => undefined,
  }),
});

async function main() {
  const [
    { InstrumentFrame },
    { GraphView },
    { ClaimsView },
    { CoverageView },
    { ClaimDetailView },
    { EvidenceView },
    { ConsolePanel },
    { SettingsScreen },
  ] = await Promise.all([
    import("../client/frame"),
    import("../client/graph"),
    import("../client/claims"),
    import("../client/coverage"),
    import("../client/detail"),
    import("../client/evidence"),
    import("../client/console"),
    import("../client/settings"),
  ]);
  const data = snapshot();
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false, enabled: false } } });
  queryClient.setQueryData(["mathcoding-snapshot", "workspace-1"], data);
  const render = (element: ReactNode) => renderToStaticMarkup(
    React(QueryClientProvider, { client: queryClient }, element),
  );
  const frameProps = {
    theme,
    compact: false,
    snapshot: data,
    onRefresh: () => undefined,
    refreshing: false,
    onRun: () => undefined,
    running: false,
    runEnabled: true,
  };
  const views: [string, ReactNode][] = [
    ["instrument frame", React(InstrumentFrame, frameProps)],
    ["proof graph", React(GraphView, { theme, compact: false, snapshot: data, mode: "proof", expanded: new Set<string>(["hello"]), onToggleClaim: () => undefined, selected: null, onSelect: () => undefined })],
    ["scope graph", React(GraphView, { theme, compact: true, snapshot: data, mode: "scope", expanded: new Set<string>(), onToggleClaim: () => undefined, selected: null, onSelect: () => undefined })],
    ["claims", React(ClaimsView, { theme, compact: false, snapshot: data, onSelect: () => undefined })],
    ["coverage", React(CoverageView, { theme, compact: true, snapshot: data, onSelect: () => undefined, onOpenScope: () => undefined })],
    ["claim detail", React(ClaimDetailView, { theme, compact: false, snapshot: data, selection: { claimId: "hello" }, onClose: () => undefined, onSelect: () => undefined, onRefresh: () => undefined })],
    ["evidence", React(EvidenceView, { theme, compact: false, snapshot: data })],
    ["console panel", React(ConsolePanel as unknown as ComponentType<Record<string, unknown>>, { theme, layout: { compact: false }, workspaceId: "workspace-1" })],
    ["settings screen", React(SettingsScreen as unknown as ComponentType<Record<string, unknown>>, { theme })],
  ];
  for (const [name, element] of views) {
    const markup = render(element);
    assert.ok(markup.length > 100, `${name} rendered too little content`);
    if (name === "console panel") {
      assert.ok(markup.includes("test the plugin"));
      assert.ok(markup.includes("Run checks are disabled"));
    }
    process.stdout.write(`ok: ${name} rendered ${markup.length} bytes\n`);
  }
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
