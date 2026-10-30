import { appendFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import type { PluginHandlerContext } from "@getpaseo/plugin/server";
import {
  findDecisionFile,
  isManualVerifier,
  readAttestations,
  readPolicies,
  readProse,
  readReviewLedger,
  type CorpusAttestation,
  type CorpusDecision,
  type ReviewLedgerEntry,
} from "./corpus";
import {
  readCounters,
  readDoctor,
  readGate,
  readGaps,
  readKernelVersion,
  promisesFromPackages,
  readPackages,
  readSelfCheck,
  type KernelGaps,
  type KernelObligation,
  type KernelPackages,
  type KernelPromise,
} from "./kernel";
import { resolveLayout, resolveRoot, type ProjectLayout } from "./layout";
import { runGit, runMathc } from "./mathc";
import { cellFor, isOpen, worstVerdict } from "../shared/verdict";
import type {
  AttestationSection,
  AttestationSummary,
  Coverage,
  DecisionSummary,
  MosaicCell,
  Obligation,
  ReviewItem,
} from "../shared/contracts";

/**
 * The console's read model.
 *
 * Everything that carries a verdict came out of the kernel. The corpus reader
 * supplies the TEXT of a decision; the kernel supplies the truth about it.
 * Where the two meet — the obligation list — the kernel's answer wins.
 */

const REVIEW_PRODUCER_PATTERN = /^(human|agent|ci):[A-Za-z0-9][A-Za-z0-9._:/-]*$/;

export function assertProducer(producer: string): string | null {
  if (!REVIEW_PRODUCER_PATTERN.test(producer.trim())) {
    return "producer must be class-tagged: human:<name>, agent:<id> or ci:<job>.";
  }
  return null;
}

/* ------------------------------------------------------------- assembly */

/**
 * The promise worklist.
 *
 * `mathc gaps` is the census: it knows which promises are checkable, which
 * are open, and why. A kernel that predates it still knows every obligation's
 * verdict, so the worklist falls back to that — with the class marked
 * unidentified rather than guessed.
 */
function promisesOf(census: KernelPromise[] | undefined, packages: KernelPackages | null): KernelPromise[] {
  if (census !== undefined) return census;
  if (packages === null) return [];
  return promisesFromPackages(packages);
}

/**
 * The obligations of one decision.
 *
 * The LIST comes from the kernel's index, because the list is what the gate
 * sees. The prose fills in the claim and the full verifier list, and the
 * attestations fill in what has already been signed. A decision whose file
 * the console cannot read still appears, with the kernel's structure and
 * verdict, and without its prose.
 */
function obligationsFor(
  kernelObligations: KernelObligation[],
  prose: CorpusDecision | undefined,
  attestations: CorpusAttestation[],
): Obligation[] {
  const proseById = new Map((prose?.obligations ?? []).map((item) => [item.id, item]));

  return kernelObligations.map((kernelObligation) => {
    const written = proseById.get(kernelObligation.id);
    const verifiers =
      written !== undefined && written.verifiers.length > 0
        ? written.verifiers
        : kernelObligation.verifier !== null
          ? [kernelObligation.verifier]
          : [];
    const covering = attestations
      .filter(
        (attestation) =>
          attestation.decision === prose?.id &&
          attestation.obligation === kernelObligation.id,
      )
      .sort((a, b) => b.issuedAt.localeCompare(a.issuedAt));
    const latest = covering[0];
    return {
      id: kernelObligation.id,
      outcome: written?.outcome ?? null,
      claim: written?.claim ?? "",
      verifier: kernelObligation.verifier ?? verifiers[0] ?? null,
      verifiers,
      verdict: kernelObligation.verdict,
      attestationId: kernelObligation.attestationId ?? latest?.id ?? null,
      attestationExpiresAt: kernelObligation.attestationExpiresAt ?? latest?.expiresAt ?? null,
      remedies: kernelObligation.remedies,
      manual: verifiers.length > 0 && verifiers.every((item) => isManualVerifier(item)),
    };
  });
}

function summarizeDecision(
  id: string,
  prose: CorpusDecision | undefined,
  obligations: Obligation[],
  file: string,
): DecisionSummary {
  const byVerdict: Record<string, number> = {};
  for (const obligation of obligations) {
    byVerdict[obligation.verdict] = (byVerdict[obligation.verdict] ?? 0) + 1;
  }
  return {
    id,
    revision: prose?.revision ?? null,
    state: prose?.state ?? "unknown",
    intent: prose?.intent.split("\n").find((line) => line.trim() !== "") ?? "",
    file,
    axiomLinks: prose?.axiomLinks ?? [],
    scopePaths: prose?.scopePaths ?? [],
    obligationCount: obligations.length,
    byVerdict,
    manualCount: obligations.filter((item) => item.manual).length,
    topVerdict: worstVerdict(obligations.map((item) => item.verdict)),
  };
}

function attestationSummary(attestation: CorpusAttestation, stale: boolean): AttestationSummary {
  return {
    id: attestation.id,
    decision: attestation.decision,
    obligation: attestation.obligation,
    kind: attestation.kind,
    result: attestation.result,
    producer: attestation.producer,
    producerClass: attestation.producerClass,
    run: attestation.run,
    issuedAt: attestation.issuedAt,
    expiresAt: attestation.expiresAt,
    materialsDigest: attestation.materialsDigest,
    evidenceDigest: attestation.evidenceDigest,
    stale,
  };
}

function attestationSection(attestations: CorpusAttestation[]): AttestationSection {
  const byKind: Record<string, number> = {};
  const byResult: Record<string, number> = {};
  const byProducerClass: Record<string, number> = {};
  const now = new Date().toISOString();
  let expired = 0;

  for (const attestation of attestations) {
    byKind[attestation.kind] = (byKind[attestation.kind] ?? 0) + 1;
    byResult[attestation.result] = (byResult[attestation.result] ?? 0) + 1;
    byProducerClass[attestation.producerClass] =
      (byProducerClass[attestation.producerClass] ?? 0) + 1;
    if (attestation.expiresAt !== null && attestation.expiresAt < now) expired += 1;
  }

  const latest = attestations
    .slice()
    .sort((a, b) => b.issuedAt.localeCompare(a.issuedAt))
    .slice(0, 30)
    .map((attestation) =>
      attestationSummary(
        attestation,
        attestation.expiresAt !== null && attestation.expiresAt < now,
      ),
    );

  return {
    total: attestations.length,
    byKind,
    byResult,
    byProducerClass,
    latest,
    expired,
  };
}

/**
 * The review queue: the promises a person is being asked to stand behind.
 *
 * Two kinds of promise land here. One is explicit — the decision names a
 * `manual-` verifier, which means no machine can close it. The other is
 * implicit — the kernel says the promise is open (missing, stale, unknown),
 * which means either the evidence was never produced or it went out of date.
 * A human signs the second kind by declaring it satisfied.
 */
/**
 * The review queue: the promises a person is being asked to stand behind.
 *
 * Two kinds of promise land here. One is explicit — the decision names a
 * `manual-` verifier, which means no machine can close it. The other is
 * implicit — the kernel says the promise is open, which means either the
 * evidence was never produced or it went out of date. A human signs the
 * second kind by declaring it satisfied.
 */
function buildReviewQueue(
  decisions: { id: string; obligations: Obligation[] }[],
  attestations: CorpusAttestation[],
  promises: KernelPromise[],
  ledger: ReviewLedgerEntry[] = [],
): ReviewItem[] {
  const notes = new Map<string, ReviewLedgerEntry>();
  for (const entry of ledger) {
    const key = `${entry.decision} ${entry.obligation}`;
    const current = notes.get(key);
    if (!current || entry.at > current.at) notes.set(key, entry);
  }

  const openPromises = new Map<string, KernelPromise>();
  for (const promise of promises) {
    openPromises.set(`${promise.decision} ${promise.obligation}`, promise);
  }

  const queue: ReviewItem[] = [];
  for (const decision of decisions) {
    for (const obligation of decision.obligations) {
      const key = `${decision.id} ${obligation.id}`;
      const promise = openPromises.get(key);
      if (!obligation.manual && promise === undefined) continue;

      const covering = attestations
        .filter(
          (attestation) =>
            attestation.decision === decision.id &&
            attestation.obligation === obligation.id &&
            attestation.kind === "review",
        )
        .sort((a, b) => b.issuedAt.localeCompare(a.issuedAt));
      const latestReview = covering[0];
      const note = notes.get(key);

      queue.push({
        decision: decision.id,
        obligation: obligation.id,
        claim: obligation.claim,
        verifier: obligation.verifier,
        verdict: obligation.verdict,
        manual: obligation.manual,
        reviewed: latestReview !== undefined,
        reviewedAt: latestReview?.issuedAt ?? note?.at ?? null,
        reviewedBy: latestReview?.producer ?? note?.producer ?? null,
        rationale: note?.rationale ?? null,
      });
    }
  }

  queue.sort((a, b) => {
    if (a.reviewed !== b.reviewed) return a.reviewed ? 1 : -1;
    if (a.manual !== b.manual) return a.manual ? -1 : 1;
    return `${a.decision}/${a.obligation}`.localeCompare(`${b.decision}/${b.obligation}`);
  });
  return queue;
}

function readGitState(root: string) {
  const branch = runGit(root, ["rev-parse", "--abbrev-ref", "HEAD"]);
  if (branch.code !== 0) return null;
  const head = runGit(root, ["rev-parse", "HEAD"]);
  const status = runGit(root, ["status", "--porcelain"]);
  const counts = runGit(root, ["rev-list", "--left-right", "--count", "HEAD...@{upstream}"]);
  const log = runGit(root, ["log", "-1", "--format=%cI%x1f%s"]);
  const [behindRaw, aheadRaw] = counts.code === 0 ? counts.stdout.split(/\s+/) : ["0", "0"];
  const [committedAt, subject] = log.code === 0 ? log.stdout.split("\u001f") : [null, null];
  const dirtyPaths = status.stdout
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line !== "");
  return {
    branch: branch.stdout,
    head: head.stdout,
    dirty: dirtyPaths.length > 0,
    dirtyPaths: dirtyPaths.slice(0, 20),
    ahead: Number(aheadRaw ?? "0") || 0,
    behind: Number(behindRaw ?? "0") || 0,
    lastCommitAt: committedAt && committedAt !== "" ? committedAt : null,
    lastCommitSubject: subject && subject !== "" ? subject : null,
  };
}

