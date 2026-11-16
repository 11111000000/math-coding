import { readdir, readFile } from "node:fs/promises";

/**
 * How many places of the machine does one package come from?
 *
 * The local page is built from the sources of two packages: the page itself
 * and the plugin package that holds the shared interface. Both carry their
 * own node_modules, so the bundle may hold two copies of React or of the
 * data layer. Two copies break the hooks of the shared interface, and the
 * page then mounts nothing.
 *
 * The build with a source map names every module of the bundle and the
 * directory it came from. This script counts the directories one package
 * was taken from.
 *
 * Usage: node bundle-copies.mjs DIST/assets
 */

const directory = process.argv[2];
if (!directory) {
  process.stderr.write("usage: node bundle-copies.mjs DIST/assets\n");
  process.exit(2);
}

const files = (await readdir(directory)).filter((name) => name.endsWith(".js.map"));
if (files.length === 0) {
  process.stderr.write(`bundle-copies: no source map in ${directory}\n`);
  process.exit(1);
}

const roots = new Map();
for (const file of files) {
  const map = JSON.parse(await readFile(`${directory}/${file}`, "utf8"));
  for (const source of map.sources ?? []) {
    const match = /^(.*?)node_modules\/((?:@[^/]+\/)?[^/]+)/.exec(source);
    if (!match) continue;
    const [, root, name] = match;
    const places = roots.get(name) ?? new Set();
    places.add(root);
    roots.set(name, places);
  }
}

let failures = 0;
for (const name of ["react", "react-dom", "@tanstack/react-query"]) {
  const places = roots.get(name);
  const count = places ? places.size : 0;
  process.stdout.write(`bundle-copies: ${name} comes from ${String(count)} place(s)\n`);
  if (count !== 1) {
    failures += 1;
  }
}

if (failures > 0) {
  process.stderr.write("bundle-copies: the bundle carries more than one copy of a package\n");
  process.exit(1);
}
