import { cn } from "@/lib/utils";
import type { InputHTMLAttributes } from "react";
import { forwardRef } from "react";

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
  hint?: string;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ label, error, hint, className, id, ...props }, ref) => {
    const inputId = id ?? label?.toLowerCase().replace(/\s+/g, "-");
    const describedBy = error ? `${inputId}-error` : hint ? `${inputId}-hint` : undefined;
    return (
      <div className="flex flex-col gap-1.5">
        {label && (
          <label htmlFor={inputId} className="text-xs font-medium text-atlas-ink-2">
            {label}
          </label>
        )}
        <input
          ref={ref}
          id={inputId}
          aria-invalid={!!error || undefined}
          aria-describedby={describedBy}
          {...props}
          className={cn(
            "h-9 rounded-md border border-atlas-border bg-atlas-bg-deep px-3 text-sm text-atlas-ink",
            "placeholder:text-atlas-ink-faint transition-colors duration-150",
            "hover:border-atlas-border-strong",
            "focus:outline-none focus:border-atlas-accent focus:ring-1 focus:ring-atlas-accent/60",
            "disabled:opacity-50 disabled:cursor-not-allowed",
            error && "border-atlas-danger/60 focus:border-atlas-danger focus:ring-atlas-danger/50",
            className
          )}
        />
        {error ? (
          <p id={`${inputId}-error`} className="text-xs text-atlas-danger">
            {error}
          </p>
        ) : hint ? (
          <p id={`${inputId}-hint`} className="text-xs text-atlas-ink-faint">
            {hint}
          </p>
        ) : null}
      </div>
    );
  }
);
Input.displayName = "Input";
