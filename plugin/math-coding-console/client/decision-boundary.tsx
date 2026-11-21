import type { ConsoleTheme } from "../shared/theme";
import { Text, View } from "react-native";
import type { Claim, ClaimState } from "../shared/domain";
import { flattenRequirements } from "../shared/requirements";
import { useT } from "./i18n";
import { Badge, Body, Card, Mono } from "./parts";
import { claimStateKey } from "./vocabulary";

export function DecisionBoundary({ theme, compact, claim, state, sourceChanged }: {
  theme: ConsoleTheme;
  compact: boolean;
  claim: Claim;
  state?: ClaimState;
  sourceChanged: boolean;
}) {
  const t = useT();
  const requirements = flattenRequirements(claim).map((node) => node.requirement);
  const verifiers = requirements.filter((requirement) => "kind" in requirement && requirement.kind === "verifier");
  const reviews = requirements.filter((requirement) => "kind" in requirement && requirement.kind === "review");
  const agentMay = sourceChanged
    ? t("boundary.agent_may_source_changed")
    : state === "refuted"
      ? t("boundary.agent_may_refuted")
      : state === "not-checkable"
        ? t("boundary.agent_may_not_checkable")
        : t("boundary.agent_may_default");
  return (
    <Card theme={theme} compact={compact} title={t("boundary.title")} subtitle={t("boundary.subtitle")}>
      <View style={{ gap: 8 }}>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5 }}>
          <Badge theme={theme} label={claim.register} />
          {state && <Badge theme={theme} label={t("boundary.claim_state", { state: t(claimStateKey(state)) })} />}
          {claim.kind === "judgment" && <Badge theme={theme} label={t("boundary.human_judgment")} tone="warn" icon="UserRoundCheck" />}
        </View>
        <BoundaryRow theme={theme} label={t("boundary.machine_checks")}>
          {verifiers.length === 0
            ? <Body theme={theme} muted>{t("boundary.no_machine_verifier")}</Body>
            : verifiers.map((requirement, index) => <Mono key={index} theme={theme}>{requirement.kind === "verifier" ? requirement.spec : ""}</Mono>)}
        </BoundaryRow>
        <BoundaryRow theme={theme} label={t("boundary.human_review")}>
          {reviews.length === 0
            ? <Body theme={theme} muted>{t("boundary.no_human_review")}</Body>
            : reviews.map((requirement, index) => (
              <Mono key={index} theme={theme}>
                {requirement.kind === "review" ? `${requirement.spec} · ${requirement.minimum_independence}` : ""}
              </Mono>
            ))}
        </BoundaryRow>
        {claim.waiver && (
          <BoundaryRow theme={theme} label={state === "waived" ? t("boundary.accepted_risk") : t("boundary.waiver_record")}>
            <Body theme={theme} muted>{claim.waiver.gap}</Body>
            <Mono theme={theme}>{t("attention.issuer_label")}: {claim.waiver.issuer}</Mono>
            <Mono theme={theme}>{t("boundary.interval")}: {new Date(claim.waiver.issued_at * 1000).toISOString()} → {new Date(claim.waiver.expires_at * 1000).toISOString()}</Mono>
            <Mono theme={theme}>{t("attention.recovery_label")}: {claim.waiver.recovery}</Mono>
          </BoundaryRow>
        )}
        <BoundaryRow theme={theme} label={t("boundary.agent_may")}>{agentMay}</BoundaryRow>
        <BoundaryRow theme={theme} label={t("boundary.agent_must_not")}>
          {t("boundary.agent_must_not_rule")}
        </BoundaryRow>
      </View>
    </Card>
  );
}

function BoundaryRow({ theme, label, children }: {
  theme: ConsoleTheme;
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
