"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { Plane, Trash2, Image as ImageIcon } from "lucide-react";
import { useFlight, useDeleteFlight } from "@/hooks/useFlights";

function flightLabel(leg: { origin_city: string | null; dest_city: string | null; origin_iata: string | null; dest_iata: string | null; flight_number: string | null }): string {
  if (leg.origin_city && leg.dest_city) return `${leg.origin_city} → ${leg.dest_city}`;
  if (leg.origin_iata && leg.dest_iata) return `${leg.origin_iata} → ${leg.dest_iata}`;
  return leg.flight_number ?? "Flight";
}

export default function FlightDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const { data: flight, isLoading } = useFlight(id);
  const { mutate: deleteFlight, isPending: deleting } = useDeleteFlight();

  if (isLoading) return <div className="p-6 text-atlas-muted text-sm">Loading...</div>;
  if (!flight) return <div className="p-6 text-red-400 text-sm">Flight not found.</div>;

  return (
    <div className="h-full overflow-y-auto p-6">
      <div className="max-w-2xl mx-auto">
        <Link href="/flights" className="text-xs text-atlas-muted hover:text-atlas-text mb-3 inline-block">
          ← All flights
        </Link>

        <div className="flex items-start justify-between gap-4 mb-8">
          <div>
            <div className="flex items-center gap-2 mb-1">
              <span className="flex h-8 w-8 items-center justify-center rounded bg-atlas-accent-cool/10 text-atlas-accent-cool">
                <Plane size={16} />
              </span>
              <h1 className="font-display text-2xl font-semibold text-atlas-text">
                {flightLabel(flight)}
              </h1>
            </div>
            {(flight.flight_number || flight.airline) && (
              <p className="text-sm text-atlas-muted">
                {[flight.airline, flight.flight_number].filter(Boolean).join(" · ")}
              </p>
            )}
          </div>
          <button
            onClick={() => {
              deleteFlight(id, { onSuccess: () => router.push("/flights") });
            }}
            disabled={deleting}
            className="text-atlas-muted hover:text-red-400 transition-colors shrink-0"
            aria-label="Delete flight"
          >
            <Trash2 size={16} />
          </button>
        </div>

        <dl className="grid grid-cols-2 gap-x-6 gap-y-4 mb-8 text-sm">
          <Field label="Departure" value={flight.departure_at?.slice(0, 16).replace("T", " ") ?? "—"} />
          <Field label="Arrival" value={flight.arrival_at?.slice(0, 16).replace("T", " ") ?? "—"} />
          <Field label="Duration" value={flight.duration_min != null ? `${Math.floor(flight.duration_min / 60)}h ${flight.duration_min % 60}m` : "—"} />
          <Field label="Distance" value={flight.distance_km != null ? `${Number(flight.distance_km).toLocaleString()} km` : "—"} />
          <Field label="Seat class" value={flight.seat_class ?? "—"} />
          <Field label="Cost" value={flight.cost != null ? `${flight.currency} ${Number(flight.cost).toLocaleString()}` : "—"} />
        </dl>

        {flight.notes && (
          <p className="text-sm text-atlas-muted mb-8 border-l-2 border-atlas-border pl-3">{flight.notes}</p>
        )}

        <Link
          href={`/flights/${id}/photos`}
          className="inline-flex items-center gap-1.5 text-xs text-atlas-accent hover:text-atlas-accent/80 transition-colors"
        >
          <ImageIcon size={12} />
          Photos
        </Link>
      </div>
    </div>
  );
}

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-xs uppercase tracking-widest text-atlas-muted mb-1">{label}</dt>
      <dd className="font-mono text-atlas-text">{value}</dd>
    </div>
  );
}
