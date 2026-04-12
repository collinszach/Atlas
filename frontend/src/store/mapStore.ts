import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { MapCountry } from "@/types";

type TripStatusFilter = "all" | "past" | "active" | "planned" | "dream";

interface MapState {
  projection: "globe" | "mercator";
  selectedCountry: MapCountry | null;
  filterYear: number | null;
  filterStatus: TripStatusFilter;
  setProjection: (p: "globe" | "mercator") => void;
  setSelectedCountry: (c: MapCountry | null) => void;
  setFilterYear: (y: number | null) => void;
  setFilterStatus: (s: TripStatusFilter) => void;
}

export const useMapStore = create<MapState>()(
  persist(
    (set) => ({
      projection: "globe",
      selectedCountry: null,
      filterYear: null,
      filterStatus: "all",
      setProjection: (projection) => set({ projection }),
      setSelectedCountry: (selectedCountry) => set({ selectedCountry }),
      setFilterYear: (filterYear) => set({ filterYear }),
      setFilterStatus: (filterStatus) => set({ filterStatus }),
    }),
    {
      name: "atlas-map",
      partialize: (s) => ({ projection: s.projection }),
    }
  )
);
