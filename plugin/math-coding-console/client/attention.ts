import type { Claim, ClaimState, MapState, Requirement, StateReason, Verdict } from "../shared/domain";
import { flattenRequirements, requirementLabel } from "../shared/requirements";
import type { SnapshotReady } from "../shared/schemas";
import type { MessageRef } from "../shared/message";
import { translate, type Translate } from "./i18n/translate";
import { stateReasonKey, stateReasonText } from "./vocabulary";

export type HumanAttentionKind =
  | "source-review"
  | "refutation"
  | "human-review"
  | "expired-waiver";

export type AgentAttentionKind = "refresh-evidence" | "investigate-unknown" | "coverage";

export interface ClaimContext {
  id: string;
  text: string;
  scope: string[];
  falsifier: string;
  requirements: string[];
}

/**
 * The canonical reason of one claim state.
 *
 * The reason is the one the map reports. It stays absent when the program
 * does not report it, and the console then says so instead of guessing.
 */
export interface StateReasonEntry {
  claimId: string;
  reason?: StateReason;
}

export interface HumanAttentionItem {
  id: string;
  kind: HumanAttentionKind;
  title: MessageRef;
  claimIds: string[];
  states: ClaimState[];
  reasons: StateReasonEntry[];
  why: MessageRef;
  humanQuestion: MessageRef;
  agentMay: MessageRef;
  agentMustNot: MessageRef;
  suggestedAction: MessageRef;
  sourcePaths: string[];
  claimContext: ClaimContext[];
}

export interface AgentAttentionItem {
  id: string;
  kind: AgentAttentionKind;
  title: MessageRef;
  claimIds: string[];
  states: ClaimState[];
  reasons: StateReasonEntry[];
  why: MessageRef;
  humanBoundary: MessageRef;
  agentMay: MessageRef;
  agentMustNot: MessageRef;
  suggestedAction: MessageRef;
  sourcePaths: string[];
  uncoveredPaths: string[];
  claimContext: ClaimContext[];
}

export interface AcceptedRiskItem {
  id: string;
  claimId: string;
  title: MessageRef;
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
  mapState: MapState,
  fields: Omit<HumanAttentionItem, "id" | "kind" | "claimIds" | "states" | "reasons" | "sourcePaths" | "claimContext">,
): HumanAttentionItem {
  return {
    id: `${kind}:${claim.id}`,
    kind,
    claimIds: [claim.id],
    states: [mapState.state],
    reasons: [{ claimId: claim.id, reason: mapState.reason }],
    sourcePaths: sourcePaths(claim),
    claimContext: [claimContext(claim)],
    ...fields,
  };
}

function humanItemForClaim(
  claim: Claim,
  mapState: MapState,
  sourceChanged: boolean,
  nowSeconds: number,
): HumanAttentionItem | null {
  const state = mapState.state;
  if (sourceChanged) {
    const source = claim.source?.path ?? "the linked source";
    return humanItem("source-review", claim, mapState, {
      title: { key: "attention.source_review_title", args: { claim: claim.id } },
      why: { key: "attention.source_review_why", args: { source } },
      humanQuestion: { key: "attention.source_review_question", args: { source, claim: claim.text } },
      agentMay: { key: "attention.source_review_agent_may" },
      agentMustNot: { key: "attention.source_review_agent_must_not" },
      suggestedAction: { key: "attention.source_review_suggested" },
    });
  }
  if (state === "refuted") {
    return humanItem("refutation", claim, mapState, {
      title: { key: "attention.refutation_title", args: { claim: claim.id } },
      why: { key: "attention.refutation_why" },
      humanQuestion: { key: "attention.refutation_question", args: { claim: claim.text } },
      agentMay: { key: "attention.refutation_agent_may" },
      agentMustNot: { key: "attention.refutation_agent_must_not" },
      suggestedAction: { key: "attention.refutation_suggested" },
    });
  }
  const reviews = reviewRequirements(claim);
  if (reviews.length > 0 && state !== "holds" && state !== "waived") {
    const authorities = reviews.map((review) => `${review.spec} (${review.minimum_independence})`).join(", ");
    return humanItem("human-review", claim, mapState, {
      title: { key: "attention.human_review_title", args: { claim: claim.id } },
      why: { key: "attention.human_review_why", args: { authorities, state } },
      humanQuestion: { key: "attention.human_review_question", args: { claim: claim.text } },
      agentMay: { key: "attention.human_review_agent_may" },
      agentMustNot: { key: "attention.human_review_agent_must_not" },
      suggestedAction: { key: "attention.human_review_suggested" },
    });
  }
  if (claim.waiver && nowSeconds >= claim.waiver.expires_at && state !== "holds") {
    return humanItem("expired-waiver", claim, mapState, {
      title: { key: "attention.expired_waiver_title", args: { claim: claim.id } },
      why: {
        key: "attention.expired_waiver_why",
        args: { time: new Date(claim.waiver.expires_at * 1000).toISOString() },
      },
      humanQuestion: { key: "attention.expired_waiver_question", args: { gap: claim.waiver.gap } },
      agentMay: { key: "attention.expired_waiver_agent_may" },
      agentMustNot: { key: "attention.expired_waiver_agent_must_not" },
      suggestedAction: { key: "attention.expired_waiver_suggested" },
    });
  }
  return null;
}

