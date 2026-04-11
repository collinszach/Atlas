"use client";

import { X } from "lucide-react";
import Link from "next/link";
import { useMapStore } from "@/store/mapStore";
import { cn } from "@/lib/utils";

export function CountryPanel() {
  const { selectedCountry, setSelectedCountry } = useMapStore();

  if (!selectedCountry) return null;

  return (
    <div
      className={cn(
        "absolute right-0 top-0 h-full w-[380px] border-l border-atlas-border bg-atlas-surface z-20",
        "flex flex-col shadow-2xl"
      )}
    >
      {/* Header */}
      <div className="flex items-center justify-between border-b border-atlas-border px-5 py-4">
        <div>
          <h2 className="font-display text-xl font-semibold text-atlas-text">
            {selectedCountry.country_name}
          </h2>
          <p className="text-xs font-mono text-atlas-muted mt-0.5">
            {selectedCountry.country_code}
          </p>
        </div>
        <button
          onClick={() => setSelectedCountry(null)}
          className="text-atlas-muted hover:text-atlas-text transition-colors"
        >
          <X size={18} />
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-3 gap-px border-b border-atlas-border bg-atlas-border">
        <Stat label="Visits" value={String(selectedCountry.visit_count)} />
        <Stat label="Nights" value={String(selectedCountry.total_nights || "—")} />
        <Stat
          label="First visit"
          value={
            selectedCountry.first_visit
              ? new Date(selectedCountry.first_visit).getFullYear().toString()
              : "—"
          }
        />
      </div>

      {/* Trips */}
      <div className="flex-1 overflow-y-auto p-5">
        <p className="text-xs uppercase tracking-widest text-atlas-muted mb-3">Trips here</p>
        {selectedCountry.trip_ids.length === 0 ? (
          <p className="text-atlas-muted text-sm">No trips logged yet.</p>
        ) : (
          <div className="flex flex-col gap-2">
            {selectedCountry.trip_ids.map((id) => (
              <Link
                key={id}
                href={`/trips/${id}`}
                className="rounded border border-atlas-border bg-atlas-bg px-3 py-2 text-sm text-atlas-text hover:border-atlas-accent/50 transition-colors"
                onClick={() => setSelectedCountry(null)}
              >
                View trip →
              </Link>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="bg-atlas-surface flex flex-col items-center py-4">
      <span className="text-xl font-semibold text-atlas-text font-mono">{value}</span>
      <span className="text-xs text-atlas-muted mt-1">{label}</span>
    </div>
  );
}