/* ---------------------------------------------------------------- state */

export async function buildState(explicitRoot?: string | null) {
  const { root, error } = resolveRoot(explicitRoot);
  const generatedAt = new Date().toISOString();

  const emptyCoverage: Coverage = {
    decisions: 0,
    activeDecisions: 0,
    obligations: 0,
    attestations: 0,
    byVerdict: {},
    promisesByClass: {},
    promisesByState: {},
    declaredPromises: 0,
    openPromises: 0,
    waivedPromises: 0,
    cramTests: 0,
    cliSubcommands: 0,
  };

  if (!root) {
    return {
      root: null,
      rootError: error,
      version: null,
      kernelVersion: null,
      generatedAt,
      verdict: null,
      coverage: emptyCoverage,
      decisions: [],
      promises: [],
      attestations: {
        total: 0,
        byKind: {},
        byResult: {},
        byProducerClass: {},
        latest: [],
        expired: 0,
      },
      reviewQueue: [],
      doctor: null,
      policies: [],
      git: null,
      warnings: [] as string[],
    };
  }

  const layout = resolveLayout(root);
  const warnings: string[] = [];

  const prose = readProse(layout);
  const attestations = readAttestations(layout);
  const policies = readPolicies(layout);
  const ledger = readReviewLedger(root);
  if (prose.unreadable.length > 0) {
    warnings.push(
      `${prose.unreadable.length} decision file(s) could not be read for their prose: ` +
        `${prose.unreadable.join(", ")}. Their structure and verdicts still come from the kernel.`,
    );
  }

  const counters = await readCounters(root);
  if (counters.error) warnings.push(`counters: ${counters.error}`);
  const gaps = await readGaps(root);
  if (gaps.error) {
    warnings.push(
      `The kernel has no promise census (${gaps.error}). The worklist is built from the ` +
        "kernel's own obligation index instead, and carries no promise classes.",
    );
  }
  const packages = await readPackages(root);
  if (packages.error) warnings.push(`packages: ${packages.error}`);
  const selfCheck = await readSelfCheck(root);
  if (selfCheck.error) warnings.push(`self-check: ${selfCheck.error}`);
  const doctor = await readDoctor(root);
  if (doctor.error) warnings.push(`doctor: ${doctor.error}`);
  const kernelVersion = await readKernelVersion(root);

  // The kernel's index is the authority for which decisions exist and what
  // their obligations are. The prose fills in what each one SAYS.
  const kernelDecisions = packages.value?.decisions ?? [];
  const obligationsByDecision = new Map<string, Obligation[]>();
  const summaries: DecisionSummary[] = [];
  for (const kernelDecision of kernelDecisions) {
    const written = prose.decisions.get(kernelDecision.id);
    const obligations = obligationsFor(kernelDecision.obligations, written, attestations);
    obligationsByDecision.set(kernelDecision.id, obligations);
    const file = findDecisionFile(layout, kernelDecision.id, prose.decisions);
    summaries.push(
      summarizeDecision(
        kernelDecision.id,
        written,
        obligations,
        file === null ? "" : file.split("/").pop() ?? "",
      ),
    );
  }
  summaries.sort((a, b) => a.id.localeCompare(b.id));

  const allObligations = [...obligationsByDecision.values()].flat();
  const byVerdict: Record<string, number> = {};
  for (const obligation of allObligations) {
    byVerdict[obligation.verdict] = (byVerdict[obligation.verdict] ?? 0) + 1;
  }

  const promises = promisesOf(gaps.value?.open, packages.value);
  const promiseStates: Record<string, number> = {};
  for (const promise of promises) {
    promiseStates[promise.state] = (promiseStates[promise.state] ?? 0) + 1;
  }

  const coverage: Coverage = {
    decisions: counters.value?.decisionsTotal ?? summaries.length,
    activeDecisions: counters.value?.decisionsActive ?? 0,
    obligations: counters.value?.obligationsTotal ?? allObligations.length,
    attestations: counters.value?.attestations ?? attestations.length,
    byVerdict: Object.keys(byVerdict).length > 0 ? byVerdict : (counters.value?.obligationsByVerdict ?? {}),
    promisesByClass: gaps.value?.counts.byClass ?? {},
    promisesByState: gaps.value?.counts.byState ?? promiseStates,
    declaredPromises: gaps.value?.counts.declared ?? allObligations.length,
    openPromises: gaps.value?.counts.open ?? promises.length,
    waivedPromises: gaps.value?.counts.waived ?? 0,
    cramTests: counters.value?.cramTests ?? 0,
    cliSubcommands: counters.value?.cliSubcommands ?? 0,
  };

  const verdict =
    selfCheck.value === null
      ? null
      : {
          verdict: selfCheck.value.verdict,
          exitCode: selfCheck.exitCode,
          kernelDigest: selfCheck.value.kernelDigest,
          repositoryDigest: selfCheck.value.repositoryDigest,
          now: selfCheck.value.now,
          subjects: {
            total: selfCheck.value.subjects.length,
            pass: selfCheck.value.subjects.filter((item) => item.verdict === "pass").length,
            fail: selfCheck.value.subjects.filter((item) => item.verdict === "fail").length,
            unknown: selfCheck.value.subjects.filter((item) => item.verdict === "unknown").length,
          },
          failures: selfCheck.value.subjects
            .filter((item) => item.verdict !== "pass")
            .slice(0, 50)
            .map((item) => ({
              name: item.name,
              verdict: item.verdict,
              causes: item.causes,
              remedies: item.remedies,
              waivers: item.waivers,
            })),
          detail: selfCheck.detail,
          error: selfCheck.error,
        };

  return {
    root,
    rootError: null,
    version: readVersionFile(layout.root),
    kernelVersion,
    generatedAt,
    verdict,
    coverage,
    decisions: summaries,
    promises: promisesOf(gaps.value?.open, packages.value),
    attestations: attestationSection(attestations),
    reviewQueue: buildReviewQueue(
      kernelDecisions.map((kernelDecision) => ({
        id: kernelDecision.id,
        obligations: obligationsByDecision.get(kernelDecision.id) ?? [],
      })),
      attestations,
      promisesOf(gaps.value?.open, packages.value),
      ledger,
    ),
    doctor: doctor.value,
    policies,
    git: readGitState(root),
    warnings,
  };
}

