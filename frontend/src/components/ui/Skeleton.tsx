import { cn } from "@/lib/utils";

/** Shimmering placeholder. Use for content loading, never a centered spinner. */
export function Skeleton({ className }: { className?: string }) {
  return (
    <div
      className={cn(
        "relative overflow-hidden rounded-md bg-atlas-surface-2",
        "after:absolute after:inset-0 after:-translate-x-full",
        "after:bg-gradient-to-r after:from-transparent after:via-white/[0.04] after:to-transparent",
        "after:animate-[shimmer_1.6s_infinite]",
        className
      )}
    />
  );
}

export function TripCardSkeleton() {
  return (
    <div className="rounded-lg border border-atlas-border bg-atlas-surface p-4 shadow-elev-1">
      <div className="mb-3 flex items-start justify-between gap-3">
        <Skeleton className="h-5 w-40" />
        <Skeleton className="h-5 w-16 rounded-full" />
      </div>
      <Skeleton className="mb-2 h-3.5 w-full" />
      <Skeleton className="mb-4 h-3.5 w-2/3" />
      <Skeleton className="h-3 w-28" />
    </div>
  );
}
