"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { Plus, MapPin, Camera } from "lucide-react";
import { useTrip } from "@/hooks/useTrips";
import { useDestinations } from "@/hooks/useDestinations";
import { formatDateRange, nightsLabel } from "@/lib/utils";

export default function TripDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { data: trip, isLoading: tripLoading } = useTrip(id);
  const { data: destinations = [], isLoading: destLoading } = useDestinations(id);

  if (tripLoading) return <div className="p-6 text-atlas-muted text-sm">Loading...</div>;
  if (!trip) return <div className="p-6 text-red-400 text-sm">Trip not found.</div>;

  return (
    <div className="h-full overflow-y-auto p-6">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <Link href="/trips" className="text-xs text-atlas-muted hover:text-atlas-text mb-3 inline-block">
            ← All trips
          </Link>
          <div className="flex items-start justify-between">
            <div>
              <h1 className="font-display text-3xl font-semibold text-atlas-text">{trip.title}</h1>
              {trip.description && (
                <p className="text-atlas-muted mt-2 text-sm">{trip.description}</p>
              )}
              <p className="text-xs font-mono text-atlas-muted mt-2">
                {formatDateRange(trip.start_date, trip.end_date)}
              </p>
            </div>
            <Link
              href={`/trips/${id}/photos`}
              className="flex items-center gap-1.5 text-xs text-atlas-accent hover:text-atlas-accent/80 transition-colors shrink-0 ml-4 mt-1"
            >
              <Camera size={12} />
              Photos
            </Link>
          </div>
        </div>

        {/* Destinations */}
        <div>
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-sm font-semibold text-atlas-text uppercase tracking-widest">
              Destinations
            </h2>
            <Link
              href={`/trips/${id}/destinations/new`}
              className="flex items-center gap-1.5 text-xs text-atlas-accent hover:text-atlas-accent/80 transition-colors"
            >
              <Plus size={12} />
              Add destination
            </Link>
          </div>

          {destLoading && <p className="text-atlas-muted text-sm">Loading...</p>}

          {!destLoading && destinations.length === 0 && (
            <p className="text-atlas-muted text-sm py-6 text-center border border-dashed border-atlas-border rounded-lg">
              No destinations yet. Add one to start building your itinerary.
            </p>
          )}

          <div className="flex flex-col gap-2">
            {destinations.map((dest) => (
              <div
                key={dest.id}
                className="rounded-lg border border-atlas-border bg-atlas-surface px-4 py-3 flex items-center gap-4"
              >
                <div className="flex h-8 w-8 items-center justify-center rounded bg-atlas-accent/10 text-atlas-accent shrink-0">
                  <MapPin size={14} />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-atlas-text">{dest.city}</p>
                  <p className="text-xs text-atlas-muted">{dest.country_name}</p>
                </div>
                <div className="text-right shrink-0">
                  <p className="text-xs font-mono text-atlas-muted">
                    {dest.arrival_date ?? "—"}
                  </p>
                  <p className="text-xs text-atlas-muted">{nightsLabel(dest.nights)}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
