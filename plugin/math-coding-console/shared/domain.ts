import { z } from "zod";

export const VERDICTS = ["green", "red", "unknown", "vacant"] as const;
export const CLAIM_STATES = [
  "holds",
  "refuted",
  "inconclusive",
  "outdated",
  "never-checked",
  "waived",
  /**
   * The generations before the current one knew a state the current one does
   * not: a claim that no check can settle. The console keeps the word of the
   * generation it read, because "nothing can check this" and "the check did
   * not decide" are two different facts about the claim.
   */
  "not-checkable",
  /**
   * The generation before the previous one knew a state the current one does
   * not: a claim a person accepted. The current method does not have it, and
   * the console does not translate it into a state that means something else.
   */
  "accepted-by-a-person",
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
 * The generations a project can be written in.
 *
 * The current generation is the sixth. The fifth is the line before it, and
 * the third and the fourth are the generations that wrote their files
 * without numbering them.
 */
export const GENERATIONS = [3, 4, 5, 6] as const;

export type Generation = (typeof GENERATIONS)[number];

/** The generation a file declares. */
export const generationSchema = z.union([
  z.literal(3),
  z.literal(4),
  z.literal(5),
  z.literal(6),
]);

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
  // The fifth generation knew this reason and the current one does not: a
  // claim that no check can settle.
  "not-checkable",
] as const;

export const stateReasonSchema = z.enum(STATE_REASONS);

/**
 * The observer of a map or of a record.
 *
 * The class names the program, and the fingerprint names the build of it. The
 * fingerprint is empty when the generation that wrote the file does not name
 * the build: a map of the generation before the current one carries no digest
 * at all, and a record carried over from the previous format names an unknown
 * producer with an empty fingerprint. An empty fingerprint is therefore not a
 * broken observer, it is an unknown one, and the console says so instead of
 * inventing a build.
 */
export const observerSchema = z.strictObject({
  class: z.string().min(1),
  fingerprint: z.string(),
});

const nullableString = z.string().nullable().default(null);
export const goalSchema = z.strictObject({
  text: z.string().min(1),
  scope: z.array(z.string()),
  by: z.string().min(1),
  // The moment the aim was declared. The map of the generations before the
  // fifth does not name it, and the console carries it as unknown.
  at: z.number().int().nullable(),
  reason: nullableString,
});

export const mapStateSchema = z.strictObject({
  id: z.string().min(1),
  state: z.enum(CLAIM_STATES),
  // The generations before the fifth did not report whether the source of a
  // claim changed. The console does not guess: an unreported state stays
  // unreported, and the panel says that the map is silent about it.
  source_changed: z.boolean().nullable(),
  reason: stateReasonSchema.optional(),
});

export const mapSchema = z.strictObject({
  // The generation of the map. The map of a project of an earlier
  // generation carries the number of that generation, so the reader knows
  // which words it reads.
  schema_version: generationSchema,
  verdict: z.enum(VERDICTS),
  exit: z.number().int(),
  claims: z.number().int().nonnegative(),
  goal: goalSchema.nullable(),
  // The program that produced this map. The digest names the build, so a
  // reader knows which observer wrote the map it reads. A map of a generation
  // that does not name the build carries an empty fingerprint, and the
  // console reads it as an unknown observer.
  tool: observerSchema,
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

export const sourceSchema = z.strictObject({
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

export const waiverSchema = z.strictObject({
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
  // The generation of the specification. The reader of the file checks the
  // number against the format it reads; the canonical shape carries it, so
  // the console can name the generation of the project it shows.
  schema_version: generationSchema,
  // The declared environment is a prefix for every declared command. It is
  // optional, and the core owns its rules; the host only has to carry it.
  environment: z.string().max(512).nullable().optional(),
  goal: goalSchema.nullable().default(null),
  claims: z.array(claimSchema),
});

export const evidenceSchema = z.strictObject({
  // The generation of the record. A journal of a project of an earlier
  // generation holds records of that generation, and the console reads them
  // as what they are.
  schema_version: generationSchema,
  claim_id: z.string().min(1),
  requirement: requirementSchema,
  candidate_tree: z.string(),
  // The digests of the generations before the fifth. A journal of an earlier
  // generation does not bind a record to the subject, to the definition and
  // to the verifier, so it carries no digest. An empty digest is not a wrong
  // digest: it is a digest the generation did not write.
  materials_digest: z.string(),
  definition_digest: z.string(),
  verifier_digest: z.string(),
  // The environment a record was produced in. A journal of an earlier
  // generation does not name it, and the console then says that it is
  // unknown.
  environment: z.strictObject({ class: z.string().min(1), fingerprint: z.string() }).nullable(),
  // The program that produced this record. A record of another build still
  // applies, and the map names the change with the reason `tool-changed`. A
  // record carried over from the previous format names an unknown producer
  // with an empty fingerprint, and that is not a broken record.
  tool: observerSchema,
  producer: z.strictObject({
    class: z.string().min(1),
    identity: z.string().min(1),
    run: nullableString,
  }),
  // The independence of the observation. A journal of an earlier generation
  // does not name it.
  independence: z.enum(INDEPENDENCE_LEVELS).nullable(),
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
