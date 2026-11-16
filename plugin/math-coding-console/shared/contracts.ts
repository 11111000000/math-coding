import { defineRpc, defineSettings } from "@getpaseo/plugin";
import {
  preferencesDefinition,
  rpcSchemas,
  snapshotReadySchema,
} from "./schemas";

export {
  binarySchema,
  claimDetailOutputSchema,
  directoryListingSchema,
  evidencePageOutputSchema,
  fileContentSchema,
  filePreviewInputSchema,
  filePreviewOutputSchema,
  humanDecisionInputSchema,
  humanDecisionOutputSchema,
  notInitializedSchema,
  pageInput,
  pageOutput,
  preferencesDefinition,
  rpcSchemas,
  runInputSchema,
  runOutputSchema,
  snapshotOutputSchema,
  snapshotReadySchema,
  workspaceSchema,
} from "./schemas";
export type {
  ClaimDetail,
  EvidencePage,
  FilePreview,
  HumanDecisionInput,
  HumanDecisionOutput,
  Preferences,
  Snapshot,
  SnapshotReady,
} from "./schemas";

/**
 * The Paseo bindings of the host-neutral contracts.
 *
 * The shared interface imports `rpcSchemas` and `preferencesDefinition`
 * directly from ./schemas, so the browser bundle never pulls the Paseo host
 * package into the page.
 */
export const snapshotRpc = defineRpc(rpcSchemas.snapshot);
export const claimDetailRpc = defineRpc(rpcSchemas.claim);
export const evidencePageRpc = defineRpc(rpcSchemas.evidence);
export const runChecksRpc = defineRpc(rpcSchemas.run);
export const filePreviewRpc = defineRpc(rpcSchemas.file);
export const humanDecisionRpc = defineRpc(rpcSchemas.humanDecision);

export const preferences = defineSettings(preferencesDefinition);
