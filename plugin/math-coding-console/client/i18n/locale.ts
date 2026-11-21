/**
 * The languages of the interface.
 *
 * The console speaks two languages: English and Russian. English is the
 * source of the keys, so a language that is missing a key falls back to it
 * rather than showing an empty string.
 */

export const SUPPORTED_LOCALES = ["en", "ru"] as const;

export type Locale = (typeof SUPPORTED_LOCALES)[number];

/** The language of the catalogue when the requested one is not shipped. */
export const FALLBACK_LOCALE: Locale = "en";

/**
 * The language a host speaks, mapped onto a language the console ships.
 *
 * A regional tag is matched by its language: `ru-RU` is Russian. A language the
 * console does not ship falls back to English, because a half-translated
 * interface is worse than an English one.
 */
export function normalizeLocale(locale: string | undefined | null): Locale {
  if (!locale) return FALLBACK_LOCALE;
  const tag = locale.trim().toLowerCase();
  if (tag === "ru" || tag.startsWith("ru-")) return "ru";
  return FALLBACK_LOCALE;
}

/**
 * The language the interface is drawn in.
 *
 * The preference is the choice of the human: `auto` follows the host, an
 * explicit language overrides it.
 */
export function resolveLocale(preference: string, appLocale: string): Locale {
  if (preference === "ru") return "ru";
  if (preference === "en") return "en";
  return normalizeLocale(appLocale);
}
