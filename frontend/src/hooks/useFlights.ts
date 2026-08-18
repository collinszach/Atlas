import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiGet, apiPost, apiPut, apiDelete } from "@/lib/api";
import type { TransportLeg } from "@/types";

export function useFlights() {
  const { getToken } = useAuth();
  return useQuery<TransportLeg[]>({
    queryKey: ["flights"],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<TransportLeg[]>("/flights", token);
    },
  });
}

export function useFlight(flightId: string) {
  const { getToken } = useAuth();
  const { data } = useFlights();
  return useQuery<TransportLeg | undefined>({
    queryKey: ["flights", flightId],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      const all = await apiGet<TransportLeg[]>("/flights", token);
      return all.find((f) => f.id === flightId);
    },
    enabled: !!flightId,
    initialData: data?.find((f) => f.id === flightId),
  });
}

export function useAddFlight() {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (body: Partial<TransportLeg>) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPost<TransportLeg>("/flights", token, body);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["flights"] });
      qc.invalidateQueries({ queryKey: ["map", "arcs"] });
      qc.invalidateQueries({ queryKey: ["stats"] });
    },
  });
}

export function useUpdateFlight() {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...body }: Partial<TransportLeg> & { id: string }) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPut<TransportLeg>(`/flights/${id}`, token, body);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["flights"] });
      qc.invalidateQueries({ queryKey: ["map", "arcs"] });
      qc.invalidateQueries({ queryKey: ["stats"] });
    },
  });
}

export function useDeleteFlight() {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (flightId: string) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiDelete(`/flights/${flightId}`, token);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["flights"] });
      qc.invalidateQueries({ queryKey: ["map", "arcs"] });
      qc.invalidateQueries({ queryKey: ["stats"] });
    },
  });
}