function readVersionFile(root: string): string | null {
  const path = join(root, "VERSION");
  if (!existsSync(path)) return null;
  try {
    return readFileSync(path, "utf8").trim() || null;
  } catch {
    return null;
  }
}

/* --------------------------------------------------------------- mosaic */

/**
 * The mosaic: one cell per obligation, coloured by the epistemic status the
 * promise is actually in.
 *
 * A cell is a JOIN of three readings, and the console contributes none of
 * them:
 *
 *   - the kernel's OBLIGATION INDEX (`mathc packages`) says whether the
 *     promise is discharged, and by which attestation;
 *   - the PROMISE CENSUS (`mathc gaps`) says whether there is any check
 *     for it at all;
 *   - the STORE says what kind of evidence covers it, how old it is and
 *     what digest it is bound to.
 *
 * Where the first two disagree about the same promise, the cell carries
 * both and says so. The kernel does not always agree with itself, and a
 * console that silently picked a side would be a console that laundered.
 */
export async function buildMosaic(explicitRoot?: string | null) {
  const { root, error } = resolveRoot(explicitRoot);
  const empty = {
    root,
    error,
    generatedAt: new Date().toISOString(),
    cells: [],
    counts: {
      total: 0,
      observed: 0,
      declared: 0,
      open: 0,
      uncheckable: 0,
      failed: 0,
      waived: 0,
    },
    store: { total: 0, namingLivePromise: 0, discharging: 0 },
    readings: { packages: "unknown", census: "unknown", disagreeing: 0 },
  };
  if (!root) return empty;

  const layout = resolveLayout(root);
  const packages = await readPackages(root);
  const gaps = await readGaps(root);
  const attestations = readAttestations(layout);

  // The store, indexed by the promise it names.
  const byPromise = new Map<string, CorpusAttestation[]>();
  for (const attestation of attestations) {
    const key = `${attestation.decision} ${attestation.obligation}`;
    const list = byPromise.get(key) ?? [];
    list.push(attestation);
    byPromise.set(key, list);
  }

  // The census, indexed by the promise it describes.
  const census = new Map<string, { state: string; class: string }>();
  for (const promise of gaps.value?.open ?? []) {
    census.set(`${promise.decision} ${promise.obligation}`, {
      state: promise.state,
      class: promise.class,
    });
  }

  const cells: MosaicCell[] = [];
  const counts = {
    observed: 0,
    declared: 0,
    open: 0,
    uncheckable: 0,
    failed: 0,
    waived: 0,
  };
  let discharging = 0;
  let disagreeing = 0;

  for (const decision of packages.value?.decisions ?? []) {
    for (const obligation of decision.obligations) {
      const key = `${decision.id} ${obligation.id}`;
      const covering = byPromise.get(key) ?? [];
      const latest = covering
        .slice()
        .sort((a, b) => b.issuedAt.localeCompare(a.issuedAt))[0];
      const counted = census.get(key);
      const state = cellFor({
        verdict: obligation.verdict,
        attestationKind: latest?.kind ?? null,
        censusClass: counted?.class ?? null,
      });
      counts[state] += 1;

      // The two kernel readings, compared rather than reconciled.
      const censusState = counted?.state ?? null;
      const disagreement =
        censusState !== null &&
        obligation.verdict !== "pass" &&
        censusState !== obligation.verdict;

      if (state === "observed" || state === "declared") discharging += 1;
      if (disagreement) disagreeing += 1;

      cells.push({
        decision: decision.id,
        obligation: obligation.id,
        state,
        verdict: obligation.verdict,
        censusState,
        censusClass: counted?.class ?? null,
        disagreement,
        verifier: obligation.verifier,
        attestationId: latest?.id ?? obligation.attestationId,
        attestationKind: latest?.kind ?? null,
        attestationProducer: latest?.producer ?? null,
        issuedAt: latest?.issuedAt ?? null,
        expiresAt: latest?.expiresAt ?? obligation.attestationExpiresAt,
        materialsDigest: latest?.materialsDigest ?? null,
      });
    }
  }

  // How much of the store reaches a promise the corpus still has.
  const live = new Set(cells.map((cell) => `${cell.decision} ${cell.obligation}`));
  let namingLive = 0;
  for (const attestation of attestations) {
    if (live.has(`${attestation.decision} ${attestation.obligation}`)) namingLive += 1;
  }

  return {
    root,
    error: null,
    generatedAt: new Date().toISOString(),
    cells,
    counts: { total: cells.length, ...counts },
    store: {
      total: attestations.length,
      namingLivePromise: namingLive,
      discharging,
    },
    readings: {
      packages: packages.value ? summariseVerdicts(packages.value) : "unknown",
      census: gaps.value ? summariseCensus(gaps.value) : "unknown",
      disagreeing,
    },
  };
}

