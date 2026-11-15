import { StrictMode, useEffect } from "react";
import { createRoot } from "react-dom/client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ConsolePanel } from "../../plugin/math-coding-console/client/console";
import { HostProvider } from "../../plugin/math-coding-console/client/host/context";
import { createBrowserHost } from "./browser-host";
import { ToastProvider } from "./toast";
import { applyTheme, useSystemTheme } from "./theme";

/**
 * The local console page.
 *
 * It renders the shared console panel, the same component the Paseo plugin
 * renders, and gives it the browser host. Nothing about the interface is
 * written twice: the page only provides the host and the project to read.
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
  useEffect(() => {
    applyTheme(theme);
  }, [theme]);
  return <ConsolePanel theme={theme} layout={{ compact: false }} workspaceId={WORKSPACE_ID} />;
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
