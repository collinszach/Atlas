"use client";

import { Globe2, Plane, Moon, MapPinned, Trophy, Route, Leaf } from "lucide-react";
import { useStats } from "@/hooks/useStats";
import { Stat } from "@/components/ui/Stat";
import { Skeleton } from "@/components/ui/Skeleton";

function fmt(n: number): string {
  return n.toLocaleString("en-US");
}

export function StatsClient() {
  const { data, isLoading, error } = useStats();

  if (isLoading) {
    return (
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        {Array.from({ length: 8 }).map((_, i) => (
          <Skeleton key={i} className="h-[124px]" />
        ))}
      </div>
    );
  }

  if (error || !data) {
    return (
      <div className="bg-graticule flex flex-col items-center justify-center rounded-lg border border-dashed border-atlas-border bg-atlas-surface/40 py-20 text-center">
        <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-full border border-atlas-accent/30 bg-atlas-accent/10">
          <Globe2 size={22} className="text-atlas-accent" strokeWidth={1.5} />
        </div>
        <h3 className="font-display text-xl font-semibold text-atlas-ink">No readout yet</h3>
        <p className="mt-1.5 max-w-sm text-sm text-atlas-ink-2">
          Your travel statistics appear here once trips are logged and the analytics endpoint is
          live.
        </p>
      </div>
    );
  }

  const distance = Math.round(data.total_distance_km);
  const moonPct = ((distance / 384400) * 100).toFixed(1);

  return (
    <div className="space-y-8">
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <Stat
          icon={<Globe2 size={18} />}
          value={fmt(data.countries_visited)}
          label="Countries visited"
          accent
        />
        <Stat icon={<MapPinned size={18} />} value={fmt(data.trips_count)} label="Trips logged" />
        <Stat icon={<Moon size={18} />} value={fmt(data.nights_away)} label="Nights away" />
        <Stat
          icon={<Plane size={18} />}
          value={fmt(distance)}
          unit="km"
          label="Distance traveled"
          sub={`${moonPct}% of the way to the Moon`}
        />
      </div>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <Stat
          icon={<Trophy size={18} />}
          value={data.most_visited_country ?? "—"}
          label="Most visited"
          className="md:col-span-1"
        />
        <Stat
          icon={<Route size={18} />}
          value={data.longest_trip_days ? `${data.longest_trip_days}` : "—"}
          unit={data.longest_trip_days ? "days" : undefined}
          label="Longest trip"
          sub={data.longest_trip_title ?? undefined}
        />
        <Stat
          icon={<Leaf size={18} />}
          value={fmt(Math.round(data.co2_kg_estimate))}
          unit="kg"
          label="Estimated CO₂"
          sub="From logged flights"
        />
      </div>
    </div>
  );
}
