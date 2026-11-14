import type { SnapshotReady } from "../shared/contracts";
import type { ClaimState } from "../shared/domain";
import { flattenRequirements, shortRequirement } from "../shared/requirements";

export type GraphNodeKind = "goal" | "source" | "claim" | "requirement" | "scope" | "uncovered";

export interface GraphNode {
  id: string;
  kind: GraphNodeKind;
  title: string;
  subtitle: string;
  depth: number;
  claimId?: string;
  requirementPath?: string;
  state?: ClaimState;
  sourceChanged?: boolean;
}

export interface GraphEdge {
  id: string;
  from: string;
  to: string;
  kind: "proof" | "scope" | "shared-scope" | "uncovered";
  claimId?: string;
}

export interface GraphModel {
  nodes: GraphNode[];
  edges: GraphEdge[];
  truncated: number;
}

const MAX_CLAIMS = 120;
const MAX_NODES = 260;

function stateMap(snapshot: SnapshotReady): Map<string, ClaimState> {
  return new Map(snapshot.map.states.map((state) => [state.id, state.state]));
}

export function buildProofGraph(
  snapshot: SnapshotReady,
  expanded: ReadonlySet<string>,
  query = "",
): GraphModel {
  const states = stateMap(snapshot);
  const normalized = query.trim().toLowerCase();
  const matching = snapshot.claims.filter((claim) =>
    normalized === "" || `${claim.id} ${claim.text} ${claim.owner ?? ""} ${claim.source?.path ?? ""}`.toLowerCase().includes(normalized),
  );
  const visible = matching.slice(0, MAX_CLAIMS);
  const nodes: GraphNode[] = [{
    id: "goal",
    kind: "goal",
    title: snapshot.map.goal?.text ?? "Claims without a declared goal",
    subtitle: snapshot.map.goal ? `Goal · ${snapshot.map.goal.by}` : "No goal in map",
    depth: 0,
  }];
  const edges: GraphEdge[] = [];
  const sources = new Map<string, GraphNode>();
  let truncated = matching.length - visible.length;
  for (const claim of visible) {
    let parent = "goal";
    let depth = 1;
    if (claim.source) {
      const source = claim.source;
      const sourceId = `source:${source.kind}:${source.path}:${source.section ?? ""}`;
      depth = 2;
      if (!sources.has(sourceId)) {
        const node: GraphNode = {
          id: sourceId,
          kind: "source",
          title: source.path,
          subtitle: `${source.kind}${source.section ? ` · ${source.section}` : ""}`,
          depth: 1,
        };
        sources.set(sourceId, node);
        nodes.push(node);
        edges.push({ id: `goal→${sourceId}`, from: "goal", to: sourceId, kind: "proof" });
      }
      parent = sourceId;
    }
    const claimId = `claim:${claim.id}`;
    nodes.push({
      id: claimId,
      kind: "claim",
      title: claim.id,
      subtitle: claim.text,
      depth,
      claimId: claim.id,
      state: states.get(claim.id),
      sourceChanged: snapshot.map.states.find((state) => state.id === claim.id)?.source_changed,
    });
    edges.push({ id: `${parent}→${claimId}`, from: parent, to: claimId, kind: "proof", claimId: claim.id });
    if (expanded.has(claim.id)) {
      for (const item of flattenRequirements(claim)) {
        if (nodes.length >= MAX_NODES) {
          truncated += 1;
          break;
        }
        const id = `requirement:${claim.id}:${item.path}`;
        const parentId = item.parentPath === null ? claimId : `requirement:${claim.id}:${item.parentPath}`;
        const kind = "all" in item.requirement ? "all" : "any" in item.requirement ? "any" : item.requirement.kind;
        nodes.push({
          id,
          kind: "requirement",
          title: shortRequirement(item.requirement),
          subtitle: `${kind} · requirement ${item.path}`,
          depth: depth + item.depth + 1,
          claimId: claim.id,
          requirementPath: item.path,
        });
        edges.push({ id: `${parentId}→${id}`, from: parentId, to: id, kind: "proof", claimId: claim.id });
      }
    }
  }
  return { nodes, edges, truncated };
}

