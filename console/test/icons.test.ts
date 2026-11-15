import assert from "node:assert/strict";
import { readdir, readFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { hasIcon, resolveIcon } from "../src/icons";

/**
 * The icon names of the shared interface.
 *
 * The interface names its icons. The browser host has to draw every one of
 * them, so the names are collected from the interface and checked against the
 * resolution the host uses.
 */

const clientRoot = resolve(
  dirname(fileURLToPath(import.meta.url)),
  "../../plugin/math-coding-console/client",
);

async function sources(directory: string): Promise<string[]> {
  const entries = await readdir(directory, { withFileTypes: true });
  const files: string[] = [];
  for (const entry of entries) {
    const full = join(directory, entry.name);
    if (entry.isDirectory()) files.push(...(await sources(full)));
    else if (/\.tsx?$/.test(entry.name)) files.push(full);
  }
  return files;
}

function iconNames(source: string): string[] {
  const names = new Set<string>();
  const positions = [
    /\bicon\s*[=:]\s*(\{[^}]*\}|"[^"]*"|'[^']*')/g,
    /<Icon\s+name=["']([A-Z][A-Za-z0-9]*)["']/g,
  ];
  for (const pattern of positions) {
    for (const match of source.matchAll(pattern)) {
      for (const literal of (match[1] ?? "").matchAll(/["']([A-Z][A-Za-z0-9]*)["']/g)) {
        names.add(literal[1]);
      }
    }
  }
  return [...names];
}

test("every icon name of the interface resolves to an icon", async () => {
  const files = await sources(clientRoot);
  assert.ok(files.length > 0, "the interface was not found");
  const names = new Set<string>();
  for (const file of files) {
    for (const name of iconNames(await readFile(file, "utf8"))) names.add(name);
  }
  assert.ok(names.size > 10, `too few icon names were collected: ${String(names.size)}`);
  for (const name of [...names].sort()) {
    const resolved = resolveIcon(name);
    assert.equal(resolved.fallback, false, `the icon ${name} is not drawn`);
    assert.equal(resolved.name, name);
    assert.ok(hasIcon(name), `the icon ${name} is unknown`);
  }
});

test("an unknown icon name falls back instead of breaking the page", () => {
  const resolved = resolveIcon("ThisIconDoesNotExist");
  assert.equal(resolved.fallback, true);
  assert.equal(resolved.requested, "ThisIconDoesNotExist");
  assert.ok(resolved.component, "the fallback has no glyph");
});
