import type { PluginServerContext } from "@getpaseo/plugin/server";
import {
  claimDetailRpc,
  evidencePageRpc,
  filePreviewRpc,
  preferences,
  runChecksRpc,
  snapshotRpc,
} from "./shared/contracts";
import { ConsoleOperations } from "./server/core/operations";
import { PaseoOperationsHost } from "./server/paseo/service";

export default function contribute(server: PluginServerContext) {
  const settings = server.registerSettings(preferences);
  const operations = new ConsoleOperations();
  server.handle(snapshotRpc, async ({ workspaceId }, { paseo }) =>
    operations.snapshot(new PaseoOperationsHost(paseo, settings), workspaceId));
  server.handle(claimDetailRpc, async (input, { paseo }) =>
    operations.claimDetail(new PaseoOperationsHost(paseo, settings), input));
  server.handle(evidencePageRpc, async (input, { paseo }) =>
    operations.evidence(new PaseoOperationsHost(paseo, settings), input));
  server.handle(runChecksRpc, async (input, { paseo }) =>
    operations.run(new PaseoOperationsHost(paseo, settings), input));
  server.handle(filePreviewRpc, async (input, { paseo }) =>
    operations.filePreview(new PaseoOperationsHost(paseo, settings), input));
  return () => {};
}
