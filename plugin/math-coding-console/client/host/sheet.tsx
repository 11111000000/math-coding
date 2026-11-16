import type { ReactNode } from "react";
import { HostProvider, useHost } from "./context";
import { HostErrorBoundary } from "./error-boundary";

/**
 * The body of a sheet of the host.
 *
 * The host draws its sheet through a portal that stands outside the tree of
 * the panel, so the context of the plugin does not reach what a sheet draws.
 * The host re-establishes its own contexts for exactly that reason; the plugin
 * re-establishes its own here.
 *
 * Every sheet of the console goes through this component. A sheet that draws
 * its content on its own loses the host surface: the failure is silent on the
 * web, where the desktop path uses a real portal, and it takes the host down
 * on a phone, where the portal of the host is not a React portal.
 */
export function HostModalContent({ children }: { children?: ReactNode }) {
  const host = useHost();
  const { Modal } = host;
  return (
    <Modal.Content>
      <HostProvider value={host}>
        <HostErrorBoundary>{children}</HostErrorBoundary>
      </HostProvider>
    </Modal.Content>
  );
}
