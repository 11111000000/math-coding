import type { Claim, ClaimState, Requirement, Verdict } from "../shared/domain";
import { flattenRequirements, requirementLabel } from "../shared/requirements";
import type { SnapshotReady } from "../shared/schemas";

export type HumanAttentionKind =
  | "source-review"
  | "refutation"
  | "human-review"
  | "acceptance-criterion"
  | "expired-waiver";

export type AgentAttentionKind = "refresh-evidence" | "investigate-unknown" | "coverage";

export interface ClaimContext {
  id: string;
  text: string;
  scope: string[];
  falsifier: string;
  requirements: string[];
}

export interface HumanAttentionItem {
  id: string;
  kind: HumanAttentionKind;
  title: string;
  claimIds: string[];
  states: ClaimState[];
  why: string;
  humanQuestion: string;
  agentMay: string;
  agentMustNot: string;
  suggestedAction: string;
  sourcePaths: string[];
  claimContext: ClaimContext[];
}

export interface AgentAttentionItem {
  id: string;
  kind: AgentAttentionKind;
  title: string;
  claimIds: string[];
  states: ClaimState[];
  why: string;
  humanBoundary: string;
  agentMay: string;
  agentMustNot: string;
  suggestedAction: string;
  sourcePaths: string[];
  uncoveredPaths: string[];
  claimContext: ClaimContext[];
}

export interface AcceptedRiskItem {
  id: string;
  claimId: string;
  title: string;
  gap: string;
  issuer: string;
  reason: string;
  issuedAt: number;
  expiresAt: number;
  recovery: string;
  compensatingControls: string[];
}

export interface AttentionModel {
  needsHuman: HumanAttentionItem[];
  agentCanAct: AgentAttentionItem[];
  acceptedRisks: AcceptedRiskItem[];
  humanDecisionCount: number;
  agentClaimCount: number;
  agentOnlyClaimCount: number;
  agentTaskCount: number;
}

/**
 * The canonical context an agent needs next to the local task.
 *
 * The brief is not only about one claim: it must carry the goal, the current
 * verdict, the coverage gap, the accepted risks and the canonical next action,
 * so the helper can act without reading the map again.
 */
export interface AttentionBriefContext {
  goal: string | null;
  verdict: Verdict;
  uncovered: string[];
  acceptedRisks: AcceptedRiskItem[];
  next: string;
}

function reviewRequirements(claim: Claim): Array<Extract<Requirement, { kind: "review" }>> {
  return flattenRequirements(claim)
    .map((node) => node.requirement)
    .filter((requirement): requirement is Extract<Requirement, { kind: "review" }> =>
      "kind" in requirement && requirement.kind === "review",
    );
}

function machineRequirements(claim: Claim): string[] {
  return flattenRequirements(claim)
    .map((node) => node.requirement)
    .filter((requirement): requirement is Extract<Requirement, { kind: "verifier" }> =>
      "kind" in requirement && requirement.kind === "verifier",
    )
    .map((requirement) => requirement.spec);
}

function sourcePaths(claim: Claim): string[] {
  return claim.source ? [claim.source.path] : [];
}

function claimContext(claim: Claim): ClaimContext {
  return {
    id: claim.id,
    text: claim.text,
    scope: claim.scope,
    falsifier: claim.falsifier,
    requirements: flattenRequirements(claim).map((node) => `${node.path}: ${requirementLabel(node.requirement)}`),
  };
}

function humanItem(
  kind: HumanAttentionKind,
  claim: Claim,
  state: ClaimState,
  fields: Omit<HumanAttentionItem, "id" | "kind" | "claimIds" | "states" | "sourcePaths" | "claimContext">,
): HumanAttentionItem {
  return {
    id: `${kind}:${claim.id}`,
    kind,
    claimIds: [claim.id],
    states: [state],
    sourcePaths: sourcePaths(claim),
    claimContext: [claimContext(claim)],
    ...fields,
  };
}

