import type { PluginTheme } from "@getpaseo/plugin";
import { useMemo, useState } from "react";
import { Pressable, Text, View } from "react-native";
import type { SnapshotReady } from "../shared/contracts";
import { Badge, Body, Button, Card, Empty, Mono, Note, SearchBox } from "./parts";
import type { GraphSelection } from "./graph";

export function CoverageView({ theme, compact, snapshot, onSelect, onOpenScope }: {
  theme: PluginTheme;
  compact: boolean;
  snapshot: SnapshotReady;
  onSelect: (selection: GraphSelection) => void;
  onOpenScope: () => void;
}) {
  const [query, setQuery] = useState("");
  const uncovered = useMemo(() => {
    const groups = new Map<string, string[]>();
    for (const path of snapshot.map.uncovered) {
      if (!path.toLowerCase().includes(query.trim().toLowerCase())) continue;
      const parts = path.split("/");
      const group = parts.length > 1 ? parts.slice(0, -1).join("/") : "project root";
      const list = groups.get(group) ?? [];
      list.push(path);
      groups.set(group, list);
    }
    return [...groups.entries()].sort(([a], [b]) => a.localeCompare(b));
  }, [snapshot, query]);
  return (
    <View style={{ gap: 10 }}>
      <Card theme={theme} compact={compact} title="Goal scope" subtitle="Coverage is computed separately from the claims verdict">
        {snapshot.map.goal ? (
          <>
            <Body theme={theme}>{snapshot.map.goal.text}</Body>
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
              {snapshot.map.goal.scope.map((path) => <Badge key={path} theme={theme} label={path} icon="Folder" />)}
            </View>
          </>
        ) : <Empty theme={theme} title="No goal scope" detail="Without a declared goal, the map cannot define its coverage boundary." icon="ScanSearch" />}
        <Note theme={theme} tone={snapshot.map.uncovered.length ? "warn" : "neutral"}>
          {snapshot.map.uncovered.length} path(s) are uncovered. No percentage is shown because this map does not expose a canonical total file count.
        </Note>
        <Button theme={theme} compact label="Open scope graph" icon="Workflow" onPress={onOpenScope} />
      </Card>
      <Card theme={theme} compact={compact} title="Uncovered paths" subtitle="Paths inside goal scope that no active claim includes">
        <SearchBox theme={theme} value={query} onChange={setQuery} placeholder="Filter uncovered paths" />
        {uncovered.length === 0 ? <Empty theme={theme} title={snapshot.map.uncovered.length === 0 ? "No uncovered paths" : "No matching paths"} detail={snapshot.map.uncovered.length === 0 ? "The declared file scope is covered. This does not prove semantic completeness." : "Clear the filter to see all uncovered paths."} icon="ScanSearch" /> : (
          <View style={{ gap: 10 }}>
            {uncovered.map(([group, paths]) => (
              <View key={group} style={{ gap: 4 }}>
                <Text style={{ color: theme.colors.foreground, fontSize: 12, fontWeight: "700" }}>{group} · {paths.length}</Text>
                {paths.map((path) => <Mono key={path} theme={theme}>{path}</Mono>)}
              </View>
            ))}
          </View>
        )}
      </Card>
      <Card theme={theme} compact={compact} title="Declared claim scopes" subtitle="Select a claim to inspect its definition and evidence">
        <View style={{ gap: 8 }}>
          {snapshot.claims.map((claim) => (
            <Pressable key={claim.id} accessibilityRole="button" accessibilityLabel={`Open scope claim ${claim.id}`} onPress={() => onSelect({ claimId: claim.id })} style={{ padding: 9, borderRadius: 8, backgroundColor: theme.colors.surface2, gap: 5 }}>
              <Text style={{ color: theme.colors.foreground, fontSize: 12, fontWeight: "600" }}>{claim.id}</Text>
              <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 4 }}>
                {claim.scope.map((path) => <Badge key={path} theme={theme} label={path} />)}
              </View>
            </Pressable>
          ))}
        </View>
      </Card>
    </View>
  );
}
