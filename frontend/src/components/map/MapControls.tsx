"use client";

import { Globe2, Map } from "lucide-react";
import { useMapStore } from "@/store/mapStore";
import { cn } from "@/lib/utils";

export function MapControls({ onToggleProjection }: { onToggleProjection: () => void }) {
  const { projection } = useMapStore();

  return (
    <div className="absolute right-4 top-4 z-10 flex flex-col gap-1">
      <button
        onClick={onToggleProjection}
        className={cn(
          "flex h-8 w-8 items-center justify-center rounded border border-atlas-border bg-atlas-surface shadow-lg transition-colors hover:bg-atlas-border",
          "text-atlas-muted hover:text-atlas-text"
        )}
        title={projection === "globe" ? "Switch to flat map" : "Switch to globe"}
      >
        {projection === "globe" ? <Map size={14} /> : <Globe2 size={14} />}
      </button>
    </div>
  );
}
