import type { Locale } from "./locale";

/**
 * The plural form of a language for a number.
 *
 * The rules are written out instead of asked of the runtime, because the
 * runtime of a host does not always carry them: Hermes, the engine of the
 * mobile application of the host, does not implement `Intl.PluralRules`, and a
 * name that is missing there is not a constructor. A panel that asks the
 * runtime for a plural form fails there and works everywhere else, which is
 * the worst way to fail.
 *
 * The console ships two languages, so the rules of two languages are written
 * out: English asks for `one` and `other`, Russian for `one`, `few` and `many`.
 */

export type PluralForm = "one" | "few" | "many" | "other";

/** English: one thing is one thing, every other number is other. */
function englishForm(count: number): PluralForm {
  return count === 1 ? "one" : "other";
}

/**
 * Russian: one is one, two to four are few, the rest are many.
 *
 * The rule of the language is the rule of the last two digits: `one` is a
 * number that ends in 1 but not in 11, `few` is a number that ends in 2, 3 or
 * 4 but not in 12, 13 or 14. A number with a fraction has no plural form.
 */
function russianForm(count: number): PluralForm {
  if (!Number.isInteger(count)) return "other";
  const number = Math.abs(count);
  const last = number % 10;
  const lastTwo = number % 100;
  if (last === 1 && lastTwo !== 11) return "one";
  if (last >= 2 && last <= 4 && (lastTwo < 12 || lastTwo > 14)) return "few";
  return "many";
}

/** The plural form of a language for a number. */
export function pluralForm(locale: Locale, count: number): PluralForm {
  return locale === "ru" ? russianForm(count) : englishForm(count);
}
