import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { createElement, type ComponentType, type ReactNode } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import mock from "mock-require";

/**
 * The shared console in a browser environment.
 *
 * The interface is written against React Native primitives. Here it is drawn
 * with react-native-web and rendered on the server, which proves that the
 * panel assembles and renders outside the Paseo plugin.
 */

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const consoleDir = resolve(here, "..");

// One React for the whole tree. The shared interface is loaded as CommonJS
// and would otherwise resolve a second copy of React and refuse to render.
mock("react", require("react"));
mock("react/jsx-runtime", require("react/jsx-runtime"));
mock("react-dom", require("react-dom"));
mock("@tanstack/react-query", require("@tanstack/react-query"));
mock("react-native", "react-native-web");

// The shared interface lies outside this project's tsconfig, so it is
// compiled with the classic JSX runtime. React is published for it.
(globalThis as { React?: unknown }).React = require("react");

const { QueryClient, QueryClientProvider } = require("@tanstack/react-query") as typeof import("@tanstack/react-query");
const { ConsolePanel } = await import("../../plugin/math-coding-console/client/console");
const { HostProvider } = await import("../../plugin/math-coding-console/client/host/context");
const { rpcSchemas } = await import("../../plugin/math-coding-console/shared/schemas");
const { preferencesDefinition } = await import("../../plugin/math-coding-console/shared/schemas");
const { createBrowserHost } = await import("../src/browser-host");
const { ToastProvider } = await import("../src/toast");
const { lightTheme } = await import("../src/theme");
const { snapshot } = await import("../../plugin/math-coding-console/test/fixtures");

const host = createBrowserHost();

interface PanelProps {
  theme: typeof lightTheme;
  layout: { compact: boolean };
  workspaceId: string;
}

const Panel = ConsolePanel as unknown as ComponentType<PanelProps>;

function render(element: ReactNode, queryClient: InstanceType<typeof QueryClient>): string {
  const panel = createElement(QueryClientProvider, { client: queryClient, children: element });
  return renderToStaticMarkup(
    createElement(
      ToastProvider,
      { children: createElement(HostProvider, { value: host, children: panel }) },
    ),
  );
}

function client(claims = 3): InstanceType<typeof QueryClient> {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false, enabled: false } } });
  const data = snapshot();
  data.map.claims = claims;
  data.map.states = data.claims.map((item) => ({ id: item.id, state: "holds" as const, source_changed: false }));
  queryClient.setQueryData(["mathcoding-snapshot", "local"], data);
  return queryClient;
}

test("the console panel renders with the browser host", () => {
  const markup = render(
    createElement(Panel, { theme: lightTheme, layout: { compact: false }, workspaceId: "local" }),
    client(),
  );
  assert.ok(markup.length > 500, `the panel rendered too little content: ${String(markup.length)}`);
  assert.ok(markup.includes("test the plugin"), "the goal of the project is missing");
  assert.ok(markup.includes("Attention"), "the attention view is missing");
});

test("the console panel renders without a snapshot", () => {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false, enabled: false } } });
  const markup = render(
    createElement(Panel, { theme: lightTheme, layout: { compact: false }, workspaceId: "local" }),
    queryClient,
  );
  assert.ok(markup.includes("Reading the canonical map"), "the loading state is missing");
});

test("the reason of a snapshot passes through the api and is rendered", async () => {
  const original = globalThis.fetch;
  const data = snapshot();
  data.map.states = [{ id: "hello", state: "outdated", source_changed: false, reason: "environment-changed" }];
  data.map.verdict = "unknown";
  data.map.exit = 3;
  globalThis.fetch = (async () => new Response(JSON.stringify(data), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  })) as typeof fetch;
  try {
    let call: ((input: unknown) => Promise<unknown>) | undefined;
    function Probe() {
      const rpc = host.useRpc(rpcSchemas.snapshot);
      call = rpc as unknown as (input: unknown) => Promise<unknown>;
      return null;
    }
    render(createElement(HostProvider, { value: host, children: createElement(Probe) }), client());
    assert.ok(call, "the rpc call was not created");

    const answer = (await call?.({ workspaceId: "local" })) as {
      status: string;
      map: { states: Array<{ reason?: string }> };
    };
    assert.equal(answer.status, "ready");
    assert.equal(answer.map.states[0]?.reason, "environment-changed", "the api did not keep the reason of the state");

    const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false, enabled: false } } });
    queryClient.setQueryData(["mathcoding-snapshot", "local"], answer);
    const markup = render(
      createElement(Panel, { theme: lightTheme, layout: { compact: false }, workspaceId: "local" }),
      queryClient,
    );
    assert.ok(
      markup.includes("The environment changed after the evidence was recorded"),
      "the page does not show the reason of the state",
    );
  } finally {
    globalThis.fetch = original;
  }
});

test("the browser host draws icons, modals and inputs", () => {
  const markup = render(
    createElement(
      "div",
      null,
      createElement(host.Icon, { name: "UserRoundCheck", size: 18, color: "#000000" }),
      createElement(host.Modal, { title: "Run project checks?", open: true, onOpenChange: () => undefined },
        createElement(host.Modal.Content, null, "The body of the modal")),
      createElement(host.TextInput, { value: "mathc", onChangeText: () => undefined, accessibilityLabel: "binary" }),
    ),
    client(),
  );
  assert.ok(markup.includes("<svg"), "the icon is not an svg");
  assert.ok(markup.includes("Run project checks?"), "the modal title is missing");
  assert.ok(markup.includes("The body of the modal"), "the modal body is missing");
  assert.ok(markup.includes("<input"), "the text input is missing");
});

