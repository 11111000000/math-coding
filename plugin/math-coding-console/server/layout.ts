import { existsSync } from "node:fs";
import { isAbsolute, join, resolve } from "node:path";

/**
 * Where a math-coding project keeps its corpus.
 *
 * The kernel owns this decision (`lib/path_config.ml`), and the console asks
 * the same question the same way, because a console that reads a different
 * directory than the gate reads is worse than no console at all.
 *
 * Precedence, per the kernel:
 *   1. the environment variable, when set — the operator owns the override;
 *   2. the forward layout (`.math-coding/…`), when any of its artefacts exist;
 *   3. the legacy layout (`decisions/`, `attestations/`);
 *   4. the forward layout, as the default for a project that has neither.
 */

export type Layout = "forward" | "legacy";

const FORWARD = {
  decisions: ".math-coding/decisions",
  attestations: ".math-coding/attestations",
  policy: ".math-coding/policy.yaml",
} as const;

const LEGACY = {
  decisions: "decisions",
  attestations: "attestations",
  policy: "decisions/decision.yaml",
} as const;

function under(root: string, relative: string): boolean {
  return existsSync(join(root, relative));
}

export function layoutOf(root: string): Layout {
  if (
    under(root, ".math-coding") ||
    under(root, FORWARD.policy) ||
    under(root, FORWARD.decisions) ||
    under(root, FORWARD.attestations)
  ) {
    return "forward";
  }
  if (under(root, LEGACY.policy) || under(root, LEGACY.decisions) || under(root, LEGACY.attestations)) {
    return "legacy";
  }
  return "forward";
}

/**
 * An env-var override wins outright, relative or absolute.
 *
 * A relative value is joined with the root, which is what the kernel does
 * (`lib/path_config.ml::at`): the env var names a path INSIDE the project.
 * An absolute value replaces the root.
 */
function fromEnv(variable: string, root: string, fallback: string): string {
  const value = (process.env[variable] ?? "").trim();
  if (value !== "") return isAbsolute(value) ? value : join(root, value);
  return isAbsolute(fallback) ? fallback : join(root, fallback);
}

export interface ProjectLayout {
  root: string;
  layout: Layout;
  decisionsDir: string;
  attestationsDir: string;
  policyPath: string;
  /** Where waivers live: `<decisions>/waivers/`. */
  waiversDir: string;
}

export function resolveLayout(root: string): ProjectLayout {
  const layout = layoutOf(root);
  const defaults = layout === "forward" ? FORWARD : LEGACY;
  const decisionsDir = fromEnv("MATH_CODING_DECISIONS_DIR", root, defaults.decisions);
  const attestationsDir = fromEnv("MATH_CODING_ATTESTATIONS_DIR", root, defaults.attestations);
  const policyPath = fromEnv("MATH_CODING_POLICY", root, defaults.policy);
  return {
    root,
    layout,
    decisionsDir,
    attestationsDir,
    policyPath,
    waiversDir: join(decisionsDir, "waivers"),
  };
}

/**
 * The repository root to operate on.
 *
 * Explicit wins, then the host setting, then the plugin subprocess's own
 * working directory — which is the directory the plugin was installed from.
 */
export function resolveRoot(explicit?: string | null): { root: string | null; error: string | null } {
  const candidates: string[] = [];
  if (explicit && explicit.trim() !== "") candidates.push(explicit.trim());
  const fromSetting = (process.env.MATH_CODING_CONSOLE_ROOT ?? "").trim();
  if (fromSetting !== "") candidates.push(fromSetting);
  candidates.push(process.cwd());

  for (const candidate of candidates) {
    const absolute = resolve(candidate);
    if (looksLikeCorpus(absolute)) return { root: absolute, error: null };
  }

  const asked = candidates[0] ? resolve(candidates[0]) : "the workspace directory";
  return {
    root: null,
    error:
      `No math-coding corpus under ${asked}. ` +
      "Set the repository root in Settings → math-coding, or open the console from a workspace that holds one.",
  };
}

function looksLikeCorpus(root: string): boolean {
  return (
    existsSync(join(root, ".math-coding", "decisions")) ||
    existsSync(join(root, "decisions")) ||
    existsSync(join(root, ".math-coding", "policy.yaml")) ||
    existsSync(join(root, "policies.yaml"))
  );
}
