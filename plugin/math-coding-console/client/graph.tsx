import type { PluginTheme } from "@getpaseo/plugin";
import { Icon } from "@getpaseo/plugin/client/ui";
import { useMemo, useState } from "react";
import { Pressable, ScrollView, Text, View } from "react-native";
import type { SnapshotReady } from "../shared/contracts";
import type { ClaimState } from "../shared/domain";
import {
  buildProofGraph,
  buildScopeGraph,
  layoutGraph,
  type GraphNode,
  type PositionedNode,
} from "./graph-layout";
import { Badge, Button, Card, Empty, Note, SearchBox } from "./parts";
import { claimStateColor, claimStateIcon } from "./vocabulary";

export interface GraphSelection {
  claimId: string;
  requirementPath?: string;
}

function nodeColor(theme: PluginTheme, node: GraphNode): string {
  if (node.state) return claimStateColor(theme, node.state);
  if (node.kind === "goal" || node.kind === "source") return theme.colors.accent;
  if (node.kind === "uncovered") return theme.colors.statusWarning;
  return theme.colors.border;
}

function nodeIcon(node: GraphNode): string {
  if (node.state) return claimStateIcon(node.state);
  switch (node.kind) {
    case "goal": return "Target";
    case "source": return "FileText";
    case "requirement": return node.title.startsWith("all") ? "ListTree" : node.title.startsWith("any") ? "GitFork" : "CheckCheck";
    case "scope": return "Folder";
    case "uncovered": return "FileQuestion";
    case "claim": return "Box";
  }
}

function NodeView({ theme, node, selected, faded, onSelect }: {
  theme: PluginTheme;
  node: PositionedNode;
  selected: boolean;
  faded: boolean;
  onSelect: () => void;
}) {
  const color = nodeColor(theme, node);
  const state: ClaimState | undefined = node.state;
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={`${node.kind} ${node.title}${state ? `, ${state}` : ""}`}
      accessibilityState={{ selected }}
      onPress={onSelect}
      style={{
        position: "absolute",
        left: node.x,
        top: node.y,
        width: node.width,
        height: node.height,
        borderRadius: 10,
        borderWidth: selected ? 2 : 1,
        borderColor: selected ? theme.colors.accent : color,
        backgroundColor: theme.colors.surface1,
        padding: Math.max(7, 11 * (node.height / 92)),
        gap: 4,
        opacity: faded ? 0.35 : 1,
        overflow: "hidden",
      }}
    >
      <View style={{ flexDirection: "row", alignItems: "center", gap: 5 }}>
        <Icon name={nodeIcon(node)} size={Math.max(11, node.height * 0.15)} color={color} />
        <Text numberOfLines={1} style={{ color: theme.colors.foregroundMuted, fontSize: Math.max(8, node.height * 0.1), fontWeight: "700", textTransform: "uppercase", flex: 1 }}>
          {node.kind}{node.requirementPath ? ` ${node.requirementPath}` : ""}
        </Text>
        {node.sourceChanged && <Icon name="FileClock" size={12} color={theme.colors.statusWarning} />}
      </View>
      <Text numberOfLines={1} style={{ color: theme.colors.foreground, fontSize: Math.max(10, node.height * 0.14), fontWeight: "600" }}>{node.title}</Text>
      <Text numberOfLines={2} style={{ color: theme.colors.foregroundMuted, fontSize: Math.max(8, node.height * 0.105), lineHeight: Math.max(11, node.height * 0.14) }}>{node.subtitle}</Text>
    </Pressable>
  );
}

