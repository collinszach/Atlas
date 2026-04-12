import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiGet, apiPost, apiPut, apiDelete } from "@/lib/api";
import type { Accommodation } from "@/types";

export function useAccommodations(tripId: string) {
  const { getToken } = useAuth();
  return useQuery<Accommodation[]>({
    queryKey: ["accommodations", tripId],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<Accommodation[]>(`/trips/${tripId}/accommodations`, token);
    },
  });
}

export function useAddAccommodation(tripId: string) {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (body: Partial<Accommodation>) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPost<Accommodation>(`/trips/${tripId}/accommodations`, token, body);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["accommodations", tripId] }),
  });
}

export function useUpdateAccommodation(tripId: string) {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...body }: Partial<Accommodation> & { id: string }) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPut<Accommodation>(`/accommodations/${id}`, token, body);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["accommodations", tripId] }),
  });
}

export function useDeleteAccommodation(tripId: string) {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (accId: string) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiDelete(`/accommodations/${accId}`, token);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["accommodations", tripId] }),
  });
}
