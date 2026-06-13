import Image from "next/image";
import Link from "next/link";
import { Calendar, MapPin, ArrowUpRight } from "lucide-react";
import { Badge } from "@/components/ui/Badge";
import { formatDateRange } from "@/lib/utils";
import type { Trip } from "@/types";

const STATUS_TONE: Record<Trip["status"], "visited" | "active" | "planned" | "dream"> = {
  past: "visited",
  active: "active",
  planned: "planned",
  dream: "dream",
};

export function TripCard({ trip, coverPhotoUrl }: { trip: Trip; coverPhotoUrl?: string }) {
  return (
    <Link
      href={`/trips/${trip.id}`}
      className="group block overflow-hidden rounded-lg border border-atlas-border bg-atlas-surface shadow-elev-1 transition-all duration-200 ease-out-quart hover:-translate-y-0.5 hover:border-atlas-border-strong hover:shadow-elev-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-atlas-accent focus-visible:ring-offset-2 focus-visible:ring-offset-atlas-bg"
    >
      <div className="relative h-32 w-full overflow-hidden">
        {coverPhotoUrl ? (
          <Image
            src={coverPhotoUrl}
            alt={trip.title}
            fill
            className="object-cover transition-transform duration-500 ease-out-quart group-hover:scale-105"
            unoptimized
          />
        ) : (
          <div className="bg-graticule-fine flex h-full w-full items-center justify-center bg-atlas-bg-deep">
            <MapPin size={22} className="text-atlas-ink-faint/60" strokeWidth={1.5} />
          </div>
        )}
        <div className="absolute inset-x-0 bottom-0 h-16 bg-gradient-to-t from-atlas-surface to-transparent" />
        <div className="absolute right-2.5 top-2.5">
          <Badge tone={STATUS_TONE[trip.status]}>{trip.status}</Badge>
        </div>
      </div>

      <div className="p-4">
        <div className="flex items-start justify-between gap-2">
          <h3 className="line-clamp-1 font-display text-lg font-semibold text-atlas-ink transition-colors group-hover:text-atlas-accent">
            {trip.title}
          </h3>
          <ArrowUpRight
            size={16}
            className="mt-1 shrink-0 text-atlas-ink-faint opacity-0 transition-opacity duration-150 group-hover:opacity-100"
          />
        </div>

        {trip.description && (
          <p className="mt-1.5 line-clamp-2 text-sm text-atlas-ink-2">{trip.description}</p>
        )}

        <div className="mt-3.5 flex items-center gap-3 font-mono text-xs text-atlas-ink-faint">
          <span className="flex items-center gap-1.5">
            <Calendar size={12} />
            {formatDateRange(trip.start_date, trip.end_date)}
          </span>
          {trip.tags.length > 0 && (
            <span className="line-clamp-1">· {trip.tags.slice(0, 2).join(" · ")}</span>
          )}
        </div>
      </div>
    </Link>
  );
}
