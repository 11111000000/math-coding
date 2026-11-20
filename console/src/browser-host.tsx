import { useCallback, useEffect, useState, type ReactNode } from "react";
import { TextInput as NativeTextInput } from "react-native-web";
import type { StyleProp, TextStyle } from "react-native";
import type { input as ZodInput, output as ZodOutput } from "zod";
import type {
  HostContextValue,
  HostIconProps,
  HostModalComponent,
  HostModalProps,
  HostRpcContract,
  HostTextInputProps,
} from "../../plugin/math-coding-console/client/host/contract";
import { useBrowserSettings } from "./browser-settings";
import { readJson, serverError } from "./http";
import { resolveIcon } from "./icons";
import { useToast } from "./toast";

/**
 * The browser implementation of the host surface.
 *
 * It answers exactly the contract the Paseo host answers, so the shared
 * interface, its data layer and its contracts stay single-sourced. Nothing
 * here re-implements console behaviour: the page only talks to the local
 * server and draws what the server returned.
 */

/* -------------------------------------------------------------------------- */
/* Icons                                                                       */
/* -------------------------------------------------------------------------- */

function BrowserIcon({ name, size = 16, color }: HostIconProps) {
  const { component: Glyph } = resolveIcon(name);
  return <Glyph size={size} color={color} aria-hidden="true" focusable="false" />;
}

/* -------------------------------------------------------------------------- */
/* Modal                                                                       */
/* -------------------------------------------------------------------------- */

function ModalView({ title, open, onOpenChange, children }: HostModalProps): ReactNode {
  useEffect(() => {
    if (!open) return;
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") onOpenChange(false);
    };
    document.addEventListener("keydown", onKeyDown);
    return () => document.removeEventListener("keydown", onKeyDown);
  }, [open, onOpenChange]);
  if (!open) return null;
  return (
    <div className="mc-modal-overlay" role="presentation" onClick={() => onOpenChange(false)}>
      <div
        className="mc-modal"
        role="dialog"
        aria-modal="true"
        aria-label={title}
        onClick={(event) => event.stopPropagation()}
      >
        {title ? <div className="mc-modal-title">{title}</div> : null}
        {children}
      </div>
    </div>
  );
}

function ModalContent({ children }: { children?: ReactNode }) {
  return <div className="mc-modal-content">{children}</div>;
}

const BrowserModal = Object.assign(ModalView, { Content: ModalContent }) as HostModalComponent;

/* -------------------------------------------------------------------------- */
/* Text input                                                                  */
/* -------------------------------------------------------------------------- */

function BrowserTextInput({
  value,
  onChangeText,
  placeholder,
  placeholderTextColor,
  accessibilityLabel,
  editable,
  style,
}: HostTextInputProps) {
  return (
    <NativeTextInput
      value={value}
      onChangeText={onChangeText}
      placeholder={placeholder}
      placeholderTextColor={placeholderTextColor}
      accessibilityLabel={accessibilityLabel}
      editable={editable}
      style={style as StyleProp<TextStyle>}
    />
  );
}

/* -------------------------------------------------------------------------- */
/* Settings primitives                                                         */
/* -------------------------------------------------------------------------- */

function SettingsSection({ title, children }: { title?: string; children?: ReactNode }) {
  return (
    <section className="mc-settings-section">
      {title ? <h2 className="mc-settings-section-title">{title}</h2> : null}
      {children}
    </section>
  );
}

function SettingsCard({ children }: { children?: ReactNode }) {
  return <div className="mc-settings-card">{children}</div>;
}

function SettingsInput({
  label,
  hint,
  initialValue,
  onChangeText,
  placeholder,
  disabled,
}: {
  label: string;
  hint?: string;
  initialValue?: string;
  onChangeText?: (value: string) => void;
  placeholder?: string;
  disabled?: boolean;
}) {
  return (
    <label className="mc-settings-row">
      <span className="mc-settings-label">{label}</span>
      {hint ? <span className="mc-settings-hint">{hint}</span> : null}
      <input
        className="mc-settings-input"
        type="text"
        defaultValue={initialValue}
        placeholder={placeholder}
        disabled={disabled}
        aria-label={label}
        onChange={(event) => onChangeText?.(event.target.value)}
      />
    </label>
  );
}

