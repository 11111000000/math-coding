import type { Claim, ClaimState, EvidenceOutcome, EvidenceRecord, IndependenceLevel } from "../shared/domain";
import type { SnapshotReady } from "../shared/schemas";
import { canonicalJson, flattenRequirements, requirementLabelRef, type RequirementNode } from "../shared/requirements";
import type { MessageRef } from "../shared/message";
import type { AttentionModel, HumanAttentionItem } from "./attention";

/**
 * The queue of the human.
 *
 * The console answers one question at a glance: what does the human have to
 * do in this repository, what is expected there, how is it checked, and what
 * does the evidence say. Every part of the answer comes from the canonical
 * map, the declared specification and the evidence trail. The queue never
 * computes a state and never invents a reason.
 */

/**
 * The newest evidence of one condition of a claim.
 *
 * The record belongs to a declared condition, so the human sees which check
 * or which review speaks for the claim.
 */
export interface ConditionEvidence {
  path: string;
  label: MessageRef;
  outcome: EvidenceOutcome;
  issuedAt: number;
  independence: IndependenceLevel | null;
  controlReach: string | null;
}

/**
 * One decision that cannot be delegated to an agent.
 *
 * The decision itself is the one the attention model states, so the panel and
 * the brief speak about the same thing. The queue adds what the human needs
 * to act: the expectation, the conditions and the files.
 */
export interface HumanQueueItem {
  id: string;
  kind: string;
  title: MessageRef;
  expectation: string;
  attention: HumanAttentionItem;
  claimIds: string[];
  files: string[];
  conditions: ConditionEvidence[];
}

/**
 * One standing obligation of the owner.
 *
 * Every claim of the goal stays the responsibility of its owner. The
 * obligation carries the expectation, the canonical state, the conditions and
 * the files, so the human can check the subject without leaving the panel.
 */
export interface StandingObligation {
  claimId: string;
  title: string;
  expectation: string;
  state: ClaimState;
  owner: string | null;
  files: string[];
  conditions: ConditionEvidence[];
}

/**
 * The third outcome of the method.
 *
 * The obligations may be confirmed and the declared area may be resolved, but
 * the result itself is accepted by the owner separately, on the basis of the
 * map. The tool keeps no record of that acceptance, so the console names the
 * step instead of reporting it as done.
 */
export interface GoalAcceptance {
  title: MessageRef;
  owner: string | null;
  obligationsConfirmed: boolean;
  areaResolved: boolean;
  uncovered: string[];
}

export interface HumanQueue {
  items: HumanQueueItem[];
  obligations: StandingObligation[];
  acceptance: GoalAcceptance;
}

function requirementKeyOf(record: EvidenceRecord): string {
  return canonicalJson(record.requirement);
}

/**
 * The conditions of a claim.
 *
 * A condition is a check or a review. The "all" and "any" nodes are the
 * structure of the tree, not conditions of their own: the trail records
 * evidence for the leaves.
 */
export function conditionRequirements(claim: Claim): RequirementNode[] {
  return flattenRequirements(claim).filter(
    (node) => "kind" in node.requirement &&
      (node.requirement.kind === "verifier" || node.requirement.kind === "review"),
  );
}

/**
 * The newest evidence of every declared condition of a claim.
 *
 * A condition without a record has no evidence: the absence of a record is
 * neither a confirmation nor a refutation.
 */
export function claimConditions(claim: Claim, records: EvidenceRecord[]): ConditionEvidence[] {
  const newest = new Map<string, EvidenceRecord>();
  for (const record of records) {
    const key = requirementKeyOf(record);
    const current = newest.get(key);
    if (!current || record.issued_at > current.issued_at ||
        (record.issued_at === current.issued_at && record.sequence > current.sequence)) {
      newest.set(key, record);
    }
  }
  return conditionRequirements(claim).map((node) => {
    const record = newest.get(canonicalJson(node.requirement));
    return {
      path: node.path,
      label: requirementLabelRef(node.requirement),
      outcome: record?.outcome ?? "not-run",
      issuedAt: record?.issued_at ?? 0,
      independence: record?.independence ?? null,
      controlReach: record?.control_reach ?? null,
    };
  });
}

/**
 * The files that show the subject of a claim.
 *
 * The scope and the linked source are the declared subject. They are paths
 * the project wrote, so the human opens exactly what the specification names.
 */
export function claimFiles(claim: Claim): string[] {
  const files = [...claim.scope];
  if (claim.source && !files.includes(claim.source.path)) files.push(claim.source.path);
  return files;
}

export function groupRecordsByClaim(records: EvidenceRecord[]): Map<string, EvidenceRecord[]> {
  const grouped = new Map<string, EvidenceRecord[]>();
  for (const record of records) {
    const list = grouped.get(record.claim_id) ?? [];
    list.push(record);
    grouped.set(record.claim_id, list);
  }
  return grouped;
}

/**
 * Whether the loaded records speak for every condition of every claim.
 *
 * The trail is read newest first. The console keeps reading pages until every
 * condition has a record, so a condition never looks untested because the
 * page ended too early.
 */
export function queueEvidenceComplete(records: EvidenceRecord[], claims: Claim[]): boolean {
  const seen = new Set<string>();
  for (const record of records) {
    seen.add(`${record.claim_id}\u0000${canonicalJson(record.requirement)}`);
  }
  return claims.every((claim) =>
    conditionRequirements(claim).every((node) =>
      seen.has(`${claim.id}\u0000${canonicalJson(node.requirement)}`),
    ),
  );
}

/**
 * Build the queue of the human.
 *
 * The decisions come from the attention model, so the panel and the brief
 * speak about the same thing. The standing obligations and the acceptance of
 * the result are added from the canonical map and the declared specification.
 */
export function buildHumanQueue(
  snapshot: SnapshotReady,
  attention: AttentionModel,
  records: EvidenceRecord[],
): HumanQueue {
  const grouped = groupRecordsByClaim(records);
  const claims = new Map(snapshot.claims.map((claim) => [claim.id, claim]));
  const items: HumanQueueItem[] = attention.needsHuman.map((item) => {
    const claim = claims.get(item.claimIds[0] ?? "");
    const conditions = claim ? claimConditions(claim, grouped.get(claim.id) ?? []) : [];
    return {
      id: item.id,
      kind: item.kind,
      title: item.title,
      expectation: claim?.text ?? "",
      attention: item,
      claimIds: item.claimIds,
      files: claim ? claimFiles(claim) : item.sourcePaths,
      conditions,
    };
  });
  const states = new Map(snapshot.map.states.map((state) => [state.id, state]));
  const obligations: StandingObligation[] = snapshot.claims.map((claim) => ({
    claimId: claim.id,
    title: claim.id,
    expectation: claim.text,
    state: states.get(claim.id)?.state ?? "never-checked",
    owner: claim.owner,
    files: claimFiles(claim),
    conditions: claimConditions(claim, grouped.get(claim.id) ?? []),
  }));
  const acceptance: GoalAcceptance = {
    title: { key: "queue.accept_basis" },
    owner: snapshot.map.goal?.by ?? null,
    // The verdict of the map is the only source of the conclusion. The states
    // of the claims cannot carry it: a journal with an unreadable record keeps
    // the states of the claims and still lowers the verdict to unknown, and a
    // panel that reads the states would report a green conclusion next to an
    // unknown verdict.
    obligationsConfirmed: snapshot.map.verdict === "green",
    areaResolved:
      (snapshot.map.goal?.scope.length ?? 0) > 0 && snapshot.map.uncovered.length === 0,
    uncovered: snapshot.map.uncovered,
  };
  return { items, obligations, acceptance };
}
