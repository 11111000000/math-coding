/**
 * The console's own theme contract.
 *
 * It mirrors exactly the colours the interface uses. The Paseo host theme has
 * the same shape, so a host theme can be passed to the shared components
 * without conversion, and the browser host can build its own theme from CSS
 * variables without importing anything from Paseo.
 */
export interface ConsoleThemeColors {
  readonly surface0: string;
  readonly surface1: string;
  readonly surface2: string;
  readonly border: string;
  readonly foreground: string;
  readonly foregroundMuted: string;
  readonly accent: string;
  readonly accentForeground: string;
  readonly statusSuccess: string;
  readonly statusWarning: string;
  readonly statusDanger: string;
}

export interface ConsoleTheme {
  readonly colors: ConsoleThemeColors;
}
