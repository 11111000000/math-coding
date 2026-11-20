import type { ConsoleTheme } from "../shared/theme";
import { useMemo, useState } from "react";
import { Pressable, Text, View } from "react-native";
import type { SnapshotReady } from "../shared/schemas";
import { Badge, Body, Button, Card, Empty, Mono, Note, SearchBox } from "./parts";
import type { GraphSelection } from "./graph";
import { useT } from "./i18n";

export function CoverageView({ theme, compact, snapshot, onSelect, onOpenScope }: {
  theme: ConsoleTheme;
  compact: boolean;
  snapshot: SnapshotReady;
  onSelect: (selection: GraphSelection) => void;
  onOpenScope: () => void;
}) {
  const t = useT();
  const [query, setQuery] = useState("");
  const uncovered = useMemo(() => {
    const groups = new Map<string, string[]>();
    for (const path of snapshot.map.uncovered) {
      if (!path.toLowerCase().includes(query.trim().toLowerCase())) continue;
      const parts = path.split("/");
      const group = parts.length > 1 ? parts.slice(0, -1).join("/") : t("scope.project_root");
      const list = groups.get(group) ?? [];
      list.push(path);
      groups.set(group, list);
    }
    return [...groups.entries()].sort(([a], [b]) => a.localeCompare(b));
  }, [snapshot, query, t]);
  return (
    <View style={{ gap: 10 }}>
      <Card theme={theme} compact={compact} title={t("scope.goal_title")} subtitle={t("scope.goal_subtitle")}>
        {snapshot.map.goal ? (
          <>
            <Body theme={theme}>{snapshot.map.goal.text}</Body>
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
              {snapshot.map.goal.scope.map((path) => <Badge key={path} theme={theme} label={path} icon="Folder" />)}
            </View>
          </>
        ) : <Empty theme={theme} title={t("scope.goal_empty_title")} detail={t("scope.goal_empty_detail")} icon="ScanSearch" />}
        <Note theme={theme} tone={snapshot.map.uncovered.length ? "warn" : "neutral"}>
          {t("scope.uncovered_note", { count: snapshot.map.uncovered.length })}
        </Note>
        <Button theme={theme} compact label={t("scope.open_scope_graph")} icon="Workflow" onPress={onOpenScope} />
      </Card>
      <Card theme={theme} compact={compact} title={t("scope.uncovered_title")} subtitle={t("scope.uncovered_subtitle")}>
        <SearchBox theme={theme} value={query} onChange={setQuery} placeholder={t("scope.uncovered_placeholder")} />
        {uncovered.length === 0 ? <Empty theme={theme} title={snapshot.map.uncovered.length === 0 ? t("scope.empty_title") : t("scope.no_match_title")} detail={snapshot.map.uncovered.length === 0 ? t("scope.empty_detail") : t("scope.clear_filter")} icon="ScanSearch" /> : (
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
      <Card theme={theme} compact={compact} title={t("scope.declared_title")} subtitle={t("scope.declared_subtitle")}>
        <View style={{ gap: 8 }}>
          {snapshot.claims.map((claim) => (
            <Pressable key={claim.id} accessibilityRole="button" accessibilityLabel={t("scope.open_scope_claim", { claim: claim.id })} onPress={() => onSelect({ claimId: claim.id })} style={{ padding: 9, borderRadius: 8, backgroundColor: theme.colors.surface2, gap: 5 }}>
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
