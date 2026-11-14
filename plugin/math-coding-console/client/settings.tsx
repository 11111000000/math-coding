import type { PluginSurfaceProps } from "@getpaseo/plugin/client";
import { useSettings } from "@getpaseo/plugin/client";
import {
  SettingsAction,
  SettingsCard,
  SettingsInput,
  SettingsSection,
  SettingsSelect,
  SettingsSwitch,
} from "@getpaseo/plugin/client/ui";
import { useState } from "react";
import { Text, View } from "react-native";
import { preferences } from "../shared/contracts";

export function SettingsScreen({ theme }: PluginSurfaceProps) {
  const settings = useSettings(preferences);
  return (
    <View style={{ gap: 14 }}>
      <SettingsSection title="Math Coding v5">
        <SettingsCard>
          {settings.status === "loading" && <Text style={{ color: theme.colors.foregroundMuted, padding: 12 }}>Loading settings…</Text>}
          {settings.status === "error" && <Text style={{ color: theme.colors.statusDanger, padding: 12 }}>{settings.error}</Text>}
          {settings.status === "invalid" && (
            <>
              <Text style={{ color: theme.colors.statusDanger, padding: 12 }}>{settings.error}</Text>
              <SettingsAction label="Invalid settings" actionLabel="Reset to defaults" onPress={() => void settings.reset()} />
            </>
          )}
          {settings.status === "ready" && <ReadySettings theme={theme} settings={settings} />}
        </SettingsCard>
      </SettingsSection>
      <Text style={{ color: theme.colors.foregroundMuted, fontSize: 12, lineHeight: 18, paddingHorizontal: 4 }}>
        The default binary is mathc on the daemon PATH. An override must be absolute and report mathc 5. Changing binaries can change the environment fingerprint and make previous evidence outdated. Automatic refresh only reads the map; it never runs checks.
      </Text>
    </View>
  );
}

type Ready = ReturnType<typeof useSettings<typeof preferences.schema>> & { status: "ready" };

function ReadySettings({ theme, settings }: { theme: PluginSurfaceProps["theme"]; settings: Ready }) {
  const [binaryPath, setBinaryPath] = useState(settings.values.binaryPath);
  const saveBinary = () => void settings.save({ ...settings.values, binaryPath: binaryPath.trim() }, settings.revision);
  const reset = () => void settings.reset().then((saved) => { if (saved) setBinaryPath(""); });
  return (
    <>
      <SettingsInput
        label="mathc binary"
        hint="Empty uses mathc from PATH; otherwise enter an absolute path on the daemon machine"
        initialValue={settings.values.binaryPath}
        onChangeText={setBinaryPath}
        placeholder="mathc"
      />
      <SettingsSelect
        label="Read-only refresh"
        hint="Applies while a workspace panel is open"
        value={String(settings.values.autoRefreshSeconds)}
        options={[
          { label: "Off", value: "0" },
          { label: "Every 15 seconds", value: "15" },
          { label: "Every 30 seconds", value: "30" },
          { label: "Every 60 seconds", value: "60" },
        ]}
        onValueChange={(value) => void settings.save({ ...settings.values, autoRefreshSeconds: Number(value) as 0 | 15 | 30 | 60 }, settings.revision)}
      />
      <SettingsSwitch
        label="Allow Run checks"
        hint="Off by default. When enabled, the Run checks action may execute project-declared verifier and control commands."
        value={settings.values.allowRunChecks}
        onValueChange={(value) => void settings.save({ ...settings.values, allowRunChecks: value }, settings.revision)}
        disabled={settings.saving}
      />
      <SettingsAction label="Binary path" actionLabel={settings.saving ? "Saving" : "Save"} onPress={saveBinary} disabled={settings.saving || binaryPath.trim() === settings.values.binaryPath} />
      <SettingsAction label="All preferences" actionLabel="Reset" onPress={reset} disabled={settings.saving} />
      {settings.saveError && <Text style={{ color: theme.colors.statusDanger, padding: 12 }}>{settings.saveError}</Text>}
    </>
  );
}
