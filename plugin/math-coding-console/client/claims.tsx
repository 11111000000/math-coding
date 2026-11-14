import type { PluginTheme } from "@getpaseo/plugin";
import { useMemo, useState } from "react";
import { Pressable, Text, View } from "react-native";
import type { SnapshotReady } from "../shared/contracts";
import { CLAIM_STATES, type Claim, type ClaimState } from "../shared/domain";
import { Badge, Body, Card, Empty, FilterRow, Mono, SearchBox, Select } from "./parts";
import type { GraphSelection } from "./graph";
import { claimStateColor, claimStateIcon, stateOrder } from "./vocabulary";

function unique(values: string[]): string[] {
  return [...new Set(values)].sort((a, b) => a.localeCompare(b));
}

export function ClaimsView({ theme, compact, snapshot, onSelect }: {
  theme: PluginTheme;
  compact: boolean;
  snapshot: SnapshotReady;
  onSelect: (selection: GraphSelection) => void;
}) {
  const [query, setQuery] = useState("");
  const [state, setState] = useState("all");
  const [register, setRegister] = useState("all");
  const [kind, setKind] = useState("all");
  const [phase, setPhase] = useState("all");
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
        (kind === "all" || claim.kind === kind) &&
        (phase === "all" || claim.phase === phase) &&
        (owner === "all" || (claim.owner ?? "no owner") === owner) &&
        (source === "all" || (claim.source?.path ?? "no source") === source);
    }).sort((a, b) => {
      const aState = states.get(a.id)?.state ?? "not-checkable";
      const bState = states.get(b.id)?.state ?? "not-checkable";
      return stateOrder(aState) - stateOrder(bState) || a.id.localeCompare(b.id);
    });
  }, [snapshot, query, state, register, kind, phase, owner, source, states]);
  const reset = () => {
    setQuery("");
    setState("all");
    setRegister("all");
    setKind("all");
    setPhase("all");
    setOwner("all");
    setSource("all");
  };
  return (
    <View style={{ gap: 10 }}>
      <Card theme={theme} compact={compact} title="Claims" subtitle={`${claims.length} of ${snapshot.claims.length} visible · canonical states from map`}>
        <SearchBox theme={theme} value={query} onChange={setQuery} placeholder="Search ID, text, owner, source or scope" />
        <FilterRow>
          <Select theme={theme} label="state" value={state} options={["all", ...CLAIM_STATES]} onChange={setState} />
          <Select theme={theme} label="register" value={register} options={["all", ...unique(snapshot.claims.map((claim) => claim.register))]} onChange={setRegister} />
          <Select theme={theme} label="kind" value={kind} options={["all", ...unique(snapshot.claims.map((claim) => claim.kind))]} onChange={setKind} />
          <Select theme={theme} label="phase" value={phase} options={["all", ...unique(snapshot.claims.map((claim) => claim.phase))]} onChange={setPhase} />
          <Select theme={theme} label="owner" value={owner} options={["all", ...unique(snapshot.claims.map((claim) => claim.owner ?? "no owner"))]} onChange={setOwner} />
          <Select theme={theme} label="source" value={source} options={["all", ...unique(snapshot.claims.map((claim) => claim.source?.path ?? "no source"))]} onChange={setSource} />
          <Pressable accessibilityRole="button" accessibilityLabel="Reset claim filters" onPress={reset} style={{ padding: 8 }}><Text style={{ color: theme.colors.accent, fontSize: 11 }}>Reset</Text></Pressable>
        </FilterRow>
        {claims.length > 0 && (
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 3, paddingVertical: 5 }}>
            {claims.map((claim) => {
              const claimState = states.get(claim.id)?.state ?? "not-checkable";
              return (
                <Pressable
                  key={claim.id}
                  accessibilityRole="button"
                  accessibilityLabel={`${claim.id}: ${claimState}`}
                  onPress={() => onSelect({ claimId: claim.id })}
                  style={{ width: 15, height: 15, borderRadius: 3, backgroundColor: claimStateColor(theme, claimState), borderWidth: claim.waiver ? 2 : 0, borderColor: theme.colors.statusWarning }}
                />
              );
            })}
          </View>
        )}
      </Card>
      {claims.length === 0 ? (
        <Card theme={theme} compact={compact}><Empty theme={theme} title="No matching claims" detail="Reset the filters or widen the search." icon="SearchX" /></Card>
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
  theme: PluginTheme;
  compact: boolean;
  claim: Claim;
  state?: ClaimState;
  sourceChanged: boolean;
  onSelect: () => void;
}) {
  return (
    <Pressable accessibilityRole="button" accessibilityLabel={`Open claim ${claim.id}`} onPress={onSelect} style={{ width: compact ? "100%" : "48.5%", flexGrow: 1 }}>
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
          {state && <Badge theme={theme} label={state} color={claimStateColor(theme, state)} icon={claimStateIcon(state)} />}
          <Badge theme={theme} label={claim.register} />
          <Badge theme={theme} label={claim.kind} />
          {sourceChanged && <Badge theme={theme} label="source changed" tone="warn" icon="FileClock" />}
        </View>
        <Text style={{ color: theme.colors.foreground, fontSize: 15, fontWeight: "700" }}>{claim.id}</Text>
        <Body theme={theme}>{claim.text}</Body>
        <View style={{ flex: 1 }} />
        <Mono theme={theme} lines={2}>{claim.source ? `${claim.source.kind}: ${claim.source.path}` : "no linked source"}</Mono>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
          <Badge theme={theme} label={claim.phase} />
          <Badge theme={theme} label={`${claim.scope.length} scope path(s)`} />
          {claim.waiver && <Badge theme={theme} label="waiver recorded" tone="warn" icon="ShieldAlert" />}
        </View>
      </View>
    </Pressable>
  );
}
