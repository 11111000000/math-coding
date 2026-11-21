import { createContext, useContext, type ReactNode } from "react";
import { translateNow } from "../i18n/current";
import type { HostContextValue } from "./contract";

const HostContext = createContext<HostContextValue | null>(null);

export function HostProvider({ value, children }: { value: HostContextValue; children: ReactNode }) {
  return <HostContext.Provider value={value}>{children}</HostContext.Provider>;
}

export function useHost(): HostContextValue {
  const value = useContext(HostContext);
  if (!value) {
    throw new Error(translateNow("error.host_provider_required"));
  }
  return value;
}
