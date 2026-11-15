import type { ComponentType, ReactNode } from "react";
import type { ZodType, input as ZodInput, output as ZodOutput } from "zod";

/**
 * The complete host surface of the console.
 *
 * The shared interface may only reach the host through these members. The
 * Paseo plugin and the local browser page implement the same surface, so the
 * interface code, the data layer and the contract stay single-sourced.
 */
export interface HostIconProps {
  name: string;
  size?: number;
  color?: string;
}

export interface HostModalProps {
  title?: string;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  children?: ReactNode;
}

export interface HostModalComponent {
  (props: HostModalProps): ReactNode;
  Content: ComponentType<{ children?: ReactNode }>;
}

export interface HostTextInputProps {
  value?: string;
  onChangeText?: (value: string) => void;
  placeholder?: string;
  placeholderTextColor?: string;
  accessibilityLabel?: string;
  editable?: boolean;
  style?: unknown;
}

export interface HostToast {
  show(message: string, options?: { variant?: "success" | "error" | "warning" | "info" }): void;
  error(message: string): void;
}

export interface HostSettingsState<Values> {
  status: "loading" | "ready" | "error" | "invalid";
  values?: Values;
  error?: string;
  revision?: string;
  saving: boolean;
  saveError: string | null;
  save(values: Values, revision: string): Promise<boolean>;
  reset(): Promise<boolean>;
  reload(): Promise<void>;
}

export interface HostSettingsSectionProps {
  title?: string;
  children?: ReactNode;
}

export interface HostSettingsCardProps {
  children?: ReactNode;
}

export interface HostSettingsInputProps {
  label: string;
  hint?: string;
  initialValue?: string;
  onChangeText?: (value: string) => void;
  placeholder?: string;
  disabled?: boolean;
}

export interface HostSettingsSelectProps {
  label: string;
  hint?: string;
  value: string;
  options: readonly { label: string; value: string }[];
  onValueChange: (value: string) => void;
  disabled?: boolean;
}

export interface HostSettingsActionProps {
  label: string;
  actionLabel: string;
  onPress: () => void;
  disabled?: boolean;
}

export interface HostSettingsSwitchProps {
  label: string;
  hint?: string;
  value: boolean;
  onValueChange: (value: boolean) => void;
  disabled?: boolean;
}

export interface HostRpcContract<Input extends ZodType = ZodType, Output extends ZodType = ZodType> {
  name: string;
  input: Input;
  output: Output;
}

export interface HostSettingsDefinition<Schema extends ZodType = ZodType> {
  id: string;
  scope: "host";
  version: number;
  schema: Schema;
  migrate?: (values: unknown, fromVersion: number) => unknown | Promise<unknown>;
}

export interface HostContextValue {
  Icon: ComponentType<HostIconProps>;
  Modal: HostModalComponent;
  TextInput: ComponentType<HostTextInputProps>;
  SettingsSection: ComponentType<HostSettingsSectionProps>;
  SettingsCard: ComponentType<HostSettingsCardProps>;
  SettingsInput: ComponentType<HostSettingsInputProps>;
  SettingsSelect: ComponentType<HostSettingsSelectProps>;
  SettingsAction: ComponentType<HostSettingsActionProps>;
  SettingsSwitch: ComponentType<HostSettingsSwitchProps>;
  copyText: (text: string) => Promise<void>;
  useToast: () => HostToast;
  useRpc: <Contract extends HostRpcContract>(
    contract: Contract,
  ) => (input: ZodInput<Contract["input"]>) => Promise<ZodOutput<Contract["output"]>>;
  useSettings: <Definition extends HostSettingsDefinition>(
    definition: Definition,
  ) => HostSettingsState<ZodOutput<Definition["schema"]>>;
}
