import { open, stat } from "node:fs/promises";
import { TextDecoder } from "node:util";
import type { ZodType } from "zod";

export async function readBounded(path: string, maxBytes: number): Promise<string> {
  const handle = await open(path, "r");
  try {
    const metadata = await handle.stat();
    if (metadata.size > maxBytes) throw new Error(`${path} exceeds the ${maxBytes}-byte limit`);
    const chunks: Buffer[] = [];
    let total = 0;
    let position = 0;
    while (true) {
      const size = Math.min(64 * 1024, maxBytes + 1 - total);
      if (size <= 0) break;
      const buffer = Buffer.alloc(size);
      const { bytesRead } = await handle.read(buffer, 0, size, position);
      if (bytesRead === 0) break;
      chunks.push(buffer.subarray(0, bytesRead));
      total += bytesRead;
      position += bytesRead;
      if (total > maxBytes) throw new Error(`${path} exceeds the ${maxBytes}-byte limit`);
    }
    return new TextDecoder("utf-8", { fatal: true }).decode(Buffer.concat(chunks, total));
  } catch (error) {
    if (error instanceof Error && error.message.includes("exceeds")) throw error;
    const wrapped = new Error(`Cannot read ${path}: ${error instanceof Error ? error.message : String(error)}`);
    if (typeof error === "object" && error !== null && "code" in error) {
      Object.assign(wrapped, { code: error.code });
    }
    throw wrapped;
  } finally {
    await handle.close();
  }
}

export async function readOptionalBounded(path: string, maxBytes: number): Promise<string> {
  try {
    return await readBounded(path, maxBytes);
  } catch (error) {
    if (typeof error === "object" && error !== null && "code" in error && error.code === "ENOENT") {
      return "";
    }
    const cause = error instanceof Error ? error.cause : null;
    if (typeof cause === "object" && cause !== null && "code" in cause && cause.code === "ENOENT") {
      return "";
    }
    throw error;
  }
}

export async function pathExists(path: string): Promise<boolean> {
  try {
    await stat(path);
    return true;
  } catch (error) {
    if (typeof error === "object" && error !== null && "code" in error && error.code === "ENOENT") {
      return false;
    }
    throw error;
  }
}

export function parseJson(text: string, label: string): unknown {
  try {
    return JSON.parse(text) as unknown;
  } catch (error) {
    throw new Error(`${label} is not valid JSON: ${error instanceof Error ? error.message : String(error)}`);
  }
}

export function parseWith<T>(schema: ZodType<T>, value: unknown, label: string): T {
  const result = schema.safeParse(value);
  if (result.success) return result.data;
  const details = result.error.issues
    .slice(0, 5)
    .map((issue) => `${issue.path.join(".") || label}: ${issue.message}`)
    .join("; ");
  throw new Error(`${label} failed validation: ${details}`);
}
