import assert from "node:assert/strict";
import test from "node:test";
import { previewChild, previewIsOpen, previewParent, previewTarget } from "../client/preview-target";

/**
 * The rules of the file preview.
 *
 * The panel decides whether the preview is open. A path that arrives after the
 * panel was rendered opens the preview exactly like a path that was there from
 * the start: the preview never decides that on its own and never keeps a path
 * from the moment it was mounted.
 */

test("the preview is open while the panel asks for a path", () => {
  assert.equal(previewIsOpen(null), false);
  assert.equal(previewIsOpen("docs/adr.md"), true);
});

test("a path that arrives later opens the preview", () => {
  assert.equal(previewTarget("docs/adr.md", null), "docs/adr.md");
  assert.equal(previewIsOpen("docs/adr.md"), true);
});

test("without a path the preview shows nothing", () => {
  assert.equal(previewTarget(null, null), null);
  assert.equal(previewIsOpen(null), false);
});

test("the navigation inside the preview does not change the requested path", () => {
  assert.equal(previewTarget("docs", "docs/adr.md"), "docs/adr.md");
  assert.equal(previewTarget("docs/adr.md", null), "docs/adr.md");
});

test("the parent of a path is the directory that holds it", () => {
  assert.equal(previewParent("docs/adr.md"), "docs");
  assert.equal(previewParent("docs/sub/adr.md"), "docs/sub");
  assert.equal(previewParent("adr.md"), null);
  assert.equal(previewParent(null), null);
});

test("a child of a directory keeps the path of the panel", () => {
  assert.equal(previewChild("docs", "adr.md"), "docs/adr.md");
  assert.equal(previewChild(null, "adr.md"), "adr.md");
});
