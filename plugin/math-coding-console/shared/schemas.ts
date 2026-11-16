import { z } from "zod";
import { claimSchema, evidenceRecordSchema, mapSchema, EVIDENCE_OUTCOMES } from "./domain";
import { HUMAN_ACTION_KINDS } from "./human-actions";

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
  /**
   * Whether the project declares protected transitions.
   *
   * The console offers the authorization step only when the project carries a
   * policy. The program decides who may authorize; the console only knows
   * that the step exists.
   */
  policyConfigured: z.boolean(),
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
 * One manual step of the method.
 *
 * The console never performs a step of its own: it asks the program to do it.
 * The confirmation is a literal, so a request without the explicit agreement
 * of the human never reaches the project.
 */
export const humanDecisionInputSchema = z.strictObject({
  workspaceId: z.string().min(1),
  confirmation: z.literal("APPLY_HUMAN_DECISION"),
  kind: z.enum(HUMAN_ACTION_KINDS),
  claimId: z.string().min(1).optional(),
  authority: z.string().min(1).optional(),
  by: z.string().min(1).max(200),
  reason: z.string().max(4000).optional(),
  outcome: z.enum(EVIDENCE_OUTCOMES).optional(),
  validForDays: z.number().int().positive().max(3650).optional(),
  recovery: z.string().max(4000).optional(),
});

export const humanDecisionOutputSchema = z.strictObject({
  snapshot: snapshotReadySchema,
  message: z.string(),
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
  humanDecision: {
    name: "mathcoding.human-decision",
    input: humanDecisionInputSchema,
    output: humanDecisionOutputSchema,
  },
} as const;

export type RpcName = (typeof rpcSchemas)[keyof typeof rpcSchemas]["name"];

export const preferencesDefinition = {
  id: "general",
  scope: "host" as const,
  version: 3,
  migrate(values: unknown, fromVersion: number): unknown {
    if (typeof values !== "object" || values === null || Array.isArray(values)) {
      return values;
    }
    const record = values as Record<string, unknown>;
    if (fromVersion === 1) {
      // The first version had no explicit permission to run checks either.
      return { ...record, allowRunChecks: false, allowHumanDecisions: false };
    }
    if (fromVersion === 2) {
      // The permission to run checks is kept; the permission to record a human
      // decision is a new one and therefore starts closed.
      return { ...record, allowHumanDecisions: false };
    }
    return values;
  },
  schema: z.strictObject({
    binaryPath: z.string().max(4096).default(""),
    allowRunChecks: z.boolean().default(false),
    /**
     * Whether the console may record a decision of the human.
     *
     * A decision of the human is a journal entry in the project. It is closed
     * by default: the human opens it in the settings of the host.
     */
    allowHumanDecisions: z.boolean().default(false),
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
export type HumanDecisionInput = z.output<typeof humanDecisionInputSchema>;
export type HumanDecisionOutput = z.output<typeof humanDecisionOutputSchema>;
