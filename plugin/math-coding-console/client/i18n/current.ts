import { FALLBACK_LOCALE, type Locale } from "./locale";
import { translate, type MessageArgs } from "./translate";

/**
 * The language of the interface outside the React tree.
 *
 * The boundary of a host sheet is drawn by the host outside the tree of the
 * panel, so it cannot read the context of the provider. It reads the language
 * the provider resolved last, and falls back to English when nothing has
 * resolved a language yet.
 */

let current: Locale = FALLBACK_LOCALE;

export function rememberLocale(locale: Locale): void {
  current = locale;
}

export function rememberedLocale(): Locale {
  return current;
}

/** The text of a key in the language the interface is drawn in. */
export function translateNow(key: string, args?: MessageArgs): string {
  return translate(current, key, args);
}
