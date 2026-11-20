import { useState, type ReactNode } from "react";
import { Pressable, ScrollView, Text, View } from "react-native";
import type { StateReason } from "../shared/domain";
import type { ConsoleTheme } from "../shared/theme";
import { useHost } from "./host/context";
import { HostModalContent } from "./host/sheet";
import { useT } from "./i18n";
import { stateReasonKey, toneColor, type Tone } from "./vocabulary";

export function Card({ theme, title, subtitle, right, children, compact = false }: {
  theme: ConsoleTheme;
  title?: string;
  subtitle?: string;
  right?: ReactNode;
  children: ReactNode;
  compact?: boolean;
}) {
  return (
    <View style={{
      backgroundColor: theme.colors.surface1,
      borderColor: theme.colors.border,
      borderWidth: 1,
      borderRadius: 12,
      padding: compact ? 12 : 16,
      gap: 10,
    }}>
      {(title || subtitle || right) && (
        <View style={{ flexDirection: "row", alignItems: "flex-start", gap: 12 }}>
          <View style={{ flex: 1, gap: 2 }}>
            {title && <Text style={{ color: theme.colors.foreground, fontSize: 15, fontWeight: "600" }}>{title}</Text>}
            {subtitle && <Text style={{ color: theme.colors.foregroundMuted, fontSize: 12, lineHeight: 17 }}>{subtitle}</Text>}
          </View>
          {right}
        </View>
      )}
      {children}
    </View>
  );
}

export function Badge({ theme, label, tone = "neutral", icon, color }: {
  theme: ConsoleTheme;
  label: string;
  tone?: Tone;
  icon?: string;
  color?: string;
}) {
  const { Icon } = useHost();
  const value = color ?? toneColor(theme, tone);
  return (
    <View style={{
      alignSelf: "flex-start",
      flexDirection: "row",
      alignItems: "center",
      gap: 4,
      borderRadius: 999,
      borderWidth: 1,
      borderColor: value,
      paddingHorizontal: 7,
      paddingVertical: 3,
    }}>
      {icon && <Icon name={icon} size={11} color={value} />}
      <Text style={{ color: value, fontSize: 10, fontWeight: "600" }}>{label}</Text>
    </View>
  );
}

export function Button({ theme, label, onPress, icon, variant = "secondary", disabled = false, compact = false }: {
  theme: ConsoleTheme;
  label: string;
  onPress: () => void;
  icon?: string;
  variant?: "primary" | "secondary" | "danger";
  disabled?: boolean;
  compact?: boolean;
}) {
  const { Icon } = useHost();
  const background = variant === "primary" ? theme.colors.accent
    : variant === "danger" ? theme.colors.statusDanger : theme.colors.surface2;
  const foreground = variant === "secondary" ? theme.colors.foreground : theme.colors.accentForeground;
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled }}
      disabled={disabled}
      onPress={onPress}
      style={{
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "center",
        gap: 6,
        paddingHorizontal: compact ? 9 : 12,
        paddingVertical: compact ? 7 : 9,
        borderRadius: 8,
        borderWidth: 1,
        borderColor: variant === "secondary" ? theme.colors.border : background,
        backgroundColor: background,
        opacity: disabled ? 0.45 : 1,
      }}
    >
      {icon && <Icon name={icon} size={14} color={foreground} />}
      <Text style={{ color: foreground, fontSize: 12, fontWeight: "600" }}>{label}</Text>
    </Pressable>
  );
}

export function Body({ theme, children, muted = false, lines }: {
  theme: ConsoleTheme;
  children: ReactNode;
  muted?: boolean;
  lines?: number;
}) {
  return <Text numberOfLines={lines} style={{
    color: muted ? theme.colors.foregroundMuted : theme.colors.foreground,
    fontSize: 13,
    lineHeight: 19,
  }}>{children}</Text>;
}

export function Mono({ theme, children, lines }: { theme: ConsoleTheme; children: ReactNode; lines?: number }) {
  return <Text selectable numberOfLines={lines} style={{
    color: theme.colors.foregroundMuted,
    fontSize: 11,
    lineHeight: 16,
    fontFamily: "monospace",
  }}>{children}</Text>;
}

export function KeyValue({ theme, label, value, color }: {
  theme: ConsoleTheme;
  label: string;
  value: string;
  color?: string;
}) {
  return (
    <View style={{ gap: 2 }}>
      <Text style={{ color: theme.colors.foregroundMuted, fontSize: 10, fontWeight: "600", textTransform: "uppercase" }}>{label}</Text>
      <Text selectable style={{ color: color ?? theme.colors.foreground, fontSize: 12, lineHeight: 17, fontFamily: "monospace" }}>{value}</Text>
    </View>
  );
}

export function Note({ theme, children, tone = "neutral" }: {
  theme: ConsoleTheme;
  children: ReactNode;
  tone?: Tone;
}) {
  return (
    <View style={{ borderLeftWidth: 3, borderLeftColor: toneColor(theme, tone), paddingLeft: 10, paddingVertical: 3 }}>
      <Body theme={theme} muted>{children}</Body>
    </View>
  );
}

/**
 * The reason of a state.
 *
 * The reason is the one the canonical map reports. When the program does not
 * report one, the text says so instead of naming a cause.
 */
