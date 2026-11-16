import { useState } from "react";
import { Text, View } from "react-native";
import { preferencesDefinition, type Preferences } from "../shared/schemas";
import type { ConsoleTheme } from "../shared/theme";
import { useHost } from "./host/context";
import type { HostSettingsState } from "./host/contract";

export interface SettingsScreenProps {
  theme: ConsoleTheme;
}

export function SettingsScreen({ theme }: SettingsScreenProps) {
  const {
    SettingsAction,
    SettingsCard,
    SettingsInput,
    SettingsSection,
    SettingsSelect,
    SettingsSwitch,
    useSettings,
  } = useHost();
  const settings = useSettings(preferencesDefinition);
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
          {isReady(settings) && <ReadySettings theme={theme} settings={settings} />}
        </SettingsCard>
      </SettingsSection>
      <Text style={{ color: theme.colors.foregroundMuted, fontSize: 12, lineHeight: 18, paddingHorizontal: 4 }}>
        The default binary is mathc on the daemon PATH. An override must be absolute and report mathc 5. Changing binaries can change the environment fingerprint and make previous evidence outdated. Automatic refresh only reads the map; it never runs checks.
      </Text>
    </View>
  );
}

type Ready = {
  status: "ready";
  values: Preferences;
  revision: string;
  saving: boolean;
  saveError: string | null;
  save(values: Preferences, revision: string): Promise<boolean>;
  reset(): Promise<boolean>;
};

/**
 * The ready branch of the host settings.
 *
 * The host contract marks the values and the revision as optional, so the
 * screen only offers to save when the host actually delivered both.
 */
function isReady(settings: HostSettingsState<Preferences>): settings is HostSettingsState<Preferences> & Ready {
  return settings.status === "ready" && settings.values !== undefined && settings.revision !== undefined;
}

function ReadySettings({ theme, settings }: { theme: ConsoleTheme; settings: Ready }) {
  const { SettingsAction, SettingsInput, SettingsSelect, SettingsSwitch } = useHost();
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
      <SettingsSwitch
        label="Allow human decisions"
        hint="Off by default. When enabled, the console may ask mathc to record a decision of the human: a review of a source, a human review, an accepted risk or an authorization."
        value={settings.values.allowHumanDecisions}
        onValueChange={(value) => void settings.save({ ...settings.values, allowHumanDecisions: value }, settings.revision)}
        disabled={settings.saving}
      />
      <SettingsAction label="Binary path" actionLabel={settings.saving ? "Saving" : "Save"} onPress={saveBinary} disabled={settings.saving || binaryPath.trim() === settings.values.binaryPath} />
      <SettingsAction label="All preferences" actionLabel="Reset" onPress={reset} disabled={settings.saving} />
      {settings.saveError && <Text style={{ color: theme.colors.statusDanger, padding: 12 }}>{settings.saveError}</Text>}
    </>
  );
}
