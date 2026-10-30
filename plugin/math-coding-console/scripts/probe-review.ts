#!/usr/bin/env tsx
/**
 * A harness for the human review path: sign a review and see what the
 * kernel's store says afterwards.
 *
 *   npx tsx scripts/probe-review.ts <repository-root> <decision-id> <obligation-id>
 */
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { submitReview } from "../server/handlers";
import { resolveLayout } from "../server/layout";

const [root, decisionId, obligationId] = process.argv.slice(2);
if (root === undefined || decisionId === undefined || obligationId === undefined) {
  console.error("usage: probe-review.ts <repository-root> <decision-id> <obligation-id>");
  process.exit(2);
}

const stubContext = {
  paseo: {
    agents: {
      ref: () => ({
        timeline: {
          append: async (item: unknown) => {
            console.log("dispatch: timeline row", JSON.stringify(item));
            return { seq: 0, epoch: "e" };
          },
        },
        send: async (text: string) => {
          console.log("dispatch: prompt");
          console.log(text);
        },
      }),
    },
  },
} as never;

async function main() {
const answer = await submitReview(
  {
    root,
    decisionId,
    obligationId,
    result: "pass",
    producer: "human:probe",
    rationale: "Read the claim, read the fixture, agreed.",
  },
  stubContext,
);

console.log("ok         ", answer.ok);
console.log("error      ", answer.error);
console.log("id         ", answer.attestationId);
console.log("path       ", answer.attestationPath);
console.log("detail     ", answer.detail);

const layout = resolveLayout(root);
console.log("\nstore files:");
for (const name of readdirSync(layout.attestationsDir)) {
  const parsed = JSON.parse(readFileSync(join(layout.attestationsDir, name), "utf8")) as Record<string, unknown>;
  console.log(" ", name, JSON.stringify({ kind_: parsed.kind_, result: parsed.result, producer: parsed.producer }));
}
}

void main();
