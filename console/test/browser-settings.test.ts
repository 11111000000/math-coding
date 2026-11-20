import assert from "node:assert/strict";
import test, { after } from "node:test";
import { SettingsStore, settingsStore, type SettingsSnapshot } from "../src/browser-settings";

/**
 * The settings of the browser host.
 *
 * The page reads the preferences in three places at once: the provider of the
 * language, the panel and the screen of the settings. They must see one state,
 * otherwise a change reaches the file and not the interface, and the interface
 * keeps the old preference until the page is reloaded.
 */

interface Answer {
  status: number;
  body: unknown;
}

const realFetch = globalThis.fetch;

after(() => {
  globalThis.fetch = realFetch;
});

/** Answers the requests of the store without touching the network. */
function answer(handler: (url: string, init?: RequestInit) => Answer): { url: string; init?: RequestInit }[] {
  const calls: { url: string; init?: RequestInit }[] = [];
  globalThis.fetch = (async (input: unknown, init?: RequestInit) => {
    const url = String(input);
    calls.push({ url, init });
    const result = handler(url, init);
    return {
      ok: result.status >= 200 && result.status < 300,
      status: result.status,
      text: async () => JSON.stringify(result.body),
    } as Response;
  }) as typeof fetch;
  return calls;
}

const READY = { status: 200, body: { status: "ready", revision: "r1", values: { locale: "auto" } } };

test("one definition of settings has one store", () => {
  assert.equal(settingsStore("general"), settingsStore("general"));
  assert.notEqual(settingsStore("general"), settingsStore("other"));
});

test("a reader of the store learns what the server answered", async () => {
  const store = new SettingsStore();
  const seen: SettingsSnapshot[] = [];
  const stop = store.subscribe((snapshot) => seen.push(snapshot));
  answer(() => READY);

  await store.load();

  assert.equal(store.getSnapshot().status, "ready");
  assert.equal(store.getSnapshot().revision, "r1");
  assert.deepEqual(store.getSnapshot().values, { locale: "auto" });
  assert.equal(seen.length, 1);
  stop();
});

test("a save publishes the values the server accepted to every reader", async () => {
  const store = new SettingsStore();
  const seen: SettingsSnapshot[] = [];
  store.subscribe((snapshot) => seen.push(snapshot));
  const calls = answer((url, init) => {
    if (init?.method === "POST") {
      const body = JSON.parse(String(init.body)) as { revision: string; values: unknown };
      assert.equal(body.revision, "r1");
      assert.deepEqual(body.values, { locale: "ru" });
      return { status: 200, body: { status: "saved", revision: "r2", values: { locale: "ru" } } };
    }
    return READY;
  });

  await store.load();
  const saved = await store.save({ locale: "ru" }, "r1");

  assert.equal(saved, true);
  assert.equal(store.getSnapshot().revision, "r2");
  assert.deepEqual(store.getSnapshot().values, { locale: "ru" });
  assert.equal(store.getSnapshot().saving, false);
  assert.equal(calls.length, 2);
  // The readers of the store see the change, not only the one that made it.
  assert.ok(seen.length >= 3, "the readers of the store did not see the save");
});

test("a refused save keeps the code of the error and the old values", async () => {
  const store = new SettingsStore();
  answer((url, init) => {
    if (init?.method === "POST") {
      return { status: 409, body: { status: "conflict", error: "settings_conflict" } };
    }
    return READY;
  });

  await store.load();
  const saved = await store.save({ locale: "ru" }, "r1");

  assert.equal(saved, false);
  assert.equal(store.getSnapshot().saveError, "settings_conflict");
  assert.deepEqual(store.getSnapshot().values, { locale: "auto" });
});

test("an unreachable server answers with the code of the error", async () => {
  const store = new SettingsStore();
  globalThis.fetch = (async () => {
    throw new Error("the server is gone");
  }) as typeof fetch;

  await store.load();

  assert.equal(store.getSnapshot().status, "error");
  assert.equal(store.getSnapshot().error, "the server is gone");
});

test("the store reads the settings once, however many readers ask", async () => {
  const store = new SettingsStore();
  const calls = answer(() => READY);

  await store.ensureLoaded();
  await store.ensureLoaded();

  assert.equal(calls.length, 1);
});
