import type { PluginTheme } from "@getpaseo/plugin";
import { Text, View } from "react-native";
import type { Claim, ClaimState } from "../shared/domain";
import { flattenRequirements } from "../shared/requirements";
import { Badge, Body, Card, Mono } from "./parts";

export function DecisionBoundary({ theme, compact, claim, state, sourceChanged }: {
  theme: PluginTheme;
  compact: boolean;
  claim: Claim;
  state?: ClaimState;
  sourceChanged: boolean;
}) {
  const requirements = flattenRequirements(claim).map((node) => node.requirement);
  const verifiers = requirements.filter((requirement) => "kind" in requirement && requirement.kind === "verifier");
  const reviews = requirements.filter((requirement) => "kind" in requirement && requirement.kind === "review");
  const agentMay = sourceChanged
    ? "Collect the source diff and prepare the changed decision context for the owner."
    : state === "refuted"
      ? "Reproduce the failure and propose a repair that preserves the declared falsifier and control."
      : state === "not-checkable"
        ? "Propose machine checks and explain their sensitivity; the owner still chooses the acceptance criterion."
        : "Implement the declared subject and run the declared checks without changing the intended contract.";
  return (
    <Card theme={theme} compact={compact} title="Decision boundary" subtitle="What the machine can establish and what remains with the human">
      <View style={{ gap: 8 }}>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
          <Badge theme={theme} label={claim.register} />
          {state && <Badge theme={theme} label={`claim: ${state}`} />}
          {claim.kind === "judgment" && <Badge theme={theme} label="human judgment" tone="warn" icon="UserRoundCheck" />}
        </View>
        <BoundaryRow theme={theme} label="Machine checks">
          {verifiers.length === 0
            ? <Body theme={theme} muted>No machine verifier is declared for this claim.</Body>
            : verifiers.map((requirement, index) => <Mono key={index} theme={theme}>{requirement.kind === "verifier" ? requirement.spec : ""}</Mono>)}
        </BoundaryRow>
        <BoundaryRow theme={theme} label="Human review">
          {reviews.length === 0
            ? <Body theme={theme} muted>No explicit human-review requirement is declared.</Body>
            : reviews.map((requirement, index) => (
              <Mono key={index} theme={theme}>
                {requirement.kind === "review" ? `${requirement.spec} · ${requirement.minimum_independence}` : ""}
              </Mono>
            ))}
        </BoundaryRow>
        {claim.waiver && (
          <BoundaryRow theme={theme} label={state === "waived" ? "Accepted risk" : "Waiver record"}>
            <Body theme={theme} muted>{claim.waiver.gap}</Body>
            <Mono theme={theme}>issuer: {claim.waiver.issuer}</Mono>
            <Mono theme={theme}>interval: {new Date(claim.waiver.issued_at * 1000).toISOString()} → {new Date(claim.waiver.expires_at * 1000).toISOString()}</Mono>
            <Mono theme={theme}>recovery: {claim.waiver.recovery}</Mono>
          </BoundaryRow>
        )}
        <BoundaryRow theme={theme} label="Agent may">{agentMay}</BoundaryRow>
        <BoundaryRow theme={theme} label="Agent must not">
          Do not impersonate a reviewer, record a human review or waiver, weaken a verifier/control, or change the claim merely to obtain green.
        </BoundaryRow>
      </View>
    </Card>
  );
}

function BoundaryRow({ theme, label, children }: {
  theme: PluginTheme;
  label: string;
  children: React.ReactNode;
}) {
  return (
    <View style={{ gap: 3 }}>
      <Text style={{ color: theme.colors.foregroundMuted, fontSize: 10, fontWeight: "700", textTransform: "uppercase" }}>{label}</Text>
      {typeof children === "string" ? <Body theme={theme} muted>{children}</Body> : children}
    </View>
  );
}
