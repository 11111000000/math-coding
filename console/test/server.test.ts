import assert from "node:assert/strict";
import { request as httpRequest } from "node:http";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test, { after, before } from "node:test";
import { startConsoleServer, type ConsoleServerHandle } from "../src/server";

/**
 * The local console server.
 *
 * The tests read an empty project, so every answer about a verdict is a
 * refusal: an uninitialised project is not a green project.
 */

interface Answer {
  status: number;
  text: string;
  body: Record<string, unknown>;
}

let handle: ConsoleServerHandle;
let root: string;
let settingsPath: string;

function ask(options: {
  method?: string;
  path?: string;
  body?: unknown;
  headers?: Record<string, string>;
}): Promise<Answer> {
  const method = options.method ?? "GET";
  const path = options.path ?? "/";
  const headers: Record<string, string> = { ...options.headers };
  let payload: string | undefined;
  if (options.body !== undefined) {
    payload = JSON.stringify(options.body);
    headers["Content-Type"] = headers["Content-Type"] ?? "application/json";
    headers["Content-Length"] = String(Buffer.byteLength(payload));
  }
  return new Promise<Answer>((resolve, reject) => {
    const request = httpRequest(
      { host: "127.0.0.1", port: handle.port, method, path, headers },
      (response) => {
        const chunks: Buffer[] = [];
        response.on("data", (chunk: Buffer) => chunks.push(chunk));
        response.on("end", () => {
          const text = Buffer.concat(chunks).toString("utf8");
          let body: Record<string, unknown> = {};
          try {
            body = text === "" ? {} : (JSON.parse(text) as Record<string, unknown>);
          } catch {
            body = {};
          }
          resolve({ status: response.statusCode ?? 0, text, body });
        });
      },
    );
    request.on("error", reject);
    if (payload !== undefined) request.write(payload);
    request.end();
  });
}

before(async () => {
  const base = await mkdtemp(join(tmpdir(), "mathc-console-server-"));
  root = join(base, "project");
  settingsPath = join(base, "settings", "settings.json");
  const { mkdir } = await import("node:fs/promises");
  await mkdir(root, { recursive: true });
  handle = await startConsoleServer({ root, port: 0, settingsPath });
});

after(async () => {
  await handle?.close();
  if (root) await rm(join(root, ".."), { recursive: true, force: true });
});

test("an empty project is not initialised, not a verdict", async () => {
  const answer = await ask({ method: "POST", path: "/api/mathcoding.snapshot", body: { workspaceId: "local" } });
  assert.equal(answer.status, 200);
  assert.equal(answer.body.status, "not-initialized");
  assert.equal("verdict" in answer.body, false);
  assert.equal((answer.body.workspace as { directory: string }).directory, root);
});

test("the project is fixed when the server starts", async () => {
  const answer = await ask({
    method: "POST",
    path: "/api/mathcoding.snapshot",
    body: { workspaceId: "another-workspace" },
  });
  assert.equal(answer.status, 200);
  assert.equal((answer.body.workspace as { directory: string }).directory, root);
});

test("a body that does not match the contract is a schema error", async () => {
  const answer = await ask({ method: "POST", path: "/api/mathcoding.snapshot", body: { workspaceId: 42 } });
  assert.equal(answer.status, 400);
  assert.equal(typeof answer.body.error, "string");
  assert.ok((answer.body.error as string).length > 0);
});

test("a request that is not JSON is refused", async () => {
  const answer = await ask({
    method: "POST",
    path: "/api/mathcoding.snapshot",
    headers: { "Content-Type": "text/plain" },
    body: { workspaceId: "local" },
  });
  assert.equal(answer.status, 400);
  assert.equal(typeof answer.body.error, "string");
});

test("checks cannot run without the confirmation", async () => {
  const answer = await ask({ method: "POST", path: "/api/mathcoding.run", body: { workspaceId: "local" } });
  assert.equal(answer.status, 400);
  assert.equal(typeof answer.body.error, "string");
});

test("checks stay disabled until they are enabled", async () => {
  const answer = await ask({
    method: "POST",
    path: "/api/mathcoding.run",
    body: { workspaceId: "local", confirmation: "RUN_CHECKS" },
  });
  assert.notEqual(answer.status, 200);
  assert.match(String(answer.body.error), /disabled/i);
});

test("a decision cannot be made without the confirmation", async () => {
  const answer = await ask({
    method: "POST",
    path: "/api/mathcoding.human-decision",
    body: { workspaceId: "local", kind: "record", claimId: "hello", authority: "owner", by: "az", outcome: "pass" },
  });
  assert.equal(answer.status, 400);
  assert.equal(typeof answer.body.error, "string");
});

test("a decision that names no step of the method is a schema error", async () => {
  const answer = await ask({
    method: "POST",
    path: "/api/mathcoding.human-decision",
    body: { workspaceId: "local", confirmation: "APPLY_HUMAN_DECISION", kind: "accept", by: "az" },
  });
  assert.equal(answer.status, 400);
  assert.equal(typeof answer.body.error, "string");
});

test("decisions stay disabled until they are enabled", async () => {
  const answer = await ask({
    method: "POST",
    path: "/api/mathcoding.human-decision",
    body: {
      workspaceId: "local",
      confirmation: "APPLY_HUMAN_DECISION",
      kind: "record",
      claimId: "hello",
      authority: "owner",
      by: "az",
      outcome: "pass",
    },
  });
  assert.notEqual(answer.status, 200);
  assert.match(String(answer.body.error), /disabled/i);
});

