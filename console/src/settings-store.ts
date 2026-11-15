import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { preferencesDefinition, type Preferences } from "../../plugin/math-coding-console/shared/schemas";

/**
 * The preferences of the local console.
 *
 * They live outside the project: the console is a viewer of a project, it
 * never writes into it. The file is versioned with the preference definition,
 * so a definition that changes its version migrates the stored values
 * instead of losing them.
 */

export type SettingsReadResult =
  | { status: "ready"; revision: string; values: Preferences }
  | { status: "invalid"; revision: string; error: string };

export type SettingsWriteResult =
  | { status: "saved"; revision: string; values: Preferences }
  | { status: "conflict"; error: string }
  | { status: "invalid"; error: string };

interface StoredSettings {
  version: number;
  values: unknown;
}

export function defaultSettingsPath(): string {
  const configured = process.env.XDG_CONFIG_HOME;
  const base = configured !== undefined && configured.trim() !== "" ? configured : join(homedir(), ".config");
  return join(base, "math-coding-console", "settings.json");
}

function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map((item) => canonical(item)).join(",")}]`;
  if (typeof value === "object" && value !== null) {
    const entries = Object.entries(value as Record<string, unknown>).sort(([left], [right]) =>
      left < right ? -1 : left > right ? 1 : 0,
    );
    return `{${entries.map(([key, item]) => `${JSON.stringify(key)}:${canonical(item)}`).join(",")}}`;
  }
  return JSON.stringify(value ?? null);
}

/** The revision of a set of values: a stable hash of its content. */
export function revisionOf(values: Preferences): string {
  return createHash("sha256")
    .update(canonical({ version: preferencesDefinition.version, values }))
    .digest("hex")
    .slice(0, 32);
}

function hashOf(text: string): string {
  return createHash("sha256").update(text).digest("hex").slice(0, 32);
}

function describe(error: { issues: readonly { path: readonly PropertyKey[]; message: string }[] }): string {
  return error.issues
    .slice(0, 5)
    .map((issue) => `${issue.path.map((part) => String(part)).join(".") || "settings"}: ${issue.message}`)
    .join("; ");
}

export class SettingsStore {
  constructor(private readonly path: string) {}

  defaults(): Preferences {
    return preferencesDefinition.schema.parse({});
  }

  async read(): Promise<SettingsReadResult> {
    let raw: string;
    try {
      raw = await readFile(this.path, "utf8");
    } catch (error) {
      if (typeof error === "object" && error !== null && "code" in error && error.code === "ENOENT") {
        const values = this.defaults();
        return { status: "ready", revision: revisionOf(values), values };
      }
      throw error;
    }
    let parsed: unknown;
    try {
      parsed = JSON.parse(raw) as unknown;
    } catch {
      return { status: "invalid", revision: hashOf(raw), error: "The stored settings are not valid JSON" };
    }
    if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
      return { status: "invalid", revision: hashOf(raw), error: "The stored settings have an unexpected shape" };
    }
    const stored = parsed as Partial<StoredSettings>;
    const version = typeof stored.version === "number" ? stored.version : 1;
    const migrated = version === preferencesDefinition.version
      ? stored.values
      : preferencesDefinition.migrate(stored.values, version);
    const result = preferencesDefinition.schema.safeParse(migrated);
    if (!result.success) {
      return { status: "invalid", revision: hashOf(raw), error: describe(result.error) };
    }
    if (version !== preferencesDefinition.version) {
      await this.persist(result.data);
    }
    return { status: "ready", revision: revisionOf(result.data), values: result.data };
  }

  async write(revision: string, values: unknown): Promise<SettingsWriteResult> {
    const current = await this.read();
    if (current.revision !== revision) {
      return { status: "conflict", error: "The settings changed since they were read; reload them before saving" };
    }
    const result = preferencesDefinition.schema.safeParse(values);
    if (!result.success) {
      return { status: "invalid", error: describe(result.error) };
    }
    await this.persist(result.data);
    return { status: "saved", revision: revisionOf(result.data), values: result.data };
  }

  async reset(): Promise<SettingsWriteResult> {
    const values = this.defaults();
    await this.persist(values);
    return { status: "saved", revision: revisionOf(values), values };
  }

  /** The values the runtime uses. Invalid stored settings fall back to the defaults. */
  async values(): Promise<Preferences> {
    const result = await this.read();
    return result.status === "ready" ? result.values : this.defaults();
  }

  private async persist(values: Preferences): Promise<void> {
    await mkdir(dirname(this.path), { recursive: true });
    const content = `${JSON.stringify({ version: preferencesDefinition.version, values }, null, 2)}\n`;
    await writeFile(this.path, content, "utf8");
  }
}
