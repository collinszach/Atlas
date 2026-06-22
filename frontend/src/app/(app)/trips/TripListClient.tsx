"use client";

import Link from "next/link";
import { Compass, Plus, AlertTriangle } from "lucide-react";
import { useTrips } from "@/hooks/useTrips";
import { TripCard } from "@/components/trips/TripCard";
import { TripCardSkeleton } from "@/components/ui/Skeleton";

const GRID = "grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3";

export function TripListClient() {
  const { data, isLoading, error } = useTrips();

  if (isLoading) {
    return (
      <div className={GRID}>
        {Array.from({ length: 6 }).map((_, i) => (
          <TripCardSkeleton key={i} />
        ))}
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center rounded-lg border border-atlas-danger/30 bg-atlas-danger/5 py-16 text-center">
        <AlertTriangle size={22} className="mb-3 text-atlas-danger" />
        <p className="text-sm font-medium text-atlas-ink">Couldn't load your trips</p>
        <p className="mt-1 text-sm text-atlas-ink-2">
          Check that the Atlas backend is reachable, then refresh.
        </p>
      </div>
    );
  }

  if (!data?.items.length) {
    return (
      <div className="bg-graticule flex flex-col items-center justify-center rounded-lg border border-dashed border-atlas-border bg-atlas-surface/40 py-20 text-center">
        <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-full border border-atlas-accent/30 bg-atlas-accent/10">
          <Compass size={22} className="text-atlas-accent" strokeWidth={1.5} />
        </div>
        <h3 className="font-display text-xl font-semibold text-atlas-ink">No trips logged yet</h3>
        <p className="mt-1.5 max-w-sm text-sm text-atlas-ink-2">
          Start the archive with your first journey. Add the places, the dates, and the routes
          between them.
        </p>
        <Link
          href="/trips/new"
          className="mt-5 inline-flex h-9 items-center gap-2 rounded-md bg-atlas-accent px-4 text-sm font-semibold text-atlas-bg-deep shadow-elev-1 transition-colors hover:bg-atlas-accent-hi"
        >
          <Plus size={15} />
          Log your first trip
        </Link>
      </div>
    );
  }

  return (
    <div className={GRID}>
      {data.items.map((trip) => (
        <TripCard key={trip.id} trip={trip} />
      ))}
    </div>
  );
}
