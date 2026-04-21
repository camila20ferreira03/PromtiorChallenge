import { useEffect, useRef } from "react";
import type { ChatMessage } from "../../types";
import { AssistantMessage } from "./AssistantMessage";
import { UserMessage } from "./UserMessage";
import { EmptyState } from "./EmptyState";

interface ChatWindowProps {
  messages: ChatMessage[];
  isThinking: boolean;
  onSelectPrompt: (prompt: string) => void;
}

export function ChatWindow({
  messages,
  isThinking,
  onSelectPrompt,
}: ChatWindowProps) {
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth", block: "end" });
  }, [messages.length, isThinking]);

  const isEmpty = messages.length === 0 && !isThinking;

  return (
    <div className="flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-3xl px-4 pb-8 pt-6 md:px-8 md:pb-10 md:pt-10">
        {isEmpty ? (
          <EmptyState onSelectPrompt={onSelectPrompt} />
        ) : (
          <div className="space-y-6">
            {messages.map((m) =>
              m.role === "user" ? (
                <UserMessage key={m.id} content={m.content} />
              ) : (
                <AssistantMessage key={m.id} content={m.content} />
              ),
            )}
            {isThinking && <AssistantMessage content="" isThinking />}
            <div ref={bottomRef} />
          </div>
        )}
      </div>
    </div>
  );
}
