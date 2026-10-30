import { defineRpc } from "@getpaseo/plugin";
import { z } from "zod";

/**
 * The console is a view and a control surface over the math-coding kernel.
 * It never re-derives a verdict: every number below that carries a verdict
 * came out of `mathc` (counters, gaps, packages, self-check, gate, doctor).
 * The console reads decision files and the attestation store only to show
 * their TEXT — the intent, the commitment, the scope, the risk triggers — and
 * to join them with the kernel's verdicts.
 */

/* ------------------------------------------------------------------ verdict */

export const selfCheckSubjectSchema = z.object({
  name: z.string(),
  verdict: z.string(),
  causes: z.array(z.string()),
  remedies: z.array(z.string()),
  waivers: z.array(z.string()),
});

export const verdictSectionSchema = z.object({
  /** pass | fail | unknown — the kernel's own word. */
  verdict: z.string(),
  exitCode: z.number(),
  kernelDigest: z.string(),
  repositoryDigest: z.string(),
  now: z.string(),
  subjects: z.object({
    total: z.number(),
    pass: z.number(),
    fail: z.number(),
    unknown: z.number(),
  }),
  /** The subjects that are not green, with the kernel's own remedies. */
  failures: z.array(selfCheckSubjectSchema),
  /** The kernel's stderr, trimmed. Often empty: the verdict travels in JSON. */
  detail: z.string(),
  /** Set when the kernel could not be run at all. */
  error: z.string().nullable(),
});

/* ---------------------------------------------------------------- coverage */

export const coverageSchema = z.object({
  decisions: z.number(),
  activeDecisions: z.number(),
  obligations: z.number(),
  attestations: z.number(),
  /** Obligation counts per verdict word, straight from `mathc packages`. */
  byVerdict: z.record(z.string(), z.number()),
  /** Promise classes from `mathc gaps`: checkable | not-a-check | ... */
  promisesByClass: z.record(z.string(), z.number()),
  /** Promise states from `mathc gaps`: missing | stale | unknown | ... */
  promisesByState: z.record(z.string(), z.number()),
  declaredPromises: z.number(),
  openPromises: z.number(),
  waivedPromises: z.number(),
  cramTests: z.number(),
  cliSubcommands: z.number(),
});

/* --------------------------------------------------------------- promises */

export const promiseSchema = z.object({
  decision: z.string(),
  obligation: z.string(),
  /** checkable | not-a-check | unidentified */
  class: z.string(),
  /** missing | stale | unknown | ... */
  state: z.string(),
  verifiers: z.array(z.string()),
  cause: z.string(),
  action: z.string(),
});

/* ------------------------------------------------------------ attestations */

export const attestationSummarySchema = z.object({
  id: z.string(),
  decision: z.string(),
  obligation: z.string(),
  kind: z.string(),
  result: z.string(),
  producer: z.string(),
  producerClass: z.string(),
  run: z.string().nullable(),
  issuedAt: z.string(),
  expiresAt: z.string().nullable(),
  materialsDigest: z.string(),
  evidenceDigest: z.string().nullable(),
  /** True when the attestation names a scope that no longer matches the tree. */
  stale: z.boolean(),
});

export const attestationSectionSchema = z.object({
  total: z.number(),
  byKind: z.record(z.string(), z.number()),
  byResult: z.record(z.string(), z.number()),
  byProducerClass: z.record(z.string(), z.number()),
  latest: z.array(attestationSummarySchema),
  expired: z.number(),
});

/* -------------------------------------------------------------- decisions */

export const obligationSchema = z.object({
  id: z.string(),
  outcome: z.string().nullable(),
  claim: z.string(),
  verifier: z.string().nullable(),
  verifiers: z.array(z.string()),
  /** The kernel's verdict for this obligation. Never guessed here. */
  verdict: z.string(),
  attestationId: z.string().nullable(),
  attestationExpiresAt: z.string().nullable(),
  remedies: z.array(z.string()),
  /** The verifier names a human, so only a person can close this. */
  manual: z.boolean(),
});

export const decisionSummarySchema = z.object({
  id: z.string(),
  revision: z.string().nullable(),
  state: z.string(),
  intent: z.string(),
  file: z.string(),
  axiomLinks: z.array(z.string()),
  scopePaths: z.array(z.string()),
  obligationCount: z.number(),
  byVerdict: z.record(z.string(), z.number()),
  manualCount: z.number(),
  /** The worst verdict among the decision's obligations. */
  topVerdict: z.string(),
});

