import { describe, it, expect, vi, beforeEach } from "vitest";
import { apiGet } from "../lib/api";

describe("API client", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("adds Authorization header when token provided", async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(JSON.stringify([]), { status: 200 })
    );
    vi.stubGlobal("fetch", fetchMock);

    await apiGet("/trips", "test-token-123");

    expect(fetchMock).toHaveBeenCalledWith(
      expect.stringContaining("/trips"),
      expect.objectContaining({
        headers: expect.objectContaining({
          Authorization: "Bearer test-token-123",
        }),
      })
    );
  });

  it("throws on non-OK response", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(new Response("Not found", { status: 404 }))
    );
    await expect(apiGet("/trips/bad-id", "token")).rejects.toThrow("404");
  });
});
