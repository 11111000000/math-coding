import { constants } from "node:fs";
import { lstat, open, readdir, realpath } from "node:fs/promises";
import { isAbsolute, join, relative, resolve, sep } from "node:path";

/**
 * A read-only view of one file inside the workspace.
 *
 * The console shows the subject of a claim, so the human can read it without
 * leaving the panel. The read is bounded, and it never leaves the workspace:
 * an absolute path, a traversal or a symbolic link that points outside is
 * refused before anything is opened. Only a regular file is opened, so a named
 * pipe inside the tree cannot make the panel wait for a writer.
 */
export interface WorkspaceFile {
  kind: "file";
  path: string;
  content: string;
  bytes: number;
  truncated: boolean;
  binary: boolean;
}

export interface WorkspaceDirectory {
  kind: "directory";
  path: string;
  entries: Array<{ name: string; kind: "file" | "directory" }>;
  truncated: boolean;
}

export type WorkspaceEntry = WorkspaceFile | WorkspaceDirectory;

const DEFAULT_MAX_BYTES = 131_072;
const MAX_ENTRIES = 200;

/**
 * The path of an entry, relative to the workspace root.
 *
 * The path travels through the interface as the project wrote it, so the human
 * sees the same path the specification declares.
 */
export function workspaceRelativePath(root: string, absolute: string): string {
  const value = relative(root, absolute);
  return value === "" ? "." : value;
}

function refuseOutside(root: string, candidate: string): void {
  if (candidate !== root && !candidate.startsWith(root + sep)) {
    throw new Error("The path leaves the workspace");
  }
}

/**
 * Resolve a declared path to a real path inside the workspace.
 *
 * The rules are the same as the ones the core applies to scope paths: the
 * path is relative, it has no traversal, and it does not point through a
 * symbolic link out of the workspace.
 */
export async function resolveWorkspacePath(root: string, declared: string): Promise<string> {
  const path = declared.trim();
  if (path === "") throw new Error("A path is required");
  if (path.includes("\0")) throw new Error("The path contains a null byte");
  if (isAbsolute(path)) throw new Error("The path must be relative to the workspace");
  const segments = path.split(/[\\/]+/).filter((segment) => segment !== "");
  if (segments.some((segment) => segment === "..")) {
    throw new Error("The path must not leave the workspace");
  }
  const rootReal = await realpath(root);
  const target = resolve(rootReal, segments.join(sep));
  refuseOutside(rootReal, target);
  const targetReal = await realpath(target);
  refuseOutside(rootReal, targetReal);
  return targetReal;
}

async function readFileEntry(root: string, absolute: string, maxBytes: number): Promise<WorkspaceFile> {
  const handle = await open(absolute, constants.O_RDONLY | constants.O_NOFOLLOW);
  try {
    const stats = await handle.stat();
    if (!stats.isFile()) throw new Error("Only a regular file can be opened");
    const length = Math.min(stats.size, maxBytes);
    const buffer = Buffer.alloc(length);
    if (length > 0) await handle.read(buffer, 0, length, 0);
    const truncated = stats.size > maxBytes;
    let binary = false;
    let content = "";
    try {
      content = new TextDecoder("utf-8", { fatal: true }).decode(buffer);
      if (content.includes("\0")) binary = true;
    } catch {
      binary = true;
      content = "";
    }
    return {
      kind: "file",
      path: workspaceRelativePath(root, absolute),
      content,
      bytes: stats.size,
      truncated,
      binary,
    };
  } finally {
    await handle.close();
  }
}

async function readDirectoryEntry(root: string, absolute: string, maxEntries: number): Promise<WorkspaceDirectory> {
  const names = await readdir(absolute);
  const sorted = [...names].sort((a, b) => a.localeCompare(b));
  const entries: Array<{ name: string; kind: "file" | "directory" }> = [];
  for (const name of sorted) {
    if (entries.length >= maxEntries) {
      return {
        kind: "directory",
        path: workspaceRelativePath(root, absolute),
        entries,
        truncated: true,
      };
    }
    const child = join(absolute, name);
    const stats = await lstat(child);
    entries.push({ name, kind: stats.isDirectory() ? "directory" : "file" });
  }
  return {
    kind: "directory",
    path: workspaceRelativePath(root, absolute),
    entries,
    truncated: false,
  };
}

/**
 * Read one entry of the workspace for the preview.
 *
 * The read never changes the project. A file is returned as text when it is
 * UTF-8 and marked as binary otherwise; a directory is returned as a bounded
 * listing of its entries.
 */
export async function readWorkspaceEntry(
  root: string,
  declared: string,
  maxBytes = DEFAULT_MAX_BYTES,
  maxEntries = MAX_ENTRIES,
): Promise<WorkspaceEntry> {
  const absolute = await resolveWorkspacePath(root, declared);
  const stats = await lstat(absolute);
  if (stats.isDirectory()) return readDirectoryEntry(root, absolute, maxEntries);
  if (!stats.isFile()) throw new Error("Only a regular file can be opened");
  return readFileEntry(root, absolute, maxBytes);
}
