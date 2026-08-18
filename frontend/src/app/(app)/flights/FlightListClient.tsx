"use client";

import Link from "next/link";
import { Plane, Plus, AlertTriangle } from "lucide-react";
import { useFlights } from "@/hooks/useFlights";
import { FlightCard } from "@/components/flights/FlightCard";
import { FlightCardSkeleton } from "@/components/ui/Skeleton";

const GRID = "grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3";

export function FlightListClient() {
  const { data, isLoading, error } = useFlights();

  if (isLoading) {
    return (
      <div className={GRID}>
        {Array.from({ length: 6 }).map((_, i) => (
          <FlightCardSkeleton key={i} />
        ))}
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center rounded-lg border border-atlas-danger/30 bg-atlas-danger/5 py-16 text-center">
        <AlertTriangle size={22} className="mb-3 text-atlas-danger" />
        <p className="text-sm font-medium text-atlas-ink">Couldn't load your flights</p>
        <p className="mt-1 text-sm text-atlas-ink-2">
          Check that the Atlas backend is reachable, then refresh.
        </p>
      </div>
    );
  }

  if (!data?.length) {
    return (
      <div className="bg-graticule flex flex-col items-center justify-center rounded-lg border border-dashed border-atlas-border bg-atlas-surface/40 py-20 text-center">
        <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-full border border-atlas-accent/30 bg-atlas-accent/10">
          <Plane size={22} className="text-atlas-accent" strokeWidth={1.5} />
        </div>
        <h3 className="font-display text-xl font-semibold text-atlas-ink">No flights logged yet</h3>
        <p className="mt-1.5 max-w-sm text-sm text-atlas-ink-2">
          Start the logbook with your first flight — route, airline, and aircraft.
        </p>
        <Link
          href="/flights/new"
          className="mt-5 inline-flex h-9 items-center gap-2 rounded-md bg-atlas-accent px-4 text-sm font-semibold text-atlas-bg-deep shadow-elev-1 transition-colors hover:bg-atlas-accent-hi"
        >
          <Plus size={15} />
          Log your first flight
        </Link>
      </div>
    );
  }

  return (
    <div className={GRID}>
      {data.map((flight) => (
        <FlightCard key={flight.id} flight={flight} />
      ))}
    </div>
  );
}
