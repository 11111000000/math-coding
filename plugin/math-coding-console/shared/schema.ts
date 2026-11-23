import { z } from "zod";
import {
  claimSchema,
  EVIDENCE_OUTCOMES,
  GENERATIONS,
  goalSchema,
  INDEPENDENCE_LEVELS,
  requirementSchema,
  sourceSchema,
  waiverSchema,
  type Claim,
  type Evidence,
  type Generation,
  type MathMap,
  type Requirement,
  type Spec,
} from "./domain";

/**
 * The readers of the generations.
 *
 * A project on disk is written in the schema of its own generation. The
 * console reads the generations that exist - the current one and the ones
 * before it - so a project of a previous line is shown by the newest console
 * instead of being refused by it.
 *
 * Every reader is strict about the format it reads: an unknown field is an
 * error, not silence. Every reader produces the same canonical types, so the
 * console has one model of a claim whatever generation wrote it. This is the
 * same shape as the reader of the previous version in the program itself
 * (`adapter/migration.ml`): the fields the previous generation carried and
 * this one does not read are dropped, not read.
 *
 * What a generation does not carry is not invented. A field that generation
 * did not write stays empty or unknown, and the console says so instead of
 * borrowing the words of another generation for it.
 */

export { GENERATIONS };
export type { Generation };

/** A file read in the generation it was written in. */
export interface GenerationRead<T> {
  generation: Generation;
  value: T;
}

/**
 * The name of a generation, as the console shows it.
 *
 * The name is data, not a sentence: it is the same in every language.
 */
export function generationName(generation: Generation): string {
  return `v${generation}`;
}

/**
 * The failure of a file that does not hold what its generation promises.
 *
 * The message names the file and the reason, so the human can act on it. It
 * is never a fallback: a file that cannot be read is refused, not read as
 * something else.
 */
export function parseWith<T>(schema: z.ZodType<T>, value: unknown, label: string): T {
  const result = schema.safeParse(value);
  if (result.success) return result.data;
  const details = result.error.issues
    .slice(0, 5)
    .map((issue) => `${issue.path.join(".") || label}: ${issue.message}`)
    .join("; ");
  throw new Error(`${label} failed validation: ${details}`);
}

/** The version a file declares, if it declares one. */
function schemaVersionOf(json: unknown): number | undefined {
  if (typeof json !== "object" || json === null || Array.isArray(json)) return undefined;
  const value = (json as Record<string, unknown>).schema_version;
  if (value === undefined) return undefined;
  if (typeof value !== "number" || !Number.isInteger(value)) {
    throw new Error("schema_version must be an integer");
  }
  return value;
}

// ---------------------------------------------------------------------------
// The current generation.
// ---------------------------------------------------------------------------

/** The aim of the current and of the fifth generation. */
const goalFileSchema = z.strictObject({
  text: z.string().min(1),
  scope: z.array(z.string()),
  by: z.string().min(1),
  at: z.number().int(),
  reason: z.string().nullable().default(null),
});

/** The specification of the current generation. */
const specFileV6 = z.strictObject({
  schema_version: z.literal(6),
  environment: z.string().max(512).nullable().optional(),
  goal: goalFileSchema.nullable().default(null),
  claims: z.array(claimSchema),
});

/**
 * The map of the current generation.
 *
 * The observer is named and its digest is never empty: a map of the current
 * generation is written by the program that reads it, so it knows its own
 * build. A map without that digest is not a map of this generation.
 */
const mapFileV6 = z.strictObject({
  schema_version: z.literal(6),
  verdict: z.enum(["green", "red", "unknown", "vacant"]),
  exit: z.number().int(),
  claims: z.number().int().nonnegative(),
  goal: goalFileSchema.nullable().default(null),
  tool: z.strictObject({ class: z.string().min(1), fingerprint: z.string().min(1) }),
  states: z.array(
    z.strictObject({
      id: z.string().min(1),
      state: z.enum(["holds", "refuted", "inconclusive", "outdated", "never-checked", "waived"]),
      source_changed: z.boolean(),
      reason: z
        .enum([
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
        ])
        .optional(),
    }),
  ),
  uncovered: z.array(z.string()),
  next: z.string(),
});