function summariseVerdicts(packages: KernelPackages): string {
  const counts: Record<string, number> = {};
  for (const decision of packages.decisions) {
    for (const obligation of decision.obligations) {
      counts[obligation.verdict] = (counts[obligation.verdict] ?? 0) + 1;
    }
  }
  return Object.entries(counts)
    .sort((a, b) => b[1] - a[1])
    .map(([verdict, count]) => `${verdict} ${count}`)
    .join(" · ");
}

function summariseCensus(gaps: KernelGaps): string {
  const parts = Object.entries(gaps.counts.byState).map(([state, count]) => `${state} ${count}`);
  return parts.length > 0 ? parts.join(" · ") : "none";
}

/* --------------------------------------------------------------- change */

/**
 * The change view: the merge gate's own reading, and nothing else.
 *
 * The console does NOT re-derive which obligations a diff touches. The
 * kernel knows and does not expose it, so a console that guessed would
 * be a second measurer. The gap is named instead.
 */
export async function buildChange(
  explicitRoot: string | undefined,
  base: string,
  head: string,
) {
  const { root, error } = resolveRoot(explicitRoot);
  if (!root) {
    return {
      ok: false,
      error,
      exitCode: 2,
      verdict: null,
      base,
      head,
      obligations: 0,
      gaps: [],
      changedFiles: [],
      limit: null,
    };
  }

  const gate = await readGate(root, base, head);
  const layout = resolveLayout(root);
  const prose = readProse(layout);

  // The gate names an obligation, not a decision. The corpus's obligation
  // ids are mostly unique, so the decision is found by looking it up; when
  // two decisions promise the same thing, the console says nothing rather
  // than guess.
  const decisionsByObligation = new Map<string, string[]>();
  for (const decision of prose.decisions.values()) {
    for (const obligation of decision.obligations) {
      const list = decisionsByObligation.get(obligation.id) ?? [];
      list.push(decision.id);
      decisionsByObligation.set(obligation.id, list);
    }
  }

  const diff = runGit(root, ["diff", "--name-only", base, head]);
  const changedFiles = diff.stdout
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line !== "");

  return {
    ok: gate.value !== null,
    error: gate.error,
    exitCode: gate.value === null ? 3 : 0,
    verdict: gate.value?.verdict ?? null,
    base: gate.value?.base ?? base,
    head: gate.value?.head ?? head,
    obligations: gate.value?.obligations ?? 0,
    gaps: (gate.value?.gaps ?? []).map((gap) => {
      const candidates = decisionsByObligation.get(gap.obligationId) ?? [];
      return {
        kind: gap.kind,
        obligationId: gap.obligationId,
        decision: candidates.length === 1 ? (candidates[0] ?? null) : null,
        causes: gap.causes,
        remedies: gap.remedies,
      };
    }),
    changedFiles,
    limit:
      "The gate reports every gap it found; it does not say which of them your diff " +
      "touched. The kernel knows and does not expose it, so the console does not guess.",
  };
}

