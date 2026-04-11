import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiGet, apiPost, apiPut, apiDelete } from "@/lib/api";
import type { Trip, TripListResponse } from "@/types";

export function useTrips(status?: string) {
  const { getToken } = useAuth();
  return useQuery<TripListResponse>({
    queryKey: ["trips", { status }],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      const params = status ? `?status=${status}` : "";
      return apiGet<TripListResponse>(`/trips${params}`, token);
    },
  });
}

export function useTrip(tripId: string) {
  const { getToken } = useAuth();
  return useQuery<Trip>({
    queryKey: ["trips", tripId],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<Trip>(`/trips/${tripId}`, token);
    },
    enabled: !!tripId,
  });
}

export function useCreateTrip() {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (data: Partial<Trip>) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPost<Trip>("/trips", token, data);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["trips"] }),
  });
}

export function useUpdateTrip(tripId: string) {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (data: Partial<Trip>) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPut<Trip>(`/trips/${tripId}`, token, data);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["trips"] });
      qc.invalidateQueries({ queryKey: ["trips", tripId] });
    },
  });
}

export function useDeleteTrip() {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (tripId: string) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiDelete(`/trips/${tripId}`, token);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["trips"] }),
  });
}
