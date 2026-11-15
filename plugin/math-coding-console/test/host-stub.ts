import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { createElement, type ReactNode } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import mock from "mock-require";
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
import { rpcSchemas } from "../shared/schemas";
import { snapshot } from "./fixtures";

const React = createElement;

/**
 * The host stub.
 *
 * The shared interface reaches the host through the contract only, so the
 * checks build a stub implementation of that contract instead of replacing
 * host modules. The stub is shared by the render check and the tests, so both
 * draw the same interface.
 */
const Icon = ({ name }: HostIconProps) => React("span", { "data-icon": name });
const Modal = Object.assign(
  // The stub behaves like the real hosts: a closed modal draws nothing. A
  // preview that never opens therefore cannot hide behind a drawn body.
  ({ children, open }: HostModalProps) => (open ? children : null),
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

export const host: HostContextValue = {
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
  useRpc: ((contract: unknown) => async () =>
    contract === rpcSchemas.file
      ? { kind: "file", path: "docs/adr.md", content: "the subject of the claim\n", bytes: 25, truncated: false, binary: false }
      : snapshot()) as unknown as HostContextValue["useRpc"],
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

// The shared interface is written against React Native primitives. The checks
// draw it with react-native-web, which renders on the server.
mock("react-native", "react-native-web");

/** Draws an element with the stub host around it. */
export function renderWithHost(element: ReactNode, queryClient?: QueryClient): string {
  const client = queryClient ?? new QueryClient({ defaultOptions: { queries: { retry: false, enabled: false } } });
  return renderToStaticMarkup(
    React(QueryClientProvider, { client }, React(HostProvider, { value: host, children: element })),
  );
}