export const policySchema = z.object({
  policyId: z.string(),
  parent: z.string().nullable(),
  scopePaths: z.array(z.string()),
  modeFloor: z.string(),
  overrideProbability: z.number(),
});

/* ----------------------------------------------------------------- review */

export const reviewItemSchema = z.object({
  decision: z.string(),
  obligation: z.string(),
  claim: z.string(),
  verifier: z.string().nullable(),
  verdict: z.string(),
  manual: z.boolean(),
  /** A review attestation already exists for this obligation. */
  reviewed: z.boolean(),
  reviewedAt: z.string().nullable(),
  reviewedBy: z.string().nullable(),
  rationale: z.string().nullable(),
});

/* ----------------------------------------------------------------- doctor */

export const doctorSectionSchema = z.object({
  id: z.string(),
  label: z.string(),
  verdict: z.string(),
  details: z.record(z.string(), z.unknown()),
});

export const doctorSchema = z.object({
  exitCode: z.number(),
  sections: z.array(doctorSectionSchema),
});

/* -------------------------------------------------------------------- git */

export const gitStateSchema = z.object({
  branch: z.string(),
  head: z.string(),
  dirty: z.boolean(),
  dirtyPaths: z.array(z.string()),
  ahead: z.number(),
  behind: z.number(),
  lastCommitAt: z.string().nullable(),
  lastCommitSubject: z.string().nullable(),
});

/* ----------------------------------------------------------------- state */

export const stateRpc = defineRpc({
  name: "mathcoding.state",
  input: z.object({ root: z.string().optional() }),
  output: z.object({
    root: z.string().nullable(),
    rootError: z.string().nullable(),
    /** The repository's VERSION file. */
    version: z.string().nullable(),
    /** What `mathc version` reports. */
    kernelVersion: z.string().nullable(),
    generatedAt: z.string(),
    verdict: verdictSectionSchema.nullable(),
    coverage: coverageSchema,
    decisions: z.array(decisionSummarySchema),
    promises: z.array(promiseSchema),
    attestations: attestationSectionSchema,
    reviewQueue: z.array(reviewItemSchema),
    doctor: doctorSchema.nullable(),
    policies: z.array(policySchema),
    git: gitStateSchema.nullable(),
    warnings: z.array(z.string()),
  }),
});

export const promiseListRpc = defineRpc({
  name: "mathcoding.promises",
  input: z.object({
    root: z.string().optional(),
    state: z.string().optional(),
    class: z.string().optional(),
    decision: z.string().optional(),
    query: z.string().optional(),
    limit: z.number().int().positive().max(2000).default(300),
  }),
  output: z.object({
    root: z.string().nullable(),
    error: z.string().nullable(),
    total: z.number(),
    promises: z.array(promiseSchema),
  }),
});

export const decisionRpc = defineRpc({
  name: "mathcoding.decision",
  input: z.object({ root: z.string().optional(), decisionId: z.string() }),
  output: z.object({
    root: z.string().nullable(),
    error: z.string().nullable(),
    id: z.string(),
    revision: z.string().nullable(),
    state: z.string(),
    intent: z.string(),
    commitment: z.string(),
    axiomLinks: z.array(z.string()),
    scopePaths: z.array(z.string()),
    file: z.string(),
    outcomes: z.array(z.object({ id: z.string(), statement: z.string() })),
    obligations: z.array(obligationSchema),
    attestations: z.array(attestationSummarySchema),
    assumptions: z.array(
      z.object({
        id: z.string(),
        state: z.string(),
        statement: z.string(),
        owner: z.string().nullable(),
        consequenceIfFalse: z.string().nullable(),
      }),
    ),
    relations: z.record(z.string(), z.array(z.string())),
    riskTriggers: z.array(z.string()),
    counterexample: z.string().nullable(),
    antithesis: z.string().nullable(),
    reviews: z.array(reviewItemSchema),
    /** The kernel's own diagnostics for this file (MC-* codes). */
    diagnostics: z.array(
      z.object({
        code: z.string(),
        severity: z.string(),
        message: z.string(),
      }),
    ),
    /**
     * False when the console could not read the file's prose. The structure
     * and the verdicts still come from the kernel, so the decision is
     * still there; what is missing is what it SAYS.
     */
    proseReadable: z.boolean(),
  }),
});