function agentBlocked(claim: Claim, state: ClaimState, sourceChanged: boolean): boolean {
  return sourceChanged ||
    state === "refuted" ||
    state === "waived" ||
    machineRequirements(claim).length === 0;
}

function agentItems(snapshot: SnapshotReady): AgentAttentionItem[] {
  const states = new Map(snapshot.map.states.map((state) => [state.id, state]));
  const refresh: AgentAttentionItem[] = [];
  const investigate: AgentAttentionItem[] = [];
  for (const claim of snapshot.claims) {
    const mapState = states.get(claim.id);
    if (!mapState) continue;
    const state = mapState.state;
    if (agentBlocked(claim, state, mapState.source_changed)) continue;
    if (state === "outdated" || state === "never-checked") {
      refresh.push({
        id: `refresh-evidence:${claim.id}`,
        kind: "refresh-evidence",
        title: { key: "attention.refresh_title" },
        claimIds: [claim.id],
        states: [state],
        reasons: [{ claimId: claim.id, reason: mapState.reason }],
        why: { key: "attention.refresh_why", args: { state } },
        humanBoundary: { key: "attention.refresh_boundary" },
        agentMay: { key: "attention.refresh_agent_may" },
        agentMustNot: { key: "attention.refresh_agent_must_not" },
        suggestedAction: { key: "attention.refresh_suggested" },
        sourcePaths: sourcePaths(claim),
        uncoveredPaths: [],
        claimContext: [claimContext(claim)],
      });
    } else if (state === "inconclusive") {
      investigate.push({
        id: `investigate-unknown:${claim.id}`,
        kind: "investigate-unknown",
        title: { key: "attention.investigate_title" },
        claimIds: [claim.id],
        states: [state],
        reasons: [{ claimId: claim.id, reason: mapState.reason }],
        why: { key: "attention.investigate_why" },
        humanBoundary: { key: "attention.investigate_boundary" },
        agentMay: { key: "attention.investigate_agent_may" },
        agentMustNot: { key: "attention.investigate_agent_must_not" },
        suggestedAction: { key: "attention.investigate_suggested" },
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
      title: { key: "attention.refresh_group_title", args: { count: refresh.length } },
      claimIds: refresh.flatMap((item) => item.claimIds),
      states: [...new Set(refresh.flatMap((item) => item.states))],
      reasons: refresh.flatMap((item) => item.reasons),
      why: { key: "attention.refresh_group_why" },
      humanBoundary: { key: "attention.refresh_group_boundary" },
      agentMay: { key: "attention.refresh_group_agent_may" },
      agentMustNot: { key: "attention.refresh_group_agent_must_not" },
      suggestedAction: { key: "attention.refresh_group_suggested" },
      sourcePaths: [...new Set(refresh.flatMap((item) => item.sourcePaths))],
      uncoveredPaths: [],
      claimContext: refresh.flatMap((item) => item.claimContext),
    });
  }
  if (investigate.length > 0) {
    result.push({
      id: "investigate-unknown:group",
      kind: "investigate-unknown",
      title: { key: "attention.investigate_group_title", args: { count: investigate.length } },
      claimIds: investigate.flatMap((item) => item.claimIds),
      states: ["inconclusive"],
      reasons: investigate.flatMap((item) => item.reasons),
      why: { key: "attention.investigate_group_why" },
      humanBoundary: { key: "attention.investigate_group_boundary" },
      agentMay: { key: "attention.investigate_group_agent_may" },
      agentMustNot: { key: "attention.investigate_group_agent_must_not" },
      suggestedAction: { key: "attention.investigate_group_suggested" },
      sourcePaths: [...new Set(investigate.flatMap((item) => item.sourcePaths))],
      uncoveredPaths: [],
      claimContext: investigate.flatMap((item) => item.claimContext),
    });
  }
  if (snapshot.map.uncovered.length > 0) {
    result.push({
      id: "coverage:group",
      kind: "coverage",
      title: { key: "attention.coverage_title", args: { count: snapshot.map.uncovered.length } },
      claimIds: [],
      states: [],
      reasons: [],
      why: { key: "attention.coverage_why" },
      humanBoundary: { key: "attention.coverage_boundary" },
      agentMay: { key: "attention.coverage_agent_may" },
      agentMustNot: { key: "attention.coverage_agent_must_not" },
      suggestedAction: { key: "attention.coverage_suggested" },
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
    if (!mapState) continue;
    const state = mapState.state;
    const item = humanItemForClaim(claim, mapState, mapState.source_changed, nowSeconds);
    if (item) needsHuman.push(item);
    if (state === "waived" && claim.waiver && nowSeconds >= claim.waiver.issued_at && nowSeconds < claim.waiver.expires_at) {
      acceptedRisks.push({
        id: `accepted-risk:${claim.id}`,
        claimId: claim.id,
        title: { key: "attention.accepted_risk_title", args: { claim: claim.id } },
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
    "expired-waiver": 3,
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

/**
 * The reason of an item, in the words of the console.
 *
 * The reason comes from the map. A group may carry several of them, and a
 * program that reports none leaves the reason unknown. An item without any
 * claim state has no reason to show at all.
 */
export function attentionReasonCodes(entries: StateReasonEntry[]): StateReason[] {
  return [...new Set(entries.map((entry) => entry.reason).filter((reason): reason is StateReason => reason !== undefined))];
}

export function attentionReasonText(entries: StateReasonEntry[], t: Translate): string {
  if (entries.length === 0) return "";
  const reasons = attentionReasonCodes(entries);
  if (reasons.length === 0) return t("state.reason_unknown");
  return reasons.map((reason) => t(stateReasonKey(reason))).join(" ");
}

/**
 * The reason lines of a brief.
 *
 * A single claim gets one line; a group gets one line per claim, so the
 * receiver knows what broke for every claim it is asked to work on.
 */
export function attentionReasonLines(entries: StateReasonEntry[]): string[] {
  if (entries.length === 0) return [];
  if (entries.length === 1) return [`Reason: ${stateReasonText(entries[0]?.reason)}`];
  return ["Reasons:", ...entries.map((entry) => `  - ${entry.claimId}: ${stateReasonText(entry.reason)}`)];
}

export function attentionBrief(item: HumanAttentionItem | AgentAttentionItem, context: AttentionBriefContext): string {
  const human = "humanQuestion" in item;
  /**
   * The brief is a contract with an agent, so it is written in one language:
   * the English one. The interface reads the same words in the language of the
   * human; the brief keeps the language of the method.
   */
  const words = (ref: MessageRef) => translate("en", ref.key, ref.args);
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
    lines.push(`  - ${words(risk.title)}: ${risk.gap} (issuer ${risk.issuer}, expires ${new Date(risk.expiresAt * 1000).toISOString()})`);
  }
  lines.push(`Canonical next action: ${context.next}`);
  lines.push(
    "",
    `Title: ${words(item.title)}`,
    `Claims: ${item.claimIds.length > 0 ? item.claimIds.join(", ") : "goal coverage"}`,
    `Canonical states: ${item.states.length > 0 ? item.states.join(", ") : "not claim-specific"}`,
  );
  lines.push(...attentionReasonLines(item.reasons));
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
  lines.push("", "Why:", words(item.why));
  if (human) {
    lines.push("", "Human decision (the agent must not make it):", words(item.humanQuestion));
  } else {
    lines.push("", "Human boundary:", words(item.humanBoundary));
  }
  lines.push("", "Agent may:", words(item.agentMay));
  lines.push("Agent must not:", words(item.agentMustNot));
  lines.push("", "Next safe step:", words(item.suggestedAction));
  return lines.join("\n");
}
