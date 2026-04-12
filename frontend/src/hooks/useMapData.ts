import { useQuery } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiGet } from "@/lib/api";
import type { MapCountry, MapCity, MapArc, PlannedCity } from "@/types";

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

export function useMapArcs() {
  const { getToken } = useAuth();
  return useQuery<MapArc[]>({
    queryKey: ["map", "arcs"],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<MapArc[]>("/map/arcs", token);
    },
    staleTime: 5 * 60 * 1000,
  });
}

export function usePlannedCities() {
  const { getToken } = useAuth();
  return useQuery<PlannedCity[]>({
    queryKey: ["map", "planned"],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<PlannedCity[]>("/map/planned", token);
    },
    staleTime: 5 * 60 * 1000,
  });
}
