import Link from "next/link";
import { MapPin, Calendar } from "lucide-react";
import { cn, formatDateRange } from "@/lib/utils";
import type { Trip } from "@/types";

const STATUS_STYLES: Record<Trip["status"], string> = {
  past: "bg-atlas-visited/10 text-atlas-visited border border-atlas-visited/20",
  active: "bg-green-900/20 text-green-400 border border-green-800",
  planned: "bg-atlas-accent/10 text-atlas-accent border border-atlas-accent/20",
  dream: "bg-atlas-muted/10 text-atlas-muted border border-atlas-muted/20",
};

export function TripCard({ trip }: { trip: Trip }) {
  return (
    <Link
      href={`/trips/${trip.id}`}
      className={cn(
        "block rounded-lg border border-atlas-border bg-atlas-surface p-4",
        "hover:border-atlas-accent/40 transition-colors group"
      )}
    >
      <div className="flex items-start justify-between gap-3 mb-3">
        <h3 className="font-display text-base font-semibold text-atlas-text group-hover:text-atlas-accent transition-colors line-clamp-1">
          {trip.title}
        </h3>
        <span className={cn("shrink-0 rounded px-2 py-0.5 text-xs font-medium", STATUS_STYLES[trip.status])}>
          {trip.status}
        </span>
      </div>

      {trip.description && (
        <p className="text-sm text-atlas-muted line-clamp-2 mb-3">{trip.description}</p>
      )}

      <div className="flex items-center gap-4 text-xs text-atlas-muted">
        <span className="flex items-center gap-1">
          <Calendar size={12} />
          {formatDateRange(trip.start_date, trip.end_date)}
        </span>
        {trip.tags.length > 0 && (
          <span className="flex items-center gap-1">
            <MapPin size={12} />
            {trip.tags.slice(0, 2).join(", ")}
          </span>
        )}
      </div>
    </Link>
  );
}
