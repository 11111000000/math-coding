import type { ConsoleTheme } from "../shared/theme";
import { useMemo, useState } from "react";
import { Pressable, Text, View } from "react-native";
import type { SnapshotReady } from "../shared/schemas";
import { CLAIM_STATES, type Claim, type ClaimState } from "../shared/domain";
import { Badge, Body, Card, Empty, FilterRow, Mono, SearchBox, Select } from "./parts";
import type { GraphSelection } from "./graph";
import { useT } from "./i18n";
import { claimStateColor, claimStateIcon, claimStateKey, stateOrder } from "./vocabulary";

function unique(values: string[]): string[] {
  return [...new Set(values)].sort((a, b) => a.localeCompare(b));
}

export function ClaimsView({ theme, compact, snapshot, onSelect }: {
  theme: ConsoleTheme;
  compact: boolean;
  snapshot: SnapshotReady;
  onSelect: (selection: GraphSelection) => void;
}) {
  const t = useT();
  const [query, setQuery] = useState("");
  const [state, setState] = useState("all");
  const [register, setRegister] = useState("all");
  const [owner, setOwner] = useState("all");
  const [source, setSource] = useState("all");
  const states = useMemo(() => new Map(snapshot.map.states.map((item) => [item.id, item])), [snapshot]);
  const claims = useMemo(() => {
    const normalized = query.trim().toLowerCase();
    return snapshot.claims.filter((claim) => {
      const haystack = `${claim.id} ${claim.text} ${claim.owner ?? ""} ${claim.source?.path ?? ""} ${claim.scope.join(" ")}`.toLowerCase();
      return (normalized === "" || haystack.includes(normalized)) &&
        (state === "all" || states.get(claim.id)?.state === state) &&
        (register === "all" || claim.register === register) &&
        (owner === "all" || (claim.owner ?? "no owner") === owner) &&
        (source === "all" || (claim.source?.path ?? "no source") === source);
    }).sort((a, b) => {
      const aState = states.get(a.id)?.state ?? "never-checked";
      const bState = states.get(b.id)?.state ?? "never-checked";
      return stateOrder(aState) - stateOrder(bState) || a.id.localeCompare(b.id);
    });
  }, [snapshot, query, state, register, owner, source, states]);
  const reset = () => {
    setQuery("");
    setState("all");
    setRegister("all");
    setOwner("all");
    setSource("all");
  };
  const all = t("claims.filter_all");
  const stateLabels: Record<string, string> = {
    all: t("claims.state_filter_all"),
    ...Object.fromEntries(CLAIM_STATES.map((item) => [item, t(claimStateKey(item))])),
  };
  const ownerLabels: Record<string, string> = {
    all,
    "no owner": t("state.no_owner"),
  };
  const sourceLabels: Record<string, string> = {
    all,
    "no source": t("state.no_source"),
  };
  return (
    <View style={{ gap: 10 }}>
      <Card
        theme={theme}
        compact={compact}
        title={t("claims.title")}
        subtitle={t("claims.subtitle", { visible: claims.length, total: snapshot.claims.length })}
      >
        <SearchBox theme={theme} value={query} onChange={setQuery} placeholder={t("claims.search_placeholder")} />
        <FilterRow>
          <Select theme={theme} label={t("claims.filter_state")} value={state} options={["all", ...CLAIM_STATES]} optionLabels={stateLabels} onChange={setState} />
          <Select theme={theme} label={t("claims.filter_register")} value={register} options={["all", ...unique(snapshot.claims.map((claim) => claim.register))]} optionLabels={{ all }} onChange={setRegister} />
          <Select theme={theme} label={t("claims.filter_owner")} value={owner} options={["all", ...unique(snapshot.claims.map((claim) => claim.owner ?? "no owner"))]} optionLabels={ownerLabels} onChange={setOwner} />
          <Select theme={theme} label={t("claims.filter_source")} value={source} options={["all", ...unique(snapshot.claims.map((claim) => claim.source?.path ?? "no source"))]} optionLabels={sourceLabels} onChange={setSource} />
          <Pressable accessibilityRole="button" accessibilityLabel={t("claims.reset_filters")} onPress={reset} style={{ padding: 8 }}><Text style={{ color: theme.colors.accent, fontSize: 11 }}>{t("common.reset")}</Text></Pressable>
        </FilterRow>
        {claims.length > 0 && (
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 3, paddingVertical: 5 }}>
            {claims.map((claim) => {
              const claimState = states.get(claim.id)?.state ?? "never-checked";
              return (
                <Pressable
                  key={claim.id}
                  accessibilityRole="button"
                  accessibilityLabel={`${claim.id}: ${t(claimStateKey(claimState))}`}
                  onPress={() => onSelect({ claimId: claim.id })}
                  style={{ width: 15, height: 15, borderRadius: 3, backgroundColor: claimStateColor(theme, claimState), borderWidth: claim.waiver ? 2 : 0, borderColor: theme.colors.statusWarning }}
                />
              );
            })}
          </View>
        )}
      </Card>
      {claims.length === 0 ? (
        <Card theme={theme} compact={compact}><Empty theme={theme} title={t("claims.empty_title")} detail={t("claims.empty_detail")} icon="SearchX" /></Card>
      ) : (
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 10 }}>
          {claims.map((claim) => (
            <ClaimCard key={claim.id} theme={theme} compact={compact} claim={claim} state={states.get(claim.id)?.state} sourceChanged={states.get(claim.id)?.source_changed ?? false} onSelect={() => onSelect({ claimId: claim.id })} />
          ))}
        </View>
      )}
    </View>
  );
}

function ClaimCard({ theme, compact, claim, state, sourceChanged, onSelect }: {
  theme: ConsoleTheme;
  compact: boolean;
  claim: Claim;
  state?: ClaimState;
  sourceChanged: boolean;
  onSelect: () => void;
}) {
  const t = useT();
  return (
    <Pressable accessibilityRole="button" accessibilityLabel={t("claims.open_claim", { claim: claim.id })} onPress={onSelect} style={{ width: compact ? "100%" : "48.5%", flexGrow: 1 }}>
      <View style={{
        minHeight: 180,
        borderRadius: 11,
        borderWidth: 1,
        borderColor: state ? claimStateColor(theme, state) : theme.colors.border,
        backgroundColor: theme.colors.surface1,
        padding: compact ? 12 : 15,
        gap: 9,
      }}>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5, alignItems: "center" }}>
          {state && <Badge theme={theme} label={t(claimStateKey(state))} color={claimStateColor(theme, state)} icon={claimStateIcon(state)} />}
          <Badge theme={theme} label={claim.register} />
          {sourceChanged && <Badge theme={theme} label={t("state.source_changed")} tone="warn" icon="FileClock" />}
        </View>
        <Text style={{ color: theme.colors.foreground, fontSize: 15, fontWeight: "700" }}>{claim.id}</Text>
        <Body theme={theme}>{claim.text}</Body>
        <View style={{ flex: 1 }} />
        <Mono theme={theme} lines={2}>{claim.source ? `${claim.source.kind}: ${claim.source.path}` : t("state.no_linked_source")}</Mono>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
          <Badge theme={theme} label={t("claims.scope_paths", { count: claim.scope.length })} />
          {claim.waiver && <Badge theme={theme} label={t("state.waiver_recorded")} tone="warn" icon="ShieldAlert" />}
        </View>
      </View>
    </Pressable>
  );
}
