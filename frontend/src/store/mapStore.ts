import { create } from "zustand";
import { persist } from "zustand/middleware";

interface MapState {
  projection: "globe" | "mercator";
  setProjection: (p: "globe" | "mercator") => void;
}

export const useMapStore = create<MapState>()(
  persist(
    (set) => ({
      projection: "globe",
      setProjection: (projection) => set({ projection }),
    }),
    {
      name: "atlas-map",
      partialize: (s) => ({ projection: s.projection }),
    }
  )
);
