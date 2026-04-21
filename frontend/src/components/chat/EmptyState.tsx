import { Logo } from "../layout/Logo";

interface EmptyStateProps {
  onSelectPrompt: (prompt: string) => void;
}

const STARTER_PROMPTS: { title: string; subtitle: string; prompt: string }[] = [
  {
    title: "What is Promtior?",
    subtitle: "A quick overview of the company",
    prompt: "What is Promtior and what does the company do?",
  },
  {
    title: "Services offered",
    subtitle: "Explore the consulting offering",
    prompt: "What services does Promtior offer to clients?",
  },
  {
    title: "GenAI adoption",
    subtitle: "How companies start the journey",
    prompt: "How does Promtior help organizations adopt generative AI?",
  },
  {
    title: "Industries & clients",
    subtitle: "Where Promtior delivers value",
    prompt: "Which industries or types of clients does Promtior typically work with?",
  },
];

export function EmptyState({ onSelectPrompt }: EmptyStateProps) {
  return (
    <div className="flex min-h-full flex-col items-center justify-center px-4 py-12 text-center">
      <div className="relative mb-6">
        <div className="absolute inset-0 -z-10 animate-breathing-glow rounded-full bg-gradient-to-br from-accent-cyan/30 via-accent-blue/20 to-accent-violet/30" />
        <div className="grid h-16 w-16 place-items-center rounded-2xl border border-white/[0.08] bg-bg-elevated/80 backdrop-blur-md">
          <Logo showWordmark={false} iconClassName="h-11 w-11" />
        </div>
      </div>

      <h2 className="text-[26px] font-semibold leading-tight tracking-tight text-white md:text-[30px]">
        How can I help you today?
      </h2>
      <p className="mt-2 max-w-md text-[14px] leading-relaxed text-white/55">
        Ask me anything about Promtior — services, approach, team or GenAI
        adoption strategy.
      </p>

      <div className="mt-10 grid w-full max-w-2xl grid-cols-1 gap-3 sm:grid-cols-2">
        {STARTER_PROMPTS.map((item) => (
          <button
            key={item.title}
            onClick={() => onSelectPrompt(item.prompt)}
            className="focus-ring group relative overflow-hidden rounded-xl border border-white/[0.06] bg-white/[0.02] p-4 text-left transition hover:border-white/[0.12] hover:bg-white/[0.04]"
          >
            <div className="pointer-events-none absolute inset-0 bg-gradient-to-br from-accent-cyan/0 via-accent-violet/0 to-accent-violet/0 opacity-0 transition-opacity duration-300 group-hover:from-accent-cyan/[0.06] group-hover:to-accent-violet/[0.06] group-hover:opacity-100" />
            <div className="relative">
              <div className="text-[13.5px] font-medium text-white">
                {item.title}
              </div>
              <div className="mt-1 text-[12.5px] text-white/50">
                {item.subtitle}
              </div>
            </div>
          </button>
        ))}
      </div>
    </div>
  );
}