/** The record of the current generation. */
const evidenceFileV6 = z.strictObject({
  schema_version: z.literal(6),
  claim_id: z.string().min(1),
  requirement: requirementSchema,
  candidate_tree: z.string().min(1),
  materials_digest: z.string().min(1),
  definition_digest: z.string().min(1),
  verifier_digest: z.string().min(1),
  environment: z.strictObject({ class: z.string().min(1), fingerprint: z.string().min(1) }),
  tool: z.strictObject({ class: z.string().min(1), fingerprint: z.string() }),
  producer: z.strictObject({
    class: z.string().min(1),
    identity: z.string().min(1),
    run: z.string().nullable().default(null),
  }),
  independence: z.enum(INDEPENDENCE_LEVELS),
  outcome: z.enum(EVIDENCE_OUTCOMES),
  issued_at: z.number().int(),
  valid_until: z.number().int().nullable().default(null),
  evidence_ref: z.string().nullable().default(null),
  control_reach: z.string().nullable().default(null),
});

// ---------------------------------------------------------------------------
// The fifth generation.
// ---------------------------------------------------------------------------

/** The kinds and the phases the fifth generation carried and dropped later. */
const KIND_V5 = ["invariant", "acceptance", "recovery", "operational", "judgment"] as const;
const PHASE_V5 = ["pre-merge", "pre-release", "post-release"] as const;

/** The waiver of the fifth generation, with the review trigger it carried. */
const waiverFileV5 = z.strictObject({
  gap: z.string().min(1),
  scope: z.array(z.string()),
  issuer: z.string().min(1),
  issued_at: z.number().int(),
  expires_at: z.number().int(),
  reason: z.string().min(1),
  compensating_controls: z.array(z.string()),
  recovery: z.string().min(1),
  review_on: z.array(z.string()).default([]),
});

/** The claim of the fifth generation. */
const claimFileV5 = z.strictObject({
  id: z.string().min(1),
  text: z.string().min(1),
  scope: z.array(z.string()),
  source: sourceSchema.nullable().default(null),
  kind: z.enum(KIND_V5).optional(),
  phase: z.enum(PHASE_V5).optional(),
  owner: z.string().nullable().default(null),
  review_on: z.array(z.string()).optional(),
  requirements: z.array(requirementSchema),
  falsifier: z.string().default(""),
  register: z.enum(["fact", "hypothesis", "judgment", "unknown"]),
  control: z.string().nullable().default(null),
  waiver: waiverFileV5.nullable().default(null),
  environment: z.string().max(512).nullable().optional(),
});

/**
 * The specification of the fifth generation.
 *
 * The fifth generation still allowed the two fields of the fourth that it
 * did not read: the price of the uncertainty and the closed waves. The
 * program of that generation accepted them and ignored them, so the reader
 * does the same.
 */
const specFileV5 = z.strictObject({
  schema_version: z.union([z.literal(4), z.literal(5)]),
  goal: goalFileSchema.nullable().default(null),
  environment: z.string().max(512).nullable().optional(),
  uncertainty_budget: z.unknown().optional(),
  closed_waves: z.unknown().optional(),
  claims: z.array(claimFileV5),
});

/** The map of the fifth generation: it names no observer. */
const mapFileV5 = z.strictObject({
  schema_version: z.literal(5),
  verdict: z.enum(["green", "red", "unknown", "vacant"]),
  exit: z.number().int(),
  claims: z.number().int().nonnegative(),
  goal: goalFileSchema.nullable().default(null),
  states: z.array(
    z.strictObject({
      id: z.string().min(1),
      state: z.enum([
        "holds",
        "refuted",
        "inconclusive",
        "not-checkable",
        "outdated",
        "never-checked",
        "waived",
      ]),
      source_changed: z.boolean(),
      reason: z
        .enum([
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
          "not-checkable",
        ])
        .optional(),
    }),
  ),
  uncovered: z.array(z.string()),
  next: z.string(),
});

