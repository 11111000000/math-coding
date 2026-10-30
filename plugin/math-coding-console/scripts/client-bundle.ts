#!/usr/bin/env tsx
/**
 * The client bundle, compiled the way the host compiles it, and evaluated.
 *
 * The Paseo app loads a plugin's client half as SOURCE and evaluates it with
 * a module resolver that offers exactly these modules:
 *
 *   react, react/jsx-runtime, react-native,
 *   @getpaseo/plugin, @getpaseo/plugin/client,
 *   @getpaseo/plugin/client/ui, @getpaseo/plugin/client/react-native,
 *   @tanstack/react-query, zod
 *
 * Anything else is a runtime error in the app, and a client half that
 * imports `server/` or a `node:` builtin is a compile error there and
 * nowhere else. This bundle is built with the same allowlist, so a
 * violation fails HERE instead of in the app, where nobody is watching.
 *
 * The bundle is then evaluated and its default export checked: the host
 * requires a function, and a plugin that default-exports anything else
 * never registers.
 */
import { build } from "esbuild";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "..");
const require = createRequire(import.meta.url);

const ALLOWED = [
  "react",
  "react/jsx-runtime",
  "react-native",
  "@getpaseo/plugin",
  "@getpaseo/plugin/client",
  "@getpaseo/plugin/client/ui",
  "@getpaseo/plugin/client/react-native",
  "@tanstack/react-query",
  "zod",
];

const stubs = join(here, "stubs");

/**
 * Every file the client half can reach: the client entry, the client
 * directory, and the shared directory (the shared code is compiled into
 * the client bundle too, so a `node:` import there is a client-side
 * violation as well).
 */
function clientSources(root: string): string[] {
  const files: string[] = [join(root, "index.client.tsx")];
  for (const directory of ["client", "shared"]) {
    const base = join(root, directory);
    if (!existsSync(base)) continue;
    for (const name of readdirSync(base)) {
      const path = join(base, name);
      if (statSync(path).isDirectory()) {
        for (const nested of readdirSync(path)) {
          if (nested.endsWith(".ts") || nested.endsWith(".tsx")) {
            files.push(join(path, nested));
          }
        }
      } else if (name.endsWith(".ts") || name.endsWith(".tsx")) {
        files.push(path);
      }
    }
  }
  return files;
}

async function main() {
  const result = await build({
    entryPoints: [join(root, "index.client.tsx")],
    bundle: true,
    write: false,
    platform: "neutral",
    format: "cjs",
    target: "es2022",
    jsx: "automatic",
    logLevel: "error",
    external: ALLOWED,
    alias: {
      "react-native": join(stubs, "react-native.tsx"),
      "@getpaseo/plugin/client/ui": join(stubs, "host.tsx"),
      "@getpaseo/plugin/client": join(stubs, "host.tsx"),
      "@getpaseo/plugin/client/react-native": join(stubs, "react-native.tsx"),
    },
  });

  const output = result.outputFiles?.[0];
  if (!output) {
    console.log("FAIL: the client bundle produced no output");
    process.exit(1);
  }

  const source = output.text;
  console.log(`ok: the client bundle compiles (${source.length} bytes)`);

  // The allowlist, checked on the SOURCE rather than on the bundle. A
  // bundle is tree-shaken, so an import that is never used disappears from
  // it — and the rule the host enforces is about the import, not about the
  // bytes that survive.
  const foreign = new Set<string>();
  for (const file of clientSources(root)) {
    const text = readFileSync(file, "utf8");
    for (const match of text.matchAll(/\bfrom\s*["']([^"']+)["']/g)) {
      const name = match[1] ?? "";
      if (name.startsWith(".") || name.startsWith("/")) continue;
      if (!ALLOWED.includes(name)) foreign.add(`${name} (in ${file.slice(root.length + 1)})`);
    }
    for (const match of text.matchAll(/\bimport\s*\(\s*["']([^"']+)["']\s*\)/g)) {
      const name = match[1] ?? "";
      if (name.startsWith(".") || name.startsWith("/")) continue;
      if (!ALLOWED.includes(name)) foreign.add(`${name} (in ${file.slice(root.length + 1)})`);
    }
  }
  if (foreign.size === 0) {
    console.log("ok: the client half imports nothing the host does not offer");
  } else {
    console.log(`FAIL: the client half imports ${[...foreign].join(", ")}`);
    process.exit(1);
  }

  // The evaluation. The host does this with its own module resolver; here
  // the same stubs stand in, and the question is only whether the bundle
  // EVALUATES and default-exports a function.
  const module_ = { exports: {} as Record<string, unknown> };
  const hostRequire = (name: string): unknown => {
    if (name === "react" || name === "react/jsx-runtime") return require(name);
    if (name === "zod") return require(name);
    if (name === "@tanstack/react-query") return require(name);
    if (name === "react-native") return require(join(stubs, "react-native.tsx"));
    if (name.startsWith("@getpaseo/plugin/client/ui")) return require(join(stubs, "host.tsx"));
    if (name.startsWith("@getpaseo/plugin/client")) return require(join(stubs, "host.tsx"));
    if (name.startsWith("@getpaseo/plugin")) return { defineRpc: () => ({}), defineSettings: () => ({}) };
    throw new Error(`Module "${name}" is not available in plugin client code`);
  };

  const evaluate = new Function("module", "exports", "require", source);
  try {
    evaluate(module_, module_.exports, hostRequire);
  } catch (error) {
    console.log(`FAIL: the bundle threw while evaluating: ${String(error).split("\n")[0]}`);
    process.exit(1);
  }

  const exported = (module_.exports as { default?: unknown }).default;
  if (typeof exported !== "function") {
    console.log("FAIL: the bundle does not default-export a function");
    process.exit(1);
  }
  console.log("ok: the bundle evaluates and default-exports a function");

  console.log();
  console.log("client-bundle: PASS");
}

void main();