export const searchRpc = defineRpc({
  name: "mathcoding.search",
  input: z.object({ root: z.string().optional(), query: z.string() }),
  output: z.object({
    root: z.string().nullable(),
    error: z.string().nullable(),
    matches: z.array(
      z.object({
        kind: z.string(),
        id: z.string(),
        decision: z.string(),
        snippet: z.string(),
      }),
    ),
  }),
});

/* ---------------------------------------------------------------- review */

export const reviewSubmitRpc = defineRpc({
  name: "mathcoding.review.submit",
  input: z.object({
    root: z.string().optional(),
    decisionId: z.string(),
    obligationId: z.string(),
    result: z.enum(["pass", "fail"]),
    producer: z.string(),
    rationale: z.string(),
    /** The session the review belongs to, when there is one. */
    agentId: z.string().optional(),
  }),
  output: z.object({
    ok: z.boolean(),
    error: z.string().nullable(),
    attestationId: z.string().nullable(),
    attestationPath: z.string().nullable(),
    /** The kernel's verdict for the obligation AFTER the signature. */
    verdictAfter: z.string().nullable(),
    dispatched: z.boolean(),
    dispatchedTo: z.string().nullable(),
    detail: z.string(),
  }),
});

export const lifecycleRpc = defineRpc({
  name: "mathcoding.lifecycle",
  input: z.object({
    root: z.string().optional(),
    decisionId: z.string(),
    action: z.enum(["mark-superseded", "mark-retired", "set"]),
    state: z.string().optional(),
    by: z.string().optional(),
  }),
  output: z.object({
    ok: z.boolean(),
    error: z.string().nullable(),
    detail: z.string(),
  }),
});

/* ---------------------------------------------------------------- actions */

export const actionRpc = defineRpc({
  name: "mathcoding.action",
  input: z.object({
    root: z.string().optional(),
    action: z.enum([
      "self-check",
      "validate",
      "verify",
      "rehash",
      "attest-batch",
      "negative-control",
      "doctor",
      "gate",
      "context",
      "render",
      "session-start",
      "record",
      "new-decision",
      "re-evaluate",
      "packages",
      "gaps",
      "counters",
      "explain-diagnostic",
      "update",
    ]),
    /** Positional arguments for the kernel subcommand. */
    args: z.array(z.string()).default([]),
    /** Extra flags, e.g. `--write`. */
    flags: z.array(z.string()).default([]),
    timeoutMs: z.number().int().positive().max(900_000).optional(),
  }),
  output: z.object({
    ok: z.boolean(),
    error: z.string().nullable(),
    exitCode: z.number(),
    stdout: z.string(),
    stderr: z.string(),
    command: z.string(),
    durationMs: z.number(),
  }),
});

export const gateRpc = defineRpc({
  name: "mathcoding.gate",
  input: z.object({
    root: z.string().optional(),
    base: z.string(),
    head: z.string(),
  }),
  output: z.object({
    ok: z.boolean(),
    error: z.string().nullable(),
    exitCode: z.number(),
    stdout: z.string(),
    stderr: z.string(),
  }),
});

export const diagnosticRpc = defineRpc({
  name: "mathcoding.diagnostic",
  input: z.object({ code: z.string() }),
  output: z.object({
    code: z.string(),
    definition: z.string(),
    occursWhen: z.string(),
    remediation: z.string(),
  }),
});

export const reviewTimelineDataSchema = z.object({
  decisionId: z.string(),
  obligationId: z.string(),
  verdict: z.string(),
  producer: z.string(),
  rationale: z.string(),
  at: z.string(),
  agentId: z.string().nullable(),
});

export type ReviewTimelineData = z.infer<typeof reviewTimelineDataSchema>;

/* ----------------------------------------------------------------- types */

export type VerdictSection = z.output<typeof verdictSectionSchema>;
export type Coverage = z.output<typeof coverageSchema>;
export type Promise_ = z.output<typeof promiseSchema>;
export type AttestationSummary = z.output<typeof attestationSummarySchema>;
export type AttestationSection = z.output<typeof attestationSectionSchema>;
export type DecisionSummary = z.output<typeof decisionSummarySchema>;
export type Obligation = z.output<typeof obligationSchema>;
export type ReviewItem = z.output<typeof reviewItemSchema>;
export type DoctorSchema = z.output<typeof doctorSchema>;
export type GitState = z.output<typeof gitStateSchema>;
export type Policy = z.output<typeof policySchema>;
export type MathCodingState = z.output<typeof stateRpc.output>;
export type MathCodingDecision = z.output<typeof decisionRpc.output>;
export type ActionResult = z.output<typeof actionRpc.output>;
