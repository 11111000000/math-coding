import type { PluginServerContext } from "@getpaseo/plugin/server";
import {
  claimDetailRpc,
  evidencePageRpc,
  preferences,
  runChecksRpc,
  snapshotRpc,
} from "./shared/contracts";
import { ProjectService } from "./server/service";

export default function contribute(server: PluginServerContext) {
  const service = new ProjectService(server.registerSettings(preferences));
  server.handle(snapshotRpc, ({ workspaceId }, { paseo }) => service.snapshot(paseo, workspaceId));
  server.handle(claimDetailRpc, (input, { paseo }) => service.claimDetail(paseo, input));
  server.handle(evidencePageRpc, (input, { paseo }) => service.evidence(paseo, input));
  server.handle(runChecksRpc, (input, { paseo }) => service.run(paseo, input));
  return () => {};
}
