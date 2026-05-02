import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiGet, apiPatch } from "@/lib/api";

export interface UserProfile {
  id: string;
  email: string;
  display_name: string | null;
  avatar_url: string | null;
  home_country: string | null;
}

export interface UserProfileUpdate {
  display_name?: string | null;
  home_country?: string | null;
}

export function useCurrentUser() {
  const { getToken } = useAuth();
  return useQuery<UserProfile>({
    queryKey: ["user", "me"],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<UserProfile>("/users/me", token);
    },
  });
}

export function useUpdateProfile() {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (body: UserProfileUpdate) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPatch<UserProfile>("/users/me", token, body);
    },
    onSuccess: (updated) => {
      qc.setQueryData(["user", "me"], updated);
    },
  });
}
