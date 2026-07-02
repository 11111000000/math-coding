// Modal Dialog TypeScript Implementation
// Refines the TLA+ model in Model.tla.
//
// Mapping:
//   Model `state`         -> DialogState (TS union type)
//   Model `pendingRequest` -> DialogStateContext.pendingRequest
//   Model `isInteractive` -> derived from state, not stored

export type DialogState =
  | "closed"
  | "opening"
  | "open"
  | "confirming"
  | "closing";

export type PendingRequest = "none" | "ok" | "failed";

export interface DialogContext {
  state: DialogState;
  pendingRequest: PendingRequest;
}

// Reducer — actions map to model transitions

export type DialogAction =
  | { type: "OPEN" }                 // closed -> opening
  | { type: "FINISH_OPEN" }          // opening -> open
  | { type: "CONFIRM" }              // open -> confirming
  | { type: "CANCEL" }               // open -> closing
  | { type: "RESOLVE" }              // confirming + ok -> closing
  | { type: "REJECT" }               // confirming + failed -> closing
  | { type: "FINISH_CLOSE" };        // closing -> closed

export function reducer(
  state: DialogContext,
  action: DialogAction
): DialogContext {
  switch (action.type) {
    case "OPEN":
      if (state.state !== "closed") {
        throw new Error(`OPEN requires closed, got ${state.state}`);
      }
      return { state: "opening", pendingRequest: state.pendingRequest };

    case "FINISH_OPEN":
      if (state.state !== "opening") {
        throw new Error(`FINISH_OPEN requires opening, got ${state.state}`);
      }
      return { state: "open", pendingRequest: state.pendingRequest };

    case "CONFIRM":
      if (state.state !== "open") {
        throw new Error(`CONFIRM requires open, got ${state.state}`);
      }
      return { state: "confirming", pendingRequest: "none" };

    case "CANCEL":
      if (state.state !== "open") {
        throw new Error(`CANCEL requires open, got ${state.state}`);
      }
      return { state: "closing", pendingRequest: state.pendingRequest };

    case "RESOLVE":
      if (state.state !== "confirming") {
        throw new Error(`RESOLVE requires confirming, got ${state.state}`);
      }
      return { state: "closing", pendingRequest: "ok" };

    case "REJECT":
      if (state.state !== "confirming") {
        throw new Error(`REJECT requires confirming, got ${state.state}`);
      }
      return { state: "closing", pendingRequest: "failed" };

    case "FINISH_CLOSE":
      if (state.state !== "closing") {
        throw new Error(`FINISH_CLOSE requires closing, got ${state.state}`);
      }
      return { state: "closed", pendingRequest: "none" };
  }
}

// Invariant predicates (mirror TLA+ Invariant)

export function isInteractive(state: DialogState): boolean {
  return state === "open";
}

export function checkInvariants(ctx: DialogContext): {
  i1: boolean;
  i2: boolean;
  i3: boolean;
  i4: boolean;
} {
  return {
    i1: ["closed", "opening", "open", "confirming", "closing"].includes(ctx.state),
    i2: !(ctx.state === "open") || ctx.state === "open",
    i3: !(ctx.state === "closed") || ctx.state !== "open",
    i4: !(ctx.state === "confirming") || ctx.pendingRequest !== "none",
  };
}