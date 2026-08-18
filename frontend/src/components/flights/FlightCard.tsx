import Link from "next/link";
import { Plane, Calendar } from "lucide-react";
import { cn } from "@/lib/utils";
import type { TransportLeg } from "@/types";

function flightLabel(leg: TransportLeg): string {
  if (leg.origin_city && leg.dest_city) return `${leg.origin_city} → ${leg.dest_city}`;
  if (leg.origin_iata && leg.dest_iata) return `${leg.origin_iata} → ${leg.dest_iata}`;
  return leg.flight_number ?? "Flight";
}

export function FlightCard({ flight }: { flight: TransportLeg }) {
  return (
    <Link
      href={`/flights/${flight.id}`}
      className={cn(
        "block rounded-lg border border-atlas-border bg-atlas-surface p-4",
        "hover:border-atlas-accent/40 transition-colors group"
      )}
    >
      <div className="flex items-start justify-between gap-3 mb-3">
        <h3 className="font-display text-base font-semibold text-atlas-text group-hover:text-atlas-accent transition-colors line-clamp-1">
          {flightLabel(flight)}
        </h3>
        <span className="shrink-0 flex h-7 w-7 items-center justify-center rounded bg-atlas-accent-cool/10 text-atlas-accent-cool">
          <Plane size={14} />
        </span>
      </div>

      {(flight.flight_number || flight.airline) && (
        <p className="text-sm text-atlas-muted line-clamp-1 mb-3">
          {[flight.airline, flight.flight_number].filter(Boolean).join(" · ")}
        </p>
      )}

      <div className="flex items-center gap-4 text-xs text-atlas-muted">
        {flight.departure_at && (
          <span className="flex items-center gap-1">
            <Calendar size={12} />
            {flight.departure_at.slice(0, 10)}
          </span>
        )}
        {flight.distance_km != null && (
          <span>{Number(flight.distance_km).toLocaleString()} km</span>
        )}
      </div>
    </Link>
  );
}