/* ------------------------------------------------------------- promises */

export async function buildPromiseList(
  explicitRoot: string | null | undefined,
  filters: {
    state?: string | undefined;
    class?: string | undefined;
    decision?: string | undefined;
    query?: string | undefined;
    limit?: number | undefined;
  },
) {
  const { root, error } = resolveRoot(explicitRoot);
  if (!root) {
    return { root: null, error, total: 0, promises: [] };
  }
  const gaps = await readGaps(root);
  const packages = await readPackages(root);
  const census = promisesOf(gaps.value?.open, packages.value);
  if (census.length === 0 && gaps.error !== null) {
    return { root, error: gaps.error, total: 0, promises: [] };
  }

  const needle = (filters.query ?? "").trim().toLowerCase();
  const filtered = census.filter((promise) => {
    if (filters.state && filters.state !== "all" && promise.state !== filters.state) return false;
    if (filters.class && filters.class !== "all" && promise.class !== filters.class) return false;
    if (filters.decision && filters.decision !== "all" && promise.decision !== filters.decision) return false;
    if (needle !== "") {
      const haystack = `${promise.decision} ${promise.obligation} ${promise.cause} ${promise.action}`.toLowerCase();
      if (!haystack.includes(needle)) return false;
    }
    return true;
  });

  const limit = Math.min(filters.limit ?? 300, 2000);
  return {
    root,
    error: null,
    total: filtered.length,
    promises: filtered.slice(0, limit).map((promise) => ({
      decision: promise.decision,
      obligation: promise.obligation,
      class: promise.class,
      state: promise.state,
      verifiers: promise.verifiers,
      cause: promise.cause,
      action: promise.action,
    })),
  };
}

/* ------------------------------------------------------------- decision */

export async function buildDecision(explicitRoot: string | undefined, decisionId: string) {
  const { root, error } = resolveRoot(explicitRoot);
  const empty = {
    root,
    error,
    id: decisionId,
    revision: null,
    state: "unknown",
    intent: "",
    commitment: "",
    axiomLinks: [],
    scopePaths: [],
    file: "",
    outcomes: [],
    obligations: [],
    attestations: [],
    assumptions: [],
    relations: {},
    riskTriggers: [],
    counterexample: null,
    antithesis: null,
    reviews: [],
    diagnostics: [],
    proseReadable: false,
  };

  if (!root) return empty;

  const layout = resolveLayout(root);
  const prose = readProse(layout);
  const decision = prose.decisions.get(decisionId);

  const attestations = readAttestations(layout);
  const packages = await readPackages(root);
  const gaps = await readGaps(root);

  const kernelDecision = packages.value?.decisions.find((item) => item.id === decisionId);
  if (kernelDecision === undefined && decision === undefined) {
    return { ...empty, error: `decision not found: ${decisionId}` };
  }

  const obligations = obligationsFor(kernelDecision?.obligations ?? [], decision, attestations);
  const reviews = buildReviewQueue(
    [{ id: decisionId, obligations }],
    attestations,
    promisesOf(gaps.value?.open, packages.value),
    readReviewLedger(root),
  ).filter((item) => item.decision === decisionId);

  const file = findDecisionFile(layout, decisionId, prose.decisions);
  const diagnostics = await readDecisionDiagnostics(root, file);

  return {
    root,
    error: null,
    id: decisionId,
    revision: decision?.revision ?? kernelDecision?.revision ?? null,
    state: decision?.state ?? "unknown",
    intent: decision?.intent ?? "",
    commitment: decision?.commitment ?? "",
    axiomLinks: decision?.axiomLinks ?? [],
    scopePaths: decision?.scopePaths ?? [],
    file: file === null ? "" : (file.split("/").pop() ?? ""),
    outcomes: decision?.outcomes ?? [],
    obligations,
    attestations: attestations
      .filter((item) => item.decision === decisionId)
      .map((item) => attestationSummary(item, false)),
    assumptions: decision?.assumptions ?? [],
    relations: decision?.relations ?? {},
    riskTriggers: decision?.riskTriggers ?? [],
    counterexample: decision?.counterexample ?? null,
    antithesis: decision?.antithesis ?? null,
    reviews,
    diagnostics,
    proseReadable: decision !== undefined,
  };
}