export function ReasonBlock({ theme, reason }: {
  theme: ConsoleTheme;
  reason?: StateReason;
}) {
  const t = useT();
  return (
    <View style={{ gap: 2 }}>
      <Text style={{ color: theme.colors.foregroundMuted, fontSize: 10, fontWeight: "600", textTransform: "uppercase" }}>{t("state.reason_title")}</Text>
      <Text selectable style={{ color: theme.colors.foreground, fontSize: 12, lineHeight: 17 }}>{t(stateReasonKey(reason))}</Text>
    </View>
  );
}

export function Empty({ theme, title, detail, icon = "Inbox" }: {
  theme: ConsoleTheme;
  title: string;
  detail?: string;
  icon?: string;
}) {
  const { Icon } = useHost();
  return (
    <View style={{ alignItems: "center", justifyContent: "center", padding: 28, gap: 8 }}>
      <Icon name={icon} size={28} color={theme.colors.foregroundMuted} />
      <Text style={{ color: theme.colors.foreground, fontSize: 15, fontWeight: "600", textAlign: "center" }}>{title}</Text>
      {detail && <Text style={{ color: theme.colors.foregroundMuted, fontSize: 12, lineHeight: 18, textAlign: "center" }}>{detail}</Text>}
    </View>
  );
}

export function Segmented({ theme, options, value, onChange }: {
  theme: ConsoleTheme;
  options: readonly { value: string; label: string; icon?: string }[];
  value: string;
  onChange: (value: string) => void;
}) {
  const { Icon } = useHost();
  return (
    <View style={{
      flexDirection: "row",
      backgroundColor: theme.colors.surface1,
      borderColor: theme.colors.border,
      borderWidth: 1,
      borderRadius: 9,
      padding: 3,
      gap: 2,
    }}>
      {options.map((option) => {
        const active = option.value === value;
        return (
          <Pressable
            key={option.value}
            accessibilityRole="tab"
            accessibilityLabel={option.label}
            accessibilityState={{ selected: active }}
            onPress={() => onChange(option.value)}
            style={{
              flex: 1,
              minHeight: 34,
              flexDirection: "row",
              alignItems: "center",
              justifyContent: "center",
              gap: 5,
              paddingHorizontal: 8,
              borderRadius: 6,
              backgroundColor: active ? theme.colors.surface2 : "transparent",
            }}
          >
            {option.icon && <Icon name={option.icon} size={13} color={active ? theme.colors.foreground : theme.colors.foregroundMuted} />}
            <Text style={{ color: active ? theme.colors.foreground : theme.colors.foregroundMuted, fontSize: 11, fontWeight: "600" }}>{option.label}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

export function SearchBox({ theme, value, onChange, placeholder }: {
  theme: ConsoleTheme;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
}) {
  const { TextInput } = useHost();
  const t = useT();
  const text = placeholder ?? t("common.search_claims");
  return (
    <TextInput
      accessibilityLabel={text}
      value={value}
      onChangeText={onChange}
      placeholder={text}
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
  );
}

/**
 * A choice of one value of a closed set.
 *
 * The value stays the value of the domain, so the filter that reads it never
 * sees a translated word; only the text the human reads is translated.
 */
export function Select({ theme, label, value, options, optionLabels, onChange }: {
  theme: ConsoleTheme;
  label: string;
  value: string;
  options: readonly string[];
  optionLabels?: Record<string, string>;
  onChange: (value: string) => void;
}) {
  const { Icon, Modal } = useHost();
  const [open, setOpen] = useState(false);
  const text = (option: string) => optionLabels?.[option] ?? option;
  return (
    <>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`${label}: ${text(value)}`}
        onPress={() => setOpen(true)}
        style={{
          flexDirection: "row",
          alignItems: "center",
          gap: 5,
          borderWidth: 1,
          borderColor: theme.colors.border,
          borderRadius: 8,
          backgroundColor: theme.colors.surface1,
          paddingHorizontal: 9,
          minHeight: 34,
        }}
      >
        <Text style={{ color: theme.colors.foregroundMuted, fontSize: 10 }}>{label}</Text>
        <Text style={{ color: theme.colors.foreground, fontSize: 11, maxWidth: 150 }} numberOfLines={1}>{text(value)}</Text>
        <Icon name="ChevronDown" size={12} color={theme.colors.foregroundMuted} />
      </Pressable>
      <Modal title={label} open={open} onOpenChange={setOpen}>
        <HostModalContent>
          <View style={{ gap: 5 }}>
            {options.map((option) => (
              <Pressable
                key={option}
                accessibilityRole="button"
                accessibilityLabel={`${label} ${text(option)}`}
                onPress={() => { onChange(option); setOpen(false); }}
                style={{
                  flexDirection: "row",
                  alignItems: "center",
                  gap: 8,
                  padding: 10,
                  borderRadius: 7,
                  backgroundColor: option === value ? theme.colors.surface2 : "transparent",
                }}
              >
                {option === value && <Icon name="Check" size={14} color={theme.colors.accent} />}
                <Text style={{ color: theme.colors.foreground, fontSize: 13 }}>{text(option)}</Text>
              </Pressable>
            ))}
          </View>
        </HostModalContent>
      </Modal>
    </>
  );
}

export function FilterRow({ children }: { children: ReactNode }) {
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false}>
      <View style={{ flexDirection: "row", gap: 6, alignItems: "center", paddingBottom: 2 }}>{children}</View>
    </ScrollView>
  );
}