/** The record of the fifth generation: it names no producer. */
const evidenceFileV5 = z.strictObject({
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
    run: z.string().nullable().default(null),
  }),
  independence: z.enum(INDEPENDENCE_LEVELS),
  outcome: z.enum(EVIDENCE_OUTCOMES),
  issued_at: z.number().int(),
  valid_until: z.number().int().nullable().default(null),
  evidence_ref: z.string().nullable().default(null),
  control_reach: z.string().nullable().default(null),
});

// ---------------------------------------------------------------------------
// The generations before the fifth.
// ---------------------------------------------------------------------------

/** The states the fourth generation knew. */
const LEGACY_STATES = [
  "holds",
  "refuted",
  "inconclusive",
  "not checkable",
  "outdated",
  "never checked",
  "accepted by a person",
] as const;

/** The aim of the generations before the fifth carried no reason. */
const goalFileLegacy = z.strictObject({
  text: z.string().min(1),
  scope: z.array(z.string()),
  by: z.string().min(1),
  at: z.number().int(),
});

/** The acceptance of the generations before the fifth. */
const acceptedFileLegacy = z.strictObject({
  by: z.string().min(1),
  reason: z.string().min(1),
});

/**
 * The claim of the third generation: one check, not a tree of conditions.
 */
const claimFileLegacyV3 = z.strictObject({
  id: z.string().min(1),
  subject: z.string().min(1),
  scope: z.array(z.string()),
  check: z.string().min(1),
  falsifier: z.string().min(1),
  register: z.enum(["fact", "hypothesis", "judgment", "unknown"]),
  accepted: acceptedFileLegacy.nullable().default(null),
});

/** The claim of the fourth generation: a tree of conditions. */
const claimFileLegacyV4 = z.strictObject({
  id: z.string().min(1),
  subject: z.string().min(1),
  scope: z.array(z.string()),
  requirements: z.array(requirementSchema),
  falsifier: z.string().min(1),
  register: z.enum(["fact", "hypothesis", "judgment", "unknown"]),
  accepted: acceptedFileLegacy.nullable().default(null),
});

/** The specification of the generations before the fifth. */
const specFileLegacy = z.strictObject({
  goal: goalFileLegacy.nullable().default(null),
  uncertainty_budget: z.number().int().nonnegative(),
  claims: z.array(z.union([claimFileLegacyV3, claimFileLegacyV4])),
});

/** The map of the fourth generation: it names no observer and no next step. */
const mapFileLegacy = z.strictObject({
  verdict: z.enum(["green", "red", "unknown"]),
  exit: z.number().int(),
  claims: z.number().int().nonnegative(),
  uncertainty_consumed: z.number().int().nonnegative(),
  uncertainty_budget: z.number().int().nonnegative(),
  uncovered: z.number().int().nonnegative(),
  uncovered_paths: z.array(z.string()),
  goal: z
    .strictObject({ text: z.string().min(1), scope: z.array(z.string()), by: z.string().min(1) })
    .nullable()
    .default(null),
  states: z.array(z.strictObject({ id: z.string().min(1), state: z.enum(LEGACY_STATES) })),
});

/**
 * The record of the generations before the fifth.
 *
 * The program of those generations read the trail leniently: it took the
 * fields it knew and ignored the rest. The reader does the same, so a
 * journal that grew in the middle of a line is still readable.
 */
