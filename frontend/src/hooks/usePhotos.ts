import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiDelete, apiPost } from "@/lib/api";
import type { Photo, PhotoListResponse } from "@/types";

export function usePhotos(tripId: string) {
  const { getToken } = useAuth();
  return useQuery<PhotoListResponse>({
    queryKey: ["photos", tripId],
    queryFn: async () => {
      const token = await getToken();
      const res = await fetch(
        `${process.env.NEXT_PUBLIC_API_BASE}/api/v1/trips/${tripId}/photos`,
        { headers: { Authorization: `Bearer ${token}` } }
      );
      if (!res.ok) throw new Error("Failed to fetch photos");
      return res.json();
    },
    enabled: !!tripId,
  });
}

export function useUploadPhotos(tripId: string) {
  const queryClient = useQueryClient();
  const { getToken } = useAuth();
  return useMutation<Photo[], Error, File[]>({
    mutationFn: async (files: File[]) => {
      const token = await getToken();
      const results: Photo[] = [];
      for (const file of files) {
        const form = new FormData();
        form.append("file", file);
        const res = await fetch(
          `${process.env.NEXT_PUBLIC_API_BASE}/api/v1/trips/${tripId}/photos/upload`,
          { method: "POST", headers: { Authorization: `Bearer ${token}` }, body: form }
        );
        if (!res.ok) throw new Error(`Upload failed for ${file.name}`);
        results.push(await res.json());
      }
      return results;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["photos", tripId] });
    },
  });
}

export function useDeletePhoto(tripId: string) {
  const queryClient = useQueryClient();
  const { getToken } = useAuth();
  return useMutation<void, Error, string>({
    mutationFn: async (photoId: string) => {
      const token = await getToken();
      await apiDelete(`/photos/${photoId}`, token!);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["photos", tripId] });
    },
  });
}

export function useSetCoverPhoto(tripId: string) {
  const queryClient = useQueryClient();
  const { getToken } = useAuth();
  return useMutation<{ cover_photo_id: string }, Error, string>({
    mutationFn: async (photoId: string) => {
      const token = await getToken();
      return apiPost(`/photos/${photoId}/set-cover`, {}, token!);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["photos", tripId] });
      queryClient.invalidateQueries({ queryKey: ["trips"] });
    },
  });
}
