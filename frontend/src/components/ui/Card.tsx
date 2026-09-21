import { cn } from "@/lib/utils";
import type { HTMLAttributes } from "react";

/**
 * Glass surface per DESIGN.md → Materials. No nested cards, no side-stripe accents.
 * `interactive` adds the hover affordance; `hero` adds the accent glow (one per screen).
 */
export function Card({
  interactive,
  hero,
  className,
  ...props
}: HTMLAttributes<HTMLDivElement> & { interactive?: boolean; hero?: boolean }) {
  return (
    <div
      className={cn(
        "glass rounded-xl",
        hero && "glass-glow",
        interactive &&
          "transition-all duration-200 ease-out-quart hover:-translate-y-0.5 hover:shadow-elev-2",
        className
      )}
      {...props}
    />
  );
}
