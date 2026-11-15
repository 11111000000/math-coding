import { z } from "zod";
import { claimSchema, evidenceRecordSchema, mapSchema } from "./domain";

/**
 * The canonical reason of a map state.
 *
 * Every state of `mapSchema` may carry a `reason` that says why the claim is
 * in that state. The field is optional: a host may run against an older
 * program that does not report it yet, and the console then says that the
 * reason is unknown instead of inventing one.
 */
export {
  mapSchema,
  mapStateSchema,
  stateReasonSchema,
  STATE_REASONS,
} from "./domain";
export type { MapState, StateReason } from "./domain";

/**
 * Host-neutral contracts.
 *
 * Everything in this module is plain data and Zod schemas. The Paseo plugin
 * wraps these into plugin calls and settings, and the browser host serves the
 * same contracts over local HTTP, so both hosts speak one language.
 */
export const workspaceSchema = z.strictObject({
  id: z.string().min(1),
  name: z.string().nullable(),
  directory: z.string().min(1),
});

export const binarySchema = z.strictObject({ path: z.string().min(1), version: z.literal("mathc 5") });

export const snapshotReadySchema = z.strictObject({
  status: z.literal("ready"),
  workspace: workspaceSchema,
  generatedAt: z.string(),
  binary: binarySchema,
  revision: z.string().min(1),
  map: mapSchema,
  claims: z.array(claimSchema),
});

export const notInitializedSchema = z.strictObject({
  status: z.literal("not-initialized"),
  workspace: workspaceSchema,
  generatedAt: z.string(),
});

export const snapshotOutputSchema = z.discriminatedUnion("status", [
  snapshotReadySchema,
  notInitializedSchema,
]);

export const pageInput = {
  workspaceId: z.string().min(1),
  cursor: z.number().int().nonnegative().optional(),
  limit: z.number().int().positive().max(200).default(80),
};

export const pageOutput = {
  revision: z.string().min(1),
  generatedAt: z.string(),
  map: mapSchema,
  total: z.number().int().nonnegative(),
  nextCursor: z.number().int().nonnegative().nullable(),
};

export const claimDetailOutputSchema = z.strictObject({
  ...pageOutput,
  claim: claimSchema,
  records: z.array(evidenceRecordSchema),
});

export const evidencePageOutputSchema = z.strictObject({
  ...pageOutput,
  records: z.array(evidenceRecordSchema),
});

export const runOutputSchema = z.strictObject({
  snapshot: snapshotReadySchema,
  durationMs: z.number().nonnegative(),
});

export const runInputSchema = z.strictObject({
  workspaceId: z.string().min(1),
  confirmation: z.literal("RUN_CHECKS"),
});

/**
 * The read-only preview of one entry of the workspace.
 *
 * The console shows the subject of a claim so the human can read it without
 * leaving the panel. The answer is either the text of a file or a bounded
 * listing of a directory; it never carries a state and never changes the
 * project.
 */
export const fileContentSchema = z.strictObject({
  kind: z.literal("file"),
  path: z.string().min(1),
  content: z.string(),
  bytes: z.number().int().nonnegative(),
  truncated: z.boolean(),
  binary: z.boolean(),
});

export const directoryListingSchema = z.strictObject({
  kind: z.literal("directory"),
  path: z.string().min(1),
  entries: z.array(
    z.strictObject({ name: z.string().min(1), kind: z.enum(["file", "directory"]) }),
  ),
  truncated: z.boolean(),
});

export const filePreviewOutputSchema = z.discriminatedUnion("kind", [
  fileContentSchema,
  directoryListingSchema,
]);

export const filePreviewInputSchema = z.strictObject({
  workspaceId: z.string().min(1),
  path: z.string().min(1).max(4096),
  maxBytes: z.number().int().positive().max(1_048_576).default(131_072),
});

export const rpcSchemas = {
  snapshot: {
    name: "mathcoding.snapshot",
    input: z.strictObject({ workspaceId: z.string().min(1) }),
    output: snapshotOutputSchema,
  },
  claim: {
    name: "mathcoding.claim",
    input: z.strictObject({ ...pageInput, claimId: z.string().min(1) }),
    output: claimDetailOutputSchema,
  },
  evidence: {
    name: "mathcoding.evidence",
    input: z.strictObject(pageInput),
    output: evidencePageOutputSchema,
  },
  run: {
    name: "mathcoding.run",
    input: runInputSchema,
    output: runOutputSchema,
  },
  file: {
    name: "mathcoding.file",
    input: filePreviewInputSchema,
    output: filePreviewOutputSchema,
  },
} as const;

export type RpcName = (typeof rpcSchemas)[keyof typeof rpcSchemas]["name"];

export const preferencesDefinition = {
  id: "general",
  scope: "host" as const,
  version: 2,
  migrate(values: unknown, fromVersion: number): unknown {
    if (fromVersion !== 1 || typeof values !== "object" || values === null || Array.isArray(values)) {
      return values;
    }
    return { ...values, allowRunChecks: false };
  },
  schema: z.strictObject({
    binaryPath: z.string().max(4096).default(""),
    allowRunChecks: z.boolean().default(false),
    autoRefreshSeconds: z.union([
      z.literal(0),
      z.literal(15),
      z.literal(30),
      z.literal(60),
    ]).default(30),
  }),
};

export type PreferencesValues = z.output<typeof preferencesDefinition.schema>;

export type SnapshotReady = z.output<typeof snapshotReadySchema>;
export type Snapshot = z.output<typeof snapshotOutputSchema>;
export type ClaimDetail = z.output<typeof claimDetailOutputSchema>;
export type EvidencePage = z.output<typeof evidencePageOutputSchema>;
export type FilePreview = z.output<typeof filePreviewOutputSchema>;
export type Preferences = z.output<typeof preferencesDefinition.schema>;
