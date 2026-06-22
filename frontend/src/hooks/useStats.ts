import { useQuery } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiGet } from "@/lib/api";
import type { UserStats, HeatmapEntry, TimelineTrip } from "@/types";

export function useStats() {
  const { getToken } = useAuth();
  return useQuery<UserStats>({
    queryKey: ["stats"],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<UserStats>("/stats", token);
    },
  });
}

export function useStatsHeatmap() {
  const { getToken } = useAuth();
  return useQuery<HeatmapEntry[]>({
    queryKey: ["stats", "heatmap"],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<HeatmapEntry[]>("/stats/heatmap", token);
    },
  });
}

export function useStatsTimeline() {
  const { getToken } = useAuth();
  return useQuery<TimelineTrip[]>({
    queryKey: ["stats", "timeline"],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<TimelineTrip[]>("/stats/timeline", token);
    },
  });
}
