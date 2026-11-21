import { Component, type ReactNode } from "react";
import { Text, View } from "react-native";
import { translateNow } from "../i18n/current";

interface HostErrorBoundaryProps {
  children: ReactNode;
}

interface HostErrorBoundaryState {
  failed: boolean;
}

/**
 * The boundary of a sheet of the host.
 *
 * The host draws its sheet outside the tree of the panel, so the boundary of
 * the host does not cover what a sheet draws: a failure inside the sheet would
 * take the whole host down. This boundary turns such a failure into a message
 * the human can read, and the rest of the console keeps working.
 *
 * The message uses no host surface on purpose. The failure may be exactly the
 * missing host surface, and a fallback that needs the host would fail again.
 */
export class HostErrorBoundary extends Component<HostErrorBoundaryProps, HostErrorBoundaryState> {
  state: HostErrorBoundaryState = { failed: false };

  static getDerivedStateFromError(): HostErrorBoundaryState {
    return { failed: true };
  }

  render() {
    if (this.state.failed) {
      return (
        <View style={{ padding: 16, gap: 6 }}>
          <Text style={{ fontSize: 15, fontWeight: "700" }}>{translateNow("error.view_failed")}</Text>
          <Text style={{ fontSize: 12 }}>{translateNow("error.view_failed_detail")}</Text>
        </View>
      );
    }
    return this.props.children;
  }
}