test("the browser host draws the settings primitives", () => {
  const markup = render(
    createElement(
      "div",
      null,
      createElement(host.SettingsSection, { title: "General" },
        createElement(host.SettingsCard, null,
          createElement(host.SettingsInput, { label: "mathc path", initialValue: "/usr/bin/mathc" }),
          createElement(host.SettingsSelect, {
            label: "auto refresh",
            value: "30",
            options: [{ label: "30 seconds", value: "30" }],
            onValueChange: () => undefined,
          }),
          createElement(host.SettingsSwitch, { label: "allow runs", value: false, onValueChange: () => undefined }),
          createElement(host.SettingsAction, { label: "reset", actionLabel: "Reset", onPress: () => undefined }))),
    ),
    client(),
  );
  assert.ok(markup.includes("General"), "the settings section is missing");
  assert.ok(markup.includes("/usr/bin/mathc"), "the settings input is missing");
  assert.ok(markup.includes("30 seconds"), "the settings select is missing");
  assert.ok(markup.includes("Reset"), "the settings action is missing");
});

test("the rpc call of the browser host checks its contract", async () => {
  const original = globalThis.fetch;
  const answers: { status: number; body: unknown }[] = [];
  globalThis.fetch = (async () => {
    const answer = answers.shift() ?? { status: 200, body: snapshot() };
    return new Response(JSON.stringify(answer.body), {
      status: answer.status,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  try {
    let call: ((input: unknown) => Promise<unknown>) | undefined;
    function Probe() {
      const rpc = host.useRpc(rpcSchemas.snapshot);
      call = rpc as unknown as (input: unknown) => Promise<unknown>;
      return null;
    }
    render(createElement(HostProvider, { value: host, children: createElement(Probe) }), client());
    assert.ok(call, "the rpc call was not created");

    answers.push({ status: 200, body: snapshot() });
    const answer = (await call?.({ workspaceId: "local" })) as { status: string };
    assert.equal(answer.status, "ready");

    await assert.rejects(async () => call?.({ workspaceId: 42 }), /workspaceId/);

    answers.push({ status: 200, body: { status: "nonsense" } });
    await assert.rejects(async () => call?.({ workspaceId: "local" }));

    answers.push({ status: 500, body: { error: "the workspace is busy" } });
    await assert.rejects(async () => call?.({ workspaceId: "local" }), /busy/);
  } finally {
    globalThis.fetch = original;
  }
});

test("the settings of the browser host are read, written and reset", async () => {
  const original = globalThis.fetch;
  const requests: { url: string; method: string; body: unknown }[] = [];
  let answer: { status: string; revision?: string; values?: unknown; error?: string } = {
    status: "ready",
    revision: "revision-1",
    values: { binaryPath: "", allowRunChecks: false, autoRefreshSeconds: 30 },
  };
  globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url;
    requests.push({ url, method: init?.method ?? "GET", body: init?.body ? JSON.parse(String(init.body)) : undefined });
    return new Response(JSON.stringify(answer), { status: 200, headers: { "Content-Type": "application/json" } });
  }) as typeof fetch;
  try {
    let settings: ReturnType<typeof host.useSettings> | undefined;
    function Probe() {
      settings = host.useSettings(preferencesDefinition);
      return null;
    }
    const markup = render(createElement(HostProvider, { value: host, children: createElement(Probe) }), client());
    assert.ok(settings, "the settings state was not created");
    assert.equal(settings.status, "loading");
    assert.equal(settings.values, undefined);
    assert.ok(markup.length > 0);

    await settings.reload();
    assert.ok(requests.some((entry) => entry.url.endsWith("/api/settings") && entry.method === "GET"));

    answer = { status: "saved", revision: "revision-2", values: { binaryPath: "", allowRunChecks: true, autoRefreshSeconds: 15 } };
    const saved = await settings.save(
      { binaryPath: "", allowRunChecks: true, autoRefreshSeconds: 15 },
      "revision-1",
    );
    assert.equal(saved, true);
    const write = requests.find((entry) => entry.method === "POST" && entry.url.endsWith("/api/settings"));
    assert.ok(write, "the settings were not written");
    assert.deepEqual(write.body, {
      revision: "revision-1",
      values: { binaryPath: "", allowRunChecks: true, autoRefreshSeconds: 15 },
    });

    answer = { status: "conflict", error: "the settings changed" };
    const refused = await settings.save(
      { binaryPath: "", allowRunChecks: true, autoRefreshSeconds: 15 },
      "revision-1",
    );
    assert.equal(refused, false);

    answer = { status: "saved", revision: "revision-3", values: { binaryPath: "", allowRunChecks: false, autoRefreshSeconds: 30 } };
    const reset = await settings.reset();
    assert.equal(reset, true);
    assert.ok(requests.some((entry) => entry.url.endsWith("/api/settings/reset") && entry.method === "POST"));
  } finally {
    globalThis.fetch = original;
  }
});
