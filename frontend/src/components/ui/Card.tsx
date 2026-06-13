import { cn } from "@/lib/utils";
import type { HTMLAttributes } from "react";

/**
 * Bordered surface with ambient elevation. No nested cards, no side-stripe accents.
 * `interactive` adds the hover affordance used for clickable cards.
 */
export function Card({
  interactive,
  className,
  ...props
}: HTMLAttributes<HTMLDivElement> & { interactive?: boolean }) {
  return (
    <div
      className={cn(
        "rounded-lg border border-atlas-border bg-atlas-surface shadow-elev-1",
        interactive &&
          "transition-all duration-200 ease-out-quart hover:border-atlas-border-strong hover:shadow-elev-2 hover:-translate-y-0.5",
        className
      )}
      {...props}
    />
  );
}
