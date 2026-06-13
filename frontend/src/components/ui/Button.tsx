import { cn } from "@/lib/utils";
import type { ButtonHTMLAttributes } from "react";

type Variant = "primary" | "secondary" | "ghost" | "danger";

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  size?: "sm" | "md" | "lg";
  loading?: boolean;
}

const variants: Record<Variant, string> = {
  primary:
    "bg-atlas-accent text-atlas-bg-deep font-semibold hover:bg-atlas-accent-hi active:translate-y-px shadow-elev-1",
  secondary:
    "bg-atlas-surface-2 text-atlas-ink border border-atlas-border hover:border-atlas-border-strong hover:bg-atlas-surface active:translate-y-px",
  ghost:
    "text-atlas-ink-2 hover:text-atlas-ink hover:bg-atlas-surface-2 active:translate-y-px",
  danger:
    "bg-atlas-danger/12 text-atlas-danger border border-atlas-danger/30 hover:bg-atlas-danger/20 active:translate-y-px",
};

const sizes = {
  sm: "h-8 px-3 text-xs gap-1.5",
  md: "h-9 px-4 text-sm gap-2",
  lg: "h-11 px-6 text-sm gap-2",
};

export function Button({
  variant = "primary",
  size = "md",
  loading,
  className,
  children,
  ...props
}: ButtonProps) {
  return (
    <button
      {...props}
      disabled={props.disabled ?? loading}
      aria-busy={loading || undefined}
      className={cn(
        "inline-flex items-center justify-center rounded-md font-medium transition-all duration-150 ease-out-quart",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-atlas-accent focus-visible:ring-offset-2 focus-visible:ring-offset-atlas-bg",
        "disabled:opacity-50 disabled:pointer-events-none",
        variants[variant],
        sizes[size],
        className
      )}
    >
      {loading ? (
        <span className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-current border-t-transparent" />
      ) : null}
      {children}
    </button>
  );
}