export function buildScopeGraph(snapshot: SnapshotReady, query = ""): GraphModel {
  const states = stateMap(snapshot);
  const normalized = query.trim().toLowerCase();
  const claims = snapshot.claims.filter((claim) =>
    normalized === "" || `${claim.id} ${claim.text} ${claim.scope.join(" ")}`.toLowerCase().includes(normalized),
  ).slice(0, MAX_CLAIMS);
  const nodes: GraphNode[] = [{
    id: "goal",
    kind: "goal",
    title: snapshot.map.goal?.text ?? "Declared scope",
    subtitle: `${snapshot.map.uncovered.length} uncovered path(s)`,
    depth: 0,
  }];
  const edges: GraphEdge[] = [];
  const scopes = new Map<string, string[]>();
  for (const claim of claims) {
    const id = `claim:${claim.id}`;
    nodes.push({
      id,
      kind: "claim",
      title: claim.id,
      subtitle: claim.text,
      depth: 1,
      claimId: claim.id,
      state: states.get(claim.id),
    });
    edges.push({ id: `goal→${id}`, from: "goal", to: id, kind: "scope", claimId: claim.id });
    for (const scope of claim.scope) {
      const list = scopes.get(scope) ?? [];
      list.push(claim.id);
      scopes.set(scope, list);
    }
  }
  for (const [scope, owners] of [...scopes.entries()].sort(([a], [b]) => a.localeCompare(b))) {
    if (nodes.length >= MAX_NODES) break;
    const id = `scope:${scope}`;
    nodes.push({
      id,
      kind: "scope",
      title: scope,
      subtitle: owners.length > 1 ? `shared declared scope · ${owners.length} claims` : "declared scope",
      depth: 2,
    });
    for (const claimId of owners) {
      edges.push({
        id: `claim:${claimId}→${id}`,
        from: `claim:${claimId}`,
        to: id,
        kind: owners.length > 1 ? "shared-scope" : "scope",
        claimId,
      });
    }
  }
  for (const path of snapshot.map.uncovered.slice(0, Math.max(0, MAX_NODES - nodes.length))) {
    const id = `uncovered:${path}`;
    nodes.push({ id, kind: "uncovered", title: path, subtitle: "uncovered in goal scope", depth: 1 });
    edges.push({ id: `goal→${id}`, from: "goal", to: id, kind: "uncovered" });
  }
  const represented = new Set(nodes.map((node) => node.id));
  return {
    nodes,
    edges: edges.filter((edge) => represented.has(edge.from) && represented.has(edge.to)),
    truncated: Math.max(0, snapshot.claims.length - claims.length) +
      Math.max(0, scopes.size + snapshot.map.uncovered.length + claims.length + 1 - nodes.length),
  };
}

export interface Segment { x: number; y: number; width: number; height: number }
export interface PositionedNode extends GraphNode { x: number; y: number; width: number; height: number }
export interface PositionedEdge extends GraphEdge { segments: Segment[]; marker: { x: number; y: number } }
export interface GraphLayout {
  nodes: PositionedNode[];
  edges: PositionedEdge[];
  width: number;
  height: number;
}

function compactOrder(model: GraphModel): GraphNode[] {
  const byId = new Map(model.nodes.map((node) => [node.id, node]));
  const children = new Map<string, GraphEdge[]>();
  for (const edge of model.edges) {
    const list = children.get(edge.from) ?? [];
    list.push(edge);
    children.set(edge.from, list);
  }
  const visited = new Set<string>();
  const result: GraphNode[] = [];
  const visit = (id: string) => {
    if (visited.has(id)) return;
    visited.add(id);
    const node = byId.get(id);
    if (node) result.push(node);
    for (const edge of children.get(id) ?? []) visit(edge.to);
  };
  visit("goal");
  for (const node of model.nodes) visit(node.id);
  return result;
}

function addSegment(segments: Segment[], x1: number, y1: number, x2: number, y2: number) {
  if (Math.abs(x2 - x1) < 0.01 && Math.abs(y2 - y1) < 0.01) return;
  segments.push({
    x: Math.min(x1, x2),
    y: Math.min(y1, y2),
    width: Math.max(1, Math.abs(x2 - x1)),
    height: Math.max(1, Math.abs(y2 - y1)),
  });
}

export function layoutGraph(model: GraphModel, compact: boolean, scale = 1): GraphLayout {
  const safeScale = Math.max(0.65, Math.min(1.4, scale));
  const nodeHeight = 92 * safeScale;
  const positions = new Map<string, PositionedNode>();
  if (compact) {
    let y = 20 * safeScale;
    for (const node of compactOrder(model)) {
      const width = Math.max(190, 286 - node.depth * 12) * safeScale;
      const positioned = { ...node, x: (16 + node.depth * 12) * safeScale, y, width, height: nodeHeight };
      positions.set(node.id, positioned);
      y += 116 * safeScale;
    }
  } else {
    const columns = new Map<number, number>();
    for (const node of model.nodes) {
      const row = columns.get(node.depth) ?? 0;
      columns.set(node.depth, row + 1);
      positions.set(node.id, {
        ...node,
        x: (24 + node.depth * 306) * safeScale,
        y: (24 + row * 118) * safeScale,
        width: 238 * safeScale,
        height: nodeHeight,
      });
    }
  }
  const nodes = [...positions.values()];
  const edges = model.edges.flatMap((edge): PositionedEdge[] => {
    const from = positions.get(edge.from);
    const to = positions.get(edge.to);
    if (!from || !to) return [];
    const segments: Segment[] = [];
    if (compact) {
      const x1 = from.x + Math.min(28 * safeScale, from.width / 3);
      const y1 = from.y + from.height;
      const x2 = to.x + Math.min(28 * safeScale, to.width / 3);
      const y2 = to.y;
      const middle = (y1 + y2) / 2;
      addSegment(segments, x1, y1, x1, middle);
      addSegment(segments, x1, middle, x2, middle);
      addSegment(segments, x2, middle, x2, y2);
      return [{ ...edge, segments, marker: { x: x2, y: y2 } }];
    }
    const x1 = from.x + from.width;
    const y1 = from.y + from.height / 2;
    const x2 = to.x;
    const y2 = to.y + to.height / 2;
    const middle = (x1 + x2) / 2;
    addSegment(segments, x1, y1, middle, y1);
    addSegment(segments, middle, y1, middle, y2);
    addSegment(segments, middle, y2, x2, y2);
    return [{ ...edge, segments, marker: { x: x2, y: y2 } }];
  });
  const width = Math.max(300 * safeScale, ...nodes.map((node) => node.x + node.width + 30 * safeScale));
  const height = Math.max(180 * safeScale, ...nodes.map((node) => node.y + node.height + 30 * safeScale));
  return { nodes, edges, width, height };
}
