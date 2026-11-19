import { createContext, useContext, useEffect, useMemo, type ReactNode } from "react";
import { preferencesDefinition } from "../../shared/schemas";
import { useHost } from "../host/context";
import { rememberLocale } from "./current";
import { resolveLocale, type Locale } from "./locale";
import { makeTranslator, type Translate } from "./translate";

/**
 * The language of the interface.
 *
 * The provider joins two sources: the choice of the human in the settings of
 * the plugin and the language of the host application. The choice wins, and
 * `auto` hands the decision to the host.
 *
 * The provider reads the settings of the host once, so a screen that draws
 * many texts does not read them many times.
 */

export type { Translate };

export interface LocaleContextValue {
  locale: Locale;
  t: Translate;
}

const LocaleContext = createContext<LocaleContextValue | null>(null);

export function LocaleProvider({ children }: { children: ReactNode }) {
  const host = useHost();
  const appLocale = host.useAppLocale();
  const settings = host.useSettings(preferencesDefinition);
  const preference = settings.status === "ready" ? settings.values?.locale ?? "auto" : "auto";
  const locale = resolveLocale(preference, appLocale);
  useEffect(() => {
    rememberLocale(locale);
  }, [locale]);
  const value = useMemo<LocaleContextValue>(
    () => ({ locale, t: makeTranslator(locale) }),
    [locale],
  );
  return <LocaleContext.Provider value={value}>{children}</LocaleContext.Provider>;
}

/**
 * The text of the interface in the language of the interface.
 *
 * Outside a provider the English catalogue answers, so a surface the provider
 * does not cover draws a readable interface instead of failing.
 */
export function useT(): Translate {
  const value = useContext(LocaleContext);
  return value?.t ?? makeTranslator("en");
}

/** The language the interface is drawn in. */
export function useLocale(): Locale {
  const value = useContext(LocaleContext);
  return value?.locale ?? "en";
}
