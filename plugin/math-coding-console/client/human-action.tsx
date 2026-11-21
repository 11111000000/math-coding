import { useMemo } from "react";
import { Pressable, Text, View } from "react-native";
import {
  humanActionArgv,
  humanActionCommand,
  type HumanAction,
  type HumanActionField,
  type HumanActionValues,
} from "../shared/human-actions";
import type { EvidenceOutcome } from "../shared/domain";
import type { ConsoleTheme } from "../shared/theme";
import { useHost } from "./host/context";
import { HostModalContent } from "./host/sheet";
import { errorText } from "./i18n/errors";
import { renderValue } from "./i18n/translate";
import { useT } from "./i18n";
import { Body, Button, Mono, Note } from "./parts";
import { outcomeKey } from "./vocabulary";

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
  const t = useT();
  const command = useMemo(() => {
    try {
      return { text: humanActionCommand(humanActionArgv(action, values)), failure: null as unknown };
    } catch (problem) {
      return { text: "", failure: problem };
    }
  }, [action, values]);
  const set = (name: keyof HumanActionValues) => (value: string) => onChange({ ...values, [name]: value });
  const expectation = renderValue(t, action.expectation);
  return (
    <HostModalContent>
      <View style={{ gap: 12 }}>
        <Body theme={theme}>{t(action.detail)}</Body>
        {expectation.length > 0 && (
          <View style={{ gap: 2 }}>
            <Text style={{ color: theme.colors.foregroundMuted, fontSize: 10, fontWeight: "700", textTransform: "uppercase" }}>{t("action.expectation_title")}</Text>
            <Text style={{ color: theme.colors.foreground, fontSize: 12, lineHeight: 18 }}>{expectation}</Text>
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
          <Text style={{ color: theme.colors.foregroundMuted, fontSize: 10, fontWeight: "700", textTransform: "uppercase" }}>{t("action.command_title")}</Text>
          {command.text.length > 0 ? (
            <Mono theme={theme} lines={3}>{command.text}</Mono>
          ) : (
            <Note theme={theme} tone="warn">{command.failure === null ? t("action.incomplete") : errorText(t, command.failure)}</Note>
          )}
        </View>
        <Note theme={theme} tone="warn">
          {t("action.journal_note")}
        </Note>
        {error !== null && error !== undefined && (
          <Note theme={theme} tone="bad">
            {t("action.refused", { error: errorText(t, error) })}
          </Note>
        )}
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8, justifyContent: "flex-end" }}>
          <Button theme={theme} label={t("common.cancel")} onPress={onCancel} disabled={running} />
          <Button
            theme={theme}
            label={running ? t("action.recording") : t("action.record_decision")}
            icon="Stamp"
            variant="danger"
            onPress={onConfirm}
            disabled={running || command.failure !== null}
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
  const t = useT();
  const label = t(field.label);
  return (
    <View style={{ gap: 4 }}>
      <Text style={{ color: theme.colors.foregroundMuted, fontSize: 10, fontWeight: "700", textTransform: "uppercase" }}>
        {label}{field.required ? "" : t("action.optional")}
      </Text>
      {field.options ? (
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6 }}>
          {field.options.map((option) => {
            const active = option === value;
            const text = t(outcomeKey(option as EvidenceOutcome));
            return (
              <Pressable
                key={option}
                accessibilityRole="button"
                accessibilityLabel={`${label} ${text}`}
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
                <Text style={{ color: active ? theme.colors.foreground : theme.colors.foregroundMuted, fontSize: 11, fontWeight: "600" }}>{text}</Text>
              </Pressable>
            );
          })}
        </View>
      ) : (
        <TextInput
          accessibilityLabel={label}
          value={value}
          onChangeText={onChange}
          editable={!disabled}
          placeholder={renderValue(t, field.placeholder ?? field.label)}
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
      <Text style={{ color: theme.colors.foregroundMuted, fontSize: 11, lineHeight: 16 }}>{t(field.hint)}</Text>
    </View>
  );
}
