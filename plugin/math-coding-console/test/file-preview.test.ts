import assert from "node:assert/strict";
import { createElement } from "react";
import { act } from "react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import TestRenderer from "react-test-renderer";
import test from "node:test";
// The stub is loaded first: it draws the interface with react-native-web, so
// the component must be read after the stub replaced react-native.
import { host } from "./host-stub";
import { theme } from "./fixtures";
import { FilePreview } from "../client/file-preview";
import { HostProvider } from "../client/host/context";

const React = createElement;

// React asks the environment to announce that it supports act().
(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;

/** Lets the read of the file settle inside the renderer. */
async function settle(): Promise<void> {
  await act(async () => {
    await new Promise((resolve) => setTimeout(resolve, 0));
  });
}

/**
 * Waits for the preview to show the file.
 *
 * The read of the file is asynchronous, so the check waits for it instead of
 * assuming that one tick is enough. The wait is bounded: a preview that never
 * shows the file fails the check instead of hanging it.
 */
async function waitFor(predicate: () => boolean): Promise<boolean> {
  for (let attempt = 0; attempt < 100; attempt += 1) {
    if (predicate()) return true;
    await act(async () => {
      await new Promise((resolve) => setTimeout(resolve, 5));
    });
  }
  return predicate();
}

/**
 * The file preview of the panel.
 *
 * The panel asks for a file by handing the preview a path. The preview must
 * open for that path even when the path arrives after the panel was drawn:
 * the human clicks "Open" long after the first screen appeared.
 */

function draw(path: string | null) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const tree = (current: string | null) =>
    React(
      QueryClientProvider,
      { client },
      React(
        HostProvider,
        { value: host, children: React(FilePreview, {
          theme,
          compact: false,
          workspaceId: "workspace-1",
          path: current,
          onClose: () => undefined,
        }) },
      ),
    );
  let renderer: TestRenderer.ReactTestRenderer | undefined;
  act(() => {
    renderer = TestRenderer.create(tree(path));
  });
  return {
    renderer: renderer!,
    update: async (next: string | null) => {
      await act(async () => {
        renderer!.update(tree(next));
        await Promise.resolve();
      });
      await settle();
    },
    markup: () => JSON.stringify(renderer!.toJSON()),
  };
}

test("the preview stays closed while no file is asked for", () => {
  const preview = draw(null);
  assert.equal(preview.markup(), "null");
});

test("a file that is asked for after the panel was drawn opens the preview", async () => {
  const preview = draw(null);
  await preview.update("docs/adr.md");
  assert.ok(preview.markup().includes("docs/adr.md"), "the preview did not open for the requested file");
  assert.ok(await waitFor(() => preview.markup().includes("the subject of the claim")), "the preview did not show the file");
});

test("a file that is asked for before the panel was drawn opens the preview too", async () => {
  const preview = draw("docs/adr.md");
  assert.ok(preview.markup().includes("docs/adr.md"), "the preview did not open for the requested file");
  assert.ok(await waitFor(() => preview.markup().includes("the subject of the claim")), "the preview did not show the file");
});
