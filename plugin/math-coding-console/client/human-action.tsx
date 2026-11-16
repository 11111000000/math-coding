import { useMemo } from "react";
import { Pressable, Text, View } from "react-native";
import {
  humanActionArgv,
  humanActionCommand,
  type HumanAction,
  type HumanActionField,
  type HumanActionValues,
} from "../shared/human-actions";
import type { ConsoleTheme } from "../shared/theme";
import { useHost } from "./host/context";
import { HostModalContent } from "./host/sheet";
import { Body, Button, Mono, Note } from "./parts";

export interface HumanActionFormProps {
  theme: ConsoleTheme;
  action: HumanAction;
  values: HumanActionValues;
  onChange: (values: HumanActionValues) => void;
  running: boolean;
  error: unknown;
  onCancel: () => void;
  onConfirm: () => void;
}

/**
 * The form of one manual step of the method.
 *
 * The form shows the command the program will run, so the human sees what the
 * decision does before it happens. The command is built by the same builder
 * the server uses, and the two cannot drift apart.
 */
export function HumanActionForm({ theme, action, values, onChange, running, error, onCancel, onConfirm }: HumanActionFormProps) {
  const command = useMemo(() => {
    try {
      return { text: humanActionCommand(humanActionArgv(action, values)), missing: null as string | null };
    } catch (problem) {
      return { text: "", missing: problem instanceof Error ? problem.message : String(problem) };
    }
  }, [action, values]);
  const set = (name: keyof HumanActionValues) => (value: string) => onChange({ ...values, [name]: value });
  return (
    <HostModalContent>
      <View style={{ gap: 12 }}>
        <Body theme={theme}>{action.detail}</Body>
        {action.expectation.length > 0 && (
          <View style={{ gap: 2 }}>
            <Text style={{ color: theme.colors.foregroundMuted, fontSize: 10, fontWeight: "700", textTransform: "uppercase" }}>Expectation</Text>
            <Text style={{ color: theme.colors.foreground, fontSize: 12, lineHeight: 18 }}>{action.expectation}</Text>
          </View>
        )}
        {action.fields.map((field) => (
          <Field
            key={field.name}
            theme={theme}
            field={field}
            value={values[field.name]}
            onChange={set(field.name)}
            disabled={running}
          />
        ))}
        <View style={{ gap: 3 }}>
          <Text style={{ color: theme.colors.foregroundMuted, fontSize: 10, fontWeight: "700", textTransform: "uppercase" }}>The command</Text>
          {command.text.length > 0 ? (
            <Mono theme={theme} lines={3}>{command.text}</Mono>
          ) : (
            <Note theme={theme} tone="warn">{command.missing ?? "The decision is not complete yet."}</Note>
          )}
        </View>
        <Note theme={theme} tone="warn">
          The decision is written into the project. The name is a journal entry, not an authentication, and the program decides whether it may be recorded.
        </Note>
        {error !== null && error !== undefined && (
          <Note theme={theme} tone="bad">
            The decision was refused: {error instanceof Error ? error.message : String(error)}
          </Note>
        )}
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8, justifyContent: "flex-end" }}>
          <Button theme={theme} label="Cancel" onPress={onCancel} disabled={running} />
          <Button
            theme={theme}
            label={running ? "Recording" : "Record the decision"}
            icon="Stamp"
            variant="danger"
            onPress={onConfirm}
            disabled={running || command.missing !== null}
          />
        </View>
      </View>
    </HostModalContent>
  );
}

function Field({ theme, field, value, onChange, disabled }: {
  theme: ConsoleTheme;
  field: HumanActionField;
  value: string;
  onChange: (value: string) => void;
  disabled: boolean;
}) {
  const { TextInput } = useHost();
  return (
    <View style={{ gap: 4 }}>
      <Text style={{ color: theme.colors.foregroundMuted, fontSize: 10, fontWeight: "700", textTransform: "uppercase" }}>
        {field.label}{field.required ? "" : " (optional)"}
      </Text>
      {field.options ? (
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6 }}>
          {field.options.map((option) => {
            const active = option === value;
            return (
              <Pressable
                key={option}
                accessibilityRole="button"
                accessibilityLabel={`${field.label} ${option}`}
                accessibilityState={{ selected: active, disabled }}
                disabled={disabled}
                onPress={() => onChange(option)}
                style={{
                  borderWidth: 1,
                  borderColor: active ? theme.colors.accent : theme.colors.border,
                  backgroundColor: active ? theme.colors.surface2 : "transparent",
                  borderRadius: 7,
                  paddingHorizontal: 9,
                  paddingVertical: 6,
                  opacity: disabled ? 0.45 : 1,
                }}
              >
                <Text style={{ color: active ? theme.colors.foreground : theme.colors.foregroundMuted, fontSize: 11, fontWeight: "600" }}>{option}</Text>
              </Pressable>
            );
          })}
        </View>
      ) : (
        <TextInput
          accessibilityLabel={field.label}
          value={value}
          onChangeText={onChange}
          editable={!disabled}
          placeholder={field.placeholder ?? field.label}
          placeholderTextColor={theme.colors.foregroundMuted}
          style={{
            borderWidth: 1,
            borderColor: theme.colors.border,
            borderRadius: 8,
            backgroundColor: theme.colors.surface1,
            color: theme.colors.foreground,
            minHeight: 38,
            paddingHorizontal: 11,
            paddingVertical: 7,
            fontSize: 12,
          }}
        />
      )}
      <Text style={{ color: theme.colors.foregroundMuted, fontSize: 11, lineHeight: 16 }}>{field.hint}</Text>
    </View>
  );
}
