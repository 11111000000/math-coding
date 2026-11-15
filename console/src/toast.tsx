import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import type { HostToast } from "../../plugin/math-coding-console/client/host/contract";

/**
 * The browser notifications of the console.
 *
 * The Paseo host owns its own notifications; the browser host owns these. Both
 * answer the same `HostToast` contract, so the interface never asks which host
 * it runs in.
 */

type ToastVariant = "success" | "error" | "warning" | "info";

interface ToastItem {
  id: number;
  message: string;
  variant: ToastVariant;
}

const TOAST_DURATION_MS = 6_000;

const ToastContext = createContext<HostToast | null>(null);

function schedule(callback: () => void, delay: number): () => void {
  const timer = setTimeout(callback, delay);
  // Node keeps the process alive for pending timers; the browser does not care.
  if (typeof timer === "object" && timer !== null && "unref" in timer) {
    (timer as { unref: () => void }).unref();
  }
  return () => clearTimeout(timer);
}

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<ToastItem[]>([]);
  const nextId = useRef(1);
  const timers = useRef<(() => void)[]>([]);

  useEffect(() => () => {
    for (const cancel of timers.current) cancel();
    timers.current = [];
  }, []);

  const show = useCallback((message: string, options?: { variant?: ToastVariant }) => {
    const id = nextId.current++;
    setToasts((current) => [...current, { id, message, variant: options?.variant ?? "info" }]);
    timers.current.push(schedule(() => {
      setToasts((current) => current.filter((toast) => toast.id !== id));
    }, TOAST_DURATION_MS));
  }, []);

  const value = useMemo<HostToast>(
    () => ({
      show,
      error: (message: string) => show(message, { variant: "error" }),
    }),
    [show],
  );

  return (
    <ToastContext.Provider value={value}>
      {children}
      <div className="mc-toasts" role="status" aria-live="polite">
        {toasts.map((toast) => (
          <div key={toast.id} className={`mc-toast mc-toast-${toast.variant}`}>
            {toast.message}
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

export function useToast(): HostToast {
  const value = useContext(ToastContext);
  if (!value) throw new Error("The Math Coding console requires a toast provider");
  return value;
}
