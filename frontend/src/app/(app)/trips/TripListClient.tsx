"use client";

import { useTrips } from "@/hooks/useTrips";
import { TripCard } from "@/components/trips/TripCard";

export function TripListClient() {
  const { data, isLoading, error } = useTrips();

  if (isLoading) return <div className="text-atlas-muted text-sm">Loading...</div>;
  if (error) return <div className="text-red-400 text-sm">Failed to load trips.</div>;
  if (!data?.items.length) {
    return (
      <div className="flex flex-col items-center justify-center py-20 text-center">
        <p className="text-atlas-muted">No trips yet.</p>
        <p className="text-atlas-muted text-sm mt-1">Add your first trip to get started.</p>
      </div>
    );
  }

  return (
    <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
      {data.items.map((trip) => (
        <TripCard key={trip.id} trip={trip} />
      ))}
    </div>
  );
}
