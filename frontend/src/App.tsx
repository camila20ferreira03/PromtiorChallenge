import { useRef, useState } from "react";
import { Sidebar } from "./components/layout/Sidebar";
import { ChatHeader } from "./components/layout/ChatHeader";
import { ChatWindow } from "./components/chat/ChatWindow";
import { ChatInput, type ChatInputHandle } from "./components/chat/ChatInput";
import { useChatSession } from "./hooks/useChatSession";

export default function App() {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const inputRef = useRef<ChatInputHandle>(null);
  const { messages, isThinking, error, send, startNewChat, dismissError } =
    useChatSession();

  const handleSelectPrompt = (prompt: string) => {
    inputRef.current?.setValue(prompt);
  };

  return (
    <div className="relative flex min-h-screen">
      <Sidebar
        isOpen={sidebarOpen}
        onClose={() => setSidebarOpen(false)}
        onNewChat={startNewChat}
        onSelectPrompt={handleSelectPrompt}
        hasMessages={messages.length > 0}
      />

      <main className="relative z-[1] flex min-h-screen w-full flex-1 flex-col">
        <ChatHeader onOpenSidebar={() => setSidebarOpen(true)} />

        <ChatWindow
          messages={messages}
          isThinking={isThinking}
          onSelectPrompt={handleSelectPrompt}
        />

        <div className="sticky bottom-0 border-t border-white/[0.04] bg-gradient-to-t from-bg-base via-bg-base/95 to-bg-base/80 px-4 pb-5 pt-3 backdrop-blur-md md:px-8 md:pb-7">
          <div className="mx-auto w-full max-w-3xl">
            {error && (
              <div
                className="mb-3 flex animate-fade-in items-start justify-between gap-3 rounded-xl border border-red-400/20 bg-red-500/[0.08] px-3.5 py-2.5 text-[13px] text-red-200"
                role="alert"
              >
                <div className="flex-1">
                  <span className="font-medium">Something went wrong.</span>{" "}
                  <span className="text-red-200/80">{error}</span>
                </div>
                <button
                  onClick={dismissError}
                  className="focus-ring rounded p-1 text-red-200/70 transition hover:bg-red-500/10 hover:text-red-100"
                  aria-label="Dismiss error"
                >
                  <svg
                    viewBox="0 0 20 20"
                    className="h-4 w-4"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="1.8"
                    strokeLinecap="round"
                  >
                    <path d="M5 5l10 10M15 5L5 15" />
                  </svg>
                </button>
              </div>
            )}
            <ChatInput ref={inputRef} onSend={send} disabled={isThinking} />
          </div>
        </div>
      </main>
    </div>
  );
}
