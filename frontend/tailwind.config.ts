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
          bg: "#0a0e1a",
          surface: "#111827",
          border: "#1e2d45",
          accent: "#c9a84c",
          "accent-cool": "#4a90d9",
          text: "#e2e8f0",
          muted: "#64748b",
          visited: "#4a90d9",
          planned: "#c9a84c",
          bucket: "#374151",
        },
      },
      fontFamily: {
        display: ["Playfair Display", "Georgia", "serif"],
        sans: ["IBM Plex Sans", "system-ui", "sans-serif"],
        mono: ["IBM Plex Mono", "monospace"],
      },
    },
  },
  plugins: [],
};

export default config;