/**
 * The kernel's own diagnostics for one decision file.
 *
 * This is where the console learns that the kernel's parser stopped halfway
 * through a file: the promise in the unread tail is outside the gate, and a
 * reader of the console is entitled to know it.
 */
async function readDecisionDiagnostics(
  root: string,
  file: string | null,
): Promise<{ code: string; severity: string; message: string }[]> {
  if (file === null) return [];
  const result = await runMathc(root, ["validate", file, "--format=json"], { timeoutMs: 60_000 });
  try {
    const parsed = JSON.parse(result.stdout) as { diagnostics?: unknown };
    const diagnostics = Array.isArray(parsed.diagnostics) ? parsed.diagnostics : [];
    return diagnostics.map((entry) => {
      const record = (entry ?? {}) as Record<string, unknown>;
      return {
        code: typeof record.code === "string" ? record.code : "MC-UNKNOWN",
        severity: typeof record.severity === "string" ? record.severity : "warn",
        message: typeof record.message === "string" ? record.message : "",
      };
    });
  } catch {
    return [];
  }
}

/* --------------------------------------------------------------- search */

export async function searchDecisions(explicitRoot: string | undefined, query: string) {
  const { root, error } = resolveRoot(explicitRoot);
  if (!root) return { root: null, error, matches: [] };

  const needle = query.trim().toLowerCase();
  if (needle === "") return { root, error: null, matches: [] };

  const layout = resolveLayout(root);
  const matches: { kind: string; id: string; decision: string; snippet: string }[] = [];
  for (const decision of readProse(layout).decisions.values()) {
    const haystacks: [string, string][] = [
      ["decision", decision.id],
      ["intent", decision.intent],
      ["commitment", decision.commitment],
      ["obligation", decision.obligations.map((item) => `${item.id} ${item.claim}`).join("\n")],
    ];
    for (const [kind, text] of haystacks) {
      if (!text.toLowerCase().includes(needle)) continue;
      matches.push({
        kind,
        id: decision.id,
        decision: decision.id,
        snippet: snippetAround(text, needle),
      });
    }
  }
  return { root, error: null, matches: matches.slice(0, 100) };
}

function snippetAround(text: string, needle: string, radius = 90): string {
  const index = text.toLowerCase().indexOf(needle);
  if (index < 0) return text.slice(0, radius * 2).trim();
  const start = Math.max(0, index - radius);
  const end = Math.min(text.length, index + needle.length + radius);
  const prefix = start > 0 ? "…" : "";
  const suffix = end < text.length ? "…" : "";
  return `${prefix}${text.slice(start, end).replace(/\s+/g, " ").trim()}${suffix}`;
}

/* --------------------------------------------------------------- review */

/**
 * Sign a human review.
 *
 * The verdict becomes a `kind_: review` attestation in the kernel's own
 * store — the one kind the schema allows to rest on a person's declaration.
 * The rationale has no field in the attestation schema, so it goes to the
 * console's own ledger under `.local/`, and into the neighbouring session
 * where the discussion actually happens.
 *
 * The attestation replaces whatever covered this obligation before. That is
 * the kernel's own semantics — one attestation file per obligation pair —
 * and the console says so before it signs, because a review that silently
 * discards a machine check is not a review.
 */
