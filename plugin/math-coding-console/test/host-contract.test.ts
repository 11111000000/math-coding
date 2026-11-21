import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import type { output as ZodOutput } from "zod";
import type {
  HostContextValue,
  HostRpcContract,
  HostSettingsDefinition,
  HostSettingsState,
} from "../client/host/contract";

const here = fileURLToPath(new URL(".", import.meta.url));
const clientDir = join(here, "..", "client");
const hostAdapter = join("host", "paseo.tsx");

function clientFiles(): string[] {
  return readdirSync(clientDir, { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile() && /\.(ts|tsx)$/.test(entry.name))
    .map((entry) => relative(clientDir, join(entry.parentPath, entry.name)));
}

test("the host contract exposes the whole surface the shared interface uses", () => {
  const stub = {
    Icon: () => null,
    Modal: Object.assign(() => null, { Content: () => null }),
    TextInput: () => null,
    SettingsSection: () => null,
    SettingsCard: () => null,
    SettingsInput: () => null,
    SettingsSelect: () => null,
    SettingsAction: () => null,
    SettingsSwitch: () => null,
    copyText: async () => undefined,
    openSettings: () => undefined,
    useToast: () => ({ show: () => undefined, error: () => undefined }),
    useAppLocale: () => "en",
    useRpc: <Contract extends HostRpcContract>(contract: Contract) => async () => undefined as unknown as ZodOutput<Contract["output"]>,
    useSettings: <Definition extends HostSettingsDefinition>(definition: Definition) => ({
      status: "ready",
      values: {},
      revision: "revision",
      saving: false,
      saveError: null,
      save: async () => true,
      reset: async () => true,
      reload: async () => undefined,
    }) as unknown as HostSettingsState<ZodOutput<Definition["schema"]>>,
  } satisfies HostContextValue;
  const surface = Object.keys(stub).sort();
  assert.deepEqual(surface, [
    "Icon",
    "Modal",
    "SettingsAction",
    "SettingsCard",
    "SettingsInput",
    "SettingsSection",
    "SettingsSelect",
    "SettingsSwitch",
    "TextInput",
    "copyText",
    "openSettings",
    "useAppLocale",
    "useRpc",
    "useSettings",
    "useToast",
  ]);
  assert.equal(typeof stub.Modal.Content, "function");
});

test("only the Paseo adapter may import the host packages", () => {
  const offenders: string[] = [];
  for (const file of clientFiles()) {
    if (file === hostAdapter) continue;
    const source = readFileSync(join(clientDir, file), "utf8");
    if (/@getpaseo\/plugin/.test(source)) offenders.push(file);
  }
  assert.deepEqual(offenders, []);
});

test("the shared interface does not import the Paseo bindings of the contracts", () => {
  const offenders: string[] = [];
  for (const file of clientFiles()) {
    const source = readFileSync(join(clientDir, file), "utf8");
    if (/shared\/contracts/.test(source)) offenders.push(file);
  }
  assert.deepEqual(offenders, []);
});
