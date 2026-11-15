import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { TextInput as NativeTextInput } from "react-native-web";
import type { StyleProp, TextStyle } from "react-native";
import type { input as ZodInput, output as ZodOutput } from "zod";
import type {
  HostContextValue,
  HostIconProps,
  HostModalComponent,
  HostModalProps,
  HostRpcContract,
  HostSettingsDefinition,
  HostSettingsState,
  HostTextInputProps,
} from "../../plugin/math-coding-console/client/host/contract";
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

const SETTINGS_ENDPOINT = "/api/settings";

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

async function readJson(response: Response): Promise<unknown> {
  const text = await response.text();
  if (text.trim() === "") return null;
  try {
    return JSON.parse(text) as unknown;
  } catch {
    return null;
  }
}

function serverError(body: unknown, fallback: string): string {
  if (typeof body === "object" && body !== null && "error" in body) {
    const value = (body as { error: unknown }).error;
    if (typeof value === "string" && value !== "") return value;
  }
  return fallback;
}

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
/* Settings                                                                    */
/* -------------------------------------------------------------------------- */

interface SettingsReadResult {
  status: "ready" | "invalid";
  revision: string;
  values?: unknown;
  error?: string;
}

interface SettingsWriteResult {
  status: "saved" | "conflict" | "invalid";
  revision?: string;
  values?: unknown;
  error?: string;
}

function useBrowserSettings<Definition extends HostSettingsDefinition>(
  definition: Definition,
): HostSettingsState<ZodOutput<Definition["schema"]>> {
  type Values = ZodOutput<Definition["schema"]>;
  const [status, setStatus] = useState<HostSettingsState<Values>["status"]>("loading");
  const [values, setValues] = useState<Values | undefined>(undefined);
  const [error, setError] = useState<string | undefined>(undefined);
  const [revision, setRevision] = useState<string | undefined>(undefined);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const alive = useRef(true);

  useEffect(() => {
    alive.current = true;
    return () => {
      alive.current = false;
    };
  }, []);

  const reload = useCallback(async () => {
    try {
      const response = await fetch(SETTINGS_ENDPOINT, { headers: { Accept: "application/json" } });
      const body = (await readJson(response)) as SettingsReadResult | null;
      if (!alive.current) return;
      if (!response.ok || !body) {
        setStatus("error");
        setError(`Settings are unavailable (${String(response.status)})`);
        return;
      }
      setRevision(body.revision);
      if (body.status === "ready") {
        setStatus("ready");
        setValues(body.values as Values);
        setError(undefined);
      } else {
        setStatus("invalid");
        setValues(undefined);
        setError(body.error ?? "The stored settings are invalid");
      }
    } catch (failure) {
      if (!alive.current) return;
      setStatus("error");
      setError(errorMessage(failure));
    }
  }, []);

  useEffect(() => {
    void reload();
  }, [reload, definition.id]);

  const save = useCallback(
    async (next: Values, currentRevision: string): Promise<boolean> => {
      setSaving(true);
      setSaveError(null);
      try {
        const response = await fetch(SETTINGS_ENDPOINT, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ revision: currentRevision, values: next }),
        });
        const body = (await readJson(response)) as SettingsWriteResult | null;
        if (!alive.current) return false;
        if (!response.ok || !body) {
          setSaveError(serverError(body, `Settings could not be saved (${String(response.status)})`));
          return false;
        }
        if (body.status === "saved") {
          setStatus("ready");
          setValues(body.values as Values);
          setRevision(body.revision);
          setError(undefined);
          return true;
        }
        setSaveError(body.error ?? "The settings were not saved");
        return false;
      } catch (failure) {
        if (alive.current) setSaveError(errorMessage(failure));
        return false;
      } finally {
        if (alive.current) setSaving(false);
      }
    },
    [],
  );

  const reset = useCallback(async (): Promise<boolean> => {
    setSaving(true);
    setSaveError(null);
    try {
      const response = await fetch(`${SETTINGS_ENDPOINT}/reset`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({}),
      });
      const body = (await readJson(response)) as SettingsWriteResult | null;
      if (!alive.current) return false;
      if (!response.ok || !body || body.status !== "saved") {
        setSaveError(serverError(body, "The settings were not reset"));
        return false;
      }
      setStatus("ready");
      setValues(body.values as Values);
      setRevision(body.revision);
      setError(undefined);
      return true;
    } catch (failure) {
      if (alive.current) setSaveError(errorMessage(failure));
      return false;
    } finally {
      if (alive.current) setSaving(false);
    }
  }, []);

  return useMemo(
    () => ({ status, values, error, revision, saving, saveError, save, reset, reload }),
    [status, values, error, revision, saving, saveError, save, reset, reload],
  );
}

/* -------------------------------------------------------------------------- */
/* The host                                                                    */
/* -------------------------------------------------------------------------- */

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
    copyText,
    useToast,
    useRpc: useBrowserRpc,
    useSettings: useBrowserSettings,
  };
}