function SettingsSelect({
  label,
  hint,
  value,
  options,
  onValueChange,
  disabled,
}: {
  label: string;
  hint?: string;
  value: string;
  options: readonly { label: string; value: string }[];
  onValueChange: (value: string) => void;
  disabled?: boolean;
}) {
  return (
    <label className="mc-settings-row">
      <span className="mc-settings-label">{label}</span>
      {hint ? <span className="mc-settings-hint">{hint}</span> : null}
      <select
        className="mc-settings-select"
        value={value}
        disabled={disabled}
        aria-label={label}
        onChange={(event) => onValueChange(event.target.value)}
      >
        {options.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>
    </label>
  );
}

function SettingsAction({
  label,
  actionLabel,
  onPress,
  disabled,
}: {
  label: string;
  actionLabel: string;
  onPress: () => void;
  disabled?: boolean;
}) {
  return (
    <div className="mc-settings-row">
      <span className="mc-settings-label">{label}</span>
      <button className="mc-settings-action" type="button" disabled={disabled} onClick={() => onPress()}>
        {actionLabel}
      </button>
    </div>
  );
}

function SettingsSwitch({
  label,
  hint,
  value,
  onValueChange,
  disabled,
}: {
  label: string;
  hint?: string;
  value: boolean;
  onValueChange: (value: boolean) => void;
  disabled?: boolean;
}) {
  return (
    <label className="mc-settings-row">
      <span className="mc-settings-label">{label}</span>
      {hint ? <span className="mc-settings-hint">{hint}</span> : null}
      <input
        className="mc-settings-switch"
        type="checkbox"
        checked={value}
        disabled={disabled}
        aria-label={label}
        onChange={(event) => onValueChange(event.target.checked)}
      />
    </label>
  );
}

/* -------------------------------------------------------------------------- */
/* Clipboard                                                                   */
/* -------------------------------------------------------------------------- */

async function copyText(text: string): Promise<void> {
  const clipboard = typeof navigator === "undefined" ? undefined : navigator.clipboard;
  if (clipboard && typeof clipboard.writeText === "function") {
    try {
      await clipboard.writeText(text);
      return;
    } catch {
      // The browser refused the clipboard; the fallback below may still work.
    }
  }
  if (typeof document !== "undefined" && typeof document.execCommand === "function") {
    const area = document.createElement("textarea");
    area.value = text;
    area.setAttribute("readonly", "");
    area.style.position = "fixed";
    area.style.opacity = "0";
    document.body.appendChild(area);
    try {
      area.select();
      if (document.execCommand("copy")) return;
    } catch {
      // Fall through to the rejection below.
    } finally {
      document.body.removeChild(area);
    }
  }
  throw new Error("The clipboard is not available in this browser");
}

/* -------------------------------------------------------------------------- */
/* RPC                                                                         */
/* -------------------------------------------------------------------------- */

function useBrowserRpc<Contract extends HostRpcContract>(
  contract: Contract,
): (input: ZodInput<Contract["input"]>) => Promise<ZodOutput<Contract["output"]>> {
  const call = useCallback(
    async (input: unknown) => {
      const parsedInput = contract.input.parse(input);
      const response = await fetch(`/api/${contract.name}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(parsedInput),
      });
      const body = await readJson(response);
      if (!response.ok) {
        throw new Error(serverError(body, `${contract.name} failed with status ${String(response.status)}`));
      }
      return contract.output.parse(body);
    },
    [contract],
  );
  return call as (input: ZodInput<Contract["input"]>) => Promise<ZodOutput<Contract["output"]>>;
}

/* -------------------------------------------------------------------------- */
/* The host                                                                    */
/* -------------------------------------------------------------------------- */

/**
 * The language of the browser.
 *
 * The page has no application around it, so the language of the browser is the
 * language of the host. A change of it reaches the interface without a reload.
 */
function useAppLocale(): string {
  const [locale, setLocale] = useState(() =>
    typeof navigator === "undefined" ? "en" : navigator.language,
  );
  useEffect(() => {
    if (typeof window === "undefined") return;
    const onChange = () => setLocale(navigator.language);
    window.addEventListener("languagechange", onChange);
    return () => window.removeEventListener("languagechange", onChange);
  }, []);
  return locale;
}

export function createBrowserHost(): HostContextValue {
  return {
    Icon: BrowserIcon,
    Modal: BrowserModal,
    TextInput: BrowserTextInput,
    SettingsSection,
    SettingsCard,
    SettingsInput,
    SettingsSelect,
    SettingsAction,
    SettingsSwitch,
    useAppLocale,
    copyText,
    useToast,
    useRpc: useBrowserRpc,
    useSettings: useBrowserSettings,
  };
}
