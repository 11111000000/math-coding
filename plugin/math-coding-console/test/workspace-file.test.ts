import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdir, mkdtemp, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { readWorkspaceEntry, resolveWorkspacePath } from "../server/workspace-file";

async function workspace(): Promise<string> {
  const root = await mkdtemp(join(tmpdir(), "mathc-file-"));
  await mkdir(join(root, "lib"), { recursive: true });
  await writeFile(join(root, "README.md"), "the project\n", "utf8");
  await writeFile(join(root, "lib", "domain.ml"), "let value = 1\n", "utf8");
  return root;
}

test("a file inside the workspace is read as text", async () => {
  const root = await workspace();
  const entry = await readWorkspaceEntry(root, "README.md");
  assert.equal(entry.kind, "file");
  if (entry.kind !== "file") return;
  assert.equal(entry.content, "the project\n");
  assert.equal(entry.bytes, 12);
  assert.equal(entry.truncated, false);
  assert.equal(entry.binary, false);
  assert.equal(entry.path, "README.md");
});

test("a directory is read as a bounded listing", async () => {
  const root = await workspace();
  const entry = await readWorkspaceEntry(root, "lib");
  assert.equal(entry.kind, "directory");
  if (entry.kind !== "directory") return;
  assert.deepEqual(entry.entries, [{ name: "domain.ml", kind: "file" }]);
  assert.equal(entry.truncated, false);
});

test("an absolute path is refused", async () => {
  const root = await workspace();
  await assert.rejects(() => readWorkspaceEntry(root, "/etc/passwd"), /relative/);
});

test("a traversal is refused", async () => {
  const root = await workspace();
  await assert.rejects(() => readWorkspaceEntry(root, "../outside.txt"), /must not leave the workspace/);
  await assert.rejects(() => readWorkspaceEntry(root, "lib/../../outside.txt"), /must not leave the workspace/);
});

test("a symbolic link that points out of the workspace is refused", async () => {
  const root = await workspace();
  const outside = join(root, "..", `outside-${process.pid}.txt`);
  await writeFile(outside, "secret\n", "utf8");
  await symlink(outside, join(root, "escape.txt"));
  await assert.rejects(() => readWorkspaceEntry(root, "escape.txt"), /leaves the workspace/);
});

test("a file that is not text is marked as binary", async () => {
  const root = await workspace();
  await writeFile(join(root, "blob.bin"), Buffer.from([0x00, 0xff, 0xfe, 0x00]));
  const entry = await readWorkspaceEntry(root, "blob.bin");
  assert.equal(entry.kind, "file");
  if (entry.kind !== "file") return;
  assert.equal(entry.binary, true);
  assert.equal(entry.content, "");
});

test("a file larger than the limit is cut and marked as truncated", async () => {
  const root = await workspace();
  await writeFile(join(root, "big.txt"), "x".repeat(4_096), "utf8");
  const entry = await readWorkspaceEntry(root, "big.txt", 1_000);
  assert.equal(entry.kind, "file");
  if (entry.kind !== "file") return;
  assert.equal(entry.content.length, 1_000);
  assert.equal(entry.bytes, 4_096);
  assert.equal(entry.truncated, true);
});

test("a path that does not exist is refused", async () => {
  const root = await workspace();
  await assert.rejects(() => readWorkspaceEntry(root, "missing.txt"));
});

test("the resolved path stays inside the workspace", async () => {
  const root = await workspace();
  const resolved = await resolveWorkspacePath(root, "lib/domain.ml");
  assert.ok(resolved.startsWith(await resolveWorkspacePath(root, "lib")));
});

test("a symbolic link to a directory out of the workspace is refused", async () => {
  const root = await workspace();
  const outside = join(root, "..", `outside-dir-${process.pid}`);
  await mkdir(outside, { recursive: true });
  await writeFile(join(outside, "secret.txt"), "secret\n", "utf8");
  await symlink(outside, join(root, "escape-dir"));
  await assert.rejects(() => readWorkspaceEntry(root, "escape-dir"), /leaves the workspace/);
});

test("a symbolic link to a file inside the workspace is read", async () => {
  const root = await workspace();
  await symlink(join(root, "README.md"), join(root, "readme-link.md"));
  const entry = await readWorkspaceEntry(root, "readme-link.md");
  assert.equal(entry.kind, "file");
  if (entry.kind !== "file") return;
  assert.equal(entry.content, "the project\n");
});

test("a named pipe is refused instead of waiting for a writer", { timeout: 10_000 }, async (t) => {
  const root = await workspace();
  try {
    execFileSync("mkfifo", [join(root, "pipe")]);
  } catch {
    t.skip("this platform has no command that creates a named pipe");
    return;
  }
  await assert.rejects(() => readWorkspaceEntry(root, "pipe"), /regular file/);
});

test("the listing of a directory is bounded", async () => {
  const root = await workspace();
  await mkdir(join(root, "many"), { recursive: true });
  await Promise.all(
    Array.from({ length: 12 }, (_, index) => writeFile(join(root, "many", `file-${index}.txt`), "x", "utf8")),
  );
  const entry = await readWorkspaceEntry(root, "many", 131_072, 5);
  assert.equal(entry.kind, "directory");
  if (entry.kind !== "directory") return;
  assert.equal(entry.entries.length, 5);
  assert.equal(entry.truncated, true);
});

test("the default limit of a file is the declared one", async () => {
  const root = await workspace();
  await writeFile(join(root, "default.txt"), "y".repeat(140_000), "utf8");
  const entry = await readWorkspaceEntry(root, "default.txt");
  assert.equal(entry.kind, "file");
  if (entry.kind !== "file") return;
  assert.equal(entry.content.length, 131_072);
  assert.equal(entry.truncated, true);
});
