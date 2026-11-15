import { useRpc, useSettings } from "@getpaseo/plugin/client";
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
    copyText,
    useToast,
    useRpc: ((contract: never) => useRpc(contract)) as HostContextValue["useRpc"],
    useSettings: ((definition: never) => useSettings(definition)) as HostContextValue["useSettings"],
  };
}
