import type { ReactNode } from "react";

/**
 * Consistent page chrome: a display title with optional coordinate-style eyebrow
 * and a right-aligned action slot. One header vocabulary across every page.
 */
export function PageHeader({
  title,
  eyebrow,
  description,
  actions,
}: {
  title: string;
  eyebrow?: string;
  description?: string;
  actions?: ReactNode;
}) {
  return (
    <div className="mb-7 flex flex-wrap items-end justify-between gap-4">
      <div>
        {eyebrow && (
          <div className="mb-1.5 font-mono text-xs uppercase tracking-[0.2em] text-atlas-ink-faint">
            {eyebrow}
          </div>
        )}
        <h1 className="font-display text-3xl font-semibold text-atlas-ink text-balance">
          {title}
        </h1>
        {description && (
          <p className="mt-2 max-w-[60ch] text-sm text-atlas-ink-2">{description}</p>
        )}
      </div>
      {actions && <div className="flex items-center gap-2">{actions}</div>}
    </div>
  );
}
