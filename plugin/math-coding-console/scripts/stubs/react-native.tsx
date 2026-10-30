/**
 * A stand-in for `react-native`, so the console's views can be rendered in
 * Node.
 *
 * The console's client half runs inside the Paseo app, where React Native
 * provides the primitives. This module provides the same primitives as plain
 * host elements, which is enough to RENDER a view and to see it throw.
 *
 * What this proves: a view renders without throwing, with real data, in the
 * order the console shows it. What it does NOT prove: how the view LOOKS on a
 * phone, and how it behaves under the host's gestures and layout. Those are
 * the host's business and are checked by opening the console in Paseo.
 */
import { createElement, type ReactNode } from "react";

type Props = Record<string, unknown> & { children?: ReactNode };

/**
 * The props React Native knows and a DOM element does not. They are dropped
 * rather than passed on, because react-dom warns about every one of them
 * and the warnings would drown the output.
 */
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
  "secureTextEntry",
  "initialValue",
  "actionLabel",
  "scrollable",
  "contentContainerStyle",
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

export const View = host("div");
export const Text = host("span");
export const ScrollView = host("div");
export const Pressable = host("button");
// An <input> would make react-dom complain about a controlled value with no
// onChange; the point of the stub is to render, not to be a form.
export const TextInput = host("div");

export function FlatList<Item>(props: Props & { data?: readonly Item[]; renderItem?: (info: { item: Item }) => ReactNode }) {
  const { data, renderItem, ...rest } = props;
  const items = Array.isArray(data) ? data : [];
  return createElement(
    "div",
    rest,
    items.map((item, index) =>
      renderItem ? renderItem({ item, index: index } as { item: Item }) : null,
    ),
  );
}

export const StyleSheet = {
  create<T extends Record<string, unknown>>(styles: T): T {
    return styles;
  },
  flatten(style: unknown): unknown {
    return style;
  },
  absoluteFill: {},
  hairlineWidth: 1,
};

export const Platform = { OS: "linux" as const, select: <T,>(spec: { [key: string]: T }): T => spec.linux as T };

export const Linking = {
  openURL: async (_url: string) => undefined,
};

export default { View, Text, ScrollView, Pressable, TextInput, FlatList, StyleSheet, Platform, Linking };
