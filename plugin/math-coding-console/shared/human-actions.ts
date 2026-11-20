import { EVIDENCE_OUTCOMES, type Claim, type EvidenceOutcome, type MapState, type Requirement } from "./domain";
import { CodedError, type ErrorCode } from "./errors";
import type { MessageRef } from "./message";
import { flattenRequirements } from "./requirements";

/**
 * The manual steps of the method.
 *
 * The console is a view over `mathc`, not a second implementation of the
 * method. Every step below is therefore a call of the program itself, with the
 * arguments the program declares: `review-source`, `record`, `waive` and
 * `authorize`. The module names the steps the human may take, collects the
 * fields the program requires, and builds the argument list. The same builder
 * produces the command the interface shows and the command the server runs,
 * so the human sees exactly what happens.
 *
 * The module never computes a verdict and never computes a state. A step is
 * offered from the canonical map and from the declared specification only.
 *
 * The words of a step are named, not written: a step carries the key of the
 * catalogue and the values of its placeholders, so the server builds the same
 * step as the client draws it and neither of them holds a language.
 */

export const HUMAN_ACTION_KINDS = ["review-source", "record", "waive", "authorize"] as const;

export type HumanActionKind = (typeof HUMAN_ACTION_KINDS)[number];

export type HumanActionFieldName = "by" | "reason" | "outcome" | "validForDays" | "recovery";

export interface HumanActionField {
  name: HumanActionFieldName;
  label: MessageRef;
  hint: MessageRef;
  required: boolean;
  placeholder?: string | MessageRef;
  /** The closed set of values of the field, when the method declares one. */
  options?: readonly string[];
}

/**
 * One manual step of the method for one claim or for the whole project.
 */
export interface HumanAction {
  id: string;
  kind: HumanActionKind;
  /** The claim the step is about. A project-wide step has none. */
  claimId: string | null;
  /** The declared review authority, for a human review. */
  authority: string | null;
  title: MessageRef;
  /** What the program will do with the step. */
  detail: MessageRef;
  /**
   * The expectation of the claim the step is about.
   *
   * A claim carries its own text, and that text is data of the project: it is
   * shown as it is. A step that belongs to no claim names its expectation with
   * a key of the catalogue instead.
   */
  expectation: string | MessageRef;
  /**
   * The declared owner of the claim.
   *
   * A claim without a declared owner names the one who may act: the words are
   * named, not written, so the interface reads them in its own language.
   */
  owner: string | MessageRef;
  fields: HumanActionField[];
}

/**
 * The values a human fills in.
 *
 * The fields are kept as text here: the interface edits them as text, and the
 * builder rejects what the method does not accept before anything is run.
 */
export interface HumanActionValues {
  by: string;
  reason: string;
  /** Empty until the human picks one of the five outcomes of the domain. */
  outcome: EvidenceOutcome | "";
  validForDays: string;
  recovery: string;
}

export function emptyHumanActionValues(): HumanActionValues {
  return { by: "", reason: "", outcome: "", validForDays: "", recovery: "" };
}

/**
 * The name of a step in the words of the method.
 *
 * The verb of the program stays visible in the command; the label says what
 * the step means.
 */
export function humanActionKindRef(kind: HumanActionKind): MessageRef {
  switch (kind) {
    case "review-source":
      return { key: "action.kind_review_source" };
    case "record":
      return { key: "action.kind_record" };
    case "waive":
      return { key: "action.kind_waive" };
    case "authorize":
      return { key: "action.kind_authorize" };
  }
}

/**
 * The project the steps are derived from.
 *
 * The states are the ones of the canonical map, the claims are the declared
 * ones. The policy flag says whether the project declares protected
 * transitions; the program decides who may authorize them.
 */
export interface HumanActionSource {
  claims: readonly Claim[];
  states: readonly MapState[];
  policyConfigured: boolean;
}

const byField: HumanActionField = {
  name: "by",
  label: { key: "action.field_by" },
  hint: { key: "action.field_by_hint" },
  required: true,
  placeholder: { key: "action.field_by_placeholder" },
};

