import { StrictMode, useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ConsolePanel } from "../../plugin/math-coding-console/client/console";
import { HostProvider } from "../../plugin/math-coding-console/client/host/context";
import { SettingsScreen } from "../../plugin/math-coding-console/client/settings";
import { createBrowserHost } from "./browser-host";
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

const host = createBrowserHost();

function ConsoleRoot() {
  const theme = useSystemTheme();
  const [settingsOpen, setSettingsOpen] = useState(false);
  useEffect(() => {
    applyTheme(theme);
  }, [theme]);
  return (
    <div className="mc-local">
      <div className="mc-local-bar">
        <span className="mc-local-title">Math Coding console</span>
        <button
          type="button"
          className="mc-local-button"
          aria-expanded={settingsOpen}
          onClick={() => setSettingsOpen((open) => !open)}
        >
          {settingsOpen ? "Close settings" : "Settings"}
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
    <ToastProvider>
      <HostProvider value={host}>
        <QueryClientProvider client={queryClient}>
          <ConsoleRoot />
        </QueryClientProvider>
      </HostProvider>
    </ToastProvider>
  </StrictMode>,
);
