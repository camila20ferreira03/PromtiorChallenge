/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: [
          "Inter",
          "ui-sans-serif",
          "system-ui",
          "-apple-system",
          "Segoe UI",
          "Roboto",
          "sans-serif",
        ],
      },
      colors: {
        bg: {
          base: "#05060a",
          elevated: "#0b0f1a",
          raised: "#101522",
        },
        accent: {
          cyan: "#22d3ee",
          blue: "#3b82f6",
          violet: "#8b5cf6",
        },
      },
      boxShadow: {
        soft: "0 1px 2px rgba(0,0,0,0.25), 0 8px 24px -12px rgba(0,0,0,0.6)",
        glow: "0 0 0 1px rgba(255,255,255,0.05), 0 0 32px -8px rgba(34,211,238,0.25)",
      },
      keyframes: {
        "slide-in-up": {
          "0%": { opacity: "0", transform: "translateY(6px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
        "fade-in": {
          "0%": { opacity: "0" },
          "100%": { opacity: "1" },
        },
        "pulse-dot": {
          "0%, 80%, 100%": { opacity: "0.25", transform: "scale(0.85)" },
          "40%": { opacity: "1", transform: "scale(1)" },
        },
        shimmer: {
          "0%": { backgroundPosition: "-200% 0" },
          "100%": { backgroundPosition: "200% 0" },
        },
        "breathing-glow": {
          "0%, 100%": { opacity: "0.55", filter: "blur(12px)" },
          "50%": { opacity: "0.9", filter: "blur(16px)" },
        },
        "caret-blink": {
          "0%, 49%": { opacity: "1" },
          "50%, 100%": { opacity: "0" },
        },
      },
      animation: {
        "slide-in-up": "slide-in-up 280ms cubic-bezier(0.2, 0.8, 0.2, 1) both",
        "fade-in": "fade-in 220ms ease-out both",
        "pulse-dot": "pulse-dot 1.2s ease-in-out infinite",
        shimmer: "shimmer 2.4s linear infinite",
        "breathing-glow": "breathing-glow 2.8s ease-in-out infinite",
        "caret-blink": "caret-blink 1s steps(2, start) infinite",
      },
    },
  },
  plugins: [require("@tailwindcss/typography")],
};