const evidenceFileLegacy = z
  .strictObject({
    claim: z.string().min(1),
    kind: z.enum(["verifier", "review"]).optional(),
    requirement: z.string().min(1).optional(),
    outcome: z.enum(["verified", "falsified", "unresolved", "refused"]),
    bound_to: z.string().min(1),
    producer: z.string().min(1).optional(),
    reason: z.string().nullable().default(null),
    at_commit: z.string().nullable().optional(),
    at: z.union([z.string(), z.number().int()]),
    valid_until: z.union([z.string(), z.number().int()]).nullable().optional(),
    control: z.string().nullable().optional(),
    reach: z.string().nullable().optional(),
  })
  .loose();

// ---------------------------------------------------------------------------
// The readers.
// ---------------------------------------------------------------------------

/** The observer of a map that names no build. */
const UNKNOWN_OBSERVER = { class: "mathc", fingerprint: "" } as const;

/** The producer of a record that names no build. */
const UNKNOWN_PRODUCER = { class: "mathc", fingerprint: "" } as const;

/**
 * The specification of a project, in the generation it was written in.
 *
 * The reader of the current generation is the format itself. The reader of
 * the previous generations drops the fields those generations carried and
 * the current one does not read, and it says which generation it read.
 */
export function readSpec(json: unknown): GenerationRead<Spec> {
  const version = schemaVersionOf(json);
  if (version === 6) return { generation: 6, value: parseWith(specFileV6, json, "spec.json") };
  if (version === 5 || version === 4) return { generation: version, value: readSpecV5(json) };
  if (version === undefined) return readSpecLegacy(json);
  throw new Error(`unsupported schema_version ${version}`);
}

/** The claim of the fifth generation, in the shape the console works with. */
function claimOfV5(claim: z.output<typeof claimFileV5>): Claim {
  return {
    id: claim.id,
    text: claim.text,
    scope: claim.scope,
    source: claim.source,
    owner: claim.owner,
    requirements: claim.requirements,
    falsifier: claim.falsifier,
    register: claim.register,
    control: claim.control,
    waiver: claim.waiver === null
      ? null
      : {
        gap: claim.waiver.gap,
        scope: claim.waiver.scope,
        issuer: claim.waiver.issuer,
        issued_at: claim.waiver.issued_at,
        expires_at: claim.waiver.expires_at,
        reason: claim.waiver.reason,
        compensating_controls: claim.waiver.compensating_controls,
        recovery: claim.waiver.recovery,
      },
    environment: claim.environment,
  };
}

function readSpecV5(json: unknown): Spec {
  const file = parseWith(specFileV5, json, "spec.json");
  return {
    schema_version: file.schema_version,
    environment: file.environment,
    goal: file.goal,
    claims: file.claims.map(claimOfV5),
  };
}

/**
 * The specification of a project of the generations before the fifth.
 *
 * Those generations did not number their format, so the generation is read
 * from the claims: the third one named one check per claim, the fourth named
 * a tree of conditions. The fields those generations carried and the
 * current one does not read - the acceptance of a person, the price of the
 * uncertainty - are dropped or kept as what they were.
 */
function readSpecLegacy(json: unknown): GenerationRead<Spec> {
  const file = parseWith(specFileLegacy, json, "spec.json");
  const third = file.claims.map((claim) => claimFileLegacyV3.safeParse(claim));
  // A project without claims says nothing about the generation it was
  // written in. The program of that era read such a specification as the
  // fourth generation, and the console reads it the same way.
  const isThird = file.claims.length > 0 && third.every((result) => result.success);
  const generation: Generation = isThird ? 3 : 4;
  const claims: Claim[] = isThird
    ? file.claims.map((claim) => claimOfLegacyV3(parseWith(claimFileLegacyV3, claim, "spec.json claim")))
    : file.claims.map((claim) => claimOfLegacyV4(parseWith(claimFileLegacyV4, claim, "spec.json claim")));
  return {
    generation,
    value: {
      schema_version: generation,
      goal: file.goal === null
        ? null
        : { text: file.goal.text, scope: file.goal.scope, by: file.goal.by, at: file.goal.at, reason: null },
      claims,
    },
  };
}

