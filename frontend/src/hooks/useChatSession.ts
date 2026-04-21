import { useCallback, useEffect, useRef, useState } from "react";
import { ensureSessionId, rotateSessionId } from "../lib/persistedSessionId";
import { sendChatMessage } from "../lib/chatApi";
import type { ChatMessage } from "../types";

function newId(): string {
  return `m_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
}

export interface UseChatSession {
  sessionId: string;
  messages: ChatMessage[];
  isThinking: boolean;
  error: string | null;
  send: (message: string) => Promise<void>;
  startNewChat: () => void;
  dismissError: () => void;
}

export function useChatSession(): UseChatSession {
  const [sessionId, setSessionId] = useState<string>(() => ensureSessionId());
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [isThinking, setIsThinking] = useState(false);
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

      try {
        const replyText = await sendChatMessage(currentSession, message);
        // Drop the reply if the user started a new chat while we were waiting.
        if (activeSessionRef.current !== currentSession) return;
        const replyMsg: ChatMessage = {
          id: newId(),
          role: "assistant",
          content: replyText,
          createdAt: Date.now(),
        };
        setMessages((prev) => [...prev, replyMsg]);
      } catch (err) {
        if (activeSessionRef.current !== currentSession) return;
        setError(err instanceof Error ? err.message : "Something went wrong.");
      } finally {
        if (activeSessionRef.current === currentSession) setIsThinking(false);
      }
    },
    [isThinking],
  );

  const startNewChat = useCallback(() => {
    setMessages([]);
    setError(null);
    setIsThinking(false);
    setSessionId(rotateSessionId());
  }, []);

  const dismissError = useCallback(() => setError(null), []);

  return { sessionId, messages, isThinking, error, send, startNewChat, dismissError };
}
