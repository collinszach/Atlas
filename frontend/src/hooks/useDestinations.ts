import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiGet, apiPost, apiDelete } from "@/lib/api";
import type { Destination } from "@/types";

export function useDestinations(tripId: string) {
  const { getToken } = useAuth();
  return useQuery<Destination[]>({
    queryKey: ["destinations", tripId],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<Destination[]>(`/trips/${tripId}/destinations`, token);
    },
    enabled: !!tripId,
  });
}

export function useAddDestination(tripId: string) {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (data: Partial<Destination>) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPost<Destination>(`/trips/${tripId}/destinations`, token, data);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["destinations", tripId] });
      qc.invalidateQueries({ queryKey: ["map", "countries"] });
      qc.invalidateQueries({ queryKey: ["map", "cities"] });
    },
  });
}

export function useDeleteDestination(tripId: string) {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (destId: string) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiDelete(`/destinations/${destId}`, token);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["destinations", tripId] });
      qc.invalidateQueries({ queryKey: ["map"] });
    },
  });
}
