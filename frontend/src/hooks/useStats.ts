import { useQuery } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiGet } from "@/lib/api";
import type { UserStats } from "@/types";

export function useStats() {
  const { getToken } = useAuth();
  return useQuery<UserStats>({
    queryKey: ["stats"],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<UserStats>("/stats", token);
    },
  });
}