function humanItemForClaim(
  claim: Claim,
  state: ClaimState,
  sourceChanged: boolean,
  nowSeconds: number,
): HumanAttentionItem | null {
  if (sourceChanged) {
    const source = claim.source?.path ?? "the linked source";
    return humanItem("source-review", claim, state, {
      title: `Review the changed source for ${claim.id}`,
      why: `The linked source ${source} changed. Previous evidence no longer applies to the current source.`,
      humanQuestion: `Does ${source} still justify “${claim.text}”, or should the claim, falsifier, or acceptance condition change?`,
      agentMay: "Collect the source diff and explain how the claim's scope, falsifier, and acceptance conditions may be affected.",
      agentMustNot: "Do not rewrite the source, record a source review, or treat the human review as complete.",
      suggestedAction: "Prepare the source diff, claim context, and relevant evidence for the owner's review.",
    });
  }
  if (state === "refuted") {
    return humanItem("refutation", claim, state, {
      title: `Decide the direction of refuted claim ${claim.id}`,
      why: "A current observation contradicted the claim. The implementation may be wrong, but the contract may also be wrong.",
      humanQuestion: `Should the implementation be repaired while keeping “${claim.text}” and its falsifier, or does the claim itself need to change?`,
      agentMay: "Reproduce the failure and propose a repair without weakening the verifier or negative control.",
      agentMustNot: "Do not weaken the oracle, alter the claim to obtain green, or decide the contract direction.",
      suggestedAction: "Reproduce the failure and present repair options; leave the contract decision to the owner.",
    });
  }
  if (state === "not-checkable") {
    return humanItem("acceptance-criterion", claim, state, {
      title: `Choose an acceptance criterion for ${claim.id}`,
      why: "The canonical map says this claim has no suitable way to establish or refute its current condition.",
      humanQuestion: `What observable condition would prove or refute “${claim.text}”, and should a machine or a human produce it?`,
      agentMay: "Propose one or more machine checks and explain their sensitivity, but do not make them authoritative.",
      agentMustNot: "Do not declare the claim checkable, weaken the intended condition, or record a human review.",
      suggestedAction: "Propose candidate machine checks; leave selection of the acceptance criterion to the owner.",
    });
  }
  const reviews = reviewRequirements(claim);
  if (reviews.length > 0 && state !== "holds" && state !== "waived") {
    const authorities = reviews.map((review) => `${review.spec} (${review.minimum_independence})`).join(", ");
    return humanItem("human-review", claim, state, {
      title: `Complete the human review for ${claim.id}`,
      why: `The claim requires human review by ${authorities}, and the current canonical state is ${state}.`,
      humanQuestion: `Do the named reviewers confirm “${claim.text}” at the declared independence, or should the condition or authority change?`,
      agentMay: "Prepare the claim, source, scope, falsifier, and relevant evidence for the reviewer.",
      agentMustNot: "Do not impersonate the reviewer, record the review, or treat a machine check as human review.",
      suggestedAction: "Prepare the review context for the named human reviewer; leave the review decision to the reviewer.",
    });
  }
  if (claim.waiver && nowSeconds >= claim.waiver.expires_at && state !== "holds") {
    return humanItem("expired-waiver", claim, state, {
      title: `Renew or close the expired waiver for ${claim.id}`,
      why: `The accepted risk expired at ${new Date(claim.waiver.expires_at * 1000).toISOString()}. It no longer covers the declared gap.`,
      humanQuestion: `Is “${claim.waiver.gap}” still accepted on the same terms, or should the recovery plan start now?`,
      agentMay: "Prepare evidence about the gap and the existing recovery plan for the decision.",
      agentMustNot: "Do not renew the waiver, extend its interval, or treat expired acceptance as current.",
      suggestedAction: "Prepare the risk and recovery evidence; leave renewal or closure to the owner.",
    });
  }
  return null;
}

function agentBlocked(claim: Claim, state: ClaimState, sourceChanged: boolean): boolean {
  return sourceChanged ||
    state === "refuted" ||
    state === "not-checkable" ||
    state === "waived" ||
    machineRequirements(claim).length === 0;
}

