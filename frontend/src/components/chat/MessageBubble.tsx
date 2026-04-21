import type { ReactNode } from "react";
import type { Role } from "../../types";

interface MessageBubbleProps {
  role: Role;
  children: ReactNode;
}

export function MessageBubble({ role, children }: MessageBubbleProps) {
  const isUser = role === "user";
  return (
    <div
      className={[
        "relative rounded-2xl px-4 py-3 text-[14.5px] leading-relaxed",
        "animate-slide-in-up motion-reduce:animate-fade-in",
        isUser
          ? "border border-white/[0.08] bg-white/[0.05] text-white"
          : "border border-white/[0.05] bg-bg-elevated/60 text-white/90 backdrop-blur-sm",
      ].join(" ")}
    >
      {children}
    </div>
  );
}
