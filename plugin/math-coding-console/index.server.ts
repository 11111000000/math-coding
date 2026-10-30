import type { PluginServerContext } from "@getpaseo/plugin/server";
import {
  buildChange,
  buildDecision,
  buildMosaic,
  buildPromiseList,
  buildState,
  changeLifecycle,
  explainDiagnostic,
  runAction,
  runGate,
  searchDecisions,
  submitReview,
} from "./server/handlers";
import {
  actionRpc,
  changeRpc,
  decisionRpc,
  diagnosticRpc,
  gateRpc,
  lifecycleRpc,
  mosaicRpc,
  promiseListRpc,
  reviewSubmitRpc,
  searchRpc,
  stateRpc,
} from "./shared/contracts";
import { preferences } from "./shared/settings";

export default function contribute(server: PluginServerContext) {
  const settings = server.registerSettings(preferences);

  server.handle(stateRpc, (input) => buildState(input.root));
  server.handle(mosaicRpc, (input) => buildMosaic(input.root));
  server.handle(changeRpc, (input) => buildChange(input.root, input.base, input.head));
  server.handle(promiseListRpc, (input) =>
    buildPromiseList(input.root, {
      state: input.state,
      class: input.class,
      decision: input.decision,
      query: input.query,
      limit: input.limit,
    }),
  );
  server.handle(decisionRpc, (input) => buildDecision(input.root, input.decisionId));
  server.handle(searchRpc, (input) => searchDecisions(input.root, input.query));
  server.handle(reviewSubmitRpc, (input, context) => submitReview(input, context));
  server.handle(lifecycleRpc, (input) =>
    changeLifecycle(input.root, input.decisionId, input.action, input.state, input.by),
  );
  server.handle(actionRpc, (input) =>
    runAction(input.root, input.action, input.args, input.flags, input.timeoutMs),
  );
  server.handle(gateRpc, (input) => runGate(input.root, input.base, input.head));
  server.handle(diagnosticRpc, (input) => explainDiagnostic(input.code));

  // The repository root is a host-scoped setting, and the handlers read it
  // from the environment the subprocess was started with. Keep the two in
  // step: a changed setting re-points the handlers at another repository.
  settings.subscribe((next) => {
    if (next.status !== "ready") return;
    const configured = next.values.repoRoot.trim();
    if (configured === "") {
      delete process.env.MATH_CODING_CONSOLE_ROOT;
      return;
    }
    process.env.MATH_CODING_CONSOLE_ROOT = configured;
  });

  return () => {};
}
