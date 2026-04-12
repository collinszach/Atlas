const API_BASE = process.env.NEXT_PUBLIC_API_BASE ?? "http://localhost:8000";

async function request<T>(
  path: string,
  token: string,
  options: RequestInit = {}
): Promise<T> {
  const url = `${API_BASE}/api/v1${path}`;
  const res = await fetch(url, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
      ...options.headers,
    },
  });
  if (!res.ok) {
    throw new Error(`${res.status}: ${await res.text()}`);
  }
  if (res.status === 204) return undefined as T;
  return res.json() as Promise<T>;
}

export const apiGet = <T>(path: string, token: string): Promise<T> =>
  request<T>(path, token);

export const apiPost = <T>(path: string, token: string, body: unknown): Promise<T> =>
  request<T>(path, token, { method: "POST", body: JSON.stringify(body) });

export const apiPut = <T>(path: string, token: string, body: unknown): Promise<T> =>
  request<T>(path, token, { method: "PUT", body: JSON.stringify(body) });

export const apiDelete = (path: string, token: string): Promise<void> =>
  request<void>(path, token, { method: "DELETE" });

export const apiPatch = <T>(path: string, token: string, body: unknown): Promise<T> =>
  request<T>(path, token, { method: "PATCH", body: JSON.stringify(body) });
