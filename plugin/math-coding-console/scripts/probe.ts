#!/usr/bin/env tsx
/**
 * A harness that exercises the console's server handlers against a real
 * repository, without a Paseo host in the loop.
 *
 * The console's whole claim is that it does not re-derive a verdict: it asks
 * the kernel. This harness is how that claim is checked — it runs the same
 * handlers the daemon runs, and prints what they say.
 *
 *   npx tsx scripts/probe.ts /path/to/math-coding/repo
 */
import { buildDecision, buildPromiseList, buildState, searchDecisions } from "../server/handlers";
import { resolveLayout } from "../server/layout";

const root = process.argv[2];
if (root === undefined) {
  console.error("usage: probe.ts <repository-root>");
  process.exit(2);
}

async function main() {

const state = await buildState(root);
console.log("root          ", state.root, state.rootError ?? "");
console.log("kernel        ", state.kernelVersion);
console.log("version       ", state.version);
console.log("verdict       ", state.verdict?.verdict ?? "(none)", "exit", state.verdict?.exitCode ?? "-");
console.log("subjects      ", JSON.stringify(state.verdict?.subjects ?? {}));
console.log("coverage      ", JSON.stringify(state.coverage, null, 1));
console.log("decisions     ", state.decisions.length);
console.log("review queue  ", state.reviewQueue.length);
console.log("promises      ", state.promises.length);
console.log("attestations  ", JSON.stringify(state.attestations.byKind));
console.log("doctor        ", JSON.stringify(state.doctor?.sections.map((s) => `${s.id}=${s.verdict}`)));
console.log("git           ", JSON.stringify(state.git));
console.log("warnings      ", state.warnings);
console.log("layout        ", JSON.stringify(resolveLayout(state.root ?? root)));

const first = state.decisions[0];
if (first !== undefined) {
  const detail = await buildDecision(root, first.id);
  console.log("\n--- decision", detail.id, "---");
  console.log("obligations   ", detail.obligations.length);
  console.log("first         ", JSON.stringify(detail.obligations[0]));
  console.log("risk triggers ", detail.riskTriggers);
  console.log("counterexample", (detail.counterexample ?? "").slice(0, 80));
  console.log("antithesis    ", (detail.antithesis ?? "").slice(0, 80));
  console.log("relations     ", JSON.stringify(detail.relations));
}

const filtered = await buildPromiseList(root, { state: "missing", limit: 5 });
console.log("\nmissing promises", filtered.total);
console.log(JSON.stringify(filtered.promises.slice(0, 2), null, 1));

const found = await searchDecisions(root, "attestation");
console.log("\nsearch hits   ", found.matches.length, found.matches.slice(0, 3).map((m) => `${m.kind}:${m.id}`));
}

void main();
