"use client";

import Link from "next/link";
import {
  BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer,
} from "recharts";
import { useStats, useStatsHeatmap, useStatsTimeline } from "@/hooks/useStats";
import type { TimelineTrip } from "@/types";

// ── helpers ──────────────────────────────────────────────────────────────────

function fmt(n: number, decimals = 0): string {
  return n.toLocaleString("en-US", { maximumFractionDigits: decimals });
}

function statusDot(status: TimelineTrip["status"]) {
  const colors: Record<TimelineTrip["status"], string> = {
    past:    "bg-atlas-muted",
    active:  "bg-green-400",
    planned: "bg-atlas-accent",
    dream:   "bg-atlas-accent/40",
  };
  return <span className={`inline-block w-2 h-2 rounded-full shrink-0 ${colors[status]}`} />;
}

// ── sub-components ────────────────────────────────────────────────────────────

function StatCard({ label, value, unit }: { label: string; value: string; unit: string }) {
  return (
    <div className="rounded-lg border border-atlas-border bg-atlas-surface px-4 py-4 flex flex-col gap-1">
      <p className="text-xs text-atlas-muted uppercase tracking-widest">{label}</p>
      <p className="text-2xl font-mono font-semibold text-atlas-accent">{value}</p>
      <p className="text-xs text-atlas-muted">{unit}</p>
    </div>
  );
}

// ── page ─────────────────────────────────────────────────────────────────────

export default function StatsPage() {
  const { data: stats, isLoading: statsLoading } = useStats();
  const { data: heatmap = [], isLoading: heatmapLoading } = useStatsHeatmap();
  const { data: timeline = [], isLoading: timelineLoading } = useStatsTimeline();

  // Bar chart: top-10 countries by nights
  const barData = heatmap
    .slice(0, 10)
    .map((e) => ({ name: e.country_name.length > 12 ? e.country_code : e.country_name, nights: e.total_nights }));

  return (
    <div className="h-full overflow-y-auto p-6">
      <div className="max-w-5xl mx-auto flex flex-col gap-10">

        {/* Header */}
        <div>
          <h1 className="font-display text-2xl font-semibold text-atlas-text">Stats</h1>
          <p className="text-sm text-atlas-muted mt-1">Your travel at a glance.</p>
        </div>

        {/* Hero row */}
        {statsLoading ? (
          <p className="text-sm text-atlas-muted">Loading…</p>
        ) : stats ? (
          <>
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
              <StatCard label="Countries" value={fmt(stats.countries_visited)} unit="visited" />
              <StatCard label="Cities" value={fmt(stats.cities_visited)} unit="visited" />
              <StatCard label="Nights away" value={fmt(stats.total_nights)} unit="nights" />
              <StatCard label="Distance" value={fmt(stats.total_distance_km)} unit="km flown" />
              <StatCard label="CO₂" value={fmt(stats.co2_estimate_kg)} unit="kg estimated" />
            </div>

            {/* Notable stats */}
            {(stats.longest_trip_title || stats.most_visited_country) && (
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                {stats.longest_trip_title && (
                  <div className="rounded-lg border border-atlas-border bg-atlas-surface px-4 py-3">
                    <p className="text-xs text-atlas-muted uppercase tracking-widest mb-1">Longest trip</p>
                    <p className="text-sm font-medium text-atlas-text">{stats.longest_trip_title}</p>
                    <p className="text-xs font-mono text-atlas-muted">{stats.longest_trip_nights} nights</p>
                  </div>
                )}
                {stats.most_visited_country && (
                  <div className="rounded-lg border border-atlas-border bg-atlas-surface px-4 py-3">
                    <p className="text-xs text-atlas-muted uppercase tracking-widest mb-1">Most visited</p>
                    <p className="text-sm font-medium text-atlas-text">{stats.most_visited_country}</p>
                    <p className="text-xs font-mono text-atlas-muted">{stats.most_visited_country_count} trip{stats.most_visited_country_count !== 1 ? "s" : ""}</p>
                  </div>
                )}
              </div>
            )}
          </>
        ) : null}

        {/* Nights by country bar chart */}
        {!heatmapLoading && barData.length > 0 && (
          <div>
            <h2 className="text-xs font-semibold text-atlas-text uppercase tracking-widest mb-4">
              Nights by country
            </h2>
            <div className="rounded-lg border border-atlas-border bg-atlas-surface p-4">
              <ResponsiveContainer width="100%" height={220}>
                <BarChart data={barData} margin={{ top: 4, right: 8, bottom: 4, left: 0 }}>
                  <XAxis
                    dataKey="name"
                    tick={{ fill: "#64748b", fontSize: 11, fontFamily: "IBM Plex Mono" }}
                    axisLine={false}
                    tickLine={false}
                  />
                  <YAxis
                    tick={{ fill: "#64748b", fontSize: 11, fontFamily: "IBM Plex Mono" }}
                    axisLine={false}
                    tickLine={false}
                    width={28}
                  />
                  <Tooltip
                    contentStyle={{ background: "#111827", border: "1px solid #1e2d45", borderRadius: 6, fontSize: 12 }}
                    labelStyle={{ color: "#e2e8f0" }}
                    itemStyle={{ color: "#4a90d9" }}
                  />
                  <Bar dataKey="nights" fill="#4a90d9" radius={[3, 3, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>
        )}

        {/* Timeline strip */}
        <div>
          <h2 className="text-xs font-semibold text-atlas-text uppercase tracking-widest mb-4">
            Trip history
          </h2>

          {timelineLoading && <p className="text-sm text-atlas-muted">Loading…</p>}

          {!timelineLoading && timeline.length === 0 && (
            <p className="text-sm text-atlas-muted py-4 text-center border border-dashed border-atlas-border rounded-lg">
              No trips logged yet.{" "}
              <Link href="/trips/new" className="text-atlas-accent hover:underline">Add your first trip</Link>.
            </p>
          )}

          {timeline.length > 0 && (
            <div className="flex gap-3 overflow-x-auto pb-2">
              {timeline.map((trip) => (
                <Link
                  key={trip.id}
                  href={`/trips/${trip.id}`}
                  className="shrink-0 w-48 rounded-lg border border-atlas-border bg-atlas-surface p-3 flex flex-col gap-2 hover:border-atlas-accent/40 transition-colors"
                >
                  <div className="flex items-center gap-1.5">
                    {statusDot(trip.status)}
                    <p className="text-sm font-medium text-atlas-text truncate">{trip.title}</p>
                  </div>
                  {trip.start_date && (
                    <p className="text-xs font-mono text-atlas-muted">{trip.start_date.slice(0, 7)}</p>
                  )}
                  <div className="flex gap-2 mt-auto">
                    <span className="text-xs text-atlas-muted">{trip.destination_count} dest</span>
                    <span className="text-xs text-atlas-muted">·</span>
                    <span className="text-xs text-atlas-muted">{trip.transport_count} legs</span>
                  </div>
                </Link>
              ))}
            </div>
          )}
        </div>

      </div>
    </div>
  );
}
