import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { MessageBubble } from "./MessageBubble";
import { ThinkingIndicator } from "./ThinkingIndicator";

interface AssistantMessageProps {
  content: string;
  isThinking?: boolean;
  isStreaming?: boolean;
}

function AssistantAvatar() {
  return (
    <div className="relative mt-1 grid h-7 w-7 shrink-0 place-items-center rounded-lg border border-white/[0.08] bg-gradient-to-br from-accent-cyan/20 to-accent-violet/20">
      <span className="absolute inset-0 rounded-lg bg-gradient-to-br from-accent-cyan/10 to-accent-violet/10 blur-sm" />
      <svg
        viewBox="0 0 16 16"
        className="relative h-3.5 w-3.5 text-white"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
      >
        <path d="M8 2 L9.2 6.2 13 7.5 9.2 8.8 8 13 6.8 8.8 3 7.5 6.8 6.2 Z" fill="currentColor" />
      </svg>
    </div>
  );
}

function StreamingCaret() {
  return (
    <span
      aria-hidden="true"
      className="ml-0.5 inline-block h-[1.05em] w-[2px] translate-y-[0.15em] rounded-sm bg-accent-cyan align-middle animate-caret-blink"
    />
  );
}

export function AssistantMessage({
  content,
  isThinking,
  isStreaming,
}: AssistantMessageProps) {
  const showThinking = isThinking && !content;
  return (
    <div className="flex items-start gap-3">
      <AssistantAvatar />
      <div className="min-w-0 max-w-[85%] md:max-w-[75%]">
        <MessageBubble role="assistant">
          {showThinking ? (
            <ThinkingIndicator />
          ) : (
            <div className="prose prose-invert prose-sm max-w-none prose-p:my-2 prose-p:leading-relaxed prose-headings:mt-3 prose-headings:mb-2 prose-ul:my-2 prose-ol:my-2 prose-li:my-0.5 prose-pre:my-3 prose-pre:rounded-xl prose-pre:bg-black/60 prose-pre:border prose-pre:border-white/[0.06] prose-code:text-accent-cyan prose-code:before:content-none prose-code:after:content-none prose-blockquote:border-l-accent-cyan/40 prose-blockquote:text-white/70 prose-a:text-accent-cyan prose-a:no-underline hover:prose-a:underline prose-strong:text-white">
              <ReactMarkdown remarkPlugins={[remarkGfm]}>{content}</ReactMarkdown>
              {isStreaming && <StreamingCaret />}
            </div>
          )}
        </MessageBubble>
      </div>
    </div>
  );
}
