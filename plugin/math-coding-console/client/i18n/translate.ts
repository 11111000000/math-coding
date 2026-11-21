import { en } from "../../shared/locales/en";
import { ru } from "../../shared/locales/ru";
import type { MessageArgs, MessageKey, MessageRef } from "../../shared/message";
import { FALLBACK_LOCALE, type Locale } from "./locale";
import { pluralForm } from "./plural";

/**
 * The resolver of the interface text.
 *
 * It reads the catalogue, picks the plural form the language asks for and
 * fills the placeholders. It knows nothing about the host: the host only says
 * which language it speaks, and the same resolver serves the plugin and the
 * local console.
 */

export type { MessageArgs };

const catalogues: Record<Locale, unknown> = { en, ru };

function lookup(catalogue: unknown, path: string): string | undefined {
  let node: unknown = catalogue;
  for (const segment of path.split(".")) {
    if (typeof node !== "object" || node === null) return undefined;
    node = (node as Record<string, unknown>)[segment];
  }
  return typeof node === "string" ? node : undefined;
}

/**
 * The candidates of a key, in the order the resolver tries them.
 *
 * A key with a count is named by its base; the language asks for the form. The
 * `_other` form is the last resort of every language, and the bare key closes
 * the row for the texts that carry no number at all.
 */
function candidates(locale: Locale, key: string, args: MessageArgs | undefined): string[] {
  const count = typeof args?.count === "number" ? args.count : undefined;
  if (count === undefined) return [key, `${key}_other`];
  const form = pluralForm(locale, count);
  return form === "other" ? [`${key}_other`, key] : [`${key}_${form}`, `${key}_other`, key];
}

function interpolate(locale: Locale, template: string, args: MessageArgs | undefined): string {
  if (!args) return template;
  return template.replace(/\{\{\s*([\w.-]+)\s*\}\}/g, (match, name: string) => {
    const value = args[name];
    if (value === undefined) return match;
    if (typeof value === "object") return translate(locale, value.key, value.args);
    return String(value);
  });
}

/**
 * The text of a key in a language.
 *
 * A key the catalogue does not hold is returned as the key itself: the
 * interface shows what is missing instead of showing nothing, and the check of
 * the catalogue refuses such a gap before it reaches a release.
 */
export function translate(locale: Locale, key: string, args?: MessageArgs): string {
  for (const candidate of candidates(locale, key, args)) {
    const found = lookup(catalogues[locale], candidate);
    if (found !== undefined) return interpolate(locale, found, args);
  }
  for (const candidate of candidates(FALLBACK_LOCALE, key, args)) {
    const found = lookup(catalogues[FALLBACK_LOCALE], candidate);
    if (found !== undefined) return interpolate(locale, found, args);
  }
  return key;
}

/**
 * The translator of the interface.
 *
 * It answers two questions with one call: a key of the catalogue, and a
 * descriptor that names a key and the values of its placeholders. The model of
 * the console carries descriptors, the screen carries keys; both end up here.
 */
export interface Translate {
  (key: MessageKey, args?: MessageArgs): string;
  (ref: MessageRef): string;
}

/** The translator of one language. */
export function makeTranslator(locale: Locale): Translate {
  return ((keyOrRef: MessageKey | MessageRef, args?: MessageArgs) => {
    if (typeof keyOrRef === "string") return translate(locale, keyOrRef, args);
    return translate(locale, keyOrRef.key, keyOrRef.args);
  }) as Translate;
}

/**
 * The text of a value that may be data.
 *
 * A claim carries its own text, and that text belongs to the project: it is
 * shown as it is. A descriptor names a text of the interface, and that text is
 * read in the language of the human.
 */
export function renderValue(t: Translate, value: string | MessageRef): string {
  return typeof value === "string" ? value : t(value);
}
