import type { PluginTheme } from "@getpaseo/plugin";
import { useMemo } from "react";
import { Pressable, Text, View } from "react-native";
import { verdictTone } from "../shared/verdict";

/**
 * The console's visual vocabulary.
 *
 * Every colour comes from `theme.colors`, because Paseo runs the plugin on
 * desktop, in a browser and on a phone, in light and dark themes. A hard-coded
 * colour would be black text on a dark background in one of them.
 */

export type Tone = "neutral" | "good" | "warn" | "bad" | "info";

export function toneColor(theme: PluginTheme, tone: Tone): string {
  switch (tone) {
    case "good":
      return theme.colors.statusSuccess;
    case "warn":
      return theme.colors.statusWarning;
    case "bad":
      return theme.colors.statusDanger;
    case "info":
      return theme.colors.accent;
    default:
      return theme.colors.foregroundMuted;
  }
}

export function Card({
  theme,
  title,
  subtitle,
  right,
  children,
  compact,
}: {
  theme: PluginTheme;
  title?: string;
  subtitle?: string;
  right?: React.ReactNode;
  children?: React.ReactNode;
  compact?: boolean;
}) {
  const styles = useMemo(
    () => ({
      card: {
        backgroundColor: theme.colors.surface1,
        borderColor: theme.colors.border,
        borderWidth: 1,
        borderRadius: 10,
        padding: compact ? 10 : 14,
        gap: compact ? 6 : 10,
      },
      header: { flexDirection: "row" as const, alignItems: "center" as const, gap: 8 },
      headerText: { flex: 1 },
      title: { color: theme.colors.foreground, fontSize: 14, fontWeight: "600" as const },
      subtitle: { color: theme.colors.foregroundMuted, fontSize: 12, marginTop: 2 },
      body: { gap: 6 },
    }),
    [theme, compact],
  );
  return (
    <View style={styles.card}>
      {(title !== undefined || right !== undefined) && (
        <View style={styles.header}>
          <View style={styles.headerText}>
            {title !== undefined && <Text style={styles.title}>{title}</Text>}
            {subtitle !== undefined && <Text style={styles.subtitle}>{subtitle}</Text>}
          </View>
          {right}
        </View>
      )}
      {children !== undefined && <View style={styles.body}>{children}</View>}
    </View>
  );
}

export function Badge({
  theme,
  label,
  tone = "neutral",
  onPress,
}: {
  theme: PluginTheme;
  label: string;
  tone?: Tone;
  onPress?: () => void;
}) {
  const styles = useMemo(
    () => ({
      badge: {
        borderRadius: 999,
        borderWidth: 1,
        paddingHorizontal: 8,
        paddingVertical: 2,
        alignSelf: "flex-start" as const,
      },
      text: { fontSize: 11, fontWeight: "600" as const },
    }),
    [theme],
  );
  const color = toneColor(theme, tone);
  const content = (
    <View style={[styles.badge, { borderColor: color, backgroundColor: `${color}22` }]}>
      <Text style={[styles.text, { color }]}>{label}</Text>
    </View>
  );
  if (!onPress) return content;
  return (
    <Pressable accessibilityRole="button" accessibilityLabel={label} onPress={onPress}>
      {content}
    </Pressable>
  );
}

export function VerdictBadge({
  theme,
  verdict,
  onPress,
}: {
  theme: PluginTheme;
  verdict: string;
  onPress?: () => void;
}) {
  return (
    <Badge theme={theme} label={verdict} tone={verdictTone(verdict) as Tone} onPress={onPress} />
  );
}

export function Label({ theme, children }: { theme: PluginTheme; children: React.ReactNode }) {
  const styles = useMemo(
    () => ({ label: { color: theme.colors.foregroundMuted, fontSize: 11, letterSpacing: 0.6 } }),
    [theme],
  );
  return <Text style={styles.label}>{children}</Text>;
}

export function Body({
  theme,
  children,
  muted,
  numberOfLines,
}: {
  theme: PluginTheme;
  children: React.ReactNode;
  muted?: boolean;
  numberOfLines?: number;
}) {
  const styles = useMemo(
    () => ({
      body: {
        color: muted ? theme.colors.foregroundMuted : theme.colors.foreground,
        fontSize: 13,
        lineHeight: 19,
      },
    }),
    [theme, muted],
  );
  return (
    <Text style={styles.body} numberOfLines={numberOfLines}>
      {children}
    </Text>
  );
}

export function Mono({ theme, children }: { theme: PluginTheme; children: React.ReactNode }) {
  const styles = useMemo(
    () => ({ mono: { color: theme.colors.foregroundMuted, fontSize: 11, fontFamily: "monospace" as const } }),
    [theme],
  );
  return <Text style={styles.mono}>{children}</Text>;
}

