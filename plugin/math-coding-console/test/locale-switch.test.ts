import assert from "node:assert/strict";
import { act, createElement } from "react";
import TestRenderer from "react-test-renderer";
import test from "node:test";
import { host } from "./host-stub";
import { HostProvider } from "../client/host/context";
import { LocaleProvider, setLocalePreference, useT } from "../client/i18n";

/**
 * The switch of the language.
 *
 * The interface follows the choice of the human at once, without a reload. The
 * choice lives in the preferences of the host, and a host may answer the
 * preferences to every reader with its own state, so the plugin announces the
 * choice to its own readers as well.
 *
 * The check draws the interface, changes the language and asks the drawing to
 * change with it. The tree stays mounted the whole time: a reload would hide
 * the defect the check looks for.
 */

(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;

function Probe() {
  const t = useT();
  return createElement("span", null, t("settings.locale_label"));
}

function draw(): TestRenderer.ReactTestRenderer {
  let renderer!: TestRenderer.ReactTestRenderer;
  act(() => {
    renderer = TestRenderer.create(
      createElement(HostProvider, {
        value: host,
        children: createElement(LocaleProvider, { children: createElement(Probe) }),
      }),
    );
  });
  return renderer;
}

test("the language of the interface follows the choice of the human at once", () => {
  setLocalePreference(undefined);
  const renderer = draw();
  const markup = () => JSON.stringify(renderer.toJSON());
  assert.match(markup(), /Interface language/);

  act(() => {
    setLocalePreference("ru");
  });
  assert.match(markup(), /Язык интерфейса/);
  assert.doesNotMatch(markup(), /Interface language/);

  act(() => {
    setLocalePreference("en");
  });
  assert.match(markup(), /Interface language/);

  act(() => {
    setLocalePreference(undefined);
  });
  assert.match(markup(), /Interface language/);
});

test("the choice of the session is over the stored preference", () => {
  setLocalePreference(undefined);
  const renderer = draw();
  const markup = () => JSON.stringify(renderer.toJSON());

  act(() => {
    setLocalePreference("ru");
  });
  assert.match(markup(), /Язык интерфейса/);

  // The stored preference of the host says "auto", and the host speaks
  // English. The choice of the session wins over both.
  act(() => {
    setLocalePreference(undefined);
  });
  assert.match(markup(), /Interface language/);
});
