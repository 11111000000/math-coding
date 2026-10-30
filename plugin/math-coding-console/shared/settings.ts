import { defineSettings } from "@getpaseo/plugin";
import { z } from "zod";

/**
 * Host-scoped settings. The repository root is the one thing the console
 * cannot guess: a Paseo workspace points at a directory, and a math-coding
 * project may live at its root or one level below it.
 */
export const preferences = defineSettings({
  id: "math-coding-console",
  scope: "host",
  version: 1,
  schema: z.object({
    /** Absolute path to the math-coding repository. Empty means "use the workspace". */
    repoRoot: z.string().default(""),
    /** Explicit `mathc` binary. Empty means "discover it". */
    kernelPath: z.string().default(""),
    /** The identity a review is signed under. Must be class-tagged. */
    reviewProducer: z.string().default("human:reviewer"),
    /** The command `mathc attest-batch --run` executes when re-signing. */
    attestRunCommand: z.string().default(""),
    /** Refresh the console on its own every N seconds. 0 disables it. */
    refreshSeconds: z.number().int().min(0).max(3600).default(0),
  }),
});
