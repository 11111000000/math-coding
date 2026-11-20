import { useCallback, useEffect, useMemo, useSyncExternalStore } from "react";
import type { output as ZodOutput } from "zod";
import type {
  HostSettingsDefinition,
  HostSettingsState,
} from "../../plugin/math-coding-console/client/host/contract";
import { errorMessage, readJson, serverError } from "./http";

/**
 * The settings of the browser host, shared by every reader.
 *
 * The page reads the preferences in three places at once: the provider of the
 * language reads them to know the language of the interface, the panel reads
 * them to know whether it may run the checks, and the screen of the settings
 * reads them to change them. All three must see one state, otherwise a change
 * reaches the file and not the interface, and the interface keeps the old
 * preference until the page is reloaded.
 *
 * The store is therefore outside the hook: the hook subscribes to it, and every
 * reader of the same definition gets the same state.
 */

const SETTINGS_ENDPOINT = "/api/settings";
const RESET_ENDPOINT = "/api/settings/reset";

export interface SettingsSnapshot {
  status: "loading" | "ready" | "error" | "invalid";
  values?: unknown;
  error?: string;
  revision?: string;
  saving: boolean;
  saveError: string | null;
}

const INITIAL_SNAPSHOT: SettingsSnapshot = { status: "loading", saving: false, saveError: null };

interface SettingsBody {
  status?: string;
  revision?: string;
  values?: unknown;
  error?: string;
}

export class SettingsStore {
  private snapshot: SettingsSnapshot = INITIAL_SNAPSHOT;
  private readonly listeners = new Set<() => void>();
  private loadStarted = false;

  /** The current state. The same object until something changes it. */
  getSnapshot = (): SettingsSnapshot => this.snapshot;

  /** Announces every change of the state to the readers. */
  subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };

  private publish(next: SettingsSnapshot): void {
    this.snapshot = next;
    for (const listener of [...this.listeners]) listener();
  }

  /** Reads the settings of the server and publishes them. */
  async load(): Promise<void> {
    try {
      const response = await fetch(SETTINGS_ENDPOINT, { headers: { Accept: "application/json" } });
      const body = (await readJson(response)) as SettingsBody | null;
      if (!response.ok || !body) {
        this.publish({ ...this.snapshot, status: "error", error: `settings_unavailable: ${String(response.status)}` });
        return;
      }
      if (body.status === "ready") {
        this.publish({ status: "ready", values: body.values, revision: body.revision, saving: false, saveError: null });
        return;
      }
      this.publish({ status: "invalid", error: body.error ?? "settings_invalid", saving: false, saveError: null });
    } catch (failure) {
      this.publish({ ...this.snapshot, status: "error", error: errorMessage(failure) });
    }
  }

  /** Reads the settings once, however many readers ask for them. */
  async ensureLoaded(): Promise<void> {
    if (this.loadStarted) return;
    this.loadStarted = true;
    await this.load();
  }

  /** Writes the values and publishes what the server answered. */
  async save(values: unknown, revision: string): Promise<boolean> {
    this.publish({ ...this.snapshot, saving: true, saveError: null });
    try {
      const response = await fetch(SETTINGS_ENDPOINT, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ revision, values }),
      });
      const body = (await readJson(response)) as SettingsBody | null;
      if (!response.ok || !body) {
        this.publish({ ...this.snapshot, saving: false, saveError: serverError(body, `settings_not_saved: ${String(response.status)}`) });
        return false;
      }
      if (body.status === "saved") {
        this.publish({ status: "ready", values: body.values, revision: body.revision, saving: false, saveError: null });
        return true;
      }
      this.publish({ ...this.snapshot, saving: false, saveError: body.error ?? "settings_not_saved" });
      return false;
    } catch (failure) {
      this.publish({ ...this.snapshot, saving: false, saveError: errorMessage(failure) });
      return false;
    }
  }

  /** Returns the settings to the defaults of the definition and publishes them. */
  async reset(): Promise<boolean> {
    this.publish({ ...this.snapshot, saving: true, saveError: null });
    try {
      const response = await fetch(RESET_ENDPOINT, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({}),
      });
      const body = (await readJson(response)) as SettingsBody | null;
      if (!response.ok || !body || body.status !== "saved") {
        this.publish({ ...this.snapshot, saving: false, saveError: serverError(body, "settings_not_reset") });
        return false;
      }
      this.publish({ status: "ready", values: body.values, revision: body.revision, saving: false, saveError: null });
      return true;
    } catch (failure) {
      this.publish({ ...this.snapshot, saving: false, saveError: errorMessage(failure) });
      return false;
    }
  }
}

const stores = new Map<string, SettingsStore>();

/** The store of a definition of settings. One store per definition. */
export function settingsStore(id: string): SettingsStore {
  const existing = stores.get(id);
  if (existing !== undefined) return existing;
  const store = new SettingsStore();
  stores.set(id, store);
  return store;
}

/** The settings of the host, as the host contract asks for them. */
export function useBrowserSettings<Definition extends HostSettingsDefinition>(
  definition: Definition,
): HostSettingsState<ZodOutput<Definition["schema"]>> {
  type Values = ZodOutput<Definition["schema"]>;
  const store = settingsStore(definition.id);
  const snapshot = useSyncExternalStore(store.subscribe, store.getSnapshot, store.getSnapshot);
  useEffect(() => {
    void store.ensureLoaded();
  }, [store]);
  const save = useCallback((values: Values, revision: string) => store.save(values, revision), [store]);
  const reset = useCallback(() => store.reset(), [store]);
  const reload = useCallback(() => store.load(), [store]);
  return useMemo(
    () => ({
      status: snapshot.status,
      values: snapshot.values as Values | undefined,
      error: snapshot.error,
      revision: snapshot.revision,
      saving: snapshot.saving,
      saveError: snapshot.saveError,
      save,
      reset,
      reload,
    }),
    [snapshot, save, reset, reload],
  );
}