function claimOfLegacyV3(claim: z.output<typeof claimFileLegacyV3>): Claim {
  return {
    id: claim.id,
    text: claim.subject,
    scope: claim.scope,
    source: null,
    // The only person that generation named for a claim is the person who
    // accepted it, so the owner of the claim is that person.
    owner: claim.accepted?.by ?? null,
    requirements: [{ kind: "verifier", spec: claim.check }],
    falsifier: claim.falsifier,
    register: claim.register,
    control: null,
    waiver: null,
  };
}

function claimOfLegacyV4(claim: z.output<typeof claimFileLegacyV4>): Claim {
  return {
    id: claim.id,
    text: claim.subject,
    scope: claim.scope,
    source: null,
    owner: claim.accepted?.by ?? null,
    requirements: claim.requirements,
    falsifier: claim.falsifier,
    register: claim.register,
    control: null,
    waiver: null,
  };
}

/**
 * The map of a project, in the generation it was written in.
 *
 * The map of the current generation names the program that wrote it. The
 * maps of the previous generations do not, so the reader carries an unknown
 * observer: the console says that it does not know which build wrote the
 * map it reads, and never names a build of its own.
 */
export function readMap(json: unknown): GenerationRead<MathMap> {
  const version = schemaVersionOf(json);
  if (version === 6) return { generation: 6, value: parseWith(mapFileV6, json, "mathc map") };
  if (version === 5) return { generation: 5, value: readMapV5(json) };
  if (version === undefined) return { generation: 4, value: readMapLegacy(json) };
  throw new Error(`unsupported schema_version ${version}`);
}

function readMapV5(json: unknown): MathMap {
  const file = parseWith(mapFileV5, json, "mathc map");
  return {
    schema_version: 5,
    verdict: file.verdict,
    exit: file.exit,
    claims: file.claims,
    goal: file.goal,
    tool: UNKNOWN_OBSERVER,
    states: file.states.map((state) => ({
      id: state.id,
      state: state.state,
      source_changed: state.source_changed,
      reason: state.reason,
    })),
    uncovered: file.uncovered,
    next: file.next,
  };
}

/**
 * The map of the fourth generation.
 *
 * That map names no observer, no reason of a state, no state of the source
 * and no next step. The reader carries what the map does not say as
 * unknown, and the words of that generation are kept: a claim that nothing
 * can check is not a claim whose check did not decide.
 */
function readMapLegacy(json: unknown): MathMap {
  const file = parseWith(mapFileLegacy, json, "mathc map");
  return {
    schema_version: 4,
    verdict: file.verdict,
    exit: file.exit,
    claims: file.claims,
    goal: file.goal === null
      ? null
      : { text: file.goal.text, scope: file.goal.scope, by: file.goal.by, at: null, reason: null },
    tool: UNKNOWN_OBSERVER,
    states: file.states.map((state) => ({
      id: state.id,
      state: LEGACY_STATE_WORDS[state.state],
      source_changed: null,
    })),
    uncovered: file.uncovered_paths,
    next: "",
  };
}

/** The words of the fourth generation, in the words of the console. */
const LEGACY_STATE_WORDS: Record<(typeof LEGACY_STATES)[number], MathMap["states"][number]["state"]> = {
  holds: "holds",
  refuted: "refuted",
  inconclusive: "inconclusive",
  "not checkable": "not-checkable",
  outdated: "outdated",
  "never checked": "never-checked",
  "accepted by a person": "accepted-by-a-person",
};

/**
 * A record of the journal, in the generation it was written in.
 *
 * The claims are needed for one thing only: the record of the third
 * generation does not name the condition it speaks about, and the condition
 * of that claim is the one check the claim declared.
 */