function reasonField(hint: MessageRef): HumanActionField {
  return { name: "reason", label: { key: "action.field_reason" }, hint, required: true };
}

const outcomeField: HumanActionField = {
  name: "outcome",
  label: { key: "action.field_outcome" },
  hint: { key: "action.field_outcome_hint" },
  required: true,
  options: EVIDENCE_OUTCOMES,
};

function validForField(required: boolean, hint: MessageRef): HumanActionField {
  return { name: "validForDays", label: { key: "action.field_valid_for" }, hint, required, placeholder: "7" };
}

const recoveryField: HumanActionField = {
  name: "recovery",
  label: { key: "action.field_recovery" },
  hint: { key: "action.field_recovery_hint" },
  required: true,
};

function reviewRequirements(claim: Claim): Array<Extract<Requirement, { kind: "review" }>> {
  return flattenRequirements(claim)
    .map((node) => node.requirement)
    .filter((requirement): requirement is Extract<Requirement, { kind: "review" }> =>
      "kind" in requirement && requirement.kind === "review",
    );
}

/**
 * The manual steps the current map allows.
 *
 * A step is offered when the method has a verb for it and the canonical state
 * asks for it. The rules are the ones the method declares:
 *
 * - a changed source needs a review by the owner of the claim;
 * - a claim that declares a human review and is not settled needs that review;
 * - an unsettled gap may be accepted as a risk for a limited time, and a
 *   refuted claim may never be waived;
 * - protected transitions may be authorized when the project declares a
 *   policy.
 */
export function humanActions(source: HumanActionSource, nowSeconds: number): HumanAction[] {
  const states = new Map(source.states.map((state) => [state.id, state]));
  const actions: HumanAction[] = [];
  for (const claim of source.claims) {
    const state = states.get(claim.id);
    if (!state) continue;
    if (state.source_changed && claim.source) {
      const owner: string | MessageRef = claim.owner ?? { key: "action.owner_fallback" };
      actions.push({
        id: `review-source:${claim.id}`,
        kind: "review-source",
        claimId: claim.id,
        authority: null,
        title: { key: "action.title_review_source", args: { claim: claim.id } },
        detail: { key: "action.detail_review_source", args: { path: claim.source.path } },
        expectation: claim.text,
        fields: [
          byField,
          reasonField({ key: "action.reason_review_source", args: { path: claim.source.path } }),
        ],
        owner,
      });
    }
    if (state.state !== "holds" && state.state !== "waived") {
      for (const review of reviewRequirements(claim)) {
        if (review.minimum_independence !== "external") continue;
        actions.push({
          id: `record:${claim.id}:${review.spec}`,
          kind: "record",
          claimId: claim.id,
          authority: review.spec,
          title: { key: "action.title_record", args: { claim: claim.id } },
          detail: { key: "action.detail_record", args: { authority: review.spec } },
          expectation: claim.text,
          fields: [byField, outcomeField, validForField(false, { key: "action.valid_for_optional" })],
          owner: claim.owner ?? "",
        });
      }
      if (state.state !== "refuted") {
        const waiver = claim.waiver;
        const expired = waiver !== null && nowSeconds >= waiver.expires_at;
        actions.push({
          id: `waive:${claim.id}`,
          kind: "waive",
          claimId: claim.id,
          authority: null,
          title: expired
            ? { key: "action.title_waive_renew", args: { claim: claim.id } }
            : { key: "action.title_waive", args: { claim: claim.id } },
          detail: expired
            ? {
              key: "action.detail_waive_renew",
              args: { time: new Date(waiver.expires_at * 1000).toISOString() },
            }
            : { key: "action.detail_waive" },
          expectation: claim.text,
          fields: [
            byField,
            reasonField({ key: "action.reason_waive" }),
            validForField(true, { key: "action.valid_for_required" }),
            recoveryField,
          ],
          owner: claim.owner ?? "",
        });
      }
    }
  }
  if (source.policyConfigured) {
    actions.push({
      id: "authorize",
      kind: "authorize",
      claimId: null,
      authority: null,
      title: { key: "action.title_authorize" },
      detail: { key: "action.detail_authorize" },
      expectation: { key: "action.expectation_authorize" },
      fields: [byField, reasonField({ key: "action.reason_authorize" })],
      owner: "",
    });
  }
  return actions;
}

