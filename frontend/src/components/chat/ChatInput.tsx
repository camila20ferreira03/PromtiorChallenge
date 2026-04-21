import {
  forwardRef,
  useEffect,
  useImperativeHandle,
  useLayoutEffect,
  useRef,
  useState,
  type KeyboardEvent,
} from "react";

interface ChatInputProps {
  onSend: (value: string) => void;
  disabled?: boolean;
  placeholder?: string;
}

export interface ChatInputHandle {
  focus: () => void;
  setValue: (value: string) => void;
}

const MAX_HEIGHT_PX = 200;

export const ChatInput = forwardRef<ChatInputHandle, ChatInputProps>(
  function ChatInput(
    {
      onSend,
      disabled = false,
      placeholder = "Ask something about Promtior…",
    },
    ref,
  ) {
    const [value, setValue] = useState("");
    const textareaRef = useRef<HTMLTextAreaElement>(null);

    useImperativeHandle(ref, () => ({
      focus: () => textareaRef.current?.focus(),
      setValue: (v: string) => {
        setValue(v);
        requestAnimationFrame(() => textareaRef.current?.focus());
      },
    }));

    useLayoutEffect(() => {
      const el = textareaRef.current;
      if (!el) return;
      el.style.height = "auto";
      const next = Math.min(el.scrollHeight, MAX_HEIGHT_PX);
      el.style.height = `${next}px`;
    }, [value]);

    useEffect(() => {
      if (!disabled) textareaRef.current?.focus();
    }, [disabled]);

    const submit = () => {
      const trimmed = value.trim();
      if (!trimmed || disabled) return;
      onSend(trimmed);
      setValue("");
    };

    const handleKeyDown = (e: KeyboardEvent<HTMLTextAreaElement>) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        submit();
      }
    };

    const hasText = value.trim().length > 0;

    return (
      <form
        onSubmit={(e) => {
          e.preventDefault();
          submit();
        }}
        className="relative"
      >
        <div className="glass-surface focus-within:shadow-glow group relative flex items-end gap-2 rounded-2xl px-3.5 py-2.5 transition-shadow">
          <textarea
            ref={textareaRef}
            rows={1}
            value={value}
            onChange={(e) => setValue(e.target.value)}
            onKeyDown={handleKeyDown}
            disabled={disabled}
            placeholder={placeholder}
            className="focus-ring max-h-[200px] min-h-[24px] flex-1 resize-none bg-transparent px-1.5 py-1.5 text-[14.5px] leading-relaxed text-white placeholder:text-white/35 focus:outline-none disabled:opacity-60"
          />

          <button
            type="submit"
            disabled={!hasText || disabled}
            aria-label="Send message"
            className={[
              "focus-ring mb-0.5 grid h-9 w-9 place-items-center rounded-xl transition",
              hasText && !disabled
                ? "bg-gradient-to-br from-accent-cyan to-accent-violet text-black shadow-glow hover:brightness-110"
                : "bg-white/5 text-white/30",
            ].join(" ")}
          >
            <svg
              viewBox="0 0 20 20"
              className="h-4 w-4"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path d="M4 10 L16 4 L12 16 L10 11 Z" fill="currentColor" />
            </svg>
          </button>
        </div>

        <p className="mt-2 px-2 text-center text-[11px] text-white/30">
          Press <kbd className="rounded bg-white/[0.06] px-1 py-0.5">Enter</kbd> to send ·{" "}
          <kbd className="rounded bg-white/[0.06] px-1 py-0.5">Shift + Enter</kbd> for a new line
        </p>
      </form>
    );
  },
);
