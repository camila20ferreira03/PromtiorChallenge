import { useLayoutEffect, useRef } from "react";
import type { ChatMessage } from "../../types";
import { AssistantMessage } from "./AssistantMessage";
import { UserMessage } from "./UserMessage";
import { EmptyState } from "./EmptyState";

interface ChatWindowProps {
  messages: ChatMessage[];
  isThinking: boolean;
  streamingMessageId: string | null;
  onSelectPrompt: (prompt: string) => void;
}

export function ChatWindow({
  messages,
  isThinking,
  streamingMessageId,
  onSelectPrompt,
}: ChatWindowProps) {
  const bottomRef = useRef<HTMLDivElement>(null);
  // During streaming we append tokens on every render; smooth-scrolling each
  // frame feels laggy and fights the browser, so fall back to instant scroll.
  const streamingContent =
    streamingMessageId !== null
      ? messages.find((m) => m.id === streamingMessageId)?.content ?? ""
      : null;

  useLayoutEffect(() => {
    const behavior: ScrollBehavior =
      streamingMessageId !== null ? "auto" : "smooth";
    bottomRef.current?.scrollIntoView({ behavior, block: "end" });
  }, [messages.length, isThinking, streamingMessageId, streamingContent]);

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
                <AssistantMessage
                  key={m.id}
                  content={m.content}
                  isStreaming={m.id === streamingMessageId}
                />
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
