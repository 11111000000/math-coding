import { View } from "react-native";
import type { ConsoleTheme } from "../shared/theme";
import type { RunScale } from "./run-scale";
import { useHost } from "./host/context";
import { Body, Button, Note } from "./parts";

/**
 * The confirmation of a run of the project checks.
 *
 * The body is a component of its own, so the checks can draw it without the
 * modal around it: the host draws a closed modal as nothing at all.
 */
export function RunConfirmation({ theme, scale, running, error, onCancel, onRun }: {
  theme: ConsoleTheme;
  scale: RunScale | undefined;
  running: boolean;
  error: unknown;
  onCancel: () => void;
  onRun: () => void;
}) {
  const { Modal } = useHost();
  return (
    <Modal.Content>
      <View style={{ gap: 14 }}>
        <Body theme={theme}>This executes the verifier and negative-control commands declared by the project and appends evidence to .math/v5/. Controls use isolated copies; verifiers still execute project code.</Body>
        <Body theme={theme} muted>Scale: {scale?.claimCount ?? 0} claim(s) and {scale?.commandCount ?? 0} check command(s) will run for this workspace.</Body>
        <Body theme={theme} muted>Refresh, graph navigation and automatic polling never perform this action. The server also requires Run checks to be enabled in plugin settings.</Body>
        {error !== null && error !== undefined && <Note theme={theme} tone="bad">Run failed: {String(error)}</Note>}
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8, justifyContent: "flex-end" }}>
          <Button theme={theme} label="Cancel" onPress={onCancel} disabled={running} />
          <Button theme={theme} label={running ? "Running checks" : "Run checks"} icon="Play" variant="danger" onPress={onRun} disabled={running} />
        </View>
      </View>
    </Modal.Content>
  );
}
