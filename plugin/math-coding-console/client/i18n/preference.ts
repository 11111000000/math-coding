import { useSyncExternalStore } from "react";
import type { Preferences } from "../../shared/schemas";

/**
 * The language the human chose in this session.
 *
 * The choice of the language lives in the preferences of the host, but a host
 * answers the preferences to every reader with its own state. The provider of
 * the language and the screen of the settings are two such readers, so a choice
 * made in the screen would reach the file and not the interface, and the
 * interface would keep the old language until the page is reloaded.
 *
 * This channel carries the choice to every reader of the plugin, so the switch
 * reaches the interface at once, on any host. The choice of the session wins
 * over the stored preference; until the human chooses, the stored preference
 * governs.
 */

export type LocalePreference = Preferences["locale"];

let chosen: LocalePreference | undefined;
const listeners = new Set<() => void>();

/** The language the human chose in this session, if they chose one. */
export function localePreference(): LocalePreference | undefined {
  return chosen;
}

/** Announces the language the human chose to every reader of the plugin. */
export function setLocalePreference(value: LocalePreference | undefined): void {
  if (chosen === value) return;
  chosen = value;
  for (const listener of [...listeners]) listener();
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

/** The language the human chose in this session, as the interface sees it. */
export function useLocalePreference(): LocalePreference | undefined {
  return useSyncExternalStore(subscribe, localePreference, localePreference);
}