function agentItems(snapshot: SnapshotReady): AgentAttentionItem[] {
  const states = new Map(snapshot.map.states.map((state) => [state.id, state]));
  const refresh: AgentAttentionItem[] = [];
  const investigate: AgentAttentionItem[] = [];
  for (const claim of snapshot.claims) {
    const mapState = states.get(claim.id);
    const state = mapState?.state;
    if (!state || agentBlocked(claim, state, mapState?.source_changed ?? false)) continue;
    if (state === "outdated" || state === "never-checked") {
      refresh.push({
        id: `refresh-evidence:${claim.id}`,
        kind: "refresh-evidence",
        title: "Refresh current evidence",
        claimIds: [claim.id],
        states: [state],
        why: `The canonical state is ${state}; the declared machine checks can restore current evidence without changing the claim.`,
        humanBoundary: "The machine portion can proceed unless a fresh result reveals that the claim's meaning changed.",
        agentMay: "Run the declared verifier and negative control, then report the canonical result.",
        agentMustNot: "Do not weaken the verifier, change the claim to obtain green, or record a human review.",
        suggestedAction: "Run checks and return any failure or human-decision ambiguity for inspection.",
        sourcePaths: sourcePaths(claim),
        uncoveredPaths: [],
        claimContext: [claimContext(claim)],
      });
    } else if (state === "inconclusive") {
      investigate.push({
        id: `investigate-unknown:${claim.id}`,
        kind: "investigate-unknown",
        title: "Investigate an inconclusive result",
        claimIds: [claim.id],
        states: [state],
        why: "The canonical state is inconclusive: the current observations did not establish or refute the claim.",
        humanBoundary: "Bring the claim back to the human only if the intended acceptance criterion remains ambiguous.",
        agentMay: "Inspect the latest observations and propose a fix or a more sensitive check.",
        agentMustNot: "Do not replace an inconclusive observation with an assumed pass or weaken the condition.",
        suggestedAction: "Diagnose the inconclusive branch and propose the smallest honest repair.",
        sourcePaths: sourcePaths(claim),
        uncoveredPaths: [],
        claimContext: [claimContext(claim)],
      });
    }
  }
  const result: AgentAttentionItem[] = [];
  if (refresh.length > 0) {
    result.push({
      id: "refresh-evidence:group",
      kind: "refresh-evidence",
      title: `Refresh evidence for ${refresh.length} claims`,
      claimIds: refresh.flatMap((item) => item.claimIds),
      states: [...new Set(refresh.flatMap((item) => item.states))],
      why: "These claims have machine-verifiable work that can proceed without waiting for a separate human-only part.",
      humanBoundary: "No human decision is required for the machine portion unless a fresh result changes the intended contract.",
      agentMay: "Run the declared checks and group the outcomes by claim.",
      agentMustNot: "Do not weaken verifiers, alter claims to obtain green, or record human decisions.",
      suggestedAction: "Refresh evidence and report only genuine failures or contract ambiguity.",
      sourcePaths: [...new Set(refresh.flatMap((item) => item.sourcePaths))],
      uncoveredPaths: [],
      claimContext: refresh.flatMap((item) => item.claimContext),
    });
  }
  if (investigate.length > 0) {
    result.push({
      id: "investigate-unknown:group",
      kind: "investigate-unknown",
      title: `Investigate ${investigate.length} inconclusive claims`,
      claimIds: investigate.flatMap((item) => item.claimIds),
      states: ["inconclusive"],
      why: "The current observations left these claims unknown rather than confirming or refuting them.",
      humanBoundary: "Return to the human only if the intended acceptance criterion is ambiguous.",
      agentMay: "Inspect the linked observations and propose fixes or more sensitive checks.",
      agentMustNot: "Do not convert unknown observations into an assumed pass.",
      suggestedAction: "Diagnose each inconclusive branch and preserve the original acceptance condition.",
      sourcePaths: [...new Set(investigate.flatMap((item) => item.sourcePaths))],
      uncoveredPaths: [],
      claimContext: investigate.flatMap((item) => item.claimContext),
    });
  }
  if (snapshot.map.uncovered.length > 0) {
    result.push({
      id: "coverage:group",
      kind: "coverage",
      title: `Map ${snapshot.map.uncovered.length} uncovered paths to claims`,
      claimIds: [],
      states: [],
      why: "These goal-scope paths are not included in any active claim subject.",
      humanBoundary: "The agent may propose claims and scope; only the human decides whether the goal boundary changes.",
      agentMay: "Inspect the uncovered paths and propose one or more checkable claims.",
      agentMustNot: "Do not expand the goal scope or create claims without the owner's decision.",
      suggestedAction: "Prepare a coverage proposal for human approval.",
      sourcePaths: [],
      uncoveredPaths: snapshot.map.uncovered,
      claimContext: [],
    });
  }
  return result;
}

/**
 * The canonical time of a snapshot.
 *
 * The server stamps the snapshot; the client clock is not a source of truth.
 * Waivers and their expiry are therefore compared against the snapshot time.
 */
export function snapshotSeconds(snapshot: SnapshotReady): number {
  return Math.floor(new Date(snapshot.generatedAt).getTime() / 1000);
}

