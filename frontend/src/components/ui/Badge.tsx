import { cn } from "@/lib/utils";
import type { ReactNode } from "react";

type Tone = "neutral" | "active" | "accent" | "cyan" | "violet" | "cool";

const tones: Record<Tone, { wrap: string; dot: string }> = {
  neutral: { wrap: "bg-atlas-surface-2 text-atlas-ink-2 border-atlas-border", dot: "bg-atlas-ink-faint" },
  active: { wrap: "bg-atlas-success/12 text-atlas-success border-atlas-success/25", dot: "bg-atlas-success" },
  cyan: { wrap: "bg-atlas-cyan/12 text-atlas-cyan border-atlas-cyan/25", dot: "bg-atlas-cyan" },
  violet: { wrap: "bg-atlas-violet/12 text-atlas-violet border-atlas-violet/25", dot: "bg-atlas-violet" },
  accent: { wrap: "bg-atlas-accent/12 text-atlas-accent border-atlas-accent/25", dot: "bg-atlas-accent" },
  cool: { wrap: "bg-atlas-cool/12 text-atlas-cool border-atlas-cool/25", dot: "bg-atlas-cool" },
};

/**
 * Status pill. Carries a dot in addition to color so it stays distinguishable
 * without relying on hue alone (color-blind safety).
 */
export function Badge({
  tone = "neutral",
  dot = true,
  children,
  className,
}: {
  tone?: Tone;
  dot?: boolean;
  children: ReactNode;
  className?: string;
}) {
  const t = tones[tone];
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1.5 rounded-full border px-2.5 py-0.5 text-xs font-medium capitalize",
        t.wrap,
        className
      )}
    >
      {dot && <span className={cn("h-1.5 w-1.5 rounded-full", t.dot)} />}
      {children}
    </span>
  );
}
