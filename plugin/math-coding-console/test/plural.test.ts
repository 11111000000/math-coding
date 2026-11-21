import assert from "node:assert/strict";
import { test } from "node:test";
import { pluralForm } from "../client/i18n/plural";
import { translate } from "../client/i18n/translate";

/**
 * The plural form is written out, not asked of the runtime.
 *
 * The host draws the panel on engines that do not carry `Intl.PluralRules`:
 * Hermes, the engine of the mobile application, has no such name, and a name
 * that is missing is not a constructor. The panel then fails where it works
 * everywhere else. These tests check the rule of the language and check that
 * the resolver asks the runtime for nothing.
 */

type MutableIntl = { PluralRules?: unknown };

function withIntl<T>(replacement: unknown, body: () => T): T {
  const intl = Intl as unknown as MutableIntl;
  const original = intl.PluralRules;
  intl.PluralRules = replacement;
  try {
    return body();
  } finally {
    intl.PluralRules = original;
  }
}

test("English asks for one thing and for other things", () => {
  assert.equal(pluralForm("en", 1), "one");
  assert.equal(pluralForm("en", 0), "other");
  assert.equal(pluralForm("en", 2), "other");
  assert.equal(pluralForm("en", 5), "other");
});

test("Russian asks for one, for few and for many", () => {
  assert.equal(pluralForm("ru", 1), "one");
  assert.equal(pluralForm("ru", 2), "few");
  assert.equal(pluralForm("ru", 4), "few");
  assert.equal(pluralForm("ru", 5), "many");
  assert.equal(pluralForm("ru", 0), "many");
  assert.equal(pluralForm("ru", 11), "many");
  assert.equal(pluralForm("ru", 12), "many");
  assert.equal(pluralForm("ru", 21), "one");
  assert.equal(pluralForm("ru", 22), "few");
  assert.equal(pluralForm("ru", 25), "many");
});

test("a number with a fraction has no plural form", () => {
  assert.equal(pluralForm("ru", 1.5), "other");
  assert.equal(pluralForm("en", 1.5), "other");
});

test("the resolver asks the runtime for nothing", () => {
  withIntl(
    () => {
      throw new Error("the runtime was asked for a plural rule");
    },
    () => {
      assert.match(translate("ru", "queue.count_decisions", { count: 1 }), /решение нельзя/);
      assert.match(translate("ru", "queue.count_decisions", { count: 2 }), /решения нельзя/);
      assert.match(translate("ru", "queue.count_decisions", { count: 5 }), /решений нельзя/);
      assert.match(translate("en", "queue.count_decisions", { count: 1 }), /1 decision\(s\)/);
    },
  );
});

test("the resolver works on a runtime without plural rules", () => {
  withIntl(undefined, () => {
    assert.equal(pluralForm("ru", 2), "few");
    assert.match(translate("ru", "queue.count_decisions", { count: 2 }), /решения нельзя/);
    assert.match(translate("en", "queue.count_decisions", { count: 5 }), /5 decision\(s\)/);
  });
});
