import type { EvidenceOutcome } from "../../shared/domain";
import { CodedError } from "../../shared/errors";
import {
  humanActionArgv,
  humanActions,
  type HumanAction,
  type HumanActionKind,
  type HumanActionValues,
} from "../../shared/human-actions";
import { runProcess, type ProcessResult } from "../process";
import { loadProject, type ProjectSnapshot } from "../project";

/**
 * The manual steps of the method, performed by the program.
 *
 * The console does not decide anything on its own: it asks `mathc` to record
 * the decision of the human. The program stays the only implementation of the
 * method, so the refusal of the program is the refusal of the console.
 *
 * The step must belong to the current canonical map. The console checks that
 * before it runs anything, so a request cannot invent a step the method does
 * not offer for the current state.
 */

const DECISION_TIMEOUT_MS = 120_000;
const MAX_DECISION_BYTES = 1024 * 1024;

export interface HumanDecisionRequest {
  kind: HumanActionKind;
  claimId?: string;
  authority?: string;
  by: string;
  reason?: string;
  outcome?: EvidenceOutcome;
  validForDays?: number;
  recovery?: string;
}

export interface HumanDecisionResult {
  snapshot: ProjectSnapshot;
  message: string;
}

function matches(action: HumanAction, request: HumanDecisionRequest): boolean {
  if (action.kind !== request.kind) return false;
  if (action.claimId !== (request.claimId ?? null)) return false;
  if (action.kind === "record" && action.authority !== (request.authority ?? null)) return false;
  return true;
}

function valuesOf(request: HumanDecisionRequest): HumanActionValues {
  return {
    by: request.by ?? "",
    reason: request.reason ?? "",
    outcome: request.outcome ?? "",
    validForDays: request.validForDays === undefined ? "" : String(request.validForDays),
    recovery: request.recovery ?? "",
  };
}

/**
 * The refusal of the program, in the words of the program.
 *
 * The program prints `mathc: <reason>` and exits. The console shows that
 * reason instead of inventing one of its own.
 */
function decisionError(result: ProcessResult): Error {
  if (result.timedOut) return new Error("The decision did not finish in time");
  if (result.truncated) return new Error("The output of the decision exceeded its limit");
  if (result.systemError) return new Error(`Cannot execute mathc: ${result.systemError}`);
  const detail = (result.stderr.trim() || result.stdout.trim()).slice(0, 2000);
  const message = detail.replace(/^mathc:\s*/, "");
  if (message === "") return new Error(`mathc refused the decision with exit ${String(result.code)}`);
  return new Error(message);
}

/**
 * Record one decision of the human.
 *
 * The order is fixed: read the canonical map, find the step in it, run the
 * program, read the canonical map again. The console shows the second map,
 * so the state after the decision is the one the program reports.
 */
export async function applyHumanDecision(
  root: string,
  binary: string,
  request: HumanDecisionRequest,
): Promise<HumanDecisionResult> {
  const before = await loadProject(root, binary, "map", true);
  const actions = humanActions(
    {
      claims: before.claims,
      states: before.map.states,
      policyConfigured: before.policyConfigured,
    },
    Math.floor(Date.now() / 1000),
  );
  const action = actions.find((candidate) => matches(candidate, request));
  if (!action) {
    throw new CodedError("decision_not_available");
  }
  const argv = humanActionArgv(action, valuesOf(request));
  const result = await runProcess(binary, ["--root", root, ...argv], {
    cwd: root,
    timeoutMs: DECISION_TIMEOUT_MS,
    maxBuffer: MAX_DECISION_BYTES,
  });
  if (result.code !== 0) throw decisionError(result);
  const after = await loadProject(root, binary, "map", true);
  return { snapshot: after, message: result.stdout.trim() };
}