/**
 * The steps of one claim.
 *
 * The interface uses it to put the step next to the decision it belongs to.
 */
export function humanActionsForClaim(actions: HumanAction[], claimId: string): HumanAction[] {
  return actions.filter((action) => action.claimId === claimId);
}

/**
 * The step the interface may offer for one claim.
 *
 * The order is the order of the method: a changed source comes first, then the
 * human review, then the accepted risk.
 */
export function primaryActionForClaim(actions: HumanAction[], claimId: string): HumanAction | undefined {
  const order: HumanActionKind[] = ["review-source", "record", "waive"];
  for (const kind of order) {
    const found = actions.find((action) => action.claimId === claimId && action.kind === kind);
    if (found) return found;
  }
  return undefined;
}

function requireText(value: string, code: ErrorCode): string {
  const text = value.trim();
  if (text === "") throw new CodedError(code);
  return text;
}

function optionalDays(value: string): number | null {
  const text = value.trim();
  if (text === "") return null;
  if (!/^\d+$/.test(text)) throw new CodedError("validity_whole");
  const days = Number(text);
  if (days <= 0) throw new CodedError("validity_positive");
  return days;
}

/**
 * The arguments of the program for one step.
 *
 * The builder is the only place that knows the shape of the call, so the
 * command the interface shows and the command the server runs cannot drift
 * apart. The arguments are passed to the program as a list; no shell is
 * involved.
 */
export function humanActionArgv(action: HumanAction, values: HumanActionValues): string[] {
  const by = requireText(values.by, "decision_needs_by");
  switch (action.kind) {
    case "review-source": {
      if (!action.claimId) throw new CodedError("review_needs_claim");
      const reason = requireText(values.reason, "decision_needs_reason");
      return ["review-source", action.claimId, "--by", by, "--reason", reason];
    }
    case "record": {
      if (!action.claimId) throw new CodedError("record_needs_claim");
      if (!action.authority) throw new CodedError("record_needs_authority");
      const outcome = requireText(values.outcome, "decision_needs_outcome");
      if (!EVIDENCE_OUTCOMES.includes(outcome as (typeof EVIDENCE_OUTCOMES)[number])) {
        throw new CodedError("outcome_unknown", EVIDENCE_OUTCOMES.join(", "));
      }
      const argv = ["record", action.claimId, action.authority, "--by", by, "--outcome", outcome];
      const days = optionalDays(values.validForDays);
      if (days !== null) argv.push("--valid-for", String(days));
      return argv;
    }
    case "waive": {
      if (!action.claimId) throw new CodedError("waive_needs_claim");
      const reason = requireText(values.reason, "decision_needs_reason_accepted_risk");
      const recovery = requireText(values.recovery, "decision_needs_recovery");
      const days = optionalDays(values.validForDays);
      if (days === null) throw new CodedError("days_required");
      return [
        "waive",
        action.claimId,
        "--by",
        by,
        "--reason",
        reason,
        "--valid-for",
        String(days),
        "--recovery",
        recovery,
      ];
    }
    case "authorize": {
      const reason = requireText(values.reason, "decision_needs_reason_authorization");
      return ["authorize", "--by", by, "--reason", reason];
    }
  }
}

/**
 * The command as it is shown to the human.
 *
 * The root of the project is left out: the step always runs in the project
 * the console was opened for.
 */
export function humanActionCommand(argv: string[]): string {
  const quote = (value: string) => (/^[A-Za-z0-9_./:@+-]+$/.test(value) ? value : `'${value.replace(/'/g, "'\\''")}'`);
  return ["mathc", ...argv].map(quote).join(" ");
}
