import { useQuery } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiGet } from "@/lib/api";
import type { MapArc } from "@/types";

export function useMapArcs() {
  const { getToken } = useAuth();
  return useQuery<MapArc[]>({
    queryKey: ["map", "arcs"],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<MapArc[]>("/map/arcs", token);
    },
    staleTime: 5 * 60 * 1000, // 5 minutes — matches Redis TTL
  });
}
