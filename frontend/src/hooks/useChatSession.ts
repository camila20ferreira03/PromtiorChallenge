import { useCallback, useEffect, useRef, useState } from "react";
import { ensureSessionId, rotateSessionId } from "../lib/persistedSessionId";
import { streamChatMessage } from "../lib/chatApi";
import type { ChatMessage } from "../types";

function newId(): string {
  return `m_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
}

export interface UseChatSession {
  sessionId: string;
  messages: ChatMessage[];
  /** True until the first token arrives (assistant bubble shows the thinking dots). */
  isThinking: boolean;
  /** Id of the assistant message currently receiving streamed tokens, or null. */
  streamingMessageId: string | null;
  error: string | null;
  send: (message: string) => Promise<void>;
  startNewChat: () => void;
  dismissError: () => void;
}

export function useChatSession(): UseChatSession {
  const [sessionId, setSessionId] = useState<string>(() => ensureSessionId());
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [isThinking, setIsThinking] = useState(false);
  const [streamingMessageId, setStreamingMessageId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const activeSessionRef = useRef(sessionId);

  useEffect(() => {
    activeSessionRef.current = sessionId;
  }, [sessionId]);

  const send = useCallback(
    async (raw: string) => {
      const message = raw.trim();
      if (!message || isThinking) return;

      setError(null);
      const currentSession = activeSessionRef.current;
      const userMsg: ChatMessage = {
        id: newId(),
        role: "user",
        content: message,
        createdAt: Date.now(),
      };
      setMessages((prev) => [...prev, userMsg]);
      setIsThinking(true);

      const assistantId = newId();
      let firstTokenSeen = false;
      let assistantAppended = false;

      try {
        await streamChatMessage(currentSession, message, {
          onToken: (token) => {
            if (activeSessionRef.current !== currentSession) return;
            if (!firstTokenSeen) {
              firstTokenSeen = true;
              assistantAppended = true;
              setIsThinking(false);
              setStreamingMessageId(assistantId);
              setMessages((prev) => [
                ...prev,
                {
                  id: assistantId,
                  role: "assistant",
                  content: token,
                  createdAt: Date.now(),
                },
              ]);
              return;
            }
            setMessages((prev) =>
              prev.map((m) =>
                m.id === assistantId ? { ...m, content: m.content + token } : m,
              ),
            );
          },
        });
      } catch (err) {
        if (activeSessionRef.current !== currentSession) return;
        if (import.meta.env.DEV) {
          console.error("Chat request failed:", err);
        }
        if (assistantAppended) {
          // Drop the half-written bubble so the error banner is the single source of truth.
          setMessages((prev) => prev.filter((m) => m.id !== assistantId));
        }
        setError("An internal error occurred. Please try again.");
      } finally {
        if (activeSessionRef.current === currentSession) {
          setIsThinking(false);
          setStreamingMessageId(null);
        }
      }
    },
    [isThinking],
  );

  const startNewChat = useCallback(() => {
    setMessages([]);
    setError(null);
    setIsThinking(false);
    setStreamingMessageId(null);
    setSessionId(rotateSessionId());
  }, []);

  const dismissError = useCallback(() => {
    setError(null);
  }, []);

  return {
    sessionId,
    messages,
    isThinking,
    streamingMessageId,
    error,
    send,
    startNewChat,
    dismissError,
  };
}