export function KeyValue({
  theme,
  label,
  value,
  tone,
}: {
  theme: PluginTheme;
  label: string;
  value: string;
  tone?: Tone;
}) {
  const styles = useMemo(
    () => ({
      row: { flexDirection: "row" as const, alignItems: "baseline" as const, gap: 8 },
      label: { color: theme.colors.foregroundMuted, fontSize: 12, minWidth: 96 },
      value: { color: theme.colors.foreground, fontSize: 13, flex: 1, fontWeight: "500" as const },
    }),
    [theme],
  );
  return (
    <View style={styles.row}>
      <Text style={styles.label}>{label}</Text>
      <Text style={[styles.value, tone ? { color: toneColor(theme, tone) } : null]}>{value}</Text>
    </View>
  );
}

export function Button({
  theme,
  label,
  onPress,
  variant = "secondary",
  disabled,
}: {
  theme: PluginTheme;
  label: string;
  onPress: () => void;
  variant?: "primary" | "secondary" | "danger";
  disabled?: boolean;
}) {
  const styles = useMemo(() => {
    const background =
      variant === "primary"
        ? theme.colors.accent
        : variant === "danger"
          ? theme.colors.statusDanger
          : theme.colors.surface2;
    const foreground =
      variant === "primary"
        ? theme.colors.accentForeground
        : variant === "danger"
          ? theme.colors.accentForeground
          : theme.colors.foreground;
    return {
      button: {
        backgroundColor: background,
        borderColor: variant === "secondary" ? theme.colors.border : background,
        borderWidth: 1,
        borderRadius: 8,
        paddingHorizontal: 12,
        paddingVertical: 8,
        opacity: disabled ? 0.45 : 1,
      },
      text: { color: foreground, fontSize: 13, fontWeight: "600" as const },
    };
  }, [theme, variant, disabled]);

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled: Boolean(disabled) }}
      disabled={disabled}
      onPress={onPress}
      style={styles.button}
    >
      <Text style={styles.text}>{label}</Text>
    </Pressable>
  );
}

export function Segmented({
  theme,
  options,
  value,
  onChange,
}: {
  theme: PluginTheme;
  options: { value: string; label: string }[];
  value: string;
  onChange: (value: string) => void;
}) {
  const styles = useMemo(
    () => ({
      bar: {
        flexDirection: "row" as const,
        backgroundColor: theme.colors.surface1,
        borderColor: theme.colors.border,
        borderWidth: 1,
        borderRadius: 8,
        padding: 2,
        gap: 2,
      },
      item: {
        flex: 1,
        paddingVertical: 6,
        paddingHorizontal: 8,
        borderRadius: 6,
        alignItems: "center" as const,
      },
      itemActive: { backgroundColor: theme.colors.surface2 },
      text: { color: theme.colors.foregroundMuted, fontSize: 12, fontWeight: "600" as const },
      textActive: { color: theme.colors.foreground },
    }),
    [theme],
  );
  return (
    <View style={styles.bar}>
      {options.map((option) => {
        const active = option.value === value;
        return (
          <Pressable
            key={option.value}
            accessibilityRole="tab"
            accessibilityState={{ selected: active }}
            accessibilityLabel={option.label}
            onPress={() => onChange(option.value)}
            style={[styles.item, active ? styles.itemActive : null]}
          >
            <Text style={[styles.text, active ? styles.textActive : null]}>{option.label}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

export function Empty({ theme, children }: { theme: PluginTheme; children: React.ReactNode }) {
  const styles = useMemo(
    () => ({
      empty: {
        color: theme.colors.foregroundMuted,
        fontSize: 12,
        textAlign: "center" as const,
        paddingVertical: 16,
      },
    }),
    [theme],
  );
  return <Text style={styles.empty}>{children}</Text>;
}

export function Note({
  theme,
  children,
  tone = "neutral",
}: {
  theme: PluginTheme;
  children: React.ReactNode;
  tone?: Tone;
}) {
  const styles = useMemo(
    () => ({
      note: {
        borderLeftWidth: 3,
        paddingLeft: 8,
        paddingVertical: 2,
      },
      text: { color: theme.colors.foregroundMuted, fontSize: 12, lineHeight: 17 },
    }),
    [theme],
  );
  return (
    <View style={[styles.note, { borderLeftColor: toneColor(theme, tone) }]}>
      <Text style={styles.text}>{children}</Text>
    </View>
  );
}

export function SectionTitle({ theme, children }: { theme: PluginTheme; children: React.ReactNode }) {
  const styles = useMemo(
    () => ({
      title: {
        color: theme.colors.foregroundMuted,
        fontSize: 11,
        fontWeight: "700" as const,
        letterSpacing: 0.8,
        textTransform: "uppercase" as const,
        marginTop: 4,
      },
    }),
    [theme],
  );
  return <Text style={styles.title}>{children}</Text>;
}