export function GraphView({ theme, compact, snapshot, mode, expanded, onToggleClaim, selected, onSelect }: {
  theme: PluginTheme;
  compact: boolean;
  snapshot: SnapshotReady;
  mode: "proof" | "scope";
  expanded: ReadonlySet<string>;
  onToggleClaim: (claimId: string) => void;
  selected: GraphSelection | null;
  onSelect: (selection: GraphSelection | null) => void;
}) {
  const [query, setQuery] = useState("");
  const [scale, setScale] = useState(compact ? 0.85 : 1);
  const [viewportWidth, setViewportWidth] = useState(0);
  const model = useMemo(
    () => mode === "proof" ? buildProofGraph(snapshot, expanded, query) : buildScopeGraph(snapshot, query),
    [snapshot, mode, expanded, query],
  );
  const graph = useMemo(() => layoutGraph(model, compact, scale), [model, compact, scale]);
  const fit = () => {
    const natural = layoutGraph(model, compact, 1);
    setScale(Math.max(0.65, Math.min(1, (viewportWidth - 20) / natural.width)));
  };
  const selectNode = (node: GraphNode) => {
    if (!node.claimId) {
      onSelect(null);
      return;
    }
    onSelect({ claimId: node.claimId, requirementPath: node.requirementPath });
    if (mode === "proof" && node.kind === "claim") onToggleClaim(node.claimId);
  };
  return (
    <Card theme={theme} compact={compact}>
      <View style={{ flexDirection: compact ? "column" : "row", gap: 8, alignItems: compact ? "stretch" : "center" }}>
        <View style={{ flex: 1 }}><SearchBox theme={theme} value={query} onChange={setQuery} placeholder="Filter the visible graph" /></View>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
          <Button theme={theme} compact label="Expand" icon="UnfoldVertical" onPress={() => snapshot.claims.forEach((claim) => { if (!expanded.has(claim.id)) onToggleClaim(claim.id); })} />
          <Button theme={theme} compact label="Collapse" icon="FoldVertical" onPress={() => [...expanded].forEach(onToggleClaim)} />
        </View>
      </View>
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6, alignItems: "center", justifyContent: "space-between" }}>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
          <Badge theme={theme} label={`${model.nodes.length} nodes`} icon="Workflow" />
          <Badge theme={theme} label={`${model.edges.length} declared links`} />
          {model.truncated > 0 && <Badge theme={theme} label={`${model.truncated} hidden`} tone="warn" />}
        </View>
        <View style={{ flexDirection: "row", gap: 4 }}>
          <Button theme={theme} compact label="−" onPress={() => setScale((value) => Math.max(0.65, value - 0.15))} />
          <Button theme={theme} compact label={`${Math.round(scale * 100)}%`} onPress={() => setScale(1)} />
          <Button theme={theme} compact label="+" onPress={() => setScale((value) => Math.min(1.4, value + 0.15))} />
          <Button theme={theme} compact label="Fit" icon="Maximize2" onPress={fit} />
        </View>
      </View>
      <View
        onLayout={(event) => setViewportWidth(event.nativeEvent.layout.width)}
        style={{ height: compact ? 450 : 560, borderWidth: 1, borderColor: theme.colors.border, borderRadius: 10, backgroundColor: theme.colors.surface0, overflow: "hidden" }}
      >
        <ScrollView horizontal showsHorizontalScrollIndicator>
          <ScrollView showsVerticalScrollIndicator nestedScrollEnabled>
            <Pressable onPress={() => onSelect(null)} style={{ width: graph.width, height: graph.height }} accessible={false}>
              <View style={{ width: graph.width, height: graph.height }}>
                {graph.edges.map((edge) => {
                  const active = !selected || edge.claimId === selected.claimId;
                  const color = edge.kind === "uncovered" ? theme.colors.statusWarning
                    : edge.kind === "shared-scope" ? theme.colors.accent : theme.colors.foregroundMuted;
                  return (
                    <View key={edge.id} pointerEvents="none">
                      {edge.segments.map((segment, index) => (
                        <View key={index} style={{
                          position: "absolute",
                          left: segment.x,
                          top: segment.y,
                          width: segment.width,
                          height: segment.height,
                          backgroundColor: color,
                          opacity: active ? 0.62 : 0.12,
                        }} />
                      ))}
                      <View style={{
                        position: "absolute",
                        left: edge.marker.x - 3,
                        top: edge.marker.y - 3,
                        width: 6,
                        height: 6,
                        backgroundColor: color,
                        opacity: active ? 0.9 : 0.15,
                        transform: [{ rotate: "45deg" }],
                      }} />
                    </View>
                  );
                })}
                {graph.nodes.map((node) => {
                  const isSelected = selected !== null && selected.claimId === node.claimId &&
                    (selected.requirementPath === undefined ? node.kind === "claim" : node.requirementPath === selected.requirementPath);
                  const faded = Boolean(selected && node.claimId && node.claimId !== selected.claimId);
                  return <NodeView key={node.id} theme={theme} node={node} selected={isSelected} faded={faded} onSelect={() => selectNode(node)} />;
                })}
              </View>
            </Pressable>
          </ScrollView>
        </ScrollView>
      </View>
      {model.truncated > 0 && <Note theme={theme} tone="warn">The graph is bounded for readability. Narrow the filter or open Claims to reach hidden items.</Note>}
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 10 }}>
        <Text style={{ color: theme.colors.foregroundMuted, fontSize: 10 }}>Select a claim to inspect evidence and reveal its requirement tree.</Text>
        <Text style={{ color: theme.colors.foregroundMuted, fontSize: 10 }}>{mode === "scope" ? "Scope links show declarations, not dependencies." : "Only source, claim and requirement links present in v5 are drawn."}</Text>
      </View>
      {snapshot.map.claims === 0 && <Empty theme={theme} title="Vacant map" detail="The canonical map has no claims. Add one to three important claims before expanding the graph." icon="CircleDashed" />}
    </Card>
  );
}