export function readEvidence(json: unknown, claims: Claim[]): GenerationRead<Evidence> {
  const version = schemaVersionOf(json);
  if (version === 6) return { generation: 6, value: parseWith(evidenceFileV6, json, "evidence record") };
  if (version === 5) return { generation: 5, value: readEvidenceV5(json) };
  if (version === undefined) return readEvidenceLegacy(json, claims);
  throw new Error(`unsupported evidence schema_version ${version}`);
}

function readEvidenceV5(json: unknown): Evidence {
  const file = parseWith(evidenceFileV5, json, "evidence record");
  return {
    ...file,
    schema_version: 5,
    // The record of that generation does not name the program that wrote it.
    tool: UNKNOWN_PRODUCER,
  };
}

/** The outcome of the generations before the fifth, in the words of the console. */
const LEGACY_OUTCOMES: Record<string, (typeof EVIDENCE_OUTCOMES)[number]> = {
  verified: "pass",
  falsified: "fail",
  unresolved: "inconclusive",
  refused: "not-run",
};

/**
 * The record of the generations before the fifth.
 *
 * That record does not bind itself to the subject, to the definition, to the
 * verifier, to the environment or to the producer, and it does not name the
 * condition it speaks about. The reader carries what the record does not say
 * as unknown, and it takes the condition of the third generation from the
 * claim the record speaks about.
 */
function readEvidenceLegacy(json: unknown, claims: Claim[]): GenerationRead<Evidence> {
  const file = parseWith(evidenceFileLegacy, json, "evidence record");
  const generation: Generation = file.kind === undefined ? 3 : 4;
  const requirement: Requirement | null = file.requirement === undefined
    ? firstRequirementOf(claims, file.claim)
    : file.kind === "review"
      ? { kind: "review", spec: file.requirement, minimum_independence: "external" }
      : { kind: "verifier", spec: file.requirement };
  if (requirement === null) {
    throw new Error(`evidence record failed validation: the record of ${file.claim} names no condition`);
  }
  return {
    generation,
    value: {
      schema_version: generation,
      claim_id: file.claim,
      requirement,
      candidate_tree: file.bound_to,
      materials_digest: "",
      definition_digest: "",
      verifier_digest: "",
      environment: null,
      tool: UNKNOWN_PRODUCER,
      producer: {
        class: file.producer === undefined ? "unknown" : "process",
        identity: file.producer ?? file.claim,
        run: null,
      },
      independence: null,
      outcome: LEGACY_OUTCOMES[file.outcome] ?? "inconclusive",
      issued_at: secondsOf(file.at),
      valid_until: file.valid_until === undefined || file.valid_until === null ? null : secondsOf(file.valid_until),
      evidence_ref: null,
      control_reach: file.reach ?? null,
    },
  };
}

/** The condition of a claim, when the claim declares exactly one. */
function firstRequirementOf(claims: Claim[], claimId: string): Requirement | null {
  const claim = claims.find((item) => item.id === claimId);
  const requirement = claim?.requirements[0];
  return requirement ?? null;
}

/** The seconds of a moment the generations before the fifth wrote as a string. */
function secondsOf(value: string | number): number {
  const seconds = typeof value === "number" ? value : Number(value);
  if (!Number.isInteger(seconds)) {
    throw new Error(`evidence record failed validation: the moment ${String(value)} is not a whole number of seconds`);
  }
  return seconds;
}

/**
 * The journal of a project, in the generation it was written in.
 *
 * The program of each generation kept its journal in its own place, and the
 * console reads the place of the generation of the project. The records of
 * that place are read in the generation each record declares, so a journal
 * that was carried over is read as what it is.
 */
export function journalPath(root: string, generation: Generation): string {
  if (generation === 6) return `${root}/.math/v6/evidence.jsonl`;
  if (generation === 5) return `${root}/.math/v5/evidence.jsonl`;
  return `${root}/.math/trail.jsonl`;
}
