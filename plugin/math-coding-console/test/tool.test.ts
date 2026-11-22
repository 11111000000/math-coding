import assert from "node:assert/strict";
import { test } from "node:test";
import { createElement } from "react";
import { buildAttentionModel } from "../client/attention";
import { mapSchema } from "../shared/domain";
import { rpcSchemas } from "../shared/schemas";
import { claim, evidence, map, snapshot, theme, unknownTool } from "./fixtures";
import { renderWithHost } from "./host-stub";

/**
 * The digest of the program.
 *
 * The map names the program that produced it, and every evidence record names
 * the program that produced the record. The reader sees which observer wrote
 * what it reads, so a map of another build can never pass for a map of this
 * one.
 */

test("the frame names the program that produced the map", async () => {
  const { InstrumentFrame } = await import("../client/frame");
  const data = snapshot();
  const model = buildAttentionModel(data, 1_000);
  const markup = renderWithHost(createElement(InstrumentFrame, {
    theme,
    compact: false,
    snapshot: data,
    attention: model,
    onRefresh: () => undefined,
    refreshing: false,
    onRun: () => undefined,
    running: false,
    runEnabled: true,
  }));
  assert.ok(
    markup.includes(`tool ${data.map.tool.class}`),
    "the frame does not name the program that produced the map",
  );
  assert.ok(
    markup.includes(data.map.tool.fingerprint.slice(0, 12)),
    "the frame does not show the digest of the program that produced the map",
  );
});

test("the evidence record names the program that produced it", async () => {
  const { EvidenceRecordCard } = await import("../client/evidence-record");
  const record = evidence();
  const markup = renderWithHost(createElement(EvidenceRecordCard, {
    theme,
    record,
    expanded: true,
    onToggle: () => undefined,
  }));
  assert.ok(
    markup.includes(`${record.tool.class} · ${record.tool.fingerprint}`),
    "the evidence record does not name the program that produced it",
  );
  assert.ok(
    markup.includes(`${record.environment.class} · ${record.environment.fingerprint}`),
    "the evidence record does not show the environment it was produced in",
  );
});

/**
 * A record of an unknown program says so.
 *
 * A record carried over from the previous format does not know the program
 * that wrote it. The panel names the class it knows and says that the build
 * is unknown, rather than showing an empty digest or inventing one.
 */
test("a record of an unknown program says so instead of naming a build", async () => {
  const { EvidenceRecordCard } = await import("../client/evidence-record");
  const record = evidence({ tool: unknownTool });
  const markup = renderWithHost(createElement(EvidenceRecordCard, {
    theme,
    record,
    expanded: true,
    onToggle: () => undefined,
  }));
  assert.ok(
    markup.includes(`${record.tool.class} · unknown`),
    "the evidence record does not say that the producer is unknown",
  );
});

/**
 * A snapshot without the digest of the program does not reach the panel.
 *
 * The field is required, so a program that does not name itself cannot be
 * read as a program that does.
 */
test("a snapshot without the digest of the program is refused", () => {
  const data = snapshot();
  const { tool: _tool, ...withoutTool } = data.map;
  assert.equal(
    rpcSchemas.snapshot.output.safeParse({ ...data, map: withoutTool }).success,
    false,
  );
});

/**
 * A map without the digest of the program is refused.
 *
 * The map is written by the program that reads it, so it always knows its own
 * digest. A map without it names no observer at all, and the reader refuses
 * it instead of guessing which build produced it.
 */
test("a map without the digest of the program is refused", () => {
  const { tool: _tool, ...withoutTool } = map([claim()]);
  assert.equal(mapSchema.safeParse(withoutTool).success, false);
  assert.equal(mapSchema.safeParse({ ...map([claim()]), tool: undefined }).success, false);
});
