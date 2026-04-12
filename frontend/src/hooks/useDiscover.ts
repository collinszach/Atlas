import { useQuery, useMutation } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiGet, apiPost } from "@/lib/api";
import type {
  BestTimeResponse,
  RecommendationRequest,
  Recommendation,
  DestinationBriefRequest,
  DestinationBriefResponse,
} from "@/types";

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
    staleTime: 24 * 60 * 60 * 1000,
  });
}

export function useRecommendations() {
  const { getToken } = useAuth();
  return useMutation<Recommendation[], Error, RecommendationRequest>({
    mutationFn: async (body) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPost<Recommendation[]>("/discover/recommend", token, body);
    },
  });
}

export function useDestinationBrief() {
  const { getToken } = useAuth();
  return useMutation<DestinationBriefResponse, Error, DestinationBriefRequest>({
    mutationFn: async (body) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPost<DestinationBriefResponse>("/discover/destination-brief", token, body);
    },
  });
}
