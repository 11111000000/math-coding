import assert from "node:assert/strict";
import { createElement, Fragment, type ReactNode } from "react";
import { act } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import TestRenderer from "react-test-renderer";
import test from "node:test";
// The stub is loaded first: it draws the interface with react-native-web, so
// the component must be read after the stub replaced react-native.
import { host, renderWithHost } from "./host-stub";
import { snapshot, theme } from "./fixtures";
import { ClaimDetailView } from "../client/detail";
import { HostModalContent } from "../client/host/sheet";
import { HostProvider } from "../client/host/context";
import { Button } from "../client/parts";
import type { HostContextValue, HostModalProps } from "../client/host/contract";

const React = createElement;

// React asks the environment to announce that it supports act().
(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;

/**
 * A host that draws its sheet the way a phone draws it.
 *
 * The host draws the sheet through a portal that stands outside the tree of
 * the panel, so the context of the plugin does not reach the content of the
 * sheet. The host re-establishes its own contexts for the sheet, the query
 * client among them; the plugin context is the one the host cannot restore.
 *
 * The check draws the content of the sheet in a tree of its own: the same
 * situation. The desktop path of the host uses a real portal, and a real portal
 * keeps the context, so the failure this check guards against is invisible on
 * the desktop and takes the whole host down on a phone.
 */
function sheetHost(): { value: HostContextValue; sheet: () => string } {
  let sheet = "";
  const client = new QueryClient({ defaultOptions: { queries: { retry: false, enabled: false } } });
  const Modal = Object.assign(
    ({ children, open }: HostModalProps) => (open ? children : null),
    {
      Content: ({ children }: { children?: ReactNode }) => {
        sheet = renderToStaticMarkup(
          React(QueryClientProvider, { client }, React(Fragment, null, children)),
        );
        return null;
      },
    },
  );
  return { value: { ...host, Modal }, sheet: () => sheet };
}

/** The claim card of the queue, opened the way the host opens it on a phone. */
function openDetail(): string {
  const sheet = sheetHost();
  renderWithHost(
    React(ClaimDetailView, {
      theme,
      compact: true,
      snapshot: snapshot(),
      selection: { claimId: "hello" },
      onClose: () => undefined,
      onSelect: () => undefined,
      onRefresh: () => undefined,
      onOpenFile: () => undefined,
    }),
    undefined,
    sheet.value,
  );
  return sheet.sheet();
}

test("the claim detail of the queue opens in the sheet of the host", () => {
  const sheet = openDetail();
  assert.ok(sheet.length > 0, "the sheet of the host drew nothing");
  assert.ok(sheet.includes("hello"), "the sheet did not show the claim");
  assert.ok(sheet.includes("the command prints hello"), "the sheet did not show the text of the claim");
});

test("the surface of the host is available inside the sheet", () => {
  // The button draws the icon of the host, so it cannot be drawn without the
  // surface of the host.
  const sheet = sheetHost();
  renderWithHost(
    React(HostModalContent, {
      children: React(Button, { theme, label: "the host", onPress: () => undefined }),
    }),
    undefined,
    sheet.value,
  );
  assert.ok(sheet.sheet().includes("the host"), "the sheet drew nothing");
});

test("a failure inside the sheet does not take the host down", () => {
  const failing = () => {
    throw new Error("the view cannot be drawn");
  };
  const client = new QueryClient({ defaultOptions: { queries: { retry: false, enabled: false } } });
  let renderer: TestRenderer.ReactTestRenderer | undefined;
  const previous = console.error;
  console.error = () => undefined;
  try {
    act(() => {
      renderer = TestRenderer.create(
        React(
          QueryClientProvider,
          { client },
          React(
            HostProvider,
            {
              value: host,
              children: React(HostModalContent, { children: React(failing) }),
            },
          ),
        ),
      );
    });
  } finally {
    console.error = previous;
  }
  const markup = JSON.stringify(renderer!.toJSON());
  assert.ok(markup.includes("could not be drawn"), "the sheet did not report the failure");
});