export async function submitReview(
  input: {
    root?: string | undefined;
    decisionId: string;
    obligationId: string;
    result: "pass" | "fail";
    producer: string;
    rationale: string;
    agentId?: string | undefined;
  },
  context: PluginHandlerContext,
) {
  const { root, error } = resolveRoot(input.root);
  if (!root) {
    return {
      ok: false,
      error,
      attestationId: null,
      attestationPath: null,
      verdictAfter: null,
      dispatched: false,
      dispatchedTo: null,
      detail: error ?? "math-coding repository not found.",
    };
  }

  const producerError = assertProducer(input.producer);
  if (producerError) {
    return {
      ok: false,
      error: producerError,
      attestationId: null,
      attestationPath: null,
      verdictAfter: null,
      dispatched: false,
      dispatchedTo: null,
      detail: "The attestation schema rejects an untagged producer identity.",
    };
  }

  const layout = resolveLayout(root);
  const prose = readProse(layout);
  const decision = prose.decisions.get(input.decisionId);
  const packages = await readPackages(root);
  const kernelDecision = packages.value?.decisions.find(
    (item) => item.id === input.decisionId,
  );
  if (decision === undefined && kernelDecision === undefined) {
    return {
      ok: false,
      error: `decision not found: ${input.decisionId}`,
      attestationId: null,
      attestationPath: null,
      verdictAfter: null,
      dispatched: false,
      dispatchedTo: null,
      detail: `No decision ${input.decisionId} under ${layout.decisionsDir}.`,
    };
  }
  const writtenObligation = decision?.obligations.find((item) => item.id === input.obligationId);
  const kernelObligation = kernelDecision?.obligations.find(
    (item) => item.id === input.obligationId,
  );
  if (writtenObligation === undefined && kernelObligation === undefined) {
    return {
      ok: false,
      error: `obligation not found: ${input.obligationId}`,
      attestationId: null,
      attestationPath: null,
      verdictAfter: null,
      dispatched: false,
      dispatchedTo: null,
      detail: `Decision ${input.decisionId} declares no obligation ${input.obligationId}.`,
    };
  }
  const obligation = {
    id: input.obligationId,
    claim: writtenObligation?.claim ?? "",
    verifier: kernelObligation?.verifier ?? writtenObligation?.verifiers[0] ?? null,
  };

  // The kernel's own batch format: decision, obligation, kind, producer,
  // result — TAB separated.
  const manifest = `${input.decisionId}\t${input.obligationId}\treview\t${input.producer.trim()}\t${input.result}\n`;
  const localDir = join(root, ".local");
  const manifestPath = join(localDir, "review-manifest.tsv");
  try {
    mkdirSync(localDir, { recursive: true });
    writeFileSync(manifestPath, manifest);
  } catch (writeError) {
    return {
      ok: false,
      error: `cannot write the review manifest: ${String(writeError)}`,
      attestationId: null,
      attestationPath: null,
      verdictAfter: null,
      dispatched: false,
      dispatchedTo: null,
      detail: String(writeError),
    };
  }

  const batch = await runMathc(
    root,
    ["attest-batch", `--manifest=${manifestPath}`, `--out=${layout.attestationsDir}`],
    { timeoutMs: 300_000 },
  );
  if (batch.code !== 0) {
    return {
      ok: false,
      error: `mathc attest-batch exited ${batch.code}`,
      attestationId: null,
      attestationPath: null,
      verdictAfter: null,
      dispatched: false,
      dispatchedTo: null,
      detail: (batch.stderr.trim() || batch.stdout.trim() || "no diagnostic").slice(0, 4000),
    };
  }

  const attestationPath = join(
    layout.attestationsDir,
    `${input.decisionId}-${input.obligationId}.json`,
  );
  let attestationId: string | null = null;
  try {
    const parsed = JSON.parse(readFileSync(attestationPath, "utf8")) as { id?: string };
    attestationId = parsed.id ?? null;
  } catch {
    attestationId = null;
  }

  // What did the kernel's verdict become? Measured, not assumed: whether a
  // fresh attestation moves the obligation depends on the kernel's store
  // admission rule, and some kernels admit only attestations that are in
  // the tree. The console reports what it observed rather than what it
  // believes should happen.
  const verdictAfter = await readObligationVerdict(root, input.decisionId, input.obligationId);
  const moved = verdictAfter !== null && !isOpen(verdictAfter);

  const at = new Date().toISOString();
  try {
    mkdirSync(localDir, { recursive: true });
    appendFileSync(
      join(localDir, "reviews.jsonl"),
      `${JSON.stringify({
        decision: input.decisionId,
        obligation: input.obligationId,
        result: input.result,
        producer: input.producer,
        rationale: input.rationale,
        at,
        agentId: input.agentId ?? null,
        attestationId,
      })}\n`,
    );
  } catch (ledgerError) {
    console.error("math-coding console: cannot write the review ledger", ledgerError);
  }

  let dispatched = false;
  let dispatchedTo: string | null = null;
  if (input.agentId) {
    const prompt = buildReviewPrompt({
      decisionId: input.decisionId,
      intent: decision?.intent ?? "",
      decisionFile: decision?.file ?? "",
      obligationId: obligation.id,
      claim: obligation.claim,
      verifier: obligation.verifier,
      result: input.result,
      producer: input.producer,
      rationale: input.rationale,
      attestationId,
      decisionPath: layout.decisionsDir,
    });
    try {
      await context.paseo.agents.ref(input.agentId).timeline.append({
        type: "plugin",
        id: `math-coding-review:${input.decisionId}:${input.obligationId}`,
        kind: "math-coding-review",
        version: 1,
        data: {
          decisionId: input.decisionId,
          obligationId: input.obligationId,
          verdict: input.result,
          producer: input.producer,
          rationale: input.rationale,
          at,
          agentId: input.agentId,
        },
      });
      await context.paseo.agents.ref(input.agentId).send(prompt);
      dispatched = true;
      dispatchedTo = input.agentId;
    } catch (dispatchError) {
      console.error("math-coding console: cannot dispatch the review", dispatchError);
    }
  }

  const detail = [
    `Signed ${input.decisionId}/${input.obligationId}.`,
    verdictAfter === null
      ? "The kernel did not report this obligation's verdict afterwards."
      : moved
        ? `The obligation now reads ${verdictAfter}.`
        : `The obligation still reads ${verdictAfter}. The attestation is written; whether the kernel admits it depends on whether it is in the tree — commit the store and refresh.`,
    dispatched ? `The review was sent to ${dispatchedTo}.` : "",
  ]
    .filter((line) => line !== "")
    .join(" ");

  return {
    ok: true,
    error: null,
    attestationId,
    attestationPath,
    verdictAfter,
    dispatched,
    dispatchedTo,
    detail,
  };
}

/**
 * The kernel's current verdict for one obligation.
 *
 * Read from the kernel's own index, because the index is what the gate reads.
 */
async function readObligationVerdict(
  root: string,
  decisionId: string,
  obligationId: string,
): Promise<string | null> {
  const packages = await readPackages(root);
  const decision = packages.value?.decisions.find((item) => item.id === decisionId);
  const obligation = decision?.obligations.find((item) => item.id === obligationId);
  return obligation?.verdict ?? null;
}

