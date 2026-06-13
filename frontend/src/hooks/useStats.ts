import { useQuery } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiGet } from "@/lib/api";
import type { StatsResponse, TimelineTrip } from "@/types";

export function useStats() {
  const { getToken } = useAuth();
  return useQuery<StatsResponse>({
    queryKey: ["stats"],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<StatsResponse>("/stats", token);
    },
  });
}

export function useTimeline() {
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
