"use client";

import { useStats } from "@/hooks/useStats";

function fmt(n: number, decimals = 0): string {
  return n.toLocaleString("en-US", { maximumFractionDigits: decimals });
}

function StatCard({ label, value, unit }: { label: string; value: string; unit?: string }) {
  return (
    <div className="rounded-lg border border-atlas-border bg-atlas-surface px-4 py-4 flex flex-col gap-1">
      <p className="text-xs text-atlas-muted uppercase tracking-widest">{label}</p>
      <p className="text-2xl font-mono font-semibold text-atlas-accent">{value}</p>
      {unit && <p className="text-xs text-atlas-muted">{unit}</p>}
    </div>
  );
}

export default function StatsPage() {
  const { data: stats, isLoading } = useStats();

  return (
    <div className="h-full overflow-y-auto p-6">
      <div className="max-w-5xl mx-auto flex flex-col gap-10">
        <div>
          <h1 className="font-display text-2xl font-semibold text-atlas-text">Stats</h1>
          <p className="text-sm text-atlas-muted mt-1">Your flying at a glance.</p>
        </div>

        {isLoading ? (
          <p className="text-sm text-atlas-muted">Loading…</p>
        ) : stats ? (
          <>
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
              <StatCard label="Flights" value={fmt(stats.flights_count)} unit="logged" />
              <StatCard label="Distance" value={fmt(stats.total_distance_km)} unit="km flown" />
              <StatCard
                label="Hours in air"
                value={stats.hours_in_air != null ? fmt(stats.hours_in_air, 1) : "—"}
                unit="hours"
              />
              <StatCard label="CO₂" value={fmt(stats.co2_kg_estimate)} unit="kg estimated" />
              <StatCard label="Top airline" value={stats.top_airline ?? "—"} />
            </div>

            {stats.most_flown_airport && (
              <div className="rounded-lg border border-atlas-border bg-atlas-surface px-4 py-3 max-w-xs">
                <p className="text-xs text-atlas-muted uppercase tracking-widest mb-1">
                  Most flown airport
                </p>
                <p className="text-sm font-mono font-medium text-atlas-text">{stats.most_flown_airport}</p>
              </div>
            )}
          </>
        ) : null}
      </div>
    </div>
  );
}
