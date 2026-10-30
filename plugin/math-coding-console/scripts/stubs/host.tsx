/**
 * Stubs for the host modules the console's client half imports.
 *
 * `@getpaseo/plugin/client` and `@getpaseo/plugin/client/ui` are supplied by
 * the Paseo app. In Node they are replaced by the smallest thing that lets a
 * view render: the hooks return the data the caller already has, and the
 * widgets are plain elements.
 *
 * The point is to RENDER, not to pretend. A view that calls a hook the host
 * does not have, or a widget that does not exist, throws here exactly as it
 * would in the app.
 */
import { createElement, type ReactNode } from "react";

type Props = Record<string, unknown> & { children?: ReactNode };

const NATIVE_ONLY = new Set([
  "accessibilityRole",
  "accessibilityState",
  "accessibilityLabel",
  "numberOfLines",
  "onPress",
  "onValueChange",
  "onChangeText",
  "placeholder",
  "multiline",
  "testID",
  "initialValue",
  "actionLabel",
  "active",
  "icon",
  "label",
  "open",
  "onOpenChange",
  "title",
  "variant",
  "disabled",
  "tone",
]);

function host(tag: string) {
  return function Host(props: Props) {
    const children = props.children;
    const rest: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(props)) {
      if (key === "children" || NATIVE_ONLY.has(key)) continue;
      rest[key] = value;
    }
    return createElement(tag, rest, children);
  };
}

/* ------------------------------------------------------------ @getpaseo/plugin/client */

export function useRpc(_contract: unknown) {
  return async (_input: unknown) => {
    throw new Error("useRpc: the render check does not call the daemon");
  };
}

export function useWorkspace(_id: string, selector: (workspace: unknown) => unknown) {
  return selector({ id: "w", directory: null, projectRootPath: null });
}

export function useAgent(_id: string, selector: (agent: unknown) => unknown) {
  return selector({ id: "a", cwd: null });
}

export function useSettings(_definition: unknown) {
  return {
    status: "ready" as const,
    revision: "r",
    values: {
      repoRoot: "",
      kernelPath: "",
      reviewProducer: "human:render-check",
      attestRunCommand: "",
      refreshSeconds: 0,
    },
    saving: false,
    saveError: null,
    save: async () => true,
    reset: async () => true,
    reload: async () => undefined,
  };
}

export function usePaseo() {
  return {};
}

export const openExternalUrl = async (_url: string) => undefined;

/* --------------------------------------------------------- @getpaseo/plugin/client/ui */

export const Icon = host("i");
export const SidebarRow = host("button");
export const SidebarSeparator = host("hr");
export const Loading = host("div");
export const DocumentFrame = host("iframe");
export const Markdown = host("div");
export const ScrollView = host("div");
export const FlatList = host("div");
export const TextInput = host("input");
export const StreamedText = host("span");
export const copyText = async (_text: string) => undefined;

export function useToast() {
  return { show: (_message: string, _options?: unknown) => undefined, error: (_message: string) => undefined };
}

export const Modal = Object.assign(host("div"), {
  Content: host("section"),
});

export const SettingsSection = host("section");
export const SettingsCard = host("div");
export const SettingsRow = host("div");
export const SettingsSwitch = host("div");
export const SettingsSelect = host("div");
export const SettingsInput = host("div");
export const SettingsAction = host("div");
export const ExternalLink = host("a");
