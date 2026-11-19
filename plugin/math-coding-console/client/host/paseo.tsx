import { defineTranslations, useRpc, useSettings, useTranslation } from "@getpaseo/plugin/client";
import {
  Icon,
  Modal,
  SettingsAction,
  SettingsCard,
  SettingsInput,
  SettingsSection,
  SettingsSelect,
  SettingsSwitch,
  TextInput,
  copyText,
  useToast,
} from "@getpaseo/plugin/client/ui";
import type { HostContextValue } from "./contract";
import { en } from "../../shared/locales/en";
import { ru } from "../../shared/locales/ru";

/**
 * The catalogue the host draws with.
 *
 * The host renders a few labels of its own: the title of the panel, the entry
 * of the command center, the description of the slash command. Those labels
 * belong to the host, so the host resolves them, in the language of the
 * application. The catalogue is the same one the interface draws with.
 */
export const messages = defineTranslations({ resources: { en, ru } });

/**
 * The language the application speaks.
 *
 * The runtime of the host knows it and tells it when it changes, so the
 * interface follows the language of the application without a reload.
 */
function useAppLocale(): string {
  const { locale } = useTranslation(messages);
  return locale;
}

/**
 * The Paseo implementation of the host surface.
 *
 * It is the only module in the shared interface that is allowed to import the
 * Paseo host packages. Every other module goes through the host contract.
 */
export function createPaseoHost(): HostContextValue {
  return {
    Icon: Icon as unknown as HostContextValue["Icon"],
    Modal: Modal as unknown as HostContextValue["Modal"],
    TextInput: TextInput as unknown as HostContextValue["TextInput"],
    SettingsSection: SettingsSection as unknown as HostContextValue["SettingsSection"],
    SettingsCard: SettingsCard as unknown as HostContextValue["SettingsCard"],
    SettingsInput: SettingsInput as unknown as HostContextValue["SettingsInput"],
    SettingsSelect: SettingsSelect as unknown as HostContextValue["SettingsSelect"],
    SettingsAction: SettingsAction as unknown as HostContextValue["SettingsAction"],
    SettingsSwitch: SettingsSwitch as unknown as HostContextValue["SettingsSwitch"],
    useAppLocale,
    copyText,
    useToast,
    useRpc: ((contract: never) => useRpc(contract)) as HostContextValue["useRpc"],
    useSettings: ((definition: never) => useSettings(definition)) as HostContextValue["useSettings"],
  };
}
