import { useState } from "react";
import { Text, View } from "react-native";
import { preferencesDefinition, type Preferences } from "../shared/schemas";
import type { ConsoleTheme } from "../shared/theme";
import { useHost } from "./host/context";
import type { HostSettingsState } from "./host/contract";
import { errorText } from "./i18n/errors";
import { useT } from "./i18n";

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
  const t = useT();
  const settings = useSettings(preferencesDefinition);
  return (
    <View style={{ gap: 14 }}>
      <SettingsSection title={t("settings.section_title")}>
        <SettingsCard>
          {settings.status === "loading" && <Text style={{ color: theme.colors.foregroundMuted, padding: 12 }}>{t("settings.loading")}</Text>}
          {settings.status === "error" && <Text style={{ color: theme.colors.statusDanger, padding: 12 }}>{errorText(t, settings.error)}</Text>}
          {settings.status === "invalid" && (
            <>
              <Text style={{ color: theme.colors.statusDanger, padding: 12 }}>{errorText(t, settings.error)}</Text>
              <SettingsAction label={t("settings.invalid")} actionLabel={t("common.reset_to_defaults")} onPress={() => void settings.reset()} />
            </>
          )}
          {isReady(settings) && <ReadySettings theme={theme} settings={settings} />}
        </SettingsCard>
      </SettingsSection>
      <Text style={{ color: theme.colors.foregroundMuted, fontSize: 12, lineHeight: 18, paddingHorizontal: 4 }}>
        {t("settings.footer")}
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
  const t = useT();
  const [binaryPath, setBinaryPath] = useState(settings.values.binaryPath);
  const saveBinary = () => void settings.save({ ...settings.values, binaryPath: binaryPath.trim() }, settings.revision);
  const reset = () => void settings.reset().then((saved) => { if (saved) setBinaryPath(""); });
  return (
    <>
      <SettingsInput
        label={t("settings.binary_label")}
        hint={t("settings.binary_hint")}
        initialValue={settings.values.binaryPath}
        onChangeText={setBinaryPath}
        placeholder="mathc"
      />
      <SettingsSelect
        label={t("settings.locale_label")}
        hint={t("settings.locale_hint")}
        value={settings.values.locale}
        options={[
          { label: t("settings.locale_auto"), value: "auto" },
          { label: t("settings.locale_en"), value: "en" },
          { label: t("settings.locale_ru"), value: "ru" },
        ]}
        onValueChange={(value) => void settings.save({ ...settings.values, locale: value as Preferences["locale"] }, settings.revision)}
        disabled={settings.saving}
      />
      <SettingsSelect
        label={t("settings.refresh_label")}
        hint={t("settings.refresh_hint")}
        value={String(settings.values.autoRefreshSeconds)}
        options={[
          { label: t("settings.refresh_off"), value: "0" },
          { label: t("settings.refresh_15"), value: "15" },
          { label: t("settings.refresh_30"), value: "30" },
          { label: t("settings.refresh_60"), value: "60" },
        ]}
        onValueChange={(value) => void settings.save({ ...settings.values, autoRefreshSeconds: Number(value) as 0 | 15 | 30 | 60 }, settings.revision)}
      />
      <SettingsSwitch
        label={t("settings.allow_run")}
        hint={t("settings.allow_run_hint")}
        value={settings.values.allowRunChecks}
        onValueChange={(value) => void settings.save({ ...settings.values, allowRunChecks: value }, settings.revision)}
        disabled={settings.saving}
      />
      <SettingsSwitch
        label={t("settings.allow_decisions")}
        hint={t("settings.allow_decisions_hint")}
        value={settings.values.allowHumanDecisions}
        onValueChange={(value) => void settings.save({ ...settings.values, allowHumanDecisions: value }, settings.revision)}
        disabled={settings.saving}
      />
      <SettingsAction label={t("settings.binary_path_label")} actionLabel={settings.saving ? t("common.saving") : t("common.save")} onPress={saveBinary} disabled={settings.saving || binaryPath.trim() === settings.values.binaryPath} />
      <SettingsAction label={t("settings.all_preferences")} actionLabel={t("common.reset")} onPress={reset} disabled={settings.saving} />
      {settings.saveError && <Text style={{ color: theme.colors.statusDanger, padding: 12 }}>{errorText(t, settings.saveError)}</Text>}
    </>
  );
}
