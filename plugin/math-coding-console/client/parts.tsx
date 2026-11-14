import type { PluginTheme } from "@getpaseo/plugin";
import { Icon, Modal, TextInput } from "@getpaseo/plugin/client/ui";
import { useState, type ReactNode } from "react";
import { Pressable, ScrollView, Text, View } from "react-native";
import { toneColor, type Tone } from "./vocabulary";

export function Card({ theme, title, subtitle, right, children, compact = false }: {
  theme: PluginTheme;
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
  theme: PluginTheme;
  label: string;
  tone?: Tone;
  icon?: string;
  color?: string;
}) {
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
  theme: PluginTheme;
  label: string;
  onPress: () => void;
  icon?: string;
  variant?: "primary" | "secondary" | "danger";
  disabled?: boolean;
  compact?: boolean;
}) {
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
  theme: PluginTheme;
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

export function Mono({ theme, children, lines }: { theme: PluginTheme; children: ReactNode; lines?: number }) {
  return <Text selectable numberOfLines={lines} style={{
    color: theme.colors.foregroundMuted,
    fontSize: 11,
    lineHeight: 16,
    fontFamily: "monospace",
  }}>{children}</Text>;
}

export function KeyValue({ theme, label, value, color }: {
  theme: PluginTheme;
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
  theme: PluginTheme;
  children: ReactNode;
  tone?: Tone;
}) {
  return (
    <View style={{ borderLeftWidth: 3, borderLeftColor: toneColor(theme, tone), paddingLeft: 10, paddingVertical: 3 }}>
      <Body theme={theme} muted>{children}</Body>
    </View>
  );
}

export function Empty({ theme, title, detail, icon = "Inbox" }: {
  theme: PluginTheme;
  title: string;
  detail?: string;
  icon?: string;
}) {
  return (
    <View style={{ alignItems: "center", justifyContent: "center", padding: 28, gap: 8 }}>
      <Icon name={icon} size={28} color={theme.colors.foregroundMuted} />
      <Text style={{ color: theme.colors.foreground, fontSize: 15, fontWeight: "600", textAlign: "center" }}>{title}</Text>
      {detail && <Text style={{ color: theme.colors.foregroundMuted, fontSize: 12, lineHeight: 18, textAlign: "center" }}>{detail}</Text>}
    </View>
  );
}

export function Segmented({ theme, options, value, onChange }: {
  theme: PluginTheme;
  options: readonly { value: string; label: string; icon?: string }[];
  value: string;
  onChange: (value: string) => void;
}) {
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

export function SearchBox({ theme, value, onChange, placeholder = "Search claims" }: {
  theme: PluginTheme;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
}) {
  return (
    <TextInput
      accessibilityLabel={placeholder}
      value={value}
      onChangeText={onChange}
      placeholder={placeholder}
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

export function Select({ theme, label, value, options, onChange }: {
  theme: PluginTheme;
  label: string;
  value: string;
  options: readonly string[];
  onChange: (value: string) => void;
}) {
  const [open, setOpen] = useState(false);
  return (
    <>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`${label}: ${value}`}
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
        <Text style={{ color: theme.colors.foreground, fontSize: 11, maxWidth: 150 }} numberOfLines={1}>{value}</Text>
        <Icon name="ChevronDown" size={12} color={theme.colors.foregroundMuted} />
      </Pressable>
      <Modal title={label} open={open} onOpenChange={setOpen}>
        <Modal.Content>
          <View style={{ gap: 5 }}>
            {options.map((option) => (
              <Pressable
                key={option}
                accessibilityRole="button"
                accessibilityLabel={`${label} ${option}`}
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
                <Text style={{ color: theme.colors.foreground, fontSize: 13 }}>{option}</Text>
              </Pressable>
            ))}
          </View>
        </Modal.Content>
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
