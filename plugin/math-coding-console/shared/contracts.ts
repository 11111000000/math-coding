import { defineRpc, defineSettings } from "@getpaseo/plugin";
import { z } from "zod";
import {
  claimSchema,
  evidenceRecordSchema,
  mapSchema,
} from "./domain";

const workspaceSchema = z.strictObject({
  id: z.string().min(1),
  name: z.string().nullable(),
  directory: z.string().min(1),
});

const binarySchema = z.strictObject({ path: z.string().min(1), version: z.literal("mathc 5") });

export const snapshotReadySchema = z.strictObject({
  status: z.literal("ready"),
  workspace: workspaceSchema,
  generatedAt: z.string(),
  binary: binarySchema,
  revision: z.string().min(1),
  map: mapSchema,
  claims: z.array(claimSchema),
});

export const snapshotRpc = defineRpc({
  name: "mathcoding.snapshot",
  input: z.strictObject({ workspaceId: z.string().min(1) }),
  output: z.discriminatedUnion("status", [
    snapshotReadySchema,
    z.strictObject({
      status: z.literal("not-initialized"),
      workspace: workspaceSchema,
      generatedAt: z.string(),
    }),
  ]),
});

const pageInput = {
  workspaceId: z.string().min(1),
  cursor: z.number().int().nonnegative().optional(),
  limit: z.number().int().positive().max(200).default(80),
};

const pageOutput = {
  revision: z.string().min(1),
  generatedAt: z.string(),
  map: mapSchema,
  total: z.number().int().nonnegative(),
  nextCursor: z.number().int().nonnegative().nullable(),
};

export const claimDetailRpc = defineRpc({
  name: "mathcoding.claim",
  input: z.strictObject({ ...pageInput, claimId: z.string().min(1) }),
  output: z.strictObject({
    ...pageOutput,
    claim: claimSchema,
    records: z.array(evidenceRecordSchema),
  }),
});

export const evidencePageRpc = defineRpc({
  name: "mathcoding.evidence",
  input: z.strictObject(pageInput),
  output: z.strictObject({ ...pageOutput, records: z.array(evidenceRecordSchema) }),
});

export const runChecksRpc = defineRpc({
  name: "mathcoding.run",
  input: z.strictObject({
    workspaceId: z.string().min(1),
    confirmation: z.literal("RUN_CHECKS"),
  }),
  output: z.strictObject({ snapshot: snapshotReadySchema, durationMs: z.number().nonnegative() }),
});

export const preferences = defineSettings({
  id: "general",
  scope: "host",
  version: 2,
  migrate(values, fromVersion) {
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
});

export type SnapshotReady = z.output<typeof snapshotReadySchema>;
export type Snapshot = z.output<typeof snapshotRpc.output>;
export type ClaimDetail = z.output<typeof claimDetailRpc.output>;
export type EvidencePage = z.output<typeof evidencePageRpc.output>;
export type Preferences = z.output<typeof preferences.schema>;
