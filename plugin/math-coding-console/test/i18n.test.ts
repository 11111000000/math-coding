import assert from "node:assert/strict";
import { test } from "node:test";
import { en } from "../shared/locales/en";
import { ru } from "../shared/locales/ru";
import { ERROR_CODES, ERROR_KEYS } from "../shared/errors";
import { makeTranslator, renderValue, translate } from "../client/i18n/translate";
import { normalizeLocale, resolveLocale } from "../client/i18n/locale";

/**
 * The catalogue is a contract between two languages.
 *
 * English names the keys, Russian translates exactly these keys. A key that
 * exists in only one of them is a defect, and it is a defect that no type can
 * catch: both catalogues are well-formed objects. These tests are the check.
 */

const PLURAL_FORMS = ["one", "few", "many", "other"] as const;

function flatten(catalogue: unknown, prefix = ""): Map<string, string> {
  const result = new Map<string, string>();
  for (const [name, value] of Object.entries(catalogue as Record<string, unknown>)) {
    const key = prefix ? `${prefix}.${name}` : name;
    if (typeof value === "string") result.set(key, value);
    else for (const [child, text] of flatten(value, key)) result.set(child, text);
  }
  return result;
}

/** The name of a key without the plural form the language appends to it. */
function baseOf(key: string): string {
  for (const form of PLURAL_FORMS) {
    if (key.endsWith(`_${form}`)) return key.slice(0, -form.length - 1);
  }
  return key;
}

const english = flatten(en);
const russian = flatten(ru);

test("the Russian catalogue holds no key the English one does not name", () => {
  const extra: string[] = [];
  for (const key of russian.keys()) {
    const base = baseOf(key);
    if (!english.has(base) && !english.has(`${base}_other`)) extra.push(key);
  }
  assert.deepEqual(extra, []);
});

test("every English key has a Russian translation", () => {
  const missing: string[] = [];
  for (const key of english.keys()) {
    const base = baseOf(key);
    const translated = PLURAL_FORMS.some((form) => russian.has(`${base}_${form}`)) || russian.has(base);
    if (!translated) missing.push(key);
  }
  assert.deepEqual(missing, []);
});

test("a counted key has every plural form the Russian language asks for", () => {
  const incomplete: string[] = [];
  for (const key of english.keys()) {
    if (!key.endsWith("_other")) continue;
    const base = baseOf(key);
    for (const form of ["one", "few", "many", "other"] as const) {
      if (!russian.has(`${base}_${form}`)) incomplete.push(`${base}_${form}`);
    }
  }
  assert.deepEqual(incomplete, []);
});

test("the placeholders of a key are the same in both languages", () => {
  const mismatched: string[] = [];
  for (const [key, text] of english) {
    const base = baseOf(key);
    const translated = russian.get(key) ?? russian.get(`${base}_other`);
    if (translated === undefined) continue;
    const placeholders = (value: string) => [...value.matchAll(/\{\{\s*([\w.-]+)\s*\}\}/g)].map((match) => match[1]).sort();
    if (placeholders(text).join(",") !== placeholders(translated).join(",")) mismatched.push(key);
  }
  assert.deepEqual(mismatched, []);
});

test("every error code has a sentence in both languages", () => {
  const missing: string[] = [];
  for (const code of ERROR_CODES) {
    const key = ERROR_KEYS[code];
    if (translate("en", key) === key) missing.push(`${code} (en)`);
    if (translate("ru", key) === key) missing.push(`${code} (ru)`);
  }
  assert.deepEqual(missing, []);
});

test("the resolver fills the placeholders of a text", () => {
  const text = translate("en", "panel.refresh_failed", { time: "12:00", error: "boom" });
  assert.match(text, /12:00/);
  assert.match(text, /boom/);
  assert.doesNotMatch(text, /\{\{/);
});

test("the resolver picks the plural form the language asks for", () => {
  assert.match(translate("ru", "queue.count_decisions", { count: 1 }), /решение нельзя/);
  assert.match(translate("ru", "queue.count_decisions", { count: 2 }), /решения нельзя/);
  assert.match(translate("ru", "queue.count_decisions", { count: 5 }), /решений нельзя/);
  assert.match(translate("en", "queue.count_decisions", { count: 1 }), /1 decision\(s\)/);
  assert.match(translate("en", "queue.count_decisions", { count: 5 }), /5 decision\(s\)/);
});

test("a key the catalogue does not hold is shown as it is", () => {
  assert.equal(translate("en", "no.such.key"), "no.such.key");
});

test("the translator answers a key and a descriptor with one call", () => {
  const t = makeTranslator("ru");
  assert.equal(t("common.close"), translate("ru", "common.close"));
  assert.equal(t({ key: "common.close" }), translate("ru", "common.close"));
  assert.equal(t({ key: "queue.count_decisions", args: { count: 3 } }), translate("ru", "queue.count_decisions", { count: 3 }));
});

test("a value of the project is shown as it is", () => {
  const t = makeTranslator("ru");
  assert.equal(renderValue(t, "the claim holds"), "the claim holds");
  assert.equal(renderValue(t, { key: "common.close" }), translate("ru", "common.close"));
});

test("the language of the host is matched by its language part", () => {
  assert.equal(normalizeLocale("ru-RU"), "ru");
  assert.equal(normalizeLocale("ru"), "ru");
  assert.equal(normalizeLocale("en-US"), "en");
  assert.equal(normalizeLocale("de-DE"), "en");
  assert.equal(normalizeLocale(undefined), "en");
});

test("the preference of the human decides the language of the interface", () => {
  assert.equal(resolveLocale("auto", "ru-RU"), "ru");
  assert.equal(resolveLocale("auto", "en-US"), "en");
  assert.equal(resolveLocale("auto", "de-DE"), "en");
  assert.equal(resolveLocale("en", "ru-RU"), "en");
  assert.equal(resolveLocale("ru", "en-US"), "ru");
});
