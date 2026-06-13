import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/app/**/*.{ts,tsx}",
    "./src/components/**/*.{ts,tsx}",
    "./src/providers/**/*.{ts,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        atlas: {
          bg: "var(--atlas-bg)",
          "bg-deep": "var(--atlas-bg-deep)",
          surface: "var(--atlas-surface)",
          "surface-2": "var(--atlas-surface-2)",
          border: "var(--atlas-border)",
          "border-strong": "var(--atlas-border-strong)",
          ink: "var(--atlas-ink)",
          "ink-2": "var(--atlas-ink-2)",
          "ink-faint": "var(--atlas-ink-faint)",
          accent: "var(--atlas-accent)",
          "accent-hi": "var(--atlas-accent-hi)",
          cool: "var(--atlas-cool)",
          visited: "var(--atlas-visited)",
          planned: "var(--atlas-planned)",
          bucket: "var(--atlas-bucket)",
          success: "var(--atlas-success)",
          warning: "var(--atlas-warning)",
          danger: "var(--atlas-danger)",
          info: "var(--atlas-info)",
          // legacy aliases kept so older class names don't break mid-sweep
          text: "var(--atlas-ink)",
          muted: "var(--atlas-ink-2)",
        },
      },
      fontFamily: {
        display: ["Playfair Display", "Georgia", "serif"],
        sans: ["IBM Plex Sans", "system-ui", "sans-serif"],
        mono: ["IBM Plex Mono", "ui-monospace", "monospace"],
      },
      fontSize: {
        xs: ["0.75rem", { lineHeight: "1rem" }],
        sm: ["0.875rem", { lineHeight: "1.25rem" }],
        base: ["1rem", { lineHeight: "1.5rem" }],
        lg: ["1.125rem", { lineHeight: "1.6rem" }],
        xl: ["1.375rem", { lineHeight: "1.75rem" }],
        "2xl": ["1.75rem", { lineHeight: "2rem", letterSpacing: "-0.01em" }],
        "3xl": ["2.25rem", { lineHeight: "2.4rem", letterSpacing: "-0.02em" }],
        "4xl": ["3rem", { lineHeight: "3.1rem", letterSpacing: "-0.025em" }],
      },
      borderRadius: {
        sm: "6px",
        DEFAULT: "8px",
        md: "8px",
        lg: "12px",
        xl: "16px",
      },
      boxShadow: {
        "elev-1": "0 1px 0 rgba(255,255,255,0.02) inset, 0 6px 18px -10px rgba(0,0,0,0.6)",
        "elev-2": "0 1px 0 rgba(255,255,255,0.03) inset, 0 14px 36px -14px rgba(0,0,0,0.7)",
        "glow-accent": "0 0 0 1px rgba(201,168,76,0.25), 0 8px 28px -10px rgba(201,168,76,0.25)",
      },
      keyframes: {
        "fade-up": {
          from: { opacity: "0", transform: "translateY(8px)" },
          to: { opacity: "1", transform: "none" },
        },
        shimmer: {
          "100%": { transform: "translateX(100%)" },
        },
      },
      animation: {
        "fade-up": "fade-up 0.5s cubic-bezier(0.22,1,0.36,1) both",
      },
      transitionTimingFunction: {
        "out-quart": "cubic-bezier(0.25, 1, 0.5, 1)",
        "out-expo": "cubic-bezier(0.16, 1, 0.3, 1)",
      },
    },
  },
  plugins: [],
};

export default config;
