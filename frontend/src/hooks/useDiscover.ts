import { useQuery } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiGet } from "@/lib/api";
import type { BestTimeResponse } from "@/types";

export function useBestTime(countryCode: string, city?: string) {
  const { getToken } = useAuth();
  const params = city ? `?city=${encodeURIComponent(city)}` : "";
  return useQuery<BestTimeResponse>({
    queryKey: ["best-time", countryCode, city],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<BestTimeResponse>(`/discover/best-time/${countryCode}${params}`, token);
    },
    enabled: !!countryCode,
    staleTime: 24 * 60 * 60 * 1000, // 24 hours — matches backend cache
  });
}
