import { z } from "zod";

export const VERDICTS = ["green", "red", "unknown", "vacant"] as const;
export const CLAIM_STATES = [
  "holds",
  "refuted",
  "inconclusive",
  "outdated",
  "never-checked",
  "waived",
] as const;
export const EVIDENCE_OUTCOMES = [
  "pass",
  "fail",
  "inconclusive",
  "infrastructure-error",
  "not-run",
] as const;
export const INDEPENDENCE_LEVELS = ["self", "fresh-context", "external"] as const;

/**
 * The canonical reason of a claim state.
 *
 * The reason comes from the map. It is optional, because a host may run
 * against an older program that does not report it yet.
 */
export const STATE_REASONS = [
  "current",
  "never-checked",
  "source-changed",
  "materials-changed",
  "definition-changed",
  "verifier-changed",
  "environment-changed",
  "expired",
  "not-run",
  "inconclusive",
  "infrastructure-error",
  "refuted",
  "waived",
  "tool-changed",
] as const;

export const stateReasonSchema = z.enum(STATE_REASONS);

/**
 * The digest of the program that produced a map.
 *
 * The class names the program, and the fingerprint names the build of it. A
 * map is always written by a program that knows itself, so the fingerprint of
 * a map is never empty.
 */
export const mapToolSchema = z.strictObject({
  class: z.string().min(1),
  fingerprint: z.string().min(1),
});

/**
 * The digest of the program that produced an evidence record.
 *
 * A record carried over from the previous format does not know the program
 * that wrote it. The migration says so honestly: it names the class and
 * leaves the fingerprint empty. An empty fingerprint is therefore not a
 * broken record, and the consumer reads it as an unknown producer.
 */
export const evidenceToolSchema = z.strictObject({
  class: z.string().min(1),
  fingerprint: z.string(),
});

const nullableString = z.string().nullable().default(null);
const goalSchema = z.strictObject({
  text: z.string().min(1),
  scope: z.array(z.string()),
  by: z.string().min(1),
  at: z.number().int(),
  reason: nullableString,
});

export const mapStateSchema = z.strictObject({
  id: z.string().min(1),
  state: z.enum(CLAIM_STATES),
  source_changed: z.boolean(),
  reason: stateReasonSchema.optional(),
});

export const mapSchema = z.strictObject({
  schema_version: z.literal(6),
  verdict: z.enum(VERDICTS),
  exit: z.number().int(),
  claims: z.number().int().nonnegative(),
  goal: goalSchema.nullable(),
  // The program that produced this map. The digest names the build, so a
  // reader knows which observer wrote the map it reads.
  tool: mapToolSchema,
  states: z.array(mapStateSchema),
  uncovered: z.array(z.string()),
  next: z.string(),
});

const sourceReviewSchema = z.strictObject({
  by: z.string().min(1),
  reason: z.string().min(1),
  at: z.number().int(),
  previous_digest: z.string().min(1),
});

const sourceSchema = z.strictObject({
  kind: z.enum(["madr", "adr-tools", "arc42", "task", "specification"]),
  path: z.string().min(1),
  section: nullableString,
  digest: z.string().min(1),
  review: sourceReviewSchema.nullable().default(null),
});

export type Requirement =
  | { kind: "verifier"; spec: string }
  | { kind: "review"; spec: string; minimum_independence: (typeof INDEPENDENCE_LEVELS)[number] }
  | { all: Requirement[] }
  | { any: Requirement[] };

export const requirementSchema: z.ZodType<Requirement> = z.lazy(() =>
  z.union([
    z.strictObject({ kind: z.literal("verifier"), spec: z.string().min(1) }),
    z.strictObject({
      kind: z.literal("review"),
      spec: z.string().min(1),
      minimum_independence: z.enum(INDEPENDENCE_LEVELS).default("external"),
    }),
    z.strictObject({ all: z.array(requirementSchema) }),
    z.strictObject({ any: z.array(requirementSchema) }),
  ]),
);

const waiverSchema = z.strictObject({
  gap: z.string().min(1),
  scope: z.array(z.string()),
  issuer: z.string().min(1),
  issued_at: z.number().int(),
  expires_at: z.number().int(),
  reason: z.string().min(1),
  compensating_controls: z.array(z.string()),
  recovery: z.string().min(1),
});

export const claimSchema = z.strictObject({
  id: z.string().min(1),
  text: z.string().min(1),
  scope: z.array(z.string()),
  source: sourceSchema.nullable().default(null),
  owner: nullableString,
  requirements: z.array(requirementSchema),
  falsifier: z.string().default(""),
  register: z.enum(["fact", "hypothesis", "judgment", "unknown"]),
  control: nullableString,
  waiver: waiverSchema.nullable().default(null),
  // A claim may declare its own environment. The core owns its rules; the
  // host only carries it, and a claim without one stays without one.
  environment: z.string().max(512).nullable().optional(),
});

export const specSchema = z.strictObject({
  schema_version: z.literal(6),
  // The declared environment is a prefix for every declared command. It is
  // optional, and the core owns its rules; the host only has to carry it.
  environment: z.string().max(512).nullable().optional(),
  goal: goalSchema.nullable().default(null),
  claims: z.array(claimSchema),
});

export const evidenceSchema = z.strictObject({
  schema_version: z.literal(6),
  claim_id: z.string().min(1),
  requirement: requirementSchema,
  candidate_tree: z.string().min(1),
  materials_digest: z.string().min(1),
  definition_digest: z.string().min(1),
  verifier_digest: z.string().min(1),
  environment: z.strictObject({ class: z.string().min(1), fingerprint: z.string().min(1) }),
  // The program that produced this record. A record of another build still
  // applies, and the map names the change with the reason `tool-changed`. A
  // record carried over from the previous format names an unknown producer
  // with an empty fingerprint, and that is not a broken record.
  tool: evidenceToolSchema,
  producer: z.strictObject({
    class: z.string().min(1),
    identity: z.string().min(1),
    run: nullableString,
  }),
  independence: z.enum(INDEPENDENCE_LEVELS),
  outcome: z.enum(EVIDENCE_OUTCOMES),
  issued_at: z.number().int(),
  valid_until: z.number().int().nullable().default(null),
  evidence_ref: nullableString,
  control_reach: nullableString,
});

export const evidenceRecordSchema = evidenceSchema.extend({
  sequence: z.number().int().nonnegative(),
  requirementPaths: z.array(z.string()),
});

export type MathMap = z.output<typeof mapSchema>;
export type MapState = z.output<typeof mapStateSchema>;
export type ClaimState = (typeof CLAIM_STATES)[number];
export type StateReason = (typeof STATE_REASONS)[number];
export type Verdict = (typeof VERDICTS)[number];
export type EvidenceOutcome = (typeof EVIDENCE_OUTCOMES)[number];
export type IndependenceLevel = (typeof INDEPENDENCE_LEVELS)[number];
export type Claim = z.output<typeof claimSchema>;
export type Spec = z.output<typeof specSchema>;
export type Evidence = z.output<typeof evidenceSchema>;
export type EvidenceRecord = z.output<typeof evidenceRecordSchema>;
export type Goal = z.output<typeof goalSchema>;
