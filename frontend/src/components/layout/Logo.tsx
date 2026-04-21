interface LogoProps {
  className?: string;
  showWordmark?: boolean;
  iconClassName?: string;
}

export function Logo({
  className = "",
  showWordmark = true,
  iconClassName = "h-8 w-8",
}: LogoProps) {
  return (
    <div className={`flex items-center gap-2.5 ${className}`}>
      <div className={`relative grid place-items-center ${iconClassName}`}>
        <div className="absolute inset-0 rounded-xl bg-gradient-to-br from-accent-cyan/30 to-accent-violet/30 blur-[6px]" />
        <img
          src="/promtior-logo.png"
          alt="Promtior"
          className={`relative ${iconClassName} object-contain`}
          draggable={false}
        />
      </div>
      {showWordmark && (
        <span className="text-[15px] font-semibold tracking-tight text-white">
          Promtior
        </span>
      )}
    </div>
  );
}