test("a foreign origin is refused", async () => {
  const answer = await ask({
    method: "POST",
    path: "/api/mathcoding.snapshot",
    headers: { Origin: "http://evil.example" },
    body: { workspaceId: "local" },
  });
  assert.equal(answer.status, 403);
  assert.equal(typeof answer.body.error, "string");
});

test("a foreign host is refused", async () => {
  const answer = await ask({
    method: "POST",
    path: "/api/mathcoding.snapshot",
    headers: { Host: "evil.example" },
    body: { workspaceId: "local" },
  });
  assert.equal(answer.status, 403);
});

test("an unknown route is not found", async () => {
  const api = await ask({ path: "/api/mathcoding.nothing" });
  assert.equal(api.status, 404);
  const page = await ask({ path: "/nowhere" });
  assert.equal(page.status, 404);
});

test("the settings are read, written and reset", async () => {
  const initial = await ask({ path: "/api/settings" });
  assert.equal(initial.status, 200);
  assert.equal(initial.body.status, "ready");
  const revision = initial.body.revision as string;
  assert.equal(typeof revision, "string");
  assert.deepEqual(initial.body.values, { binaryPath: "", allowRunChecks: false, allowHumanDecisions: false, autoRefreshSeconds: 30, locale: "auto" });

  const saved = await ask({
    method: "POST",
    path: "/api/settings",
    body: { revision, values: { binaryPath: "", allowRunChecks: true, allowHumanDecisions: false, autoRefreshSeconds: 15, locale: "auto" } },
  });
  assert.equal(saved.status, 200);
  assert.equal(saved.body.status, "saved");
  assert.notEqual(saved.body.revision, revision);
  assert.deepEqual(saved.body.values, { binaryPath: "", allowRunChecks: true, allowHumanDecisions: false, autoRefreshSeconds: 15, locale: "auto" });

  const reread = await ask({ path: "/api/settings" });
  assert.deepEqual(reread.body.values, { binaryPath: "", allowRunChecks: true, allowHumanDecisions: false, autoRefreshSeconds: 15, locale: "auto" });

  const conflict = await ask({
    method: "POST",
    path: "/api/settings",
    body: { revision, values: { binaryPath: "", allowRunChecks: false, allowHumanDecisions: false, autoRefreshSeconds: 30, locale: "auto" } },
  });
  assert.equal(conflict.body.status, "conflict");
  assert.equal(typeof conflict.body.error, "string");

  const invalid = await ask({
    method: "POST",
    path: "/api/settings",
    body: { revision: saved.body.revision, values: { binaryPath: "", allowRunChecks: "yes", autoRefreshSeconds: 30 } },
  });
  assert.equal(invalid.body.status, "invalid");
  assert.equal(typeof invalid.body.error, "string");

  const reset = await ask({ method: "POST", path: "/api/settings/reset", body: {} });
  assert.equal(reset.body.status, "saved");
  assert.deepEqual(reset.body.values, { binaryPath: "", allowRunChecks: false, allowHumanDecisions: false, autoRefreshSeconds: 30, locale: "auto" });

  const afterReset = await ask({ path: "/api/settings" });
  assert.deepEqual(afterReset.body.values, { binaryPath: "", allowRunChecks: false, allowHumanDecisions: false, autoRefreshSeconds: 30, locale: "auto" });
});

test("the settings live outside the project", async () => {
  const { readFile } = await import("node:fs/promises");
  const stored = JSON.parse(await readFile(settingsPath, "utf8")) as { version: number; values: unknown };
  assert.equal(stored.version, 4);
  assert.deepEqual(stored.values, { binaryPath: "", allowRunChecks: false, allowHumanDecisions: false, autoRefreshSeconds: 30, locale: "auto" });
});

test("a file of the project is read through the file endpoint", async () => {
  const { writeFile } = await import("node:fs/promises");
  await writeFile(join(root, "notes.md"), "the subject\n", "utf8");
  const answer = await ask({
    method: "POST",
    path: "/api/mathcoding.file",
    body: { workspaceId: "local", path: "notes.md" },
  });
  assert.equal(answer.status, 200);
  assert.equal(answer.body.kind, "file");
  assert.equal(answer.body.path, "notes.md");
  assert.equal(answer.body.content, "the subject\n");
});

test("a path that leaves the project is refused by the file endpoint", async () => {
  const absolute = await ask({
    method: "POST",
    path: "/api/mathcoding.file",
    body: { workspaceId: "local", path: "/etc/passwd" },
  });
  assert.equal(absolute.status, 400);
  assert.equal(typeof absolute.body.error, "string");
  const traversal = await ask({
    method: "POST",
    path: "/api/mathcoding.file",
    body: { workspaceId: "local", path: "../outside.txt" },
  });
  assert.equal(traversal.status, 400);
  assert.equal(typeof traversal.body.error, "string");
});

test("a file request that does not match the contract is a schema error", async () => {
  const answer = await ask({
    method: "POST",
    path: "/api/mathcoding.file",
    body: { workspaceId: "local", path: "notes.md", maxBytes: "a lot" },
  });
  assert.equal(answer.status, 400);
  assert.equal(typeof answer.body.error, "string");
});
