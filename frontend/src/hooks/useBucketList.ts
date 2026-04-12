import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiGet, apiPost, apiPut, apiDelete } from "@/lib/api";
import type { BucketListItem, BucketListCreate, BucketListUpdate } from "@/types";

export function useBucketList() {
  const { getToken } = useAuth();
  return useQuery<BucketListItem[]>({
    queryKey: ["bucket-list"],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<BucketListItem[]>("/bucket-list", token);
    },
  });
}

export function useAddBucketListItem() {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (body: BucketListCreate) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPost<BucketListItem>("/bucket-list", token, body);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["bucket-list"] }),
  });
}

export function useUpdateBucketListItem() {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...body }: BucketListUpdate & { id: string }) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPut<BucketListItem>(`/bucket-list/${id}`, token, body);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["bucket-list"] }),
  });
}

export function useDeleteBucketListItem() {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiDelete(`/bucket-list/${id}`, token);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["bucket-list"] }),
  });
}

export function useEnrichBucketListItem() {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPost<BucketListItem>(`/bucket-list/${id}/enrich`, token, {});
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["bucket-list"] }),
  });
}
