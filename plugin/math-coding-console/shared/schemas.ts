import { z } from "zod";
import { claimSchema, evidenceRecordSchema, mapSchema } from "./domain";

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
export type Preferences = z.output<typeof preferencesDefinition.schema>;
