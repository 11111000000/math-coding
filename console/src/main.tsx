import { StrictMode, useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ConsolePanel } from "../../plugin/math-coding-console/client/console";
import { HostProvider } from "../../plugin/math-coding-console/client/host/context";
import { LocaleProvider, useT } from "../../plugin/math-coding-console/client/i18n";
import { SettingsScreen } from "../../plugin/math-coding-console/client/settings";
import { createBrowserHost } from "./browser-host";
import { ErrorBoundary } from "./error-boundary";
import { ToastProvider } from "./toast";
import { applyTheme, useSystemTheme } from "./theme";

/**
 * The local console page.
 *
 * It renders the shared console panel, the same component the Paseo plugin
 * renders, and gives it the browser host. Nothing about the interface is
 * written twice: the page only provides the host and the project to read.
 *
 * The page also opens the shared settings screen. The plugin shows the same
 * screen in the settings of Paseo, so the two hosts keep one set of
 * preferences and one explanation of what they do.
 */

const WORKSPACE_ID = "local";

const queryClient = new QueryClient({
  defaultOptions: {
    queries: { retry: false, refetchOnWindowFocus: true },
  },
});

function ConsoleRoot() {
  const [settingsOpen, setSettingsOpen] = useState(false);
  /**
   * The host of the console.
   *
   * The permissions of the console live in the settings of the page, so the
   * host opens that panel for the human who has to change them.
   */
  const host = useMemo(() => createBrowserHost({ openSettings: () => setSettingsOpen(true) }), []);
  return (
    <HostProvider value={host}>
      <LocaleProvider>
        <ConsolePage
          settingsOpen={settingsOpen}
          onToggleSettings={() => setSettingsOpen((open) => !open)}
        />
      </LocaleProvider>
    </HostProvider>
  );
}

/**
 * The page itself.
 *
 * It draws the bar with the settings of the page and the shared console under
 * it. The host of the console is above it, so every part of the page reads
 * the same host.
 */
function ConsolePage({ settingsOpen, onToggleSettings }: {
  settingsOpen: boolean;
  onToggleSettings: () => void;
}) {
  const theme = useSystemTheme();
  const t = useT();
  useEffect(() => {
    applyTheme(theme);
  }, [theme]);
  return (
    <div className="mc-local">
      <div className="mc-local-bar">
        <span className="mc-local-title">{t("local.title")}</span>
        <button
          type="button"
          className="mc-local-button"
          aria-expanded={settingsOpen}
          onClick={onToggleSettings}
        >
          {settingsOpen ? t("local.close_settings") : t("local.settings")}
        </button>
      </div>
      {settingsOpen && (
        <div className="mc-local-settings">
          <SettingsScreen theme={theme} />
        </div>
      )}
      <ConsolePanel theme={theme} layout={{ compact: false }} workspaceId={WORKSPACE_ID} />
    </div>
  );
}

const container = document.getElementById("root");
if (!container) throw new Error("The Math Coding console page needs a root element");

createRoot(container).render(
  <StrictMode>
    <ErrorBoundary>
      <ToastProvider>
        <QueryClientProvider client={queryClient}>
          <ConsoleRoot />
        </QueryClientProvider>
      </ToastProvider>
    </ErrorBoundary>
  </StrictMode>,
);