function buildReviewPrompt(args: {
  decisionId: string;
  intent: string;
  decisionFile: string;
  obligationId: string;
  claim: string;
  verifier: string | null;
  result: string;
  producer: string;
  rationale: string;
  attestationId: string | null;
  decisionPath: string;
}): string {
  return [
    `Human review of math-coding obligation \`${args.decisionId}/${args.obligationId}\`.`,
    "",
    `Intent: ${args.intent.split("\n")[0] ?? ""}`,
    `Claim: ${args.claim}`,
    `Verifier: ${args.verifier ?? "(none)"}`,
    `Verdict: ${args.result}`,
    `Signed by: ${args.producer}`,
    args.attestationId ? `Attestation: ${args.attestationId}` : "",
    "",
    "Rationale from the reviewer:",
    args.rationale.trim() === "" ? "(none given)" : args.rationale.trim(),
    "",
    "Your job in this session is to challenge the review, not to rubber-stamp it:",
    "1. Check whether the claim is actually the thing the obligation promises.",
    "2. Check whether the verifier (if any) can decide the claim at all.",
    "3. Say plainly whether you agree with the verdict, and why.",
    "4. If the verdict is wrong, name the evidence that would make it right.",
    "",
    `Decision file: ${args.decisionPath}/${args.decisionFile}`,
  ]
    .filter((line) => line !== "")
    .join("\n");
}

/* ------------------------------------------------------------ lifecycle */

export async function changeLifecycle(
  explicitRoot: string | undefined,
  decisionId: string,
  action: "mark-superseded" | "mark-retired" | "set",
  state?: string | undefined,
  by?: string | undefined,
) {
  const { root, error } = resolveRoot(explicitRoot);
  if (!root) return { ok: false, error, detail: error ?? "math-coding repository not found." };

  const args = ["decision-state", decisionId, action];
  if (action === "set") {
    if (!state) {
      return { ok: false, error: "set needs a state", detail: "set needs a state: draft, active, retired or superseded." };
    }
    args.push(state);
  }
  if (by && by.trim() !== "") args.push(`--by=${by.trim()}`);

  const result = await runMathc(root, args, { timeoutMs: 120_000 });
  const detail = (result.stdout.trim() || result.stderr.trim()).slice(0, 2000);
  if (result.code !== 0) {
    return {
      ok: false,
      error: `mathc decision-state exited ${result.code}`,
      detail: (result.stderr.trim() || result.stdout.trim() || "no diagnostic").slice(0, 4000),
    };
  }
  return { ok: true, error: null, detail: detail === "" ? "state changed." : detail };
}

/* ------------------------------------------------------------- actions */

const ACTION_SUBCOMMAND: Record<string, string> = {
  "self-check": "self-check",
  validate: "validate",
  verify: "verify",
  rehash: "rehash",
  "attest-batch": "attest-batch",
  "negative-control": "negative-control",
  doctor: "doctor",
  gate: "gate",
  context: "context",
  render: "render",
  "session-start": "session-start",
  record: "record",
  "new-decision": "new-decision",
  "re-evaluate": "re-evaluate",
  packages: "packages",
  gaps: "gaps",
  counters: "counters",
  "explain-diagnostic": "explain-diagnostic",
  update: "update",
};

export async function runAction(
  explicitRoot: string | undefined,
  action: string,
  args: string[],
  flags: string[],
  timeoutMs?: number | undefined,
) {
  const { root, error } = resolveRoot(explicitRoot);
  const subcommand = ACTION_SUBCOMMAND[action];
  if (!subcommand) {
    return {
      ok: false,
      error: `unknown action: ${action}`,
      exitCode: 2,
      stdout: "",
      stderr: "",
      command: action,
      durationMs: 0,
    };
  }
  if (!root) {
    return {
      ok: false,
      error,
      exitCode: 2,
      stdout: "",
      stderr: "",
      command: subcommand,
      durationMs: 0,
    };
  }

  const argv = [subcommand, ...args, ...flags];
  const result = await runMathc(root, argv, {
    timeoutMs: timeoutMs ?? (action === "self-check" || action === "render" ? 600_000 : 180_000),
  });

  return {
    ok: result.code === 0,
    error: result.code === 0 ? null : `mathc ${subcommand} exited ${result.code}`,
    exitCode: result.code,
    stdout: result.stdout,
    stderr: result.stderr,
    command: `mathc ${argv.join(" ")}`,
    durationMs: result.durationMs,
  };
}

/* ---------------------------------------------------------------- gate */

export async function runGate(explicitRoot: string | undefined, base: string, head: string) {
  const { root, error } = resolveRoot(explicitRoot);
  if (!root) {
    return { ok: false, error, exitCode: 2, stdout: "", stderr: "" };
  }
  const result = await runMathc(root, ["gate", base, head], { timeoutMs: 300_000 });
  return {
    ok: result.code === 0,
    error: result.code === 0 ? null : `mathc gate exited ${result.code}`,
    exitCode: result.code,
    stdout: result.stdout,
    stderr: result.stderr,
  };
}

/* ----------------------------------------------------------- diagnostics */

export async function explainDiagnostic(code: string) {
  // `explain-diagnostic` reads the kernel's own diagnostic table, not a
  // repository, so it runs against the plugin's working directory.
  const result = await runMathc(process.cwd(), ["explain-diagnostic", code]);
  let definition = "";
  let occursWhen = "";
  let remediation = "";
  try {
    const parsed = JSON.parse(result.stdout) as Record<string, unknown>;
    definition = typeof parsed.definition === "string" ? parsed.definition : "";
    occursWhen = typeof parsed.occurs_when === "string" ? parsed.occurs_when : "";
    remediation = typeof parsed.remediation === "string" ? parsed.remediation : "";
    if (definition === "" && typeof parsed.message === "string") {
      definition = parsed.message;
    }
  } catch {
    definition = result.stderr.trim() || result.stdout.trim();
  }
  return { code, definition, occursWhen, remediation };
}
