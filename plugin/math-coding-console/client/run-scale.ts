import { flattenRequirements } from "../shared/requirements";
import type { SnapshotReady } from "../shared/schemas";

/**
 * The scale of one run.
 *
 * The numbers are read from the canonical snapshot only: the claims the map
 * declares and the commands those claims declare. Nothing is executed here.
 */
export interface RunScale {
  claimCount: number;
  commandCount: number;
}

/**
 * Counts the commands a run would execute.
 *
 * A claim contributes one command per declared verifier requirement plus one
 * negative control, which is the same set the canonical verifier digest covers.
 */
export function runScale(snapshot: SnapshotReady): RunScale {
  let commandCount = 0;
  for (const claim of snapshot.claims) {
    commandCount += flattenRequirements(claim)
      .filter((node) => "kind" in node.requirement && node.requirement.kind === "verifier").length;
    if (claim.control) commandCount += 1;
  }
  return { claimCount: snapshot.claims.length, commandCount };
}
