import { EVIDENCE_OUTCOMES, type Claim, type EvidenceOutcome, type MapState, type Requirement } from "./domain";
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
 */

export const HUMAN_ACTION_KINDS = ["review-source", "record", "waive", "authorize"] as const;

export type HumanActionKind = (typeof HUMAN_ACTION_KINDS)[number];

export type HumanActionFieldName = "by" | "reason" | "outcome" | "validForDays" | "recovery";

export interface HumanActionField {
  name: HumanActionFieldName;
  label: string;
  hint: string;
  required: boolean;
  placeholder?: string;
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
  title: string;
  /** What the program will do with the step. */
  detail: string;
  /** The expectation of the claim the step is about. */
  expectation: string;
  /** The declared owner of the claim, empty when the claim has none. */
  owner: string;
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
export function humanActionKindLabel(kind: HumanActionKind): string {
  switch (kind) {
    case "review-source":
      return "review of a source";
    case "record":
      return "human review";
    case "waive":
      return "accepted risk";
    case "authorize":
      return "authorization";
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
  label: "Who decides",
  hint: "The name is written into the journal of decisions. It is not an authentication.",
  required: true,
  placeholder: "the name of the person who decided",
};

function reasonField(hint: string): HumanActionField {
  return { name: "reason", label: "Why", hint, required: true };
}

const outcomeField: HumanActionField = {
  name: "outcome",
  label: "Outcome of the review",
  hint: "Only the five outcomes of the domain are accepted.",
  required: true,
  options: EVIDENCE_OUTCOMES,
};

function validForField(required: boolean, hint: string): HumanActionField {
  return { name: "validForDays", label: "Valid for (days)", hint, required, placeholder: "7" };
}

const recoveryField: HumanActionField = {
  name: "recovery",
  label: "Recovery plan",
  hint: "What is done when the accepted risk is no longer accepted.",
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
      const owner = claim.owner ?? "the owner of the claim";
      actions.push({
        id: `review-source:${claim.id}`,
        kind: "review-source",
        claimId: claim.id,
        authority: null,
        title: `Review the changed source of ${claim.id}`,
        detail:
          `The linked source ${claim.source.path} changed. The review stores the author, the reason and the previous digest, ` +
          "clears the accepted risk and still requires a fresh run. Only the owner of the claim may record it.",
        expectation: claim.text,
        fields: [
          byField,
          reasonField(`Why ${claim.source.path} still justifies the claim, or why it does not.`),
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
          title: `Record the human review of ${claim.id}`,
          detail:
            `The claim declares the review by ${review.spec}. The record is human evidence with external independence: ` +
            "it is not a machine verification, and it does not authenticate the author.",
          expectation: claim.text,
          fields: [byField, outcomeField, validForField(false, "Optional. The record expires after this many days.")],
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
            ? `Renew the accepted risk of ${claim.id}`
            : `Accept the risk of ${claim.id}`,
          detail: expired
            ? `The accepted risk expired at ${new Date(waiver.expires_at * 1000).toISOString()}. A new waiver replaces it and acts only inside its own interval.`
            : "The waiver marks the unknown gap of the claim as accepted for a limited time. It never turns an unknown into a confirmation, it never covers a refutation and it does not give a green verdict.",
          expectation: claim.text,
          fields: [
            byField,
            reasonField("Why this gap is accepted on these terms."),
            validForField(true, "The waiver acts only inside this interval."),
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
      title: "Authorize the protected changes",
      detail:
        "The project declares protected transitions. The authorization is a journal entry for the current commit; " +
        "it is not an authentication, and only the declared person may record it.",
      expectation: "The protected changes of the current commit.",
      fields: [byField, reasonField("Why the protected changes are authorized.")],
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

function requireText(value: string, label: string): string {
  const text = value.trim();
  if (text === "") throw new Error(`The decision needs ${label}`);
  return text;
}

function optionalDays(value: string, label: string): number | null {
  const text = value.trim();
  if (text === "") return null;
  if (!/^\d+$/.test(text)) throw new Error(`${label} must be a whole number of days`);
  const days = Number(text);
  if (days <= 0) throw new Error(`${label} must be a positive number of days`);
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
  const by = requireText(values.by, "the name of the person who decided");
  switch (action.kind) {
    case "review-source": {
      if (!action.claimId) throw new Error("The review of a source needs a claim");
      const reason = requireText(values.reason, "the reason of the review");
      return ["review-source", action.claimId, "--by", by, "--reason", reason];
    }
    case "record": {
      if (!action.claimId) throw new Error("A human review needs a claim");
      if (!action.authority) throw new Error("A human review needs the declared authority");
      const outcome = requireText(values.outcome, "the outcome of the review");
      if (!EVIDENCE_OUTCOMES.includes(outcome as (typeof EVIDENCE_OUTCOMES)[number])) {
        throw new Error(`The outcome must be one of ${EVIDENCE_OUTCOMES.join(", ")}`);
      }
      const argv = ["record", action.claimId, action.authority, "--by", by, "--outcome", outcome];
      const days = optionalDays(values.validForDays, "The validity");
      if (days !== null) argv.push("--valid-for", String(days));
      return argv;
    }
    case "waive": {
      if (!action.claimId) throw new Error("An accepted risk needs a claim");
      const reason = requireText(values.reason, "the reason of the accepted risk");
      const recovery = requireText(values.recovery, "the recovery plan");
      const days = optionalDays(values.validForDays, "The validity");
      if (days === null) throw new Error("An accepted risk needs the number of days it acts for");
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
      const reason = requireText(values.reason, "the reason of the authorization");
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
