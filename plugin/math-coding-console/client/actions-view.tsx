import type { PluginTheme } from "@getpaseo/plugin";
import { useRpc } from "@getpaseo/plugin/client";
import { TextInput, useToast } from "@getpaseo/plugin/client/ui";
import { useMutation } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { View } from "react-native";
import { actionRpc } from "../shared/contracts";
import { Badge, Body, Button, Card, Label, Mono, Note } from "./parts";

/**
 * The control panel.
 *
 * Every button here runs a kernel subcommand and shows what it said. The
 * console does not decide anything the kernel could decide; it only makes the
 * kernel's vocabulary reachable from a screen.
 */
export function ActionsView({
  theme,
  root,
  attestRunCommand,
  onRefresh,
}: {
  theme: PluginTheme;
  root: string | null;
  attestRunCommand: string;
  onRefresh: () => void;
}) {
  const toast = useToast();
  const run = useRpc(actionRpc);

  const [args, setArgs] = useState<Record<string, string>>({});
  const [last, setLast] = useState<{
    command: string;
    exitCode: number;
    stdout: string;
    stderr: string;
    durationMs: number;
  } | null>(null);

  const mutation = useMutation({
    mutationFn: async (input: { action: string; args: string[]; flags: string[] }) =>
      run({
        root: root ?? undefined,
        action: input.action as never,
        args: input.args,
        flags: input.flags,
      }),
    onSuccess: (result) => {
      setLast({
        command: result.command,
        exitCode: result.exitCode,
        stdout: result.stdout,
        stderr: result.stderr,
        durationMs: result.durationMs,
      });
      if (result.ok) {
        toast.show(`${result.command} → ${result.exitCode}`, { variant: "success" });
        onRefresh();
      } else {
        toast.error(`${result.command} exited ${result.exitCode}`);
      }
    },
    onError: (error) => {
      toast.error(String(error));
    },
  });

  const styles = useMemo(
    () => ({
      stack: { gap: 10 },
      rows: { gap: 6 },
      row: { flexDirection: "row" as const, flexWrap: "wrap" as const, gap: 6 },
      field: { gap: 4 },
      input: {
        borderWidth: 1,
        borderColor: theme.colors.border,
        borderRadius: 8,
        paddingHorizontal: 10,
        paddingVertical: 8,
        color: theme.colors.foreground,
        fontSize: 13,
      },
      output: {
        borderWidth: 1,
        borderColor: theme.colors.border,
        borderRadius: 8,
        padding: 10,
        gap: 4,
        backgroundColor: theme.colors.surface2,
      },
      stream: { color: theme.colors.foreground, fontSize: 11, lineHeight: 16, fontFamily: "monospace" as const },
    }),
    [theme],
  );

  const arg = (key: string) => args[key] ?? "";
  const setArg = (key: string, value: string) => setArgs((current) => ({ ...current, [key]: value }));

  const runAction = (
    action: string,
    options: { args?: string[]; flags?: string[] } = {},
  ) => {
    mutation.mutate({
      action,
      args: options.args ?? [],
      flags: options.flags ?? [],
    });
  };

  const busy = mutation.isPending;

  return (
    <View style={styles.stack}>
      <Card theme={theme} title="Read">
        <View style={styles.row}>
          <Button
            theme={theme}
            label="self-check"
            disabled={busy}
            onPress={() => runAction("self-check")}
          />
          <Button
            theme={theme}
            label="counters"
            disabled={busy}
            onPress={() => runAction("counters")}
          />
          <Button
            theme={theme}
            label="gaps"
            disabled={busy}
            onPress={() => runAction("gaps", { flags: ["--format=json"] })}
          />
          <Button
            theme={theme}
            label="packages"
            disabled={busy}
            onPress={() => runAction("packages", { flags: ["--format=json"] })}
          />
          <Button theme={theme} label="doctor" disabled={busy} onPress={() => runAction("doctor")} />
        </View>
      </Card>

      <Card theme={theme} title="Repair">
        <View style={styles.row}>
          <Button
            theme={theme}
            label="rehash (dry run)"
            disabled={busy}
            onPress={() => runAction("rehash")}
          />
          <Button
            theme={theme}
            label="rehash --write"
            disabled={busy}
            onPress={() => runAction("rehash", { flags: ["--write"] })}
          />
          <Button
            theme={theme}
            label="negative controls"
            disabled={busy}
            onPress={() => runAction("negative-control")}
          />
        </View>
        <Note theme={theme}>
          rehash recomputes each decision's digest from its own bytes. The dry run shows
          what would change; --write changes it.
        </Note>
      </Card>

      <Card theme={theme} title="Sign">
        <View style={styles.field}>
          <Label theme={theme}>base ref for the changed scope</Label>
          <TextInput
            style={styles.input}
            value={arg("base")}
            onChangeText={(value) => setArg("base", value)}
            placeholder="HEAD~1"
            accessibilityLabel="Base ref"
          />
        </View>
        <View style={styles.row}>
          <Button
            theme={theme}
            label="re-sign changed"
            disabled={busy}
            onPress={() =>
              runAction("attest-batch", {
                flags: [
                  `--only-changed=${arg("base").trim() === "" ? "HEAD~1" : arg("base").trim()}`,
                  "--kind=test",
                  ...(attestRunCommand.trim() === "" ? [] : [`--run=${attestRunCommand.trim()}`]),
                ],
              })
            }
          />
        </View>
        {attestRunCommand.trim() === "" && (
          <Note theme={theme} tone="warn">
            No run command is configured. A `test` attestation claims something ran, so the
            kernel refuses to sign one without a named run. Set the run command in Settings,
            or sign a `review` from the review queue instead.
          </Note>
        )}
      </Card>

      <Card theme={theme} title="Check one decision">
        <View style={styles.field}>
          <Label theme={theme}>decision file</Label>
          <TextInput
            style={styles.input}
            value={arg("file")}
            onChangeText={(value) => setArg("file", value)}
            placeholder="decisions/my-decision.yaml"
            accessibilityLabel="Decision file"
          />
        </View>
        <View style={styles.row}>
          <Button
            theme={theme}
            label="validate"
            disabled={busy || arg("file").trim() === ""}
            onPress={() => runAction("validate", { args: [arg("file").trim()] })}
          />
          <Button
            theme={theme}
            label="verify"
            disabled={busy || arg("file").trim() === ""}
            onPress={() => runAction("verify", { args: [arg("file").trim()] })}
          />
        </View>
      </Card>

      <Card theme={theme} title="Diff assurance">
        <View style={styles.row}>
          <Button
            theme={theme}
            label="gate HEAD~1..HEAD"
            disabled={busy}
            onPress={() => runAction("gate", { args: ["HEAD~1", "HEAD"] })}
          />
          <Button
            theme={theme}
            label="context capsule"
            disabled={busy}
            onPress={() =>
              runAction("context", { args: ["HEAD~1", "HEAD", "--budget", "4000"] })
            }
          />
        </View>
      </Card>

      <Card theme={theme} title="Scaffold">
        <View style={styles.field}>
          <Label theme={theme}>decision id</Label>
          <TextInput
            style={styles.input}
            value={arg("id")}
            onChangeText={(value) => setArg("id", value)}
            placeholder="my-decision"
            accessibilityLabel="Decision id"
          />
        </View>
        <View style={styles.row}>
          <Button
            theme={theme}
            label="new decision (dry run)"
            disabled={busy || arg("id").trim() === ""}
            onPress={() => runAction("new-decision", { args: [arg("id").trim()] })}
          />
          <Button
            theme={theme}
            label="new decision --write"
            disabled={busy || arg("id").trim() === ""}
            onPress={() =>
              runAction("new-decision", { args: [arg("id").trim()], flags: ["--write"] })
            }
          />
        </View>
      </Card>

      <Card theme={theme} title="Session and time">
        <View style={styles.row}>
          <Button
            theme={theme}
            label="session-start"
            disabled={busy}
            onPress={() => runAction("session-start")}
          />
          <Button
            theme={theme}
            label="record step-count"
            disabled={busy || arg("id").trim() === ""}
            onPress={() =>
              runAction("record", {
                args: ["--decision-id", arg("id").trim(), "--scale", "step-count", "--value", "1"],
              })
            }
          />
        </View>
      </Card>

      <Card theme={theme} title="Kernel">
        <View style={styles.row}>
          <Button
            theme={theme}
            label="render site"
            disabled={busy}
            onPress={() => runAction("render")}
          />
          <Button
            theme={theme}
            label="self-update"
            disabled={busy}
            onPress={() => runAction("update")}
          />
        </View>
        <Note theme={theme}>
          self-update replaces the kernel binary. The console never does it on its own.
        </Note>
      </Card>

      {last !== null && (
        <Card
          theme={theme}
          title="Last command"
          right={<Badge theme={theme} label={`exit ${last.exitCode}`} tone={last.exitCode === 0 ? "good" : "bad"} />}
        >
          <Mono theme={theme}>{last.command}</Mono>
          <Mono theme={theme}>{last.durationMs} ms</Mono>
          <View style={styles.output}>
            {last.stdout.trim() !== "" && <Body theme={theme}>{trim(last.stdout)}</Body>}
            {last.stderr.trim() !== "" && (
              <Note theme={theme} tone="warn">
                {trim(last.stderr)}
              </Note>
            )}
            {last.stdout.trim() === "" && last.stderr.trim() === "" && (
              <Mono theme={theme}>(no output)</Mono>
            )}
          </View>
        </Card>
      )}
    </View>
  );
}

function trim(text: string): string {
  const limit = 4000;
  return text.length <= limit ? text.trim() : `${text.slice(0, limit)}\n…`;
}
