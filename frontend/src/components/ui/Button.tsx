import { cn } from "@/lib/utils";
import type { ButtonHTMLAttributes } from "react";

type Variant = "primary" | "secondary" | "ghost" | "danger";

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  size?: "sm" | "md";
  loading?: boolean;
}

const variants: Record<Variant, string> = {
  primary: "bg-atlas-accent text-atlas-bg hover:bg-atlas-accent/90",
  secondary: "bg-atlas-surface text-atlas-text border border-atlas-border hover:bg-atlas-border",
  ghost: "text-atlas-muted hover:text-atlas-text hover:bg-atlas-surface",
  danger: "bg-red-900/50 text-red-300 border border-red-800 hover:bg-red-900",
};

const sizes = {
  sm: "px-3 py-1.5 text-xs",
  md: "px-4 py-2 text-sm",
};

export function Button({ variant = "primary", size = "md", loading, className, children, ...props }: ButtonProps) {
  return (
    <button
      {...props}
      disabled={props.disabled ?? loading}
      className={cn(
        "inline-flex items-center justify-center gap-2 rounded font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed",
        variants[variant],
        sizes[size],
        className
      )}
    >
      {loading ? <span className="h-3 w-3 animate-spin rounded-full border border-current border-t-transparent" /> : null}
      {children}
    </button>
  );
}
