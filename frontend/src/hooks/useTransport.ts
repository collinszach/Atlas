import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiGet, apiPost, apiPut, apiDelete } from "@/lib/api";
import type { TransportLeg } from "@/types";

export function useTransport(tripId: string) {
  const { getToken } = useAuth();
  return useQuery<TransportLeg[]>({
    queryKey: ["transport", tripId],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<TransportLeg[]>(`/trips/${tripId}/transport`, token);
    },
  });
}

export function useAddTransport(tripId: string) {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (body: Partial<TransportLeg>) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPost<TransportLeg>(`/trips/${tripId}/transport`, token, body);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["transport", tripId] });
      qc.invalidateQueries({ queryKey: ["map", "arcs"] });
    },
  });
}

export function useUpdateTransport(tripId: string) {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...body }: Partial<TransportLeg> & { id: string }) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPut<TransportLeg>(`/transport/${id}`, token, body);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["transport", tripId] });
      qc.invalidateQueries({ queryKey: ["map", "arcs"] });
    },
  });
}

export function useDeleteTransport(tripId: string) {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (legId: string) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiDelete(`/transport/${legId}`, token);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["transport", tripId] });
      qc.invalidateQueries({ queryKey: ["map", "arcs"] });
    },
  });
}
