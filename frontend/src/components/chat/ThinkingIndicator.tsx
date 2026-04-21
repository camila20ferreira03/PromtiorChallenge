import { useEffect, useState } from "react";

const MICRO_COPY = ["Thinking", "Analyzing", "Preparing response"];

export function ThinkingIndicator() {
  const [idx, setIdx] = useState(0);

  useEffect(() => {
    const prefersReduced =
      typeof window !== "undefined" &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (prefersReduced) return;
    const interval = window.setInterval(() => {
      setIdx((i) => (i + 1) % MICRO_COPY.length);
    }, 1600);
    return () => window.clearInterval(interval);
  }, []);

  return (
    <div
      className="flex items-center gap-3 py-0.5"
      role="status"
      aria-live="polite"
      aria-label="Assistant is thinking"
    >
      <div className="flex items-center gap-1.5" aria-hidden="true">
        <span
          className="block h-1.5 w-1.5 rounded-full bg-accent-cyan animate-pulse-dot"
          style={{ animationDelay: "0ms" }}
        />
        <span
          className="block h-1.5 w-1.5 rounded-full bg-accent-cyan animate-pulse-dot"
          style={{ animationDelay: "160ms" }}
        />
        <span
          className="block h-1.5 w-1.5 rounded-full bg-accent-violet animate-pulse-dot"
          style={{ animationDelay: "320ms" }}
        />
      </div>
      <div className="relative h-px w-28 overflow-hidden rounded-full bg-white/[0.05]">
        <span className="shimmer-line absolute inset-0 animate-shimmer motion-reduce:hidden" />
      </div>
      <span className="text-[11.5px] font-medium tracking-wide text-white/40">
        {MICRO_COPY[idx]}
        <span className="motion-reduce:hidden">…</span>
      </span>
    </div>
  );
}
