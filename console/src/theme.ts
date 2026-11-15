import { useEffect, useState } from "react";
import type { ConsoleTheme } from "../../plugin/math-coding-console/shared/theme";

/**
 * The browser palettes of the console.
 *
 * They follow the shared theme contract exactly: the same eleven colours the
 * Paseo host provides, so the interface components receive the same shape and
 * never learn where they run.
 */

export type ThemeMode = "light" | "dark";

export const lightTheme: ConsoleTheme = {
  colors: {
    surface0: "#ffffff",
    surface1: "#f5f6f8",
    surface2: "#e9ecf1",
    border: "#d5dae1",
    foreground: "#14181f",
    foregroundMuted: "#5b6472",
    accent: "#2f6f4f",
    accentForeground: "#ffffff",
    statusSuccess: "#1f7a45",
    statusWarning: "#9a6400",
    statusDanger: "#b3261e",
  },
};

export const darkTheme: ConsoleTheme = {
  colors: {
    surface0: "#101318",
    surface1: "#171b21",
    surface2: "#1f242c",
    border: "#2c333d",
    foreground: "#e8ecf1",
    foregroundMuted: "#9aa4b2",
    accent: "#6ee7a8",
    accentForeground: "#0d1117",
    statusSuccess: "#4ade80",
    statusWarning: "#fbbf24",
    statusDanger: "#f87171",
  },
};

export function themeForMode(mode: ThemeMode): ConsoleTheme {
  return mode === "dark" ? darkTheme : lightTheme;
}

export function systemMode(): ThemeMode {
  if (typeof window === "undefined" || typeof window.matchMedia !== "function") return "light";
  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

/**
 * The theme of the operating system.
 *
 * The page follows the system preference and follows it when the system
 * changes it. No manual switch is added: the console keeps one appearance.
 */
export function useSystemTheme(): ConsoleTheme {
  const [theme, setTheme] = useState<ConsoleTheme>(() => themeForMode(systemMode()));
  useEffect(() => {
    if (typeof window === "undefined" || typeof window.matchMedia !== "function") return;
    const query = window.matchMedia("(prefers-color-scheme: dark)");
    const update = () => setTheme(themeForMode(query.matches ? "dark" : "light"));
    update();
    query.addEventListener("change", update);
    return () => query.removeEventListener("change", update);
  }, []);
  return theme;
}

function cssVariableName(key: string): string {
  return `--mc-${key.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`)}`;
}

/** Publishes the palette as CSS variables for the browser-side host pieces. */
export function applyTheme(theme: ConsoleTheme): void {
  if (typeof document === "undefined") return;
  const root = document.documentElement;
  for (const [key, value] of Object.entries(theme.colors)) {
    root.style.setProperty(cssVariableName(key), value);
  }
  root.style.colorScheme = theme === darkTheme ? "dark" : "light";
}
