"use client";

import { useMapStore } from "@/store/mapStore";

const STATUS_OPTIONS = [
  { value: "all", label: "All" },
  { value: "past", label: "Past" },
  { value: "active", label: "Active" },
  { value: "planned", label: "Planned" },
  { value: "dream", label: "Dream" },
] as const;

export function MapFilterBar() {
  const { filterStatus, setFilterStatus } = useMapStore();

  return (
    <div className="absolute top-3 left-1/2 -translate-x-1/2 z-10 flex items-center gap-1 rounded-lg border border-atlas-border bg-atlas-surface/90 backdrop-blur-sm px-2 py-1.5 shadow-lg">
      {STATUS_OPTIONS.map((opt) => (
        <button
          key={opt.value}
          onClick={() => setFilterStatus(opt.value)}
          className={`px-2.5 py-1 rounded text-xs font-medium transition-colors ${
            filterStatus === opt.value
              ? "bg-atlas-accent text-atlas-bg"
              : "text-atlas-muted hover:text-atlas-text"
          }`}
        >
          {opt.label}
        </button>
      ))}
    </div>
  );
}
