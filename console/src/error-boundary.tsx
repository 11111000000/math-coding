import { Component, type ReactNode } from "react";

interface BoundaryState {
  error: Error | null;
}

/**
 * The last line of defence of the page.
 *
 * An exception in the interface must not blank the whole console: the map on
 * the server stays untouched, and the page says what happened instead of
 * disappearing. Everything under this boundary can fail without taking the
 * page with it.
 */
export class ErrorBoundary extends Component<{ children: ReactNode }, BoundaryState> {
  state: BoundaryState = { error: null };

  static getDerivedStateFromError(error: unknown): BoundaryState {
    return { error: error instanceof Error ? error : new Error(String(error)) };
  }

  render() {
    const { error } = this.state;
    if (error === null) return this.props.children;
    return (
      <div role="alert" style={{ padding: 24, fontFamily: "ui-monospace, monospace" }}>
        <p>The console interface failed. The canonical map on the server stays untouched.</p>
        <p>{error.message}</p>
        <button
          type="button"
          onClick={() => {
            this.setState({ error: null });
            location.reload();
          }}
        >
          Reload the page / Перезагрузить страницу
        </button>
      </div>
    );
  }
}