export function buildAttentionModel(snapshot: SnapshotReady, nowSeconds = snapshotSeconds(snapshot)): AttentionModel {
  const states = new Map(snapshot.map.states.map((state) => [state.id, state]));
  const needsHuman: HumanAttentionItem[] = [];
  const acceptedRisks: AcceptedRiskItem[] = [];
  for (const claim of snapshot.claims) {
    const mapState = states.get(claim.id);
    const state = mapState?.state;
    if (!state) continue;
    const item = humanItemForClaim(claim, state, mapState?.source_changed ?? false, nowSeconds);
    if (item) needsHuman.push(item);
    if (state === "waived" && claim.waiver && nowSeconds >= claim.waiver.issued_at && nowSeconds < claim.waiver.expires_at) {
      acceptedRisks.push({
        id: `accepted-risk:${claim.id}`,
        claimId: claim.id,
        title: `Accepted risk for ${claim.id}`,
        gap: claim.waiver.gap,
        issuer: claim.waiver.issuer,
        reason: claim.waiver.reason,
        issuedAt: claim.waiver.issued_at,
        expiresAt: claim.waiver.expires_at,
        recovery: claim.waiver.recovery,
        compensatingControls: claim.waiver.compensating_controls,
      });
    }
  }
  const priority: Record<HumanAttentionKind, number> = {
    "source-review": 0,
    refutation: 1,
    "human-review": 2,
    "acceptance-criterion": 3,
    "expired-waiver": 4,
  };
  needsHuman.sort((a, b) => priority[a.kind] - priority[b.kind] || a.claimIds[0]!.localeCompare(b.claimIds[0]!));
  acceptedRisks.sort((a, b) => a.expiresAt - b.expiresAt || a.claimId.localeCompare(b.claimId));
  const agentCanAct = agentItems(snapshot);
  const agentClaimIds = new Set(agentCanAct.flatMap((item) => item.claimIds));
  const humanClaimIds = new Set(needsHuman.flatMap((item) => item.claimIds));
  const agentClaimCount = agentClaimIds.size;
  const agentOnlyClaimCount = [...agentClaimIds].filter((id) => !humanClaimIds.has(id)).length;
  return {
    needsHuman,
    agentCanAct,
    acceptedRisks,
    humanDecisionCount: needsHuman.length,
    agentClaimCount,
    agentOnlyClaimCount,
    agentTaskCount: agentCanAct.length,
  };
}

/**
 * The canonical context of a snapshot, ready to be pasted into a brief.
 */
export function attentionContext(snapshot: SnapshotReady, model: AttentionModel): AttentionBriefContext {
  return {
    goal: snapshot.map.goal?.text ?? null,
    verdict: snapshot.map.verdict,
    uncovered: snapshot.map.uncovered,
    acceptedRisks: model.acceptedRisks,
    next: snapshot.map.next,
  };
}

export function attentionBrief(item: HumanAttentionItem | AgentAttentionItem, context: AttentionBriefContext): string {
  const human = "humanQuestion" in item;
  const lines = [
    "Math Coding attention brief",
    "",
    `Goal: ${context.goal ?? "no goal declared"}`,
    `Canonical verdict: ${context.verdict}`,
    `Goal scope uncovered: ${context.uncovered.length} path(s)`,
  ];
  for (const path of context.uncovered) lines.push(`  - ${path}`);
  lines.push(`Accepted risks: ${context.acceptedRisks.length}`);
  for (const risk of context.acceptedRisks) {
    lines.push(`  - ${risk.title}: ${risk.gap} (issuer ${risk.issuer}, expires ${new Date(risk.expiresAt * 1000).toISOString()})`);
  }
  lines.push(`Canonical next action: ${context.next}`);
  lines.push(
    "",
    `Title: ${item.title}`,
    `Claims: ${item.claimIds.length > 0 ? item.claimIds.join(", ") : "goal coverage"}`,
    `Canonical states: ${item.states.length > 0 ? item.states.join(", ") : "not claim-specific"}`,
  );
  if (item.sourcePaths.length > 0) lines.push(`Sources: ${item.sourcePaths.join(", ")}`);
  if ("uncoveredPaths" in item && item.uncoveredPaths.length > 0) lines.push(`Task uncovered paths: ${item.uncoveredPaths.join(", ")}`);
  if (item.claimContext.length > 0) {
    lines.push("", "Claim context:");
    for (const entry of item.claimContext) {
      lines.push(`- ${entry.id}: ${entry.text}`);
      lines.push(`  scope: ${entry.scope.join(", ") || "none"}`);
      lines.push(`  falsifier: ${entry.falsifier || "not declared"}`);
      lines.push(`  requirements: ${entry.requirements.join(" | ") || "none"}`);
    }
  }
  lines.push("", "Why:", item.why);
  if (human) {
    lines.push("", "Human decision (the agent must not make it):", item.humanQuestion);
  } else {
    lines.push("", "Human boundary:", item.humanBoundary);
  }
  lines.push("", "Agent may:", item.agentMay);
  lines.push("Agent must not:", item.agentMustNot);
  lines.push("", "Next safe step:", item.suggestedAction);
  return lines.join("\n");
}
