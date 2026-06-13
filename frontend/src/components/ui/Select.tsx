import { cn } from "@/lib/utils";
import type { SelectHTMLAttributes } from "react";
import { forwardRef } from "react";
import { ChevronDown } from "lucide-react";

interface SelectProps extends SelectHTMLAttributes<HTMLSelectElement> {
  label?: string;
  error?: string;
  options: { value: string; label: string }[];
}

export const Select = forwardRef<HTMLSelectElement, SelectProps>(
  ({ label, error, options, className, id, ...props }, ref) => {
    const selectId = id ?? label?.toLowerCase().replace(/\s+/g, "-");
    return (
      <div className="flex flex-col gap-1.5">
        {label && (
          <label htmlFor={selectId} className="text-xs font-medium text-atlas-ink-2">
            {label}
          </label>
        )}
        <div className="relative">
          <select
            ref={ref}
            id={selectId}
            aria-invalid={!!error || undefined}
            {...props}
            className={cn(
              "h-9 w-full appearance-none rounded-md border border-atlas-border bg-atlas-bg-deep pl-3 pr-9 text-sm text-atlas-ink",
              "transition-colors duration-150 hover:border-atlas-border-strong",
              "focus:outline-none focus:border-atlas-accent focus:ring-1 focus:ring-atlas-accent/60",
              "disabled:opacity-50 disabled:cursor-not-allowed",
              error && "border-atlas-danger/60",
              className
            )}
          >
            {options.map((o) => (
              <option key={o.value} value={o.value} className="bg-atlas-surface text-atlas-ink">
                {o.label}
              </option>
            ))}
          </select>
          <ChevronDown
            size={15}
            className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-atlas-ink-faint"
          />
        </div>
        {error && <p className="text-xs text-atlas-danger">{error}</p>}
      </div>
    );
  }
);
Select.displayName = "Select";
