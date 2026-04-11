import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { MapCountry } from "@/types";

interface MapState {
  projection: "globe" | "mercator";
  selectedCountry: MapCountry | null;
  setProjection: (p: "globe" | "mercator") => void;
  setSelectedCountry: (c: MapCountry | null) => void;
}

export const useMapStore = create<MapState>()(
  persist(
    (set) => ({
      projection: "globe",
      selectedCountry: null,
      setProjection: (projection) => set({ projection }),
      setSelectedCountry: (selectedCountry) => set({ selectedCountry }),
    }),
    { name: "atlas-map", partialize: (s) => ({ projection: s.projection }) }
  )
);
