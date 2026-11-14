import { z } from "zod";

export const VERDICTS = ["green", "red", "unknown", "vacant"] as const;
export const CLAIM_STATES = [
  "holds",
  "refuted",
  "inconclusive",
  "not-checkable",
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
});

export const mapSchema = z.strictObject({
  schema_version: z.literal(5),
  verdict: z.enum(VERDICTS),
  exit: z.number().int(),
  claims: z.number().int().nonnegative(),
  goal: goalSchema.nullable(),
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
  review_on: z.array(z.string()),
});

export const claimSchema = z.strictObject({
  id: z.string().min(1),
  text: z.string().min(1),
  scope: z.array(z.string()),
  source: sourceSchema.nullable().default(null),
  kind: z.enum(["invariant", "acceptance", "recovery", "operational", "judgment"]).default("invariant"),
  phase: z.enum(["pre-merge", "pre-release", "post-release"]).default("pre-merge"),
  owner: nullableString,
  review_on: z.array(z.string()).default([]),
  requirements: z.array(requirementSchema),
  falsifier: z.string().default(""),
  register: z.enum(["fact", "hypothesis", "judgment", "unknown"]),
  control: nullableString,
  waiver: waiverSchema.nullable().default(null),
});

export const specSchema = z.strictObject({
  schema_version: z.literal(5),
  goal: goalSchema.nullable().default(null),
  claims: z.array(claimSchema),
  uncertainty_budget: z.unknown().optional(),
  closed_waves: z.unknown().optional(),
});

export const evidenceSchema = z.strictObject({
  schema_version: z.literal(5),
  claim_id: z.string().min(1),
  requirement: requirementSchema,
  candidate_tree: z.string().min(1),
  materials_digest: z.string().min(1),
  definition_digest: z.string().min(1),
  verifier_digest: z.string().min(1),
  environment: z.strictObject({ class: z.string().min(1), fingerprint: z.string().min(1) }),
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
export type ClaimState = (typeof CLAIM_STATES)[number];
export type Verdict = (typeof VERDICTS)[number];
export type EvidenceOutcome = (typeof EVIDENCE_OUTCOMES)[number];
export type Claim = z.output<typeof claimSchema>;
export type Spec = z.output<typeof specSchema>;
export type Evidence = z.output<typeof evidenceSchema>;
export type EvidenceRecord = z.output<typeof evidenceRecordSchema>;
export type Goal = z.output<typeof goalSchema>;
