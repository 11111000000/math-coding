import { execFile } from "node:child_process";

export interface ProcessResult {
  code: number | null;
  stdout: string;
  stderr: string;
  durationMs: number;
  systemError: string | null;
  timedOut: boolean;
  truncated: boolean;
}

export function runProcess(
  binary: string,
  args: readonly string[],
  options: { cwd: string; timeoutMs: number; maxBuffer: number },
): Promise<ProcessResult> {
  const startedAt = Date.now();
  return new Promise((resolve) => {
    execFile(
      binary,
      [...args],
      {
        cwd: options.cwd,
        timeout: options.timeoutMs,
        maxBuffer: options.maxBuffer,
        encoding: "utf8",
        windowsHide: true,
      },
      (error, stdout, stderr) => {
        const failure = error as {
          code?: unknown;
          killed?: boolean;
          signal?: unknown;
          message?: string;
        } | null;
        const code = typeof failure?.code === "number" ? failure.code : error ? null : 0;
        const message = String(failure?.message ?? "");
        const timedOut = Boolean(failure?.killed && failure.signal === "SIGTERM");
        const truncated = message.includes("maxBuffer");
        const systemError = error && code === null && !timedOut && !truncated
          ? message.split("\n")[0]?.slice(0, 500) ?? "process failed"
          : null;
        resolve({
          code,
          stdout: String(stdout ?? ""),
          stderr: String(stderr ?? ""),
          durationMs: Date.now() - startedAt,
          systemError,
          timedOut,
          truncated,
        });
      },
    );
  });
}
