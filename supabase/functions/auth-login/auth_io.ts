export async function requestPasswordGrant(
  url: string,
  anonKey: string,
  email: string,
  password: string,
  fetchImpl: typeof fetch = fetch,
): Promise<Response | null> {
  try {
    return await fetchImpl(`${url}/auth/v1/token?grant_type=password`, {
      method: "POST",
      headers: {
        apikey: anonKey,
        "content-type": "application/json",
      },
      body: JSON.stringify({ email, password }),
      signal: AbortSignal.timeout(10_000),
    });
  } catch (_) {
    return null;
  }
}

export type LoginDecision = "recorded" | "locked" | "unavailable";

export async function runLoginDecisionRpc(
  operation: () => PromiseLike<{ data: unknown; error: unknown }>,
): Promise<LoginDecision> {
  try {
    const result = await operation();
    if (result.error != null || !result.data || typeof result.data !== "object") {
      return "unavailable";
    }
    const status = (result.data as { status?: unknown }).status;
    return status === "recorded" || status === "locked" ? status : "unavailable";
  } catch (_) {
    return "unavailable";
  }
}
