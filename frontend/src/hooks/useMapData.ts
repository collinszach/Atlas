import { useQuery } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiGet } from "@/lib/api";
import type { MapCountry, MapCity } from "@/types";

export function useMapCountries() {
  const { getToken } = useAuth();
  return useQuery<MapCountry[]>({
    queryKey: ["map", "countries"],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<MapCountry[]>("/map/countries", token);
    },
    staleTime: 5 * 60 * 1000, // 5 minutes — matches Redis TTL
  });
}

export function useMapCities() {
  const { getToken } = useAuth();
  return useQuery<MapCity[]>({
    queryKey: ["map", "cities"],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<MapCity[]>("/map/cities", token);
    },
    staleTime: 5 * 60 * 1000,
  });
}
