import type { ReactNode } from "react";

/**
 * Consistent page chrome: a display title, an optional description and a
 * right-aligned action slot. One header vocabulary across every page.
 *
 * No eyebrow: a tracked-caps line above the title restated the heading without
 * carrying a fact, so the prop is gone rather than merely unused.
 */
export function PageHeader({
  title,
  description,
  actions,
}: {
  title: string;
  description?: string;
  actions?: ReactNode;
}) {
  return (
    <div className="mb-7 flex flex-wrap items-end justify-between gap-4">
      <div>
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
