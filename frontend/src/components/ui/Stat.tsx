import { cn } from "@/lib/utils";
import type { ReactNode } from "react";

/**
 * Instrument-style readout: a mono numeral with an ink-2 label.
 * The brand's signature for any earned number (countries, distance, nights).
 */
export function Stat({
  value,
  label,
  unit,
  sub,
  icon,
  accent,
  className,
}: {
  value: ReactNode;
  label: string;
  unit?: string;
  sub?: string;
  icon?: ReactNode;
  accent?: boolean;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "group relative overflow-hidden rounded-lg border border-atlas-border bg-atlas-surface p-5 shadow-elev-1",
        className
      )}
    >
      <div className="bg-graticule-fine pointer-events-none absolute inset-0 opacity-60" />
      <div className="relative">
        {icon && (
          <div className="mb-3 text-atlas-ink-faint group-hover:text-atlas-accent transition-colors">
            {icon}
          </div>
        )}
        <div className="flex items-baseline gap-1.5">
          <span
            className={cn(
              "font-mono text-3xl font-medium tabular-nums leading-none",
              accent ? "text-atlas-accent" : "text-atlas-ink"
            )}
          >
            {value}
          </span>
          {unit && <span className="font-mono text-sm text-atlas-ink-2">{unit}</span>}
        </div>
        <div className="mt-2 text-sm text-atlas-ink-2">{label}</div>
        {sub && <div className="mt-0.5 text-xs text-atlas-ink-faint">{sub}</div>}
      </div>
    </div>
  );
}
