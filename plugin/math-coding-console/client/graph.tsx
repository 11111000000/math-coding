import { useMemo, useState } from "react";
import { Pressable, ScrollView, Text, View } from "react-native";
import type { ClaimState } from "../shared/domain";
import type { SnapshotReady } from "../shared/schemas";
import type { ConsoleTheme } from "../shared/theme";
import {
  buildProofGraph,
  buildScopeGraph,
  layoutGraph,
  type GraphNode,
  type PositionedNode,
} from "./graph-layout";
import { useHost } from "./host/context";
import { renderValue, useT } from "./i18n";
import { Badge, Button, Card, Empty, Note, SearchBox } from "./parts";
import { claimStateColor, claimStateIcon, claimStateKey } from "./vocabulary";

export interface GraphSelection {
  claimId: string;
  requirementPath?: string;
}

function nodeColor(theme: ConsoleTheme, node: GraphNode): string {
  if (node.state) return claimStateColor(theme, node.state);
  if (node.kind === "goal" || node.kind === "source") return theme.colors.accent;
  if (node.kind === "uncovered") return theme.colors.statusWarning;
  return theme.colors.border;
}

/**
 * The icon of a node.
 *
 * The icon follows the kind of the node as a value of the domain, so a
 * translated word never decides what a node looks like.
 */
function nodeIcon(node: GraphNode): string {
  if (node.state) return claimStateIcon(node.state);
  switch (node.kind) {
    case "goal": return "Target";
    case "source": return "FileText";
    case "requirement": return node.requirementKind === "all" ? "ListTree" : node.requirementKind === "any" ? "GitFork" : "CheckCheck";
    case "scope": return "Folder";
    case "uncovered": return "FileQuestion";
    case "claim": return "Box";
  }
}

/** The name of the kind of a node, in the language of the interface. */
const KIND_KEYS = {
  goal: "graph.kind_goal",
  source: "graph.kind_source",
  claim: "graph.kind_claim",
  requirement: "graph.kind_requirement",
  scope: "graph.kind_scope",
  uncovered: "graph.kind_uncovered",
} as const;

function NodeView({ theme, node, selected, faded, onSelect }: {
  theme: ConsoleTheme;
  node: PositionedNode;
  selected: boolean;
  faded: boolean;
  onSelect: () => void;
}) {
  const { Icon } = useHost();
  const t = useT();
  const color = nodeColor(theme, node);
  const state: ClaimState | undefined = node.state;
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={`${t(KIND_KEYS[node.kind])} ${renderValue(t, node.title)}${state ? `, ${t(claimStateKey(state))}` : ""}`}
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
          {t(KIND_KEYS[node.kind])}{node.requirementPath ? ` ${node.requirementPath}` : ""}
        </Text>
        {node.sourceChanged && <Icon name="FileClock" size={12} color={theme.colors.statusWarning} />}
      </View>
      <Text numberOfLines={1} style={{ color: theme.colors.foreground, fontSize: Math.max(10, node.height * 0.14), fontWeight: "600" }}>{renderValue(t, node.title)}</Text>
      <Text numberOfLines={2} style={{ color: theme.colors.foregroundMuted, fontSize: Math.max(8, node.height * 0.105), lineHeight: Math.max(11, node.height * 0.14) }}>{renderValue(t, node.subtitle)}</Text>
    </Pressable>
  );
}

export function GraphView({ theme, compact, snapshot, mode, expanded, onToggleClaim, selected, onSelect, onClose }: {
  theme: ConsoleTheme;
  compact: boolean;
  snapshot: SnapshotReady;
  mode: "proof" | "scope";
  expanded: ReadonlySet<string>;
  onToggleClaim: (claimId: string) => void;
  selected: GraphSelection | null;
  onSelect: (selection: GraphSelection | null) => void;
  onClose?: () => void;
}) {
  const [query, setQuery] = useState("");
  const [scale, setScale] = useState(compact ? 0.85 : 1);
  const [viewportWidth, setViewportWidth] = useState(0);
  const t = useT();
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
        <View style={{ flex: 1 }}><SearchBox theme={theme} value={query} onChange={setQuery} placeholder={t("graph.search_placeholder")} /></View>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
          {onClose && <Button theme={theme} compact label={t("graph.back_to_lists")} icon="ArrowLeft" onPress={onClose} />}
          <Button theme={theme} compact label={t("graph.expand")} icon="UnfoldVertical" onPress={() => snapshot.claims.forEach((claim) => { if (!expanded.has(claim.id)) onToggleClaim(claim.id); })} />
          <Button theme={theme} compact label={t("graph.collapse")} icon="FoldVertical" onPress={() => [...expanded].forEach(onToggleClaim)} />
        </View>
      </View>
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6, alignItems: "center", justifyContent: "space-between" }}>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
          <Badge theme={theme} label={t("graph.nodes_count", { count: model.nodes.length })} icon="Workflow" />
          <Badge theme={theme} label={t("graph.links_count", { count: model.edges.length })} />
          {model.truncated > 0 && <Badge theme={theme} label={t("graph.hidden_count", { count: model.truncated })} tone="warn" />}
        </View>
        <View style={{ flexDirection: "row", gap: 4 }}>
          <Button theme={theme} compact label="−" onPress={() => setScale((value) => Math.max(0.65, value - 0.15))} />
          <Button theme={theme} compact label={`${Math.round(scale * 100)}%`} onPress={() => setScale(1)} />
          <Button theme={theme} compact label="+" onPress={() => setScale((value) => Math.min(1.4, value + 0.15))} />
          <Button theme={theme} compact label={t("graph.fit")} icon="Maximize2" onPress={fit} />
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
      {model.truncated > 0 && <Note theme={theme} tone="warn">{t("graph.bounded_note")}</Note>}
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 10 }}>
        <Text style={{ color: theme.colors.foregroundMuted, fontSize: 10 }}>{t("graph.select_hint")}</Text>
        <Text style={{ color: theme.colors.foregroundMuted, fontSize: 10 }}>{mode === "scope" ? t("graph.scope_links_note") : t("graph.links_note")}</Text>
      </View>
      {snapshot.map.claims === 0 && <Empty theme={theme} title={t("graph.vacant_title")} detail={t("graph.vacant_detail")} icon="CircleDashed" />}
    </Card>
  );
}
