import { Suspense } from "react";
import Link from "next/link";
import { Plus } from "lucide-react";
import { TripListClient } from "./TripListClient";

export default function TripsPage() {
  return (
    <div className="h-full overflow-y-auto p-6">
      <div className="max-w-4xl mx-auto">
        <div className="flex items-center justify-between mb-6">
          <h1 className="font-display text-2xl font-semibold text-atlas-text">Trips</h1>
          <Link
            href="/trips/new"
            className="flex items-center gap-2 rounded bg-atlas-accent px-3 py-1.5 text-sm font-medium text-atlas-bg hover:bg-atlas-accent/90 transition-colors"
          >
            <Plus size={14} />
            New trip
          </Link>
        </div>
        <Suspense fallback={<div className="text-atlas-muted text-sm">Loading trips...</div>}>
          <TripListClient />
        </Suspense>
      </div>
    </div>
  );
}
