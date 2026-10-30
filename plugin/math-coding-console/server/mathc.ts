import { execFile, execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import { isAbsolute, join, resolve } from "node:path";

export interface RunResult {
  code: number;
  stdout: string;
  stderr: string;
  durationMs: number;
}

const DEFAULT_TIMEOUT_MS = 120_000;
const MAX_BUFFER = 64 * 1024 * 1024;

/**
 * The kernel binary.
 *
 * Order matters: an explicit override, then the repository's own build, then
 * whatever `mathc` is on PATH. A developer running the console against a
 * worktree wants THAT worktree's kernel — the one the worktree built — not
 * the release installed system-wide, whose vocabulary may be older.
 */
export function mathcBinary(root: string | null, override?: string | null): string {
  const explicit = (override ?? process.env.MATH_CODING_BIN ?? "").trim();
  if (explicit !== "") return explicit;

  if (root) {
    const local = join(root, "_build", "default", "bin", "mathc.exe");
    if (existsSync(local)) return local;
  }

  return "mathc";
}

/**
 * Run a kernel subcommand in the repository.
 *
 * `MATH_CODING_ROOT` is set to the same root as the working directory: the
 * kernel resolves the decisions directory, the attestation store and the
 * policy from the root, and the two must not disagree.
 */
export function runMathc(
  root: string,
  args: string[],
  options: { timeoutMs?: number; binary?: string | null } = {},
): Promise<RunResult> {
  const bin = mathcBinary(root, options.binary);
  const timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const startedAt = Date.now();
  return new Promise<RunResult>((resolvePromise) => {
    execFile(
      bin,
      args,
      {
        cwd: root,
        timeout: timeoutMs,
        maxBuffer: MAX_BUFFER,
        env: { ...process.env, MATH_CODING_ROOT: root },
      },
      (error, stdout, stderr) => {
        const code = error
          ? typeof (error as { code?: unknown }).code === "number"
            ? (error as { code: number }).code
            : 1
          : 0;
        resolvePromise({
          code,
          stdout: String(stdout ?? ""),
          stderr: String(stderr ?? ""),
          durationMs: Date.now() - startedAt,
        });
      },
    );
  });
}

/** Run a kernel subcommand and parse its stdout as JSON. */
export async function runMathcJson<T>(
  root: string,
  args: string[],
  options: { timeoutMs?: number; binary?: string | null } = {},
): Promise<{ ok: true; value: T; result: RunResult } | { ok: false; result: RunResult; error: string }> {
  const result = await runMathc(root, args, options);
  if (result.code !== 0) {
    const detail = result.stderr.trim() || result.stdout.trim() || `exit ${result.code}`;
    return { ok: false, result, error: detail.slice(0, 2000) };
  }
  try {
    return { ok: true, value: JSON.parse(result.stdout) as T, result };
  } catch (error) {
    return {
      ok: false,
      result,
      error: `the kernel did not answer with JSON: ${String(error)}`,
    };
  }
}

/** Run a git command in the repository and return its trimmed stdout. */
export function runGit(root: string, args: string[]): { code: number; stdout: string } {
  const result = spawnSyncCapture("git", args, root);
  return { code: result.code, stdout: result.stdout.trim() };
}

function spawnSyncCapture(
  bin: string,
  args: string[],
  cwd: string,
): { code: number; stdout: string; stderr: string } {
  // execFileSync throws on a nonzero exit; `git rev-parse` legitimately exits
  // 128 on an unborn branch, and the caller wants to see that, not a throw.
  try {
    const stdout = execFileSync(bin, args, {
      cwd,
      encoding: "utf8",
      maxBuffer: MAX_BUFFER,
      stdio: ["ignore", "pipe", "pipe"],
    });
    return { code: 0, stdout, stderr: "" };
  } catch (error) {
    const err = error as { status?: number; stdout?: string; stderr?: string };
    return {
      code: typeof err.status === "number" ? err.status : 1,
      stdout: String(err.stdout ?? ""),
      stderr: String(err.stderr ?? ""),
    };
  }
}

export function isAbsolutePath(candidate: string): boolean {
  return isAbsolute(candidate);
}

/**
 * A directory that holds a math-coding corpus.
 *
 * Both layouts count: the forward one (`mathc init` writes
 * `.math-coding/decisions/`) and the legacy one (`decisions/` at the root).
 * The kernel decides between them; the console only asks whether there is
 * anything to show.
 */
export function looksLikeMathCodingRoot(candidate: string): boolean {
  if (!candidate || !isAbsolute(candidate)) return false;
  const root = resolve(candidate);
  return (
    existsSync(join(root, ".math-coding", "decisions")) ||
    existsSync(join(root, "decisions")) ||
    existsSync(join(root, ".math-coding", "policy.yaml")) ||
    existsSync(join(root, "policies.yaml"))
  );
}
