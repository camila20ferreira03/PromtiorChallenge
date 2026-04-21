interface ChatHeaderProps {
  onOpenSidebar: () => void;
}

export function ChatHeader({ onOpenSidebar }: ChatHeaderProps) {
  return (
    <header className="sticky top-0 z-10 flex items-center gap-3 border-b border-white/[0.04] bg-bg-base/70 px-4 py-3 backdrop-blur-md md:px-8">
      <button
        onClick={onOpenSidebar}
        className="focus-ring rounded-lg p-2 text-white/60 transition hover:bg-white/5 hover:text-white md:hidden"
        aria-label="Open sidebar"
      >
        <svg
          viewBox="0 0 20 20"
          className="h-5 w-5"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.8"
          strokeLinecap="round"
        >
          <path d="M3 6h14M3 10h14M3 14h14" />
        </svg>
      </button>

      <h1 className="flex-1 text-[14px] font-medium tracking-tight text-white">
        Promtior Assistant
      </h1>
    </header>
  );
}
