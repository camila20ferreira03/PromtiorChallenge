import { Logo } from "./Logo";

interface SidebarProps {
  isOpen: boolean;
  onClose: () => void;
  onNewChat: () => void;
  onSelectPrompt: (prompt: string) => void;
  hasMessages: boolean;
}

const SUGGESTED_PROMPTS: string[] = [
  "What does Promtior do?",
  "How do you approach GenAI adoption?",
  "Which industries does Promtior work with?",
  "What services are offered?",
];

export function Sidebar({
  isOpen,
  onClose,
  onNewChat,
  onSelectPrompt,
  hasMessages,
}: SidebarProps) {
  const handleNewChat = () => {
    if (hasMessages) {
      const ok = window.confirm(
        "Start a new chat? The current conversation will be cleared.",
      );
      if (!ok) return;
    }
    onNewChat();
    onClose();
  };

  const handleSuggestion = (prompt: string) => {
    onSelectPrompt(prompt);
    onClose();
  };

  return (
    <>
      {/* Mobile overlay */}
      <div
        className={`fixed inset-0 z-30 bg-black/60 backdrop-blur-sm transition-opacity duration-300 md:hidden ${
          isOpen ? "opacity-100" : "pointer-events-none opacity-0"
        }`}
        onClick={onClose}
        aria-hidden="true"
      />

      <aside
        className={`fixed inset-y-0 left-0 z-40 flex w-72 flex-col border-r border-white/[0.06] bg-bg-elevated/80 backdrop-blur-xl transition-transform duration-300 md:sticky md:top-0 md:h-screen md:translate-x-0 ${
          isOpen ? "translate-x-0" : "-translate-x-full"
        }`}
        aria-label="Primary"
      >
        <div className="flex items-center justify-between px-5 pt-5">
          <Logo />
          <button
            onClick={onClose}
            className="focus-ring rounded-lg p-1.5 text-white/50 transition hover:bg-white/5 hover:text-white md:hidden"
            aria-label="Close sidebar"
          >
            <svg
              viewBox="0 0 20 20"
              className="h-5 w-5"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.8"
              strokeLinecap="round"
            >
              <path d="M5 5l10 10M15 5L5 15" />
            </svg>
          </button>
        </div>

        <div className="px-4 pt-5">
          <button
            onClick={handleNewChat}
            className="focus-ring group flex w-full items-center gap-2 rounded-xl border border-white/[0.08] bg-white/[0.03] px-3.5 py-2.5 text-sm font-medium text-white/90 transition hover:border-white/[0.14] hover:bg-white/[0.06]"
          >
            <svg
              viewBox="0 0 20 20"
              className="h-4 w-4 text-accent-cyan transition group-hover:scale-110"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.8"
              strokeLinecap="round"
            >
              <path d="M10 4v12M4 10h12" />
            </svg>
            New chat
          </button>
        </div>

        <div className="mt-6 flex-1 overflow-y-auto px-4 pb-6">
          <div className="px-1.5 pb-2 text-[11px] font-medium uppercase tracking-wider text-white/40">
            Suggested questions
          </div>
          <ul className="space-y-1">
            {SUGGESTED_PROMPTS.map((prompt) => (
              <li key={prompt}>
                <button
                  onClick={() => handleSuggestion(prompt)}
                  className="focus-ring w-full rounded-lg px-2.5 py-2 text-left text-[13px] leading-snug text-white/70 transition hover:bg-white/5 hover:text-white"
                >
                  {prompt}
                </button>
              </li>
            ))}
          </ul>
        </div>

      </aside>
    </>
  );
}
